#requires -Version 5.1
# Shared plumbing for the step-3 performance builds (New-PerfBuild.ps1) and the
# build matrix (Invoke-PerfMatrix.ps1): native process calls with exact UTF-8
# output, the fix manifest, and the per-build record each build carries.

Set-StrictMode -Version Latest

# Windows command-line quoting for one argument (the rules CommandLineToArgvW
# and the MSVC runtime use), so paths with spaces or quotes reach git intact.
function ConvertTo-ParallaxNativeArgument([string]$Value) {
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $builder = [Text.StringBuilder]::new('"')
    $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq [char]92) { $slashes++; continue }
        if ($character -eq [char]34) {
            $null = $builder.Append([char]92, $slashes * 2 + 1).Append([char]34)
        } else {
            if ($slashes) { $null = $builder.Append([char]92, $slashes) }
            $null = $builder.Append($character)
        }
        $slashes = 0
    }
    if ($slashes) { $null = $builder.Append([char]92, $slashes * 2) }
    $null = $builder.Append([char]34)
    $builder.ToString()
}

# Runs a console program without a window, returns exit code and UTF-8 output.
function Invoke-ParallaxNative {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [string]$WorkingDirectory = (Get-Location).Path,
        [hashtable]$Environment = @{}
    )
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $FilePath
    $info.Arguments = (@($ArgumentList | ForEach-Object { ConvertTo-ParallaxNativeArgument $_ }) -join ' ')
    $info.WorkingDirectory = $WorkingDirectory
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $info.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    foreach ($key in $Environment.Keys) { $info.EnvironmentVariables[$key] = [string]$Environment[$key] }
    $process = [Diagnostics.Process]::Start($info)
    try {
        $stderr = $process.StandardError.ReadToEndAsync()
        $stdout = $process.StandardOutput.ReadToEnd()
        $process.WaitForExit()
        [pscustomobject]@{ ExitCode = $process.ExitCode; Stdout = $stdout; Stderr = $stderr.Result }
    }
    finally { $process.Dispose() }
}

# git -C <Directory> <arguments>; throws with git's message unless -AllowFailure.
function Invoke-ParallaxGit {
    param(
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$AllowFailure,
        [string]$Git = 'git'
    )
    $result = Invoke-ParallaxNative -FilePath $Git -ArgumentList (@('-C', $Directory) + $Arguments) -WorkingDirectory $Directory -Environment @{ GIT_TERMINAL_PROMPT = '0'; GIT_EDITOR = 'false' }
    if ($result.ExitCode -ne 0 -and -not $AllowFailure) {
        $message = ($result.Stderr + $result.Stdout).Trim()
        throw "git $($Arguments -join ' ') failed ($($result.ExitCode)) in ${Directory}: $message"
    }
    $result
}

function Split-ParallaxNul([string]$Text) {
    @($Text.Split([char]0) | Where-Object { $_ -ne '' })
}

# The fix manifest (tools/perf-fixes.json): fixes, their commits, packages and
# support commits, with lookups by id and by commit.
function Read-ParallaxFixManifest {
    param([Parameter(Mandatory)][string]$Path)
    $manifest = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.schema -ne 1) { throw "Unsupported fix manifest schema in ${Path}: $($manifest.schema)" }
    $fixes = [ordered]@{}
    $order = 0
    foreach ($fix in @($manifest.fixes)) {
        if ($fixes.Contains($fix.id)) { throw "Duplicate fix id in manifest: $($fix.id)" }
        $fix | Add-Member -NotePropertyName Order -NotePropertyValue ($order++) -Force
        $fixes[$fix.id] = $fix
    }
    $packages = [ordered]@{}
    foreach ($package in @($manifest.packages)) {
        if ($fixes.Contains($package.id)) { throw "Package id collides with a fix id: $($package.id)" }
        $packages[$package.id] = @($fixes.Values | Where-Object { $_.package -eq $package.id } | ForEach-Object { $_.id })
    }
    foreach ($fix in $fixes.Values) {
        foreach ($required in @($fix.requires | Where-Object { $_ })) {
            if (-not $fixes.Contains($required)) { throw "Fix $($fix.id) requires unknown fix $required" }
            if ($fixes[$required].Order -ge $fix.Order) { throw "Fix $($fix.id) requires a later fix ($required); requirements must point back in history." }
        }
        $partners = if ($fix.PSObject.Properties['revertWith']) { @($fix.revertWith | Where-Object { $_ }) } else { @() }
        foreach ($partner in $partners) {
            if (-not $fixes.Contains($partner)) { throw "Fix $($fix.id) names unknown revertWith fix $partner" }
            if ($fixes[$partner].Order -le $fix.Order) { throw "Fix $($fix.id) names an earlier revertWith fix ($partner); revert partners must be later fixes." }
        }
    }
    [pscustomobject]@{
        Path     = (Resolve-Path -LiteralPath $Path).Path
        Data     = $manifest
        Fixes    = $fixes
        Packages = $packages
    }
}

# Expands fix ids and package ids into a sorted, de-duplicated fix id list.
# A unit token may join several ids with '+' (A2-1+A2-2) to measure them as one.
function Resolve-ParallaxFixUnit {
    param([Parameter(Mandatory)]$Manifest, [Parameter(Mandatory)][string[]]$Unit)
    $ids = [Collections.Generic.List[string]]::new()
    foreach ($token in $Unit) {
        foreach ($item in $token.Split([char[]]@(',', '+'))) {
            $item = $item.Trim()
            if (-not $item) { continue }
            if ($Manifest.Fixes.Contains($item)) { $ids.Add($item) }
            elseif ($Manifest.Packages.Contains($item)) { foreach ($id in $Manifest.Packages[$item]) { $ids.Add($id) } }
            else { throw "Unknown fix or package id: $item" }
        }
    }
    @($ids | Sort-Object -Unique | Sort-Object { $Manifest.Fixes[$_].Order })
}

# Fixes that must leave together with a set of fixes (all - unit): every fix
# that requires one of them, and every revert partner they name (a later fix
# whose change cannot be reverted around them), to a fixed point.
function Get-ParallaxFixDependents {
    param([Parameter(Mandatory)]$Manifest, [Parameter(Mandatory)][string[]]$Ids)
    $set = [Collections.Generic.HashSet[string]]::new([string[]]$Ids)
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($fix in $Manifest.Fixes.Values) {
            if ($set.Contains($fix.id)) {
                $partners = if ($fix.PSObject.Properties['revertWith']) { @($fix.revertWith | Where-Object { $_ }) } else { @() }
                foreach ($partner in $partners) { if ($set.Add($partner)) { $changed = $true } }
            } elseif (@(@($fix.requires) | Where-Object { $_ -and $set.Contains($_) }).Count) {
                if ($set.Add($fix.id)) { $changed = $true }
            }
        }
    }
    @($set | Where-Object { $_ -notin $Ids } | Sort-Object { $Manifest.Fixes[$_].Order })
}

# Scope: which repository paths a build applies. Include entries are path
# prefixes ('Skins/'); exclude entries are case-insensitive regular expressions
# matched against the slash-separated repository path.
function Test-ParallaxInScope {
    param([Parameter(Mandatory)][string]$Path, [string[]]$Include = @(), [string[]]$Exclude = @())
    $normal = $Path.Replace('\', '/')
    $included = ($Include.Count -eq 0)
    foreach ($prefix in $Include) {
        $p = $prefix.Replace('\', '/')
        if ($p -eq '' -or $p -eq '.' -or $p -eq '/') { $included = $true; break }
        if (-not $p.EndsWith('/')) { $p += '/' }
        if ($normal.StartsWith($p, [StringComparison]::OrdinalIgnoreCase) -or ($normal + '/').Equals($p, [StringComparison]::OrdinalIgnoreCase)) { $included = $true; break }
    }
    if (-not $included) { return $false }
    foreach ($pattern in $Exclude) { if ($normal -match $pattern) { return $false } }
    $true
}

# The record New-PerfBuild.ps1 writes into each build (build\perf-build.json,
# ignored by git).
function Get-ParallaxPerfBuildRecordPath([string]$BuildPath) { Join-Path $BuildPath 'build\perf-build.json' }

function Read-ParallaxPerfBuild {
    param([Parameter(Mandatory)][string]$BuildPath)
    $path = Get-ParallaxPerfBuildRecordPath $BuildPath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Not a perf build (no build\perf-build.json): $BuildPath" }
    Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

Export-ModuleMember -Function ConvertTo-ParallaxNativeArgument, Invoke-ParallaxNative, Invoke-ParallaxGit, Split-ParallaxNul,
    Read-ParallaxFixManifest, Resolve-ParallaxFixUnit, Get-ParallaxFixDependents, Test-ParallaxInScope, Get-ParallaxPerfBuildRecordPath, Read-ParallaxPerfBuild

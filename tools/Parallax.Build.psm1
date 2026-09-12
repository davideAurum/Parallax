Set-StrictMode -Version Latest

function Test-ParallaxChildPath {
    param([string]$Path, [string]$Parent)
    $prefix = [IO.Path]::GetFullPath($Parent).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    return [IO.Path]::GetFullPath($Path).StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
}

function Get-ParallaxExclusionReason {
    param([Parameter(Mandatory)][string]$RelativePath, [IO.FileAttributes]$Attributes = [IO.FileAttributes]::Normal)
    $segments = $RelativePath -split '[\\/]'
    if (@($segments | Where-Object { $_ -match '^\.|^(Cache|Caches|Runtime|Logs?|Temp|Tmp|Private|Secrets?|Tokens?|Credentials?|Tests?|QA|Fixtures|__pycache__)$' }).Count -gt 0) {
        return 'Private, hidden, developer, cache, or runtime path'
    }
    if (-not ($Attributes -band [IO.FileAttributes]::Directory) -and $RelativePath -match '(?i)(^|[\\/])[^\\/]*(secret|credential|token)[^\\/]*$|(^|[\\/])[^\\/]*\.(bak|tmp|log)$') {
        return 'Secret, credential, token, or transient filename'
    }
    if ($Attributes -band [IO.FileAttributes]::Hidden) { return 'Hidden file or directory' }
    return $null
}

function Get-ParallaxFiles {
    param(
        [Parameter(Mandatory)][string]$Root,
        [switch]$ProductionOnly,
        [Collections.Generic.List[object]]$ExcludedEntries = $null
    )
    $rootItem = Get-Item -LiteralPath $Root -Force -ErrorAction Stop
    if (-not $rootItem.PSIsContainer) { throw "Expected a directory: $Root" }
    if ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse points are not allowed: $Root" }
    $pending = [Collections.Generic.Stack[string]]::new()
    $pending.Push($rootItem.FullName)
    while ($pending.Count -gt 0) {
        foreach ($item in Get-ChildItem -LiteralPath $pending.Pop() -Force -ErrorAction Stop) {
            if (-not (Test-ParallaxChildPath $item.FullName $rootItem.FullName)) { throw "Path escaped source: $($item.FullName)" }
            if ($ProductionOnly) {
                $relative = Get-ParallaxRelativePath $item.FullName $rootItem.FullName
                $reason = Get-ParallaxExclusionReason $relative $item.Attributes
                if ($reason) {
                    if ($null -ne $ExcludedEntries) {
                        $kind = if ($item.PSIsContainer) { 'Directory' } else { 'File' }
                        $ExcludedEntries.Add([pscustomobject]@{ Path = $relative; Kind = $kind; Reason = $reason })
                    }
                    # Prune before pushing directories. QA may create/delete arbitrary
                    # contents below them while production validation is running.
                    continue
                }
            }
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse points are not allowed: $($item.FullName)" }
            if ($item.PSIsContainer) { $pending.Push($item.FullName) } else { $item }
        }
    }
}

function Get-ParallaxRelativePath {
    param([string]$Path, [string]$Root)
    if (-not (Test-ParallaxChildPath $Path $Root)) { throw "Path is outside root: $Path" }
    return [IO.Path]::GetFullPath($Path).Substring([IO.Path]::GetFullPath($Root).TrimEnd('\', '/').Length + 1)
}

Export-ModuleMember -Function Test-ParallaxChildPath, Get-ParallaxFiles, Get-ParallaxRelativePath, Get-ParallaxExclusionReason

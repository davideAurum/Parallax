#requires -Version 5.1
<#
.SYNOPSIS
Checks that upgrading the installed suite through Rainmeter's Skin Installer keeps saved settings.

.DESCRIPTION
The beta.1 check "Upgrades keep settings" (docs/ROADMAP.md, Stage 2), scripted. Without -Run it is a
dry run: it checks the preconditions, backs up the installed settings, builds the candidate package
and prints the plan, touching nothing that Rainmeter uses. With -Run, against the installed release:

  1. Writes probe values into four settings files through Rainmeter's own !WriteKeyValue (the path
     every settings panel uses): two Global Settings values, a countdown timer label with non-ASCII
     text and its duration, an emptied timer label, and one Disk Meter and one Network value.
  2. Opens the candidate package in Skin Installer and presses Cancel. Rainmeter must keep running
     and not one installed file may change.
  3. Opens it again and presses Install. Every settings file must then equal the candidate's
     defaults with each old value carried over wherever the key still exists, and each probe must
     survive byte for byte. The candidate is HEAD's skin plus one key that only it has
     (UpgradeTestNewDefault in Settings.inc), which must arrive with its packaged default. Every
     other shipped file must equal the candidate's.
  4. Restores: installs the published release package again (the test-only key must disappear and
     the probes must survive a second time), then copies the settings backed up in step 0 back
     byte for byte, refreshes the suite and unloads Welcome again if it was not loaded before.

Skin Installer is opened the way a double-click opens it (through Explorer), so the Rainmeter it
restarts inherits Explorer's environment, not this shell's. Its buttons are found through UI
Automation and pressed with the WM_COMMAND their own click sends. Rainmeter 4.5.28 carries values over with GetPrivateProfileSection/WritePrivateProfileString
(KeepVariables in Library/DialogInstall.cpp): only keys present in both the old and the new file are
copied, and only the first 32,767 characters of an old [Variables] section are read, so this script
also fails when any settings section comes near that limit.

Refuses to run while a second Rainmeter process is open: Skin Installer closes whichever Rainmeter
window it finds first. Evidence goes to build\upgrade-test-<time>\ (log, before/after copies,
results.json). If a step fails after the installed copy was changed, the restore still runs; the
backup folder printed at the start is the manual fallback.

.EXAMPLE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-ParallaxUpgrade.ps1
.EXAMPLE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-ParallaxUpgrade.ps1 -Run
#>
[CmdletBinding()]
param(
    # Perform the live steps. Without it, nothing Rainmeter uses is touched.
    [switch]$Run,
    # The Skins folder that holds the release. Default: SkinPath from Rainmeter's own settings file.
    [string]$SkinsPath,
    # Package that restores the installed release. Default: dist\Parallax_<installed version>.rmskin.
    [string]$ReleasePackage,
    # Seconds to wait for each Skin Installer run and for Rainmeter to come back.
    [int]$TimeoutSeconds = 180,
    # Leave the candidate installed with its probes (for inspection). The backup is still printed.
    [switch]$NoRestore
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Windows PowerShell only: its Encoding.Default is the ANSI code page that Rainmeter 4.5's INI calls write.
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Run this with powershell.exe (Windows PowerShell 5.1), not PowerShell 7.' }

# Files the loaded skins rewrite on their own (shipped defaults plus runtime state). They are reported
# when they change, never counted as an upgrade or cancel failure.
$runtimeFiles = @('@Resources\Update\State.inc', '@Resources\Modules\Media\CaptureState.inc', '@Resources\Modules\Visualizer\StandbyState.inc')
function Test-RuntimeFile([string]$Relative) { ($script:runtimeFiles -contains $Relative) -or $Relative -like '*.state' }
$installerError = $null

$ProjectRoot = (Get-Item -LiteralPath (Join-Path $PSScriptRoot '..')).FullName
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$evidence = Join-Path $ProjectRoot "build\upgrade-test-$stamp"
New-Item -ItemType Directory -Path $evidence | Out-Null
$logPath = Join-Path $evidence 'log.txt'
$ansi = [Text.Encoding]::Default
$results = [ordered]@{ Started = (Get-Date).ToString('o'); Mode = $(if ($Run) { 'Run' } else { 'DryRun' }); Checks = @() }
$failures = New-Object System.Collections.Generic.List[string]

function Write-Log([string]$Message) {
    $line = '{0}  {1}' -f (Get-Date).ToString('HH:mm:ss.fff'), $Message
    Write-Host $line
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
}

function Add-Check([string]$Name, [bool]$Passed, [string]$Detail = '') {
    $script:results.Checks += [ordered]@{ Name = $Name; Passed = $Passed; Detail = $Detail }
    Write-Log ('{0}  {1}{2}' -f $(if ($Passed) { 'PASS' } else { 'FAIL' }), $Name, $(if ($Detail) { " - $Detail" } else { '' }))
    if (-not $Passed) { $script:failures.Add($Name) }
}

function Get-Sha256([string]$Path) {
    # .NET directly: Get-FileHash fails in a Windows PowerShell started from PowerShell 7 (PSModulePath).
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $stream = [IO.File]::OpenRead($Path)
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') } finally { $stream.Dispose() }
    } finally { $sha.Dispose() }
}

function Get-TreeHashes([string]$Root) {
    $map = @{}
    Get-ChildItem -LiteralPath $Root -Recurse -File -Force | ForEach-Object {
        $map[$_.FullName.Substring($Root.Length + 1)] = Get-Sha256 $_.FullName
    }
    return $map
}

function Read-VariablesLines([string]$Path) {
    # Lines of the file and, for the [Variables] section, what KeepVariables sees: every line with an
    # '=' (comments included, exactly as GetPrivateProfileSection returns them) split at the first '='.
    $bytes = [IO.File]::ReadAllBytes($Path)
    $text = if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { [Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2) }
        elseif ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { [Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3) }
        else { $ansi.GetString($bytes) }
    $lines = [regex]::Split($text, '\r?\n')
    $section = ''
    $entries = @()
    $values = @{}
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $trimmed = $line.Trim()
        if ($trimmed -match '^\[(.+)\]$') { $section = $Matches[1]; continue }
        if ($section -ne 'Variables') { continue }
        $eq = $line.IndexOf('=')
        if ($eq -lt 0) { continue }
        $key = $line.Substring(0, $eq)
        $value = $line.Substring($eq + 1)
        $entries += [pscustomobject]@{ Index = $i; Key = $key; Value = $value }
        $values[$key] = $value
    }
    $sectionChars = 0
    $inVars = $false
    foreach ($line in $lines) {
        if ($line.Trim() -match '^\[(.+)\]$') { $inVars = ($Matches[1] -eq 'Variables'); continue }
        if ($inVars) { $sectionChars += $line.Length + 1 }
    }
    return [pscustomobject]@{ Lines = $lines; Entries = $entries; Values = $values; SectionChars = $sectionChars; Crlf = $text.Contains("`r`n") }
}

function Get-ExpectedLines($Candidate, $Old) {
    # Mirror of KeepVariables: the new file, with each key that also exists in the old file given its old value.
    $lines = [string[]]$Candidate.Lines.Clone()
    foreach ($entry in $Candidate.Entries) {
        if ($Old.Values.ContainsKey($entry.Key)) { $lines[$entry.Index] = $entry.Key + '=' + $Old.Values[$entry.Key] }
    }
    return $lines
}

function Compare-Lines([string[]]$Expected, [string[]]$Actual) {
    $diffs = @()
    $count = [Math]::Max($Expected.Count, $Actual.Count)
    for ($i = 0; $i -lt $count; $i++) {
        $e = if ($i -lt $Expected.Count) { $Expected[$i] } else { '<none>' }
        $a = if ($i -lt $Actual.Count) { $Actual[$i] } else { '<none>' }
        if ($e -cne $a) { $diffs += "line $($i + 1): expected '$e', found '$a'" }
    }
    return $diffs
}

function Get-RainmeterProcesses {
    @(Get-CimInstance Win32_Process -Filter "Name='Rainmeter.exe'" | Select-Object ProcessId, ExecutablePath, CommandLine)
}

function Invoke-RainmeterBang([string[]]$Arguments) {
    # Windows PowerShell drops an empty argument on its way to a program; pass it as "" instead.
    $quoted = @($Arguments | ForEach-Object { if ($_ -eq '') { '""' } else { $_ } })
    & $script:rainmeterExe @quoted
}

function Wait-Until([scriptblock]$Condition, [int]$Seconds, [int]$PollMs = 250) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        $value = & $Condition
        if ($value) { return $value }
        Start-Sleep -Milliseconds $PollMs
    }
    return $null
}

Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$uia = [System.Windows.Automation.AutomationElement]
$tree = [System.Windows.Automation.TreeScope]

function Get-InstallerWindows {
    $name = New-Object System.Windows.Automation.PropertyCondition($uia::NameProperty, 'Rainmeter Skin Installer')
    @($uia::RootElement.FindAll($tree::Children, $name))
}

# Skin Installer's controls reach UI Automation only as panes with their Win32 class names and no
# Invoke pattern, so a button is found by class and caption and pressed with the WM_COMMAND/BN_CLICKED
# its own click sends to the dialog (which, unlike BM_CLICK, does not need the dialog to be active).
Add-Type -Namespace ParallaxUpgradeTest -Name Win32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr hWnd);
[DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr hWnd);
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
'@

function Find-Control($Window, [string]$ClassName, [string]$Name) {
    $Window.FindFirst($tree::Descendants, (New-Object System.Windows.Automation.AndCondition(
        (New-Object System.Windows.Automation.PropertyCondition($uia::ClassNameProperty, $ClassName)),
        (New-Object System.Windows.Automation.PropertyCondition($uia::NameProperty, $Name)))))
}

function Get-WindowText($Window) {
    $static = New-Object System.Windows.Automation.PropertyCondition($uia::ClassNameProperty, 'Static')
    (@($Window.FindAll($tree::Descendants, $static)) | ForEach-Object { $_.Current.Name } | Where-Object { $_ }) -join ' | '
}

function Push-Button($Button) {
    $hwnd = [IntPtr]$Button.Current.NativeWindowHandle
    $id = [ParallaxUpgradeTest.Win32]::GetDlgCtrlID($hwnd)
    $parent = [ParallaxUpgradeTest.Win32]::GetParent($hwnd)
    if (-not [ParallaxUpgradeTest.Win32]::PostMessage($parent, 0x0111, [IntPtr]$id, $hwnd)) { throw "Could not press '$($Button.Current.Name)'." }
}

function Invoke-InstallerButton($Window, [string]$Name) {
    $button = Wait-Until { Find-Control $Window 'Button' $Name } 10
    if (-not $button) { throw "Skin Installer has no '$Name' button." }
    if (-not $button.Current.IsEnabled) { throw "Skin Installer's '$Name' button is disabled." }
    Push-Button $button
}

function Invoke-SkinInstaller([string]$Package, [ValidateSet('Install', 'Cancel')][string]$Button) {
    if (Get-Process -Name SkinInstaller -ErrorAction SilentlyContinue) { throw 'Skin Installer is already open; close it first.' }
    Write-Log "Opening $([IO.Path]::GetFileName($Package)) in Skin Installer through Explorer, then pressing $Button."
    Start-Process -FilePath (Join-Path $env:WINDIR 'explorer.exe') -ArgumentList ('"{0}"' -f $Package)
    $window = Wait-Until { Get-InstallerWindows | Select-Object -First 1 } 30
    if (-not $window) { throw 'Skin Installer did not open within 30 seconds.' }
    $heading = Get-WindowText $window
    Write-Log "Skin Installer shows: $heading"
    Invoke-InstallerButton $window $Button
    $closed = Wait-Until {
        foreach ($w in Get-InstallerWindows) {
            # A second window with the same title is Skin Installer's error box.
            $ok = Find-Control $w 'Button' 'OK'
            if ($ok) { $script:installerError = Get-WindowText $w; Push-Button $ok }
        }
        -not (Get-Process -Name SkinInstaller -ErrorAction SilentlyContinue)
    } $TimeoutSeconds 500
    if (-not $closed) { throw "Skin Installer was still open after $TimeoutSeconds seconds." }
    if ($script:installerError) { $message = $script:installerError; $script:installerError = $null; throw "Skin Installer reported: $message" }
    Write-Log 'Skin Installer closed.'
}

function Wait-Rainmeter {
    $proc = Wait-Until { Get-RainmeterProcesses | Select-Object -First 1 } 30
    if (-not $proc) { throw 'Rainmeter did not come back within 30 seconds.' }
    Start-Sleep -Seconds 5   # let it finish loading before bangs and file reads
    return $proc
}

function Get-WelcomeActive([string]$IniPath) {
    $text = [IO.File]::ReadAllText($IniPath)
    $m = [regex]::Match($text, '(?ms)^\[Parallax\\Welcome\]\s*$(.*?)(?=^\[|\z)')
    if (-not $m.Success) { return $false }
    return [regex]::IsMatch($m.Groups[1].Value, '(?m)^Active=1\s*$')
}

# --- 0. Preconditions --------------------------------------------------------------------------
Write-Log "Upgrade-safety test, $($results.Mode). Evidence: $evidence"
$rainmeterIni = Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'
if (-not $SkinsPath) {
    $m = [regex]::Match([IO.File]::ReadAllText($rainmeterIni), '(?m)^SkinPath=([^\r\n]+)')
    if (-not $m.Success) { throw "No SkinPath in $rainmeterIni; pass -SkinsPath." }
    $SkinsPath = $m.Groups[1].Value.Trim()
}
$installed = Join-Path $SkinsPath 'Parallax'
$userDir = Join-Path $installed '@Resources\User'
if (-not (Test-Path -LiteralPath $userDir -PathType Container)) { throw "No installed Parallax at $installed." }

$procs = @(Get-RainmeterProcesses)
$normal = @($procs | Where-Object { $_.CommandLine -notmatch 'Rainmeter\.exe"?\s+\S' })
if (-not $normal) { throw 'Rainmeter is not running on its normal profile.' }
$list = ($procs | ForEach-Object { "PID $($_.ProcessId): $($_.CommandLine.Trim())" }) -join '; '
Add-Check 'Only one Rainmeter is running (Skin Installer closes whichever it finds first)' ($procs.Count -eq 1) $list
$rainmeterExe = $normal[0].ExecutablePath
$rainmeterPid = $normal[0].ProcessId
$installerExe = Join-Path (Split-Path $rainmeterExe) 'SkinInstaller.exe'
$installerVersion = (Get-Item -LiteralPath $installerExe).VersionInfo.FileVersion
Write-Log "Rainmeter PID $rainmeterPid ($rainmeterExe), Skin Installer $installerVersion, skins in $SkinsPath."

$installedVersion = ([regex]::Match([IO.File]::ReadAllText((Join-Path $installed '@Resources\Version.inc')), '(?m)^ParallaxVersion=(\S+)')).Groups[1].Value
$releaseVersion = (Get-Content -LiteralPath (Join-Path $ProjectRoot 'packaging\release.json') -Raw | ConvertFrom-Json).version
if (-not $ReleasePackage) { $ReleasePackage = Join-Path $ProjectRoot "dist\Parallax_$installedVersion.rmskin" }
if (-not (Test-Path -LiteralPath $ReleasePackage -PathType Leaf)) { throw "Restore package not found: $ReleasePackage" }
$releaseSha = Get-Sha256 $ReleasePackage
$recordedSha = if (Test-Path -LiteralPath "$ReleasePackage.sha256") { ((Get-Content -LiteralPath "$ReleasePackage.sha256" -Raw) -split '\s+')[0].ToUpperInvariant() } else { '' }
Add-Check 'Restore package matches its recorded SHA-256' ($recordedSha -and $releaseSha -eq $recordedSha) "$([IO.Path]::GetFileName($ReleasePackage)) $releaseSha"
Add-Check 'Installed version is the version being built' ($installedVersion -eq $releaseVersion) "installed $installedVersion, release.json $releaseVersion"

foreach ($file in Get-ChildItem -LiteralPath $userDir -Filter *.inc) {
    $chars = (Read-VariablesLines $file.FullName).SectionChars
    Add-Check "$($file.Name) [Variables] fits Skin Installer's 32,767-character read" ($chars -lt 30000) "$chars characters"
}
if ($failures.Count -and $Run) { throw "Preconditions failed: $($failures -join '; ')" }

# Backup: the user's own settings and Rainmeter's settings file, before anything is written.
$before = Join-Path $evidence 'before'
New-Item -ItemType Directory -Path (Join-Path $before 'User') | Out-Null
Copy-Item -Path (Join-Path $userDir '*.inc') -Destination (Join-Path $before 'User')
Copy-Item -LiteralPath $rainmeterIni -Destination $before
$welcomeWasActive = Get-WelcomeActive $rainmeterIni
Write-Log "Backed up settings to $before (Welcome loaded before: $welcomeWasActive)."

# --- Candidate package: HEAD's skin plus one key only the candidate has ------------------------
$src = Join-Path $evidence 'src'
New-Item -ItemType Directory -Path $src | Out-Null
$zip = Join-Path $evidence 'src.zip'
$head = (& git -C $ProjectRoot rev-parse --short HEAD).Trim()
& git -C $ProjectRoot archive --format=zip -o $zip HEAD Skins/Parallax packaging
if ($LASTEXITCODE) { throw 'git archive failed.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($zip, $src)
Remove-Item -LiteralPath $zip
$probeFile = Join-Path $src 'Skins\Parallax\@Resources\User\Settings.inc'
$probeText = $ansi.GetString([IO.File]::ReadAllBytes($probeFile))
$newline = if ($probeText.Contains("`r`n")) { "`r`n" } else { "`n" }
if (-not $probeText.EndsWith($newline)) { $probeText += $newline }
$probeText += "; Upgrade-test probe: exists only in the candidate package.$newline" + "UpgradeTestNewDefault=from-package$newline"
[IO.File]::WriteAllBytes($probeFile, $ansi.GetBytes($probeText))
Write-Log "Building the candidate from HEAD $head plus UpgradeTestNewDefault in Settings.inc."
$candidateOut = Join-Path $evidence 'candidate'
& (Join-Path $PSScriptRoot 'Package-Parallax.ps1') -ProjectRoot $src -OutputDirectory $candidateOut -NoReadme -Force | Out-File -LiteralPath (Join-Path $evidence 'package.log') -Encoding UTF8
$candidate = Get-ChildItem -LiteralPath $candidateOut -Filter '*.rmskin' | Select-Object -First 1
if (-not $candidate) { throw "Package-Parallax produced no .rmskin; see $evidence\package.log." }
$candidateStage = Get-ChildItem -LiteralPath (Join-Path $src 'build') -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$candidateSkin = Join-Path $candidateStage.FullName 'Skins\Parallax'
Write-Log "Candidate: $($candidate.FullName) ($(Get-Sha256 $candidate.FullName))."

# Probes: (file, key, value). The empty label and the non-ASCII label are the ones most likely to be lost.
$probes = @(
    @{ File = 'Settings.inc'; Key = 'AccentColor2'; Value = '200,120,40' },
    @{ File = 'Settings.inc'; Key = 'Gutter'; Value = '9' },
    @{ File = 'Chronometer.inc'; Key = 'ChronometerList3Timer1Label'; Value = "Caf$([char]0xE9) $([char]0xC5)ngstr$([char]0xF6)m" },
    @{ File = 'Chronometer.inc'; Key = 'ChronometerList3Timer1Seconds'; Value = '75' },
    @{ File = 'Chronometer.inc'; Key = 'ChronometerList3Timer2Label'; Value = '' },
    @{ File = 'IO.inc'; Key = 'IODiskMaxMiBs'; Value = '1500' },
    @{ File = 'Network.inc'; Key = 'NetworkInCeilingMbps'; Value = '250' }
)
foreach ($p in $probes) {
    $old = (Read-VariablesLines (Join-Path $userDir $p.File)).Values
    if (-not $old.ContainsKey($p.Key)) { throw "Probe key $($p.Key) is not in the installed $($p.File)." }
    if ($old[$p.Key] -ceq $p.Value) { throw "Probe $($p.Key) already has the probe value; pick another." }
    Write-Log ("Probe {0} {1}: '{2}' -> '{3}'" -f $p.File, $p.Key, $old[$p.Key], $p.Value)
}

if (-not $Run) {
    $results.Finished = (Get-Date).ToString('o')
    $results.Failures = @($failures)
    $results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidence 'results.json') -Encoding UTF8
    if ($failures.Count) { Write-Log "Dry run: the candidate is built, but -Run would stop on: $($failures -join '; ')"; exit 1 }
    Write-Log 'Dry run complete: preconditions hold, settings are backed up, the candidate is built. Run again with -Run to perform the upgrade.'
    exit 0
}

$changed = $false
try {
    # --- 1. Probes through Rainmeter's own writer ------------------------------------------------
    foreach ($p in $probes) {
        $path = Join-Path $userDir $p.File
        Invoke-RainmeterBang @('!WriteKeyValue', 'Variables', $p.Key, $p.Value, $path)
        $changed = $true
        $ok = Wait-Until { (Read-VariablesLines $path).Values[$p.Key] -ceq $p.Value } 10
        Add-Check "Probe written: $($p.File) $($p.Key)" ([bool]$ok)
    }
    if ($failures.Count) { throw 'A probe could not be written.' }
    $preInstall = Join-Path $evidence 'pre-install'
    New-Item -ItemType Directory -Path $preInstall | Out-Null
    Copy-Item -Path (Join-Path $userDir '*.inc') -Destination $preInstall
    $preTree = Get-TreeHashes $installed

    # --- 2. Cancel leaves everything as it was ---------------------------------------------------
    Invoke-SkinInstaller $candidate.FullName 'Cancel'
    $still = Get-RainmeterProcesses
    Add-Check 'Cancel: Rainmeter kept running' (@($still | Where-Object ProcessId -eq $rainmeterPid).Count -eq 1) "PID $rainmeterPid"
    $postCancel = Get-TreeHashes $installed
    $changedAll = @(@($preTree.Keys) + @($postCancel.Keys) | Sort-Object -Unique | Where-Object { $preTree[$_] -ne $postCancel[$_] })
    $changedFiles = @($changedAll | Where-Object { -not (Test-RuntimeFile $_) })
    $churn = @($changedAll | Where-Object { Test-RuntimeFile $_ })
    if ($churn) { Write-Log "Runtime files the skins rewrote meanwhile: $($churn -join ', ')" }
    Add-Check 'Cancel: no installed file changed' ($changedFiles.Count -eq 0) $(if ($changedFiles) { $changedFiles -join ', ' } else { "$($preTree.Count) files compared" })

    # --- 3. Install keeps every value whose key still exists -------------------------------------
    Invoke-SkinInstaller $candidate.FullName 'Install'
    $proc = Wait-Rainmeter
    Write-Log "Rainmeter is back as PID $($proc.ProcessId)."
    $afterCandidate = Join-Path $evidence 'after-candidate'
    New-Item -ItemType Directory -Path $afterCandidate | Out-Null
    Copy-Item -Path (Join-Path $userDir '*.inc') -Destination $afterCandidate

    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $candidateSkin '@Resources\User') -Filter *.inc) {
        $old = Read-VariablesLines (Join-Path $preInstall $file.Name)
        $new = Read-VariablesLines $file.FullName
        $actual = Read-VariablesLines (Join-Path $userDir $file.Name)
        $diffs = @(Compare-Lines (Get-ExpectedLines $new $old) $actual.Lines)
        Add-Check "Install: $($file.Name) is the new file with old values carried over" ($diffs.Count -eq 0) ($diffs -join '; ')
    }
    foreach ($p in $probes) {
        $value = (Read-VariablesLines (Join-Path $userDir $p.File)).Values[$p.Key]
        Add-Check "Install: probe kept, $($p.File) $($p.Key)" ($value -ceq $p.Value) "found '$value'"
    }
    $newDefault = (Read-VariablesLines (Join-Path $userDir 'Settings.inc')).Values['UpgradeTestNewDefault']
    Add-Check 'Install: a key only the new package has arrives with its default' ($newDefault -ceq 'from-package') "found '$newDefault'"
    $stageTree = Get-TreeHashes $candidateSkin
    $installedTree = Get-TreeHashes $installed
    $wrong = @($stageTree.Keys | Where-Object { $_ -notlike '@Resources\User\*' -and -not (Test-RuntimeFile $_) -and $installedTree[$_] -ne $stageTree[$_] })
    Add-Check 'Install: every other shipped file equals the candidate' ($wrong.Count -eq 0) $(if ($wrong) { $wrong -join ', ' } else { "$($stageTree.Count) files" })
    $extra = @($installedTree.Keys | Where-Object { -not $stageTree.ContainsKey($_) })
    if ($extra) { Write-Log "Files present but not shipped (runtime state written after load): $($extra -join ', ')" }
}
catch {
    Add-Check 'Run completed without an error' $false $_.Exception.Message
}
finally {
    if ($changed -and -not $NoRestore) {
        # --- 4. Restore: the published release, then the user's own settings ----------------------
        try {
            if (-not (Get-RainmeterProcesses)) { Start-Process -FilePath $rainmeterExe; Wait-Rainmeter | Out-Null }
            Invoke-SkinInstaller $ReleasePackage 'Install'
            Wait-Rainmeter | Out-Null
            $settings = Read-VariablesLines (Join-Path $userDir 'Settings.inc')
            Add-Check 'Restore: the test-only key is gone with the release package' (-not $settings.Values.ContainsKey('UpgradeTestNewDefault'))
            foreach ($p in $probes) {
                $value = (Read-VariablesLines (Join-Path $userDir $p.File)).Values[$p.Key]
                Add-Check "Restore: probe kept again, $($p.File) $($p.Key)" ($value -ceq $p.Value) "found '$value'"
            }
            $afterRelease = Join-Path $evidence 'after-release'
            New-Item -ItemType Directory -Path $afterRelease | Out-Null
            Copy-Item -Path (Join-Path $userDir '*.inc') -Destination $afterRelease

            Copy-Item -Path (Join-Path $before 'User\*.inc') -Destination $userDir -Force
            $same = @(Get-ChildItem -LiteralPath (Join-Path $before 'User') -Filter *.inc | Where-Object { (Get-Sha256 $_.FullName) -ne (Get-Sha256 (Join-Path $userDir $_.Name)) })
            Add-Check 'Restore: settings are byte-identical to the backup' ($same.Count -eq 0) $(if ($same) { $same.Name -join ', ' } else { '' })
            Invoke-RainmeterBang @('!RefreshGroup', 'Parallax')
            if (-not $welcomeWasActive) { Invoke-RainmeterBang @('!DeactivateConfig', 'Parallax\Welcome') }
            Write-Log 'Restored the release and the backed-up settings, and refreshed the suite.'
        }
        catch {
            Add-Check 'Restore completed' $false "$($_.Exception.Message). Copy $before\User\*.inc back into $userDir by hand."
        }
    }
    elseif ($changed) {
        Write-Log "NoRestore: the candidate and its probes stay installed. Backup: $before"
    }
    $results.Finished = (Get-Date).ToString('o')
    $results.Failures = @($failures)
    $results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidence 'results.json') -Encoding UTF8
}

if ($failures.Count) { Write-Log "FAILED: $($failures.Count) check(s): $($failures -join '; ')"; exit 1 }
Write-Log "All $(@($results.Checks).Count) checks passed."
exit 0

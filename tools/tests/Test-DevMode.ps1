#requires -Version 5.1
<#
Checks the developer copy engine (Skins\Parallax\@Resources\Dev\DevCopy.psm1, DevMode.ps1) and
tools\Sync-ParallaxDev.ps1 against throwaway trees. Nothing here reads or writes a live Rainmeter
installation: every Skins folder, settings folder and "project" is created below a fresh directory in
%TEMP%, and Rainmeter is never started or sent a bang (-NoRefresh).

Run: .\tools\tests\Test-DevMode.ps1   (prints PASS <assertions> or throws on the first failure)
#>
[CmdletBinding()]
param([switch]$KeepWork)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$module = Join-Path $repo 'Skins\Parallax\@Resources\Dev\DevCopy.psm1'
$cli = Join-Path $repo 'Skins\Parallax\@Resources\Dev\DevMode.ps1'
Import-Module $module -Force
$assertions = 0
function Assert-That([bool]$Condition, [string]$Message) {
    $script:assertions++
    if (-not $Condition) { throw "FAILED: $Message" }
}
function Assert-Equal($Actual, $Expected, [string]$Message) {
    $script:assertions++
    if ($Actual -ne $Expected) { throw "FAILED: $Message (expected '$Expected', got '$Actual')" }
}
function Get-Status([string]$DevRoot) {
    $values = @{}
    foreach ($line in Get-Content -LiteralPath (Join-Path $DevRoot '@Resources\Dev\Status.inc')) {
        if ($line -match '^(Dev\w+)=(.*)$') { $values[$Matches[1]] = $Matches[2] }
    }
    return $values
}
function Edit-Text([string]$Path, [scriptblock]$Change) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $text = (Read-ParallaxDevText $bytes)
    [IO.File]::WriteAllBytes($Path, (ConvertTo-ParallaxDevBytes $text.Kind (& $Change $text.Text)))
}
function Invoke-Cli([string[]]$Arguments) {
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $cli @Arguments 2>&1
    return [pscustomobject]@{ Exit = $LASTEXITCODE; Lines = @($output | ForEach-Object { [string]$_ }) }
}

$work = Join-Path ([IO.Path]::GetTempPath()) ('Parallax-DevModeTest-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $work
try {
    # ---- pure functions --------------------------------------------------------------------------------------------
    $rewrite = { param([string]$Text, [string]$Ext = '.ini') [Text.Encoding]::UTF8.GetString((ConvertTo-ParallaxDevRewrite ([Text.Encoding]::UTF8.GetBytes($Text)) $Ext)) }
    Assert-Equal (& $rewrite 'ContextAction=[!ActivateConfig "Parallax\Settings" "Settings.ini"]') 'ContextAction=[!ActivateConfig "ParallaxDev\Settings" "Settings.ini"]' 'INI config reference'
    Assert-Equal (& $rewrite "SKIN:Bang('!ActivateConfig', 'Parallax\\ColorPicker', 'ColorPicker.ini')" '.lua') "SKIN:Bang('!ActivateConfig', 'ParallaxDev\\ColorPicker', 'ColorPicker.ini')" 'Lua doubled backslashes'
    Assert-Equal (& $rewrite '!ActivateConfig "Parallax\Media\Settings" "Settings.ini"') '!ActivateConfig "ParallaxDev\Media\Settings" "Settings.ini"' 'nested config'
    foreach ($same in 'Group=Parallax | ParallaxCPU', 'ParallaxIdleHeadline=MeterTitle', '!RefreshGroup Parallax', 'ParallaxVersion=1', 'Parallax\Unknown', 'XParallax\CPU', 'ParallaxDev\CPU', 'Parallax\CPUs') {
        Assert-Equal (& $rewrite $same) $same "must stay: $same"
    }
    Assert-Equal (& $rewrite 'Temp\Parallax\Update' '.ps1') 'Temp\Parallax\Update' 'only .ini/.inc/.lua are rewritten'
    $crlf = [Text.Encoding]::UTF8.GetBytes("A=Parallax\RAM`r`nB=1`r`n")
    Assert-Equal ([Text.Encoding]::UTF8.GetString((ConvertTo-ParallaxDevRewrite $crlf '.inc'))) "A=ParallaxDev\RAM`r`nB=1`r`n" 'CRLF preserved'
    $utf16 = ConvertTo-ParallaxDevBytes 'utf16le' "x='Parallax\\Media'"
    $out = ConvertTo-ParallaxDevRewrite $utf16 '.lua'
    Assert-That ($out[0] -eq 0xFF -and $out[1] -eq 0xFE) 'UTF-16LE BOM kept'
    Assert-Equal ([Text.Encoding]::Unicode.GetString($out, 2, $out.Length - 2)) "x='ParallaxDev\\Media'" 'UTF-16LE rewritten'
    $plain = [byte[]](1, 2, 3, 4, 5)
    Assert-That ([object]::ReferenceEquals((ConvertTo-ParallaxDevRewrite $plain '.ttf'), $plain) -or ((ConvertTo-ParallaxDevRewrite $plain '.ttf') -join ',') -eq '1,2,3,4,5') 'binary untouched'

    $area = { param($p) $a = Get-ParallaxDevArea $p; if ($null -eq $a) { '<ignored>' } else { $a } }
    foreach ($case in @(
        @('CPU\CPU.ini', 'CPU'), @('IO\IO-Disk.ini', 'IO'), @('CPU\Settings\Settings.ini', 'CPU'),
        @('@Resources\Modules\GPU\Meters.inc', 'GPU'), @('Settings\Settings.ini', 'Suite'), @('Idle\Idle.ini', 'Suite'),
        @('@Resources\Modules\Welcome\Welcome.lua', 'Suite'), @('@Resources\Scripts\Settings.lua', 'Suite'),
        @('@Resources\Scripts\SettingsInput.ps1', 'Shared'), @('@Resources\Defaults.inc', 'Shared'), @('@Resources\Styles.inc', 'Shared'),
        @('@Resources\Idle\Hook.inc', 'Shared'), @('@Resources\Fonts\x.ttf', 'Shared'), @('@Resources\Dev\Hook1.inc', 'Shared'),
        @('@Resources\User\CPU.inc', '<ignored>'), @('@Resources\User\Settings.inc', '<ignored>'),
        @('@Resources\Update\State.inc', '<ignored>'), @('@Resources\Dev\Status.inc', '<ignored>'),
        @('@Resources\Dev\Diff.txt', '<ignored>'), @('@Resources\Dev\DevStatus.lua', '<ignored>'),
        @('@Resources\Dev\DevCopy.psm1', '<ignored>'), @('@Resources\Dev\Icons\Lucide\README.md', '<ignored>'),
        @('@Resources\Dev\Hook0.inc', 'Shared'),@('@Resources\Modules\Media\CaptureState.inc', '<ignored>')
    )) { Assert-Equal (& $area $case[0]) $case[1] "area of $($case[0])" }

    $hash = { param([string]$Text, [string]$Ext = '.ini') Get-ParallaxDevHash ([Text.Encoding]::UTF8.GetBytes($Text)) $Ext }
    Assert-Equal (& $hash "a`r`nb`r`n") (& $hash "a`nb`n") 'CRLF and LF hash alike'
    Assert-That ((& $hash 'a') -ne (& $hash 'b')) 'different text hashes differently'
    Assert-That ((Get-ParallaxDevHash ([byte[]](0xEF, 0xBB, 0xBF, 0x61)) '.ini') -ne (Get-ParallaxDevHash ([byte[]](0x61)) '.ini')) 'a BOM is a difference'
    Assert-That ((Get-ParallaxDevHash ([byte[]](13, 10)) '.ttf') -ne (Get-ParallaxDevHash ([byte[]](10)) '.ttf')) 'binary files compare byte for byte'

    # Placement geometry: beside the release window, never over another window or off the work area.
    $areas = @([pscustomobject]@{ Left = 0; Top = 0; Right = 1000; Bottom = 800 })
    $win = { param($n, $l, $t, $r, $b) [pscustomobject]@{ Name = $n; Left = $l; Top = $t; Right = $r; Bottom = $b } }
    $p = Get-ParallaxDevPlacements -Windows @(& $win 'a' 100 100 300 300) -WorkAreas $areas
    Assert-Equal ($p['a'] -join ',') '300,100' 'right of the release window'
    $p = Get-ParallaxDevPlacements -Windows @(& $win 'a' 800 100 1000 300) -WorkAreas $areas
    Assert-Equal ($p['a'] -join ',') '600,100' 'left when the right side is off the work area'
    $p = Get-ParallaxDevPlacements -Windows @(& $win 'a' 0 0 1000 300) -WorkAreas $areas
    Assert-Equal ($p['a'] -join ',') '0,300' 'below when neither side fits'
    $both = @((& $win 'a' 100 100 300 300), (& $win 'b' 300 100 500 300))
    $p = Get-ParallaxDevPlacements -Windows $both -WorkAreas $areas
    Assert-Equal ($p['a'] -join ',') '100,300' 'a: its right is b, its left is off the work area, so below'
    Assert-Equal ($p['b'] -join ',') '500,100' 'b: right of its window, clear of a''s copy'
    $p = Get-ParallaxDevPlacements -Windows @(& $win 'a' 0 0 1000 800) -WorkAreas $areas
    Assert-That (-not $p.ContainsKey('a')) 'no spot: the window is left to Rainmeter'

    # ---- a throwaway release, built the way a release is: the staged skin ---------------------------------------
    $stageOutput = @(& (Join-Path $repo 'tools\Stage-Parallax.ps1') -Version 'devmode-test' -SkipValidation 6>$null)
    $stage = $stageOutput[-1]
    $skins = Join-Path $work 'Skins'
    $release = Join-Path $skins 'Parallax'
    $dev = Join-Path $skins 'ParallaxDev'
    $null = New-Item -ItemType Directory -Path $skins
    Copy-Item -LiteralPath $stage.SkinRoot -Destination $release -Recurse
    $settingsFolder = Join-Path $work 'Settings'
    $null = New-Item -ItemType Directory -Path $settingsFolder
    $bom = [byte[]](0xFF, 0xFE)
    $iniText = "[Rainmeter]`r`nSkinPath=$skins\`r`n`r`n[Parallax\CPU]`r`nActive=1`r`n`r`n[Parallax\RAM]`r`nActive=1`r`n`r`n[Parallax\Media]`r`nActive=2`r`n`r`n[Parallax\Settings]`r`nActive=1`r`n"
    [IO.File]::WriteAllBytes((Join-Path $settingsFolder 'Rainmeter.ini'), ($bom + [Text.Encoding]::Unicode.GetBytes($iniText)))
    $releaseFiles = @(Get-ParallaxDevFiles $release)
    $releaseHashBefore = (Get-ChildItem -LiteralPath $release -Recurse -File | ForEach-Object { (Get-FileHash -LiteralPath $_.FullName).Hash }) -join ''

    # ---- Enable: clone, compare, list what to load --------------------------------------------------------------
    $r = Invoke-Cli @('-Action', 'Enable', '-SkinsPath', ($skins + '\.'), '-SettingsPath', ($settingsFolder + '\.'), '-NoPlace')
    Assert-Equal $r.Exit 0 'Enable exits 0'
    Assert-Equal $r.Lines[0].Substring(0, 22) 'RESULT|OK|Enable|0|0|c' 'Enable result: no differences'
    Assert-Equal (@(Get-ParallaxDevFiles $dev).Count) $releaseFiles.Count 'the copy has every release file'
    $config = @($r.Lines | Where-Object { $_ -like 'CONFIG|*' })
    Assert-Equal ($config -join ';') 'CONFIG|ParallaxDev\CPU|CPU.ini|-|-;CONFIG|ParallaxDev\Media|Setup.ini|-|-;CONFIG|ParallaxDev\RAM|RAM.ini|-|-' 'Enable lists the release''s loaded utilities, with the loaded file (Media Active=2 is Setup.ini)'
    Assert-That (Test-ParallaxDevIdentity $dev) 'the copy is marked'
    $userSettings = Get-Content -LiteralPath (Join-Path $dev '@Resources\User\Settings.inc') -Raw
    Assert-That ($userSettings -match '(?m)^ParallaxDevBuild=1\s*$') 'dev flag written'
    Assert-That ($userSettings -match '(?m)^UpdateCheck=0\s*$') 'update checks stopped in the copy'
    Assert-That ((Get-Content -LiteralPath (Join-Path $release '@Resources\User\Settings.inc') -Raw) -notmatch 'ParallaxDevBuild') 'the release''s settings are untouched'
    $leftover = @(Get-ChildItem -LiteralPath $dev -Recurse -File -Include *.ini, *.inc, *.lua | Select-String -Pattern '(?<![A-Za-z0-9_])Parallax\\{1,2}(Settings|ColorPicker|Welcome|Update|Idle|Chronometer|CPU|RAM|GPU|IO|Network|Media|Visualizer)(?![A-Za-z0-9_])')
    Assert-Equal $leftover.Count 0 'no hard-coded release config name is left in the copy'
    $viaFinder = @(Get-ChildItem -LiteralPath $dev -Recurse -File -Include *.ini, *.inc, *.lua | Select-String -Pattern 'ParallaxDev\\')
    Assert-That ($viaFinder.Count -gt 20) 'config names were rewritten to the copy'
    $s = Get-Status $dev
    Assert-Equal $s['DevDiffTotal'] '0' 'status: no changes'
    Assert-That ([int64]$s['DevComparedAt'] -gt 1700000000) 'status: compared time'
    Assert-Equal $s['DevReleaseVersion'] ((Select-String -LiteralPath (Join-Path $release '@Resources\Version.inc') -Pattern '^ParallaxVersion=(.+)$').Matches[0].Groups[1].Value.Trim()) 'status: release version'
    Assert-That (-not (Get-ChildItem -LiteralPath $skins -Directory | Where-Object Name -like '@ParallaxDevNew-*')) 'no temporary folder left'
    $r = Invoke-Cli @('-Action', 'Enable', '-SkinsPath', ($skins + '\.'), '-NoPlace')
    Assert-Equal $r.Lines[0] 'RESULT|OK|Enable|0|0|' 'a second Enable adopts the existing copy (no clone)'

    # ---- a new release since the copy was made: Enable rebuilds it, keeping the old copy -------------------------
    $releaseVersion = (Select-String -LiteralPath (Join-Path $release '@Resources\Version.inc') -Pattern '^ParallaxVersion=(.+)$').Matches[0].Groups[1].Value.Trim()
    Assert-That ($userSettings -match ('(?m)^ParallaxDevBase=' + [regex]::Escape($releaseVersion) + '\s*$')) 'the copy records the release it was cloned from'
    Assert-Equal $s['DevBaseVersion'] $releaseVersion 'status: base version'
    $upgrade = Join-Path $work 'Skins3'
    $null = New-Item -ItemType Directory -Path $upgrade
    Copy-Item -LiteralPath $release -Destination (Join-Path $upgrade 'Parallax') -Recurse
    $null = Invoke-Cli @('-Action', 'Enable', '-SkinsPath', ($upgrade + '\.'), '-NoPlace')
    $upgradeDev = Join-Path $upgrade 'ParallaxDev'
    Add-Content -LiteralPath (Join-Path $upgradeDev 'CPU\Marker.inc') -Value '; edit made in the old copy'
    Edit-Text (Join-Path $upgrade 'Parallax\@Resources\Version.inc') { param($t) $t -replace '(?m)^ParallaxVersion=.*', 'ParallaxVersion=9.9.9-test' }
    $r = Invoke-Cli @('-Action', 'Enable', '-SkinsPath', ($upgrade + '\.'), '-NoPlace')
    Assert-Equal $r.Exit 0 'Enable after a release change exits 0'
    Assert-That ($r.Lines[0] -match 'backup @ParallaxDev-backup-.*; was .*, release is 9\.9\.9-test; rebuilt \d+ files$') 'Enable reports the rebuild (so the panel needs no Rainmeter refresh)'
    Assert-That ($r.Lines[0] -notmatch 'cloned') 'a rebuild is not reported as a new clone'
    Assert-That (-not (Test-Path -LiteralPath (Join-Path $upgradeDev 'CPU\Marker.inc'))) 'the rebuilt copy starts from the new release'
    $kept = @(Get-ChildItem -LiteralPath $upgrade -Directory | Where-Object Name -like '@ParallaxDev-backup-*')
    Assert-Equal $kept.Count 1 'the old copy was kept as one backup'
    Assert-That (Test-Path -LiteralPath (Join-Path $kept[0].FullName 'CPU\Marker.inc')) 'the backup holds the edit made in the old copy'
    Assert-Equal (Get-Status $upgradeDev)['DevBaseVersion'] '9.9.9-test' 'the rebuilt copy is based on the new release'
    $r = Invoke-Cli @('-Action', 'Enable', '-SkinsPath', ($upgrade + '\.'), '-NoPlace')
    Assert-Equal $r.Lines[0] 'RESULT|OK|Enable|0|0|' 'an up-to-date copy is not rebuilt again'
    $r = Invoke-Cli @('-Action', 'Reset', '-SkinsPath', ($upgrade + '\.'), '-NoPlace')
    Assert-That ($r.Lines[0] -match 'rebuilt \d+ files$') 'Reset rebuilds an up-to-date copy too'

    # ---- progress file: the clone reports files, the helper reports its phases --------------------------------------
    $progress = Join-Path $work 'progress.txt'
    $fresh = Join-Path $work 'Skins4'
    $null = New-Item -ItemType Directory -Path $fresh
    Copy-Item -LiteralPath $release -Destination (Join-Path $fresh 'Parallax') -Recurse
    $cloned = New-ParallaxDevCopy (Join-Path $fresh 'Parallax') (Join-Path $fresh 'ParallaxDev') $progress
    Assert-Equal ([IO.File]::ReadAllText($progress)) "build|$cloned|$cloned" 'the clone finishes by reporting every file'
    $r = Invoke-Cli @('-Action', 'Compare', '-SkinsPath', ($fresh + '\.'), '-ProgressFile', $progress)
    Assert-Equal $r.Exit 0 'a progress file does not change the result'
    Assert-Equal ([IO.File]::ReadAllText($progress)) 'list|0|1' 'the helper ends on its last phase'
    $r = Invoke-Cli @('-Action', 'Compare', '-SkinsPath', ($fresh + '\.'), '-ProgressFile', (Join-Path $work 'no\such\folder\p.txt'))
    Assert-Equal $r.Exit 0 'an unwritable progress file never fails the run'

    # ---- Compare ----------------------------------------------------------------------------------------------------
    $cpuIni = Join-Path $dev 'CPU\CPU.ini'
    Edit-Text $cpuIni { param($t) $t + "`r`n; edited`r`n" }
    $r = Invoke-Cli @('-Action', 'Compare', '-SkinsPath', ($skins + '\.'))
    Assert-Equal $r.Lines[0] 'RESULT|OK|Compare|1|1|' 'one edited file: one utility differs'
    $s = Get-Status $dev
    Assert-Equal $s['DevDiffCPU'] '1' 'CPU differs'
    foreach ($m in 'Chronometer', 'GPU', 'IO', 'Media', 'Network', 'RAM', 'Visualizer') { Assert-Equal $s["DevDiff$m"] '0' "$m still matches" }
    Assert-Equal $s['DevDiffShared'] '0' 'no shared change'
    $report = Get-Content -LiteralPath (Join-Path $dev '@Resources\Dev\Diff.txt') -Raw
    Assert-That ($report -match '(?m)^  M CPU\\CPU\.ini') 'the report lists the changed file'
    # CRLF-only and ignored files do not count
    Edit-Text $cpuIni { param($t) $t.Replace("`r`n; edited`r`n", '') }
    $viaLf = (Get-Content -LiteralPath $cpuIni -Raw).Replace("`r`n", "`n")
    [IO.File]::WriteAllText($cpuIni, $viaLf, (New-Object Text.UTF8Encoding($false)))
    $r = Invoke-Cli @('-Action', 'Compare', '-SkinsPath', ($skins + '\.'))
    Assert-Equal $r.Lines[0] 'RESULT|OK|Compare|0|0|' 'a CRLF/LF-only change is not a difference'
    Add-Content -LiteralPath (Join-Path $dev '@Resources\User\CPU.inc') -Value '; user choice'
    Add-Content -LiteralPath (Join-Path $dev '@Resources\Update\State.inc') -Value 'UpdateX=1'
    $r = Invoke-Cli @('-Action', 'Compare', '-SkinsPath', ($skins + '\.'))
    Assert-Equal $r.Lines[0] 'RESULT|OK|Compare|0|0|' 'user and runtime state files are ignored'
    # suite-level change: no utility turns red
    Edit-Text (Join-Path $dev 'Settings\Settings.ini') { param($t) $t + "`r`n; edited`r`n" }
    $r = Invoke-Cli @('-Action', 'Compare', '-SkinsPath', ($skins + '\.'))
    Assert-Equal $r.Lines[0] 'RESULT|OK|Compare|1|0|' 'a Global Settings change leaves every utility green'
    Assert-Equal (Get-Status $dev)['DevDiffSuite'] '1' 'counted as a suite change'
    # shared change: every utility turns red
    Edit-Text (Join-Path $dev '@Resources\Defaults.inc') { param($t) $t + "`r`n; edited`r`n" }
    $r = Invoke-Cli @('-Action', 'Compare', '-SkinsPath', ($skins + '\.'))
    Assert-Equal $r.Lines[0] 'RESULT|OK|Compare|2|8|' 'a shared file makes all eight utilities differ'
    Assert-Equal (Get-Status $dev)['DevDiffShared'] '1' 'counted as a shared change'
    # added and removed files
    Set-Content -LiteralPath (Join-Path $dev 'GPU\Scratch.inc') -Value '; new'
    Remove-Item -LiteralPath (Join-Path $dev 'RAM\Settings\Settings.ini')
    $null = Invoke-Cli @('-Action', 'Compare', '-SkinsPath', ($skins + '\.'))
    $report = Get-Content -LiteralPath (Join-Path $dev '@Resources\Dev\Diff.txt') -Raw
    Assert-That ($report -match '(?m)^  A GPU\\Scratch\.inc') 'added file reported'
    Assert-That ($report -match '(?m)^  D RAM\\Settings\\Settings\.ini') 'removed file reported'
    Assert-Equal ((Get-ChildItem -LiteralPath $release -Recurse -File | ForEach-Object { (Get-FileHash -LiteralPath $_.FullName).Hash }) -join '') $releaseHashBefore 'the release folder was never modified'
    # loaded dev configs are listed so the caller can tell them to re-read the status
    $devIni = "[Rainmeter]`r`n`r`n[ParallaxDev\GPU]`r`nActive=1`r`n"
    [IO.File]::WriteAllBytes((Join-Path $settingsFolder 'Rainmeter.ini'), ($bom + [Text.Encoding]::Unicode.GetBytes($devIni)))
    $r = Invoke-Cli @('-Action', 'Compare', '-SkinsPath', ($skins + '\.'), '-SettingsPath', ($settingsFolder + '\.'))
    Assert-Equal (@($r.Lines | Where-Object { $_ -like 'CONFIG|*' }) -join ';') 'CONFIG|ParallaxDev\GPU|GPU.ini|-|-' 'Compare lists the loaded dev configs'
    $r = Invoke-Cli @('-Action', 'Disable', '-SkinsPath', ($skins + '\.'), '-SettingsPath', ($settingsFolder + '\.'))
    Assert-Equal (@($r.Lines | Where-Object { $_ -like 'CONFIG|*' }) -join ';') 'CONFIG|ParallaxDev\GPU|GPU.ini|-|-' 'Disable lists what to unload'
    Assert-That (Test-Path -LiteralPath $dev) 'Disable keeps the copy''s files'

    # ---- refusals -----------------------------------------------------------------------------------------------------
    $r = Invoke-Cli @('-Action', 'Compare', '-SkinsPath', ($work + '\.'))
    Assert-Equal $r.Exit 1 'no release: exit 1'
    Assert-That ($r.Lines[0] -like 'RESULT|ERR|NoRelease|*') 'no release: NoRelease'
    $foreign = Join-Path $work 'Skins2'
    $null = New-Item -ItemType Directory -Path $foreign
    Copy-Item -LiteralPath $release -Destination (Join-Path $foreign 'Parallax') -Recurse
    $null = New-Item -ItemType Directory -Path (Join-Path $foreign 'ParallaxDev')
    $r = Invoke-Cli @('-Action', 'Enable', '-SkinsPath', ($foreign + '\.'), '-NoPlace')
    Assert-That ($r.Lines[0] -like 'RESULT|ERR|Foreign|*') 'an unrelated ParallaxDev folder is refused'
    Assert-That (-not (Test-Path -LiteralPath (Join-Path $foreign 'ParallaxDev\@Resources'))) 'the unrelated folder was not written'
    $r = Invoke-Cli @('-Action', 'Compare', '-SkinsPath', ($skins + '\.'), '-Release', 'ParallaxDev')
    Assert-That ($r.Lines[0] -like 'RESULT|OK|Compare|*') 'run from the copy itself, the release is the folder without Dev'
    $r = Invoke-Cli @('-Action', 'Compare', '-SkinsPath', ($skins + '\.'), '-Release', 'Par"allax')
    Assert-That ($r.Lines[0] -like 'RESULT|ERR|BadName|*') 'an unusable release name is refused'

    # ---- Reset: the old copy is set aside, never deleted ----------------------------------------------------------
    $r = Invoke-Cli @('-Action', 'Reset', '-SkinsPath', ($skins + '\.'), '-NoPlace')
    Assert-That ($r.Lines[0] -like 'RESULT|OK|Reset|0|0|backup @ParallaxDev-backup-*') 'Reset reports the backup'
    $backup = @(Get-ChildItem -LiteralPath $skins -Directory | Where-Object Name -like '@ParallaxDev-backup-*')
    Assert-Equal $backup.Count 1 'one backup folder'
    Assert-That (Test-Path -LiteralPath (Join-Path $backup[0].FullName 'GPU\Scratch.inc')) 'the edits live on in the backup'
    Assert-That (-not (Test-Path -LiteralPath (Join-Path $dev 'GPU\Scratch.inc'))) 'the new copy is a fresh clone'

    # ---- Sync tool end to end: a "project" whose skin has moved on from the release ----------------------------
    $project = Join-Path $work 'project'
    $null = New-Item -ItemType Directory -Path (Join-Path $project 'Skins')
    Copy-Item -LiteralPath $release -Destination (Join-Path $project 'Skins\Parallax') -Recurse
    $null = New-Item -ItemType Directory -Path (Join-Path $project 'tools')
    foreach ($tool in 'Stage-Parallax.ps1', 'Test-Parallax.ps1', 'Parallax.Build.psm1', 'Parallax.LuaScan.psm1') { Copy-Item -LiteralPath (Join-Path $repo "tools\$tool") -Destination (Join-Path $project "tools\$tool") }
    # Tests and QA folders and private files in the project are not part of a release, so they must not reach the copy.
    $null = New-Item -ItemType Directory -Path (Join-Path $project 'Skins\Parallax\CPU\tests')
    Set-Content -LiteralPath (Join-Path $project 'Skins\Parallax\CPU\tests\x.lua') -Value 'x'
    Set-Content -LiteralPath (Join-Path $project 'Skins\Parallax\@Resources\Modules\CPU\test_it.py') -Value 'x'
    Edit-Text (Join-Path $project 'Skins\Parallax\RAM\RAM.ini') { param($t) $t.Replace('Memory Meter', 'Memory Meter 2') }
    Edit-Text (Join-Path $project 'Skins\Parallax\@Resources\Modules\Network\Meters.inc') { param($t) $t + "`r`n; moved on`r`n" }
    Remove-Item -LiteralPath (Join-Path $project 'Skins\Parallax\GPU\Settings\Settings.ini')
    $null = Invoke-Cli @('-Action', 'Reset', '-SkinsPath', ($skins + '\.'), '-NoPlace')
    $tool = Join-Path $repo 'tools\Sync-ParallaxDev.ps1'
    $syncOutput = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -Action Sync -SkinsPath $skins -SettingsPath $settingsFolder -ProjectRoot $project -NoRefresh -NoValidate 2>&1 | ForEach-Object { [string]$_ })
    Assert-That ($LASTEXITCODE -eq 0) "Sync tool exit: $($syncOutput -join ' / ')"
    Assert-That (($syncOutput -join ' ') -match 'Sync: 3 file\(s\) differ from the release; 3 of 8 utilities show red') "Sync result line: $($syncOutput -join ' / ')"
    $s = Get-Status $dev
    Assert-Equal $s['DevDiffRAM'] '1' 'RAM edit reaches the copy'
    Assert-Equal $s['DevDiffNetwork'] '1' 'Network edit reaches the copy'
    Assert-Equal $s['DevDiffGPU'] '1' 'a file removed in the project is removed from the copy'
    Assert-Equal $s['DevDiffCPU'] '0' 'CPU still matches'
    Assert-That (-not (Test-Path -LiteralPath (Join-Path $dev 'CPU\tests'))) 'tests folders stay out of the copy'
    Assert-That (-not (Test-Path -LiteralPath (Join-Path $dev '@Resources\Modules\CPU\test_it.py'))) 'files a release excludes stay out of the copy'
    Assert-Equal (Get-Content -LiteralPath (Join-Path $dev '@Resources\User\Settings.inc') -Raw).Contains('ParallaxDevBuild=1') $true 'user settings survive a sync'
    Assert-That (-not (Get-ChildItem -LiteralPath (Join-Path $project 'build') -Directory -ErrorAction SilentlyContinue | Where-Object Name -like 'Parallax-dev-sync-*')) 'the temporary stage is removed'
    $again = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -Action Sync -SkinsPath $skins -SettingsPath $settingsFolder -ProjectRoot $project -NoRefresh -NoValidate 2>&1 | ForEach-Object { [string]$_ })
    Assert-That (($again -join ' ') -match 'updated 0, removed 0') "a second sync changes nothing: $($again -join ' / ')"

    # ---- the copy is a valid skin tree, and the status icon loads in it -------------------------------------------
    $validation = & (Join-Path $repo 'tools\Test-Parallax.ps1') -SkinRoot $dev -Variable 'ParallaxDevBuild=1' 6>$null
    Assert-Equal $validation.Errors 0 'static validation of the copy as a developer build'
    Assert-Equal $validation.Warnings 0 'static validation of the copy: no warnings'
    Remove-Item -LiteralPath $stage.StageRoot -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "PASS $assertions"
} finally {
    if (-not $KeepWork -and (Test-Path -LiteralPath $work)) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
    elseif ($KeepWork) { Write-Host "Work folder kept: $work" }
}

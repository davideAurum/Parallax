#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [ValidateSet(180,200,240,280,320)][int]$ColumnWidth = 180,
    [ValidateSet('0.75','1','1.25','1.5','2')][string]$Scale = '1',
    [ValidateSet(1,2)][int]$Columns = 1,
    [ValidateSet('IO.ini','IO-Disk.ini')][string]$IOVariant = 'IO.ini',
    [ValidateSet('Current','Default','Maximum')][string]$Typography = 'Current',
    [ValidateSet('Current','None','Thick')][string]$Surfaces = 'Current',
    [switch]$RoleColors,
    [switch]$ReplayHover
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\..\..'))
$previewScript = Join-Path $projectRoot 'tools\Preview-Parallax.ps1'
$process = $null
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter required; nothing is installed.' }
$stage = & (Join-Path $projectRoot 'tools\Stage-Parallax.ps1') -Version 'io-settings-smoke'
$runRoot = $stage.StageRoot
$skinRoot = Join-Path $runRoot 'Skins'
$parallaxRoot = $stage.SkinRoot
$utf8 = [Text.UTF8Encoding]::new($false)
function Write-RunFile([string]$Path, [string]$Text) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Refusing write outside generated smoke directory.'
    }
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}
foreach ($directory in @('Layouts','Plugins','Addons','captures')) {
    $null = New-Item -ItemType Directory -Path (Join-Path $runRoot $directory)
}
Write-RunFile (Join-Path $runRoot 'TEST-ONLY.txt') "Isolated integration test with instrumentation. Not distributable.`n"
$globalPath = Join-Path $parallaxRoot '@Resources\User\Settings.inc'
$globalText = Get-Content -LiteralPath $globalPath -Raw
$globalText = [regex]::Replace($globalText, '(?m)^Scale=[^\r\n]*', "Scale=$Scale")
$globalText = [regex]::Replace($globalText, '(?m)^ColumnWidth=[^\r\n]*', "ColumnWidth=$ColumnWidth")
function Set-PreviewVariable([string]$Text, [string]$Key, [string]$Value) {
    $pattern = '(?m)^' + [regex]::Escape($Key) + '=[^\r\n]*'
    if ([regex]::IsMatch($Text, $pattern)) { return [regex]::Replace($Text, $pattern, "$Key=$Value") }
    return $Text + "`n$Key=$Value`n"
}
$previewVariables = @{}
if ($Typography -ne 'Current') {
    $previewVariables.TitleFontSize = if ($Typography -eq 'Maximum') { '12' } else { '10' }
    $previewVariables.HeaderFontSize = if ($Typography -eq 'Maximum') { '10' } else { '8' }
    $previewVariables.FontSize = if ($Typography -eq 'Maximum') { '10' } else { '9' }
}
if ($RoleColors) {
    $previewVariables.TitleTextColor = '255,200,120'
    $previewVariables.HeaderTextColor = '160,210,255'
    $previewVariables.TextColor = '235,235,235'
    $previewVariables.AccentColor = '137,190,250'
    $previewVariables.AccentColor2 = '181,161,226'
}
if ($Surfaces -ne 'Current') {
    $previewVariables.BorderThickness = if ($Surfaces -eq 'Thick') { '4' } else { '0' }
    $previewVariables.DividerThickness = $previewVariables.BorderThickness
}
foreach ($key in $previewVariables.Keys) { $globalText = Set-PreviewVariable $globalText $key $previewVariables[$key] }
Write-RunFile $globalPath $globalText
$userPath = Join-Path $parallaxRoot '@Resources\User\IO.inc'
$userText = [regex]::Replace((Get-Content -LiteralPath $userPath -Raw), '(?m)^Columns=[^\r\n]*', "Columns=$Columns")
foreach ($key in $previewVariables.Keys) {
    if ([regex]::IsMatch($userText, '(?m)^' + [regex]::Escape($key) + '=')) {
        $userText = Set-PreviewVariable $userText $key $previewVariables[$key]
    }
}
Write-RunFile $userPath $userText
$mainPath = Join-Path $parallaxRoot ('IO\' + $IOVariant)
$mainText = Get-Content -LiteralPath $mainPath -Raw
# Replay only this source's gear-open and settings-close actions, within its own
# test INI. The user's live Rainmeter instance never receives command-line bangs.
$openAction = '[!ActivateConfig "Parallax\IO\Settings" "Settings.ini"]'
$viewText = Get-Content -LiteralPath (Join-Path $parallaxRoot '@Resources\Modules\IO\View.inc') -Raw
if (-not $viewText.Contains('LeftMouseUpAction=' + $openAction)) { throw 'Unexpected gear target.' }
$hoverSequence = ''
if ($ReplayHover) {
    $enter = [regex]::Match($mainText, '(?m)^MouseOverAction=([^\r\n]*)').Groups[1].Value
    $leave = [regex]::Match($mainText, '(?m)^MouseLeaveAction=([^\r\n]*)').Groups[1].Value
    if (-not $enter -or -not $leave) { throw 'Missing main hover actions.' }
    $hoverSequence = $enter + '[!Delay 4000]' + $leave
}
$mainText = $mainText.Replace('[Rainmeter]', "[Rainmeter]`nOnRefreshAction=[!Delay 1000]$openAction$hoverSequence")
$resultPath = Join-Path $runRoot 'suite-results.txt'
$observedPath = Join-Path $runRoot 'main-observed-units.txt'
$initialUnits = [regex]::Match($userText, '(?m)^IODiskUnits=([^\r\n]*)').Groups[1].Value
$expectedUnits = if ($initialUnits -eq 'bytes') { 'bits' } else { 'bytes' }
$controllerSuite = Join-Path $PSScriptRoot 'ControllerSuite.lua'
$settingsSuite = Join-Path $PSScriptRoot 'SettingsSuite.lua'
$controller = Join-Path $parallaxRoot '@Resources\Modules\IO\IO.lua'
$settings = Join-Path $parallaxRoot '@Resources\Modules\IO\Settings.lua'
$harnessPath = Join-Path $runRoot 'Harness.lua'
Write-RunFile $harnessPath @"
local done = false
function Initialize() end
function Update()
    if done then return 0 end
    done = true
    local ok, result = pcall(function()
        local a, ar = dofile([=[$controllerSuite]=]).run([=[$controller]=])
        local b, br = dofile([=[$settingsSuite]=]).run([=[$settings]=])
        return 'PASS: '..tostring(a+b)..' assertions under '.._VERSION..'\n'..tostring(ar)..'\n'..tostring(br)
    end)
    local file = assert(io.open([=[$resultPath]=], 'wb'))
    file:write(ok and result or ('FAIL: '..tostring(result))); file:close()
    file = assert(io.open([=[$observedPath]=], 'wb'))
    file:write(SKIN:GetVariable('IODiskUnits')); file:close()
    return 0
end
"@
$mainText += "`n[MeasureIOTests]`nMeasure=Script`nScriptFile=$harnessPath`n"
Write-RunFile $mainPath $mainText
$popupPath = Join-Path $parallaxRoot 'IO\Settings\Settings.ini'
$popupText = Get-Content -LiteralPath $popupPath -Raw
$popupHarnessPath = Join-Path $runRoot 'PopupHarness.lua'
# A temporary cadence drives explicit user actions only in this staged copy.
# Production settings retain Update=-1 and never poll.
Write-RunFile $popupHarnessPath @'
local ticks = 0
function Initialize() end
function Update()
    ticks = ticks + 1
    if ticks == 24 then SKIN:Bang('!CommandMeasure', 'MeasureIOSettings', 'CycleUnits()') end
    if ticks == 40 then SKIN:Bang('!CommandMeasure', 'MeasureIOSettings', 'Close()') end
    return 0
end
'@
$popupText = [regex]::Replace($popupText, '(?m)^Update=-1', 'Update=250')
$popupText += "`n[MeasureIOPopupTest]`nMeasure=Script`nScriptFile=$popupHarnessPath`n"
Write-RunFile $popupPath $popupText
$variants = @(Get-ChildItem -LiteralPath (Split-Path -Parent $mainPath) -File -Filter '*.ini' | Sort-Object Name)
$active = 1
for ($i=0; $i -lt $variants.Count; $i++) { if ($variants[$i].Name -eq $IOVariant) { $active = $i+1 } }
$iniPath = Join-Path $runRoot 'Rainmeter.ini'
Write-RunFile $iniPath @"
[Rainmeter]
SkinPath=$skinRoot\
DisableVersionCheck=1
DisableAutoUpdate=1
Logging=1
Language=1033
TrayIcon=0

[Parallax\IO]
Active=$active
WindowX=-20000
WindowY=-20000
KeepOnScreen=0
Draggable=0
ClickThrough=1

[Parallax\IO\Settings]
Active=0
WindowX=-20000
WindowY=-20000
KeepOnScreen=0
Draggable=0
ClickThrough=1
"@
Write-RunFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
# Reuse the reviewed window capture class without running an all-suite preview.
$definition = [regex]::Match((Get-Content -LiteralPath $previewScript -Raw), "(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@").Groups[1].Value
if (-not $definition.Contains('class ParallaxPreviewNative')) { throw 'Missing isolated capture helper.' }
Add-Type -AssemblyName System.Drawing
if (-not ('ParallaxPreviewNative' -as [type])) { Add-Type -TypeDefinition $definition }
try {
    $process = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 4
    $readyDeadline = [DateTime]::UtcNow.AddSeconds(8)
    do {
        $windows = @([ParallaxPreviewNative]::GetOwnWindows([uint32]$process.Id))
        $ready = $windows.Count -eq 2 -and @($windows | Where-Object { $_.Width -lt 1 -or $_.Height -lt 1 }).Count -eq 0
        if (-not $ready) { Start-Sleep -Milliseconds 250 }
    } while (-not $ready -and [DateTime]::UtcNow -lt $readyDeadline)
    if (-not $ready) { throw 'Main IO and settings windows did not finish their native layout before the capture deadline.' }
    foreach ($window in $windows) {
        if ($window.Width -gt 4096 -or $window.Height -gt 4096) { throw 'Unexpected own window dimensions.' }
        $name = if ($window.Title -match 'IO[\\/]Settings') { 'IO-Settings' } elseif ($ReplayHover) { 'IO-hover' } else { 'IO' }
        $bitmap = [Drawing.Bitmap]::new($window.Width, $window.Height)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        $hdc = [IntPtr]::Zero
        try {
            $graphics.Clear([Drawing.Color]::Magenta)
            $hdc = $graphics.GetHdc()
            $printed = [ParallaxPreviewNative]::PrintWindow($window.Handle, $hdc, 2)
            $graphics.ReleaseHdc($hdc); $hdc = [IntPtr]::Zero
            if (-not $printed) { throw 'Native window capture failed.' }
            $bitmap.Save((Join-Path $runRoot "captures\$name.png"), [Drawing.Imaging.ImageFormat]::Png)
            Write-Output "$name native window: $($window.Width)x$($window.Height)"
        } finally {
            if ($hdc -ne [IntPtr]::Zero) { $graphics.ReleaseHdc($hdc) }
            $graphics.Dispose(); $bitmap.Dispose()
        }
    }
    # The first opening has completed. Remove its test-only action before the
    # actual save refreshes the main skin, so it cannot reopen the popup.
    Write-RunFile $mainPath ([regex]::Replace($mainText, '(?m)^OnRefreshAction=[^\r\n]*\r?\n', ''))
    $deadline = [DateTime]::UtcNow.AddSeconds(12)
    do {
        Start-Sleep -Milliseconds 250
        $remaining = @([ParallaxPreviewNative]::GetOwnWindows([uint32]$process.Id))
    } while ($remaining.Count -ne 1 -and [DateTime]::UtcNow -lt $deadline)
    if ($remaining.Count -ne 1 -or $remaining[0].Title -match 'IO[\\/]Settings') {
        throw 'Settings close did not leave the IO monitor running independently.'
    }
    $report = Get-Content -LiteralPath $resultPath -Raw
    Write-Output (($report -split '\r?\n' | Where-Object { $_ -match '^(PASS: \d+ assertions|SUMMARY:)' }) -join "`n")
    if ($report -notmatch '^PASS:') { throw 'Lua regression suite failed.' }
    $savedText = Get-Content -LiteralPath $userPath -Raw
    $savedUnits = [regex]::Match($savedText, '(?m)^IODiskUnits=([^\r\n]*)').Groups[1].Value
    if ($savedUnits -ne $expectedUnits -or (Get-Content -LiteralPath $observedPath -Raw) -ne $expectedUnits) {
        throw 'Native setting save or main IO refresh failed.'
    }
    $errors = @(Get-Content -LiteralPath (Join-Path $runRoot 'Rainmeter.log') | Where-Object { $_ -match '^ERRO' })
    if ($errors.Count) { throw ($errors -join "`n") }
    Write-Output 'PASS: gear target opened separate settings; units persisted and main IO refreshed; close left IO running; zero Rainmeter errors.'
    Write-Output "Preview: $IOVariant; width=$ColumnWidth; scale=$Scale; columns=$Columns; typography=$Typography; role colors=$RoleColors; surfaces=$Surfaces"
    Write-Output "Evidence: $runRoot"
} finally {
    if ($null -ne $process) {
        $process.Refresh()
        if (-not $process.HasExited) { Stop-Process -InputObject $process -Force; $null = $process.WaitForExit(5000) }
        $process.Dispose()
    }
}

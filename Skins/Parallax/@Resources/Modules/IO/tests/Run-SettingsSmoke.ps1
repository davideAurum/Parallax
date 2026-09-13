#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [string]$BaseStage,
    [ValidateSet(180,200,220,240,280,320)][int]$ColumnWidth = 180,
    [ValidateSet('0.75','1','1.25','1.5','2')][string]$Scale = '1',
    [ValidateSet(1,2)][int]$Columns = 1,
    [ValidateSet('IO-Disk.ini')][string]$IOVariant = 'IO-Disk.ini',
    [ValidateSet('Current','Default','Maximum','Minimum')][string]$Typography = 'Current',
    [ValidateSet(0,6,10,12)][int]$TitleSize = 0,
    [ValidateRange(1,12)][double]$DataBarThickness,
    [ValidatePattern('^(current|all|none|[A-Z](,[A-Z])*)$')][string]$Drives = 'current',
    [ValidateSet('current','c','combined','overlay','split')][string]$GraphMode = 'current',
    [ValidateSet('current','letters','volume','model','both')][string]$DriveNames = 'current',
    [ValidateSet('Current','None','Thick')][string]$Surfaces = 'Current',
    [switch]$RoleColors,
    [switch]$ReplayHover,
    [switch]$ExerciseSelection,
    [switch]$ExerciseNames,
    [switch]$ExerciseNumberInput,
    [switch]$LongNameFixture,
    [ValidateRange(0,60)][int]$HistorySeconds = 0
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\..\..'))
$previewScript = Join-Path $projectRoot 'tools\Preview-Parallax.ps1'
$process = $null
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter required; nothing is installed.' }
if ($BaseStage) {
    # Reuse a coherent suite snapshot while other module tasks are editing.
    # Overlay only IO and its shared appearance inputs; no other current module
    # enters this TEST-ONLY copy, and the runner loads only the two IO configs.
    $baseRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $BaseStage))
    $buildRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'build'))
    if (-not $baseRoot.StartsWith($buildRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath (Join-Path $baseRoot 'Skins\Parallax\IO\IO-Disk.ini') -PathType Leaf)) {
        throw 'BaseStage must be an existing coherent test copy under this project build directory.'
    }
    $snapshotRoot = Join-Path $buildRoot ('Parallax-io-settings-smoke-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
    $null = New-Item -ItemType Directory -Path $snapshotRoot
    Copy-Item -LiteralPath (Join-Path $baseRoot 'Skins') -Destination $snapshotRoot -Recurse
    $snapshotSkin = Join-Path $snapshotRoot 'Skins\Parallax'
    foreach ($relativeRoot in @('IO', '@Resources\Modules\IO')) {
        $sourceRoot = Join-Path $projectRoot ('Skins\Parallax\' + $relativeRoot)
        foreach ($sourceFile in Get-ChildItem -LiteralPath $sourceRoot -Recurse -File) {
            $relativeFile = $sourceFile.FullName.Substring($sourceRoot.Length + 1)
            if ($relativeFile -like 'tests\*') { continue }
            $targetFile = Join-Path (Join-Path $snapshotSkin $relativeRoot) $relativeFile
            $null = New-Item -ItemType Directory -Path (Split-Path -Parent $targetFile) -Force
            Copy-Item -LiteralPath $sourceFile.FullName -Destination $targetFile -Force
        }
    }
    foreach ($sharedFile in @('Defaults.inc','Geometry.inc','Styles.inc','UtilitySettingsNote.inc','User\Settings.inc','User\IO.inc','Scripts\SettingsInput.ps1')) {
        Copy-Item -LiteralPath (Join-Path $projectRoot ('Skins\Parallax\@Resources\' + $sharedFile)) -Destination (Join-Path $snapshotSkin ('@Resources\' + $sharedFile)) -Force
    }
    $stage = [pscustomobject]@{ StageRoot=$snapshotRoot; SkinRoot=$snapshotSkin }
    Write-Output 'Using coherent TEST-ONLY base; current source overlay is limited to IO and shared appearance inputs.'
} else {
    $stage = & (Join-Path $projectRoot 'tools\Stage-Parallax.ps1') -Version 'io-settings-smoke'
}
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
    if ($Typography -eq 'Minimum') {
        $previewVariables.TitleFontSize = '6'
        $previewVariables.HeaderFontSize = '6'
        $previewVariables.FontSize = '6'
    }
}
if ($TitleSize -ne 0) { $previewVariables.TitleFontSize = [string]$TitleSize }
if ($PSBoundParameters.ContainsKey('DataBarThickness')) {
    $previewVariables.DataBarThickness = $DataBarThickness.ToString('0.##', [Globalization.CultureInfo]::InvariantCulture)
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
if ($Drives -ne 'current') { $userText = Set-PreviewVariable $userText 'IODiskDrives' $Drives }
if ($GraphMode -ne 'current') { $userText = Set-PreviewVariable $userText 'IOGraphMode' $GraphMode }
if ($DriveNames -ne 'current') { $userText = Set-PreviewVariable $userText 'IODriveNames' $DriveNames }
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
$observedSelectionPath = Join-Path $runRoot 'main-observed-selection.txt'
$observedLimitPath = Join-Path $runRoot 'main-observed-limit.txt'
$initialGraphMode = [regex]::Match($userText, '(?m)^IOGraphMode=([^\r\n]*)').Groups[1].Value
$initialUnits = [regex]::Match($userText, '(?m)^IODiskUnits=([^\r\n]*)').Groups[1].Value
$expectedUnits = if ($initialUnits -eq 'bytes') { 'bits' } else { 'bytes' }
$controllerSuite = Join-Path $PSScriptRoot 'ControllerSuite.lua'
$settingsSuite = Join-Path $PSScriptRoot 'SettingsSuite.lua'
$namesSuite = Join-Path $PSScriptRoot 'NamesSuite.lua'
$namesLibrary = Join-Path $parallaxRoot '@Resources\Modules\IO\Names.lua'
$namesObservedPath = Join-Path $runRoot 'drive-names-observed.txt'
$mainNamesPath = Join-Path $runRoot 'main-observed-names.txt'
$mainGenerationPath = Join-Path $runRoot 'main-generation.txt'
$namesActionPath = Join-Path $runRoot 'names-action-result.txt'
$nameMode = [regex]::Match($userText, '(?m)^IODriveNames=([^\r\n]*)').Groups[1].Value
$nextNames = @{ letters='volume'; volume='model'; model='both'; both='letters' }
$expectedNames = $nextNames[$nameMode]
$controller = Join-Path $parallaxRoot '@Resources\Modules\IO\IO.lua'
$settings = Join-Path $parallaxRoot '@Resources\Modules\IO\Settings.lua'
$settingsForSuite = $settings
if ($ExerciseNumberInput) {
    # Exercise the actual shared helper/caller/protocol with its documented
    # headless validation switch. This fixed fixture exists only in this copy.
    # Shared helper HWND/Enter/Escape behavior is validated by its owner.
    $inputCall = "SKIN:Bang('!SetOption', 'MeasureIOSettingsNumberInput', 'Parameter', args)"
    $inputSource = [IO.File]::ReadAllText($settings)
    if (-not $inputSource.Contains($inputCall)) { throw 'Unexpected numeric input caller.' }
    Write-RunFile $settings ($inputSource.Replace($inputCall, "SKIN:Bang('!SetOption', 'MeasureIOSettingsNumberInput', 'Parameter', args .. ' -ValidateOnly -Value 123.4567')"))
    $settingsForSuite = Join-Path $projectRoot 'Skins\Parallax\@Resources\Modules\IO\Settings.lua'
}
$harnessPath = Join-Path $runRoot 'Harness.lua'
$fixtureMainPath = Join-Path $runRoot 'main-name-fixture.txt'
$fixturePopupPath = Join-Path $runRoot 'popup-name-fixture.txt'
function Get-NameFixtureLua([string]$LongMeter, [string]$ShortMeter, [string]$ResultFile) {
    if (-not $LongNameFixture) { return '' }
    return @"
    SKIN:Bang('!SetOption', '$LongMeter', 'Text', 'C: TEST ONLY long spaced drive name repeated to exceed the entire available width several times and prove ellipsis on a single line')
    SKIN:Bang('!SetOption', '$ShortMeter', 'Text', 'D: Test')
    SKIN:Bang('!UpdateMeter', '$LongMeter')
    SKIN:Bang('!UpdateMeter', '$ShortMeter')
    SKIN:Bang('!Redraw')
    local longH = SKIN:GetMeter('$LongMeter'):GetH()
    local shortH = SKIN:GetMeter('$ShortMeter'):GetH()
    local file = assert(io.open([=[$ResultFile]=], 'wb'))
    file:write(longH == shortH and longH > 0 and 'PASS' or ('FAIL '..tostring(longH)..'/'..tostring(shortH))); file:close()
"@
}
$mainNameFixture = Get-NameFixtureLua 'MeterIODriveC' 'MeterIODriveD' $fixtureMainPath
$popupNameFixture = Get-NameFixtureLua 'MeterIOSettingsDriveCLabel' 'MeterIOSettingsDriveDLabel' $fixturePopupPath
Write-RunFile $harnessPath @"
local done = false
function Initialize()
    local old = io.open([=[$mainGenerationPath]=], 'rb')
    local count = old and tonumber(old:read('*a')) or 0
    if old then old:close() end
    local file = assert(io.open([=[$mainGenerationPath]=], 'wb'))
    file:write(tostring(count+1)); file:close()
end
function Update()
$mainNameFixture
    local namesFile = assert(io.open([=[$mainNamesPath]=], 'wb'))
    namesFile:write(SKIN:GetVariable('IODriveNames')); namesFile:close()
    if done then return 0 end
    done = true
    -- Run the expensive synthetic matrix once, not on every settings refresh.
    local existing = io.open([=[$resultPath]=], 'rb')
    if existing then existing:close() else
        local ok, result = pcall(function()
            local a, ar = dofile([=[$controllerSuite]=]).run([=[$controller]=])
            local b, br = dofile([=[$settingsSuite]=]).run([=[$settingsForSuite]=])
            local c, cr = dofile([=[$namesSuite]=]).run([=[$namesLibrary]=])
            return 'PASS: '..tostring(a+b+c)..' assertions under '.._VERSION..'\n'..tostring(ar)..'\n'..tostring(br)..'\n'..tostring(cr)
        end)
        local report = assert(io.open([=[$resultPath]=], 'wb'))
        report:write(ok and result or ('FAIL: '..tostring(result))); report:close()
    end
    local file = assert(io.open([=[$observedPath]=], 'wb'))
    file:write(SKIN:GetVariable('IODiskUnits')); file:close()
    file = assert(io.open([=[$observedSelectionPath]=], 'wb'))
    file:write(SKIN:GetVariable('IODiskDrives')..'\n'..SKIN:GetVariable('IOGraphMode')); file:close()
    file = assert(io.open([=[$observedLimitPath]=], 'wb'))
    file:write(SKIN:GetVariable('IODiskMaxMiBs')); file:close()
    return 0
end
"@
$mainText += "`n[MeasureIOTests]`nMeasure=Script`nScriptFile=$harnessPath`n"
Write-RunFile $mainPath $mainText
$popupPath = Join-Path $parallaxRoot 'IO\Settings\Settings.ini'
$popupText = Get-Content -LiteralPath $popupPath -Raw
$popupHarnessPath = Join-Path $runRoot 'PopupHarness.lua'
$actionsReadyPath = Join-Path $runRoot 'settings-actions-ready.txt'
$selectionActions = if ($ExerciseSelection) { @'
    if ticks == 28 then SKIN:Bang('!CommandMeasure', 'MeasureIOSettings', 'SelectAllDrives()') end
    if ticks == 32 then SKIN:Bang('!CommandMeasure', 'MeasureIOSettings', 'CycleGraphMode()') end
'@ } else { '' }
$namesActions = if ($ExerciseNames) { @"
    if ticks == 8 then SKIN:Bang('!CommandMeasure', 'MeasureIOSettings', 'CycleNamesMode()') end
    if ticks == 12 then SKIN:Bang('!CommandMeasure', 'MeasureIOSettings', 'RefreshInventory()') end
    if ticks == 20 then
        local nameFile = assert(io.open([=[$mainNamesPath]=], 'rb'))
        local name = nameFile:read('*a'); nameFile:close()
        local generationFile = assert(io.open([=[$mainGenerationPath]=], 'rb'))
        local generation = generationFile:read('*a'); generationFile:close()
        local report = assert(io.open([=[$namesActionPath]=], 'wb'))
        report:write(name == '$expectedNames' and generation == '1' and 'PASS' or ('FAIL '..name..' generation '..generation))
        report:close()
    end
"@ } else { '' }
$numberActions = if ($ExerciseNumberInput) { @'
    if ticks == 28 then SKIN:Bang('!CommandMeasure', 'MeasureIOSettings', 'BeginLimitInput()') end
'@ } else { '' }
# A temporary cadence drives explicit user actions only in this staged copy.
# Production settings retain Update=-1 and never poll.
Write-RunFile $popupHarnessPath @"
local ticks = 0
local started = false
local names
function Initialize() names = dofile([=[$namesLibrary]=]) end
function Update()
$popupNameFixture
    local query = SKIN:GetMeasure('MeasureIOModelQuery')
    local packet = query and query:GetStringValue() or ''
    if packet ~= '' then
        local file = assert(io.open([=[$namesObservedPath]=], 'wb'))
        file:write(packet..'\n\n')
        for code = 65, 90 do
            local letter = string.char(code)
            local kind = SKIN:GetMeasure('MeasureIOType'..letter):GetValue()
            if kind >= 3 and kind <= 7 then
                local name, detail = names.Format(SKIN, letter, 'both')
                file:write(letter..'| '..name..' | '..detail..'\n')
            end
        end
        file:close()
    end
    if not started then
        local marker = io.open([=[$actionsReadyPath]=], 'rb')
        if not marker then return 0 end
        marker:close()
        started = true
    end
    ticks = ticks + 1
$namesActions
    if ticks == 24 then SKIN:Bang('!CommandMeasure', 'MeasureIOSettings', 'CycleUnits()') end
$selectionActions
$numberActions
    if ticks == 40 then SKIN:Bang('!CommandMeasure', 'MeasureIOSettings', 'Close()') end
    return 0
end
"@
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
function Save-OwnWindowCapture($Window, [string]$Name) {
    if ($Window.Width -lt 1 -or $Window.Height -lt 1 -or $Window.Width -gt 4096 -or $Window.Height -gt 4096) {
        throw 'Unexpected own window dimensions.'
    }
    $bitmap = [Drawing.Bitmap]::new($Window.Width, $Window.Height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $hdc = [IntPtr]::Zero
    try {
        $graphics.Clear([Drawing.Color]::Magenta)
        $hdc = $graphics.GetHdc()
        $printed = [ParallaxPreviewNative]::PrintWindow($Window.Handle, $hdc, 2)
        $graphics.ReleaseHdc($hdc); $hdc = [IntPtr]::Zero
        if (-not $printed) { throw 'Native window capture failed.' }
        $bitmap.Save((Join-Path $runRoot "captures\$Name.png"), [Drawing.Imaging.ImageFormat]::Png)
        Write-Output "$Name native window: $($Window.Width)x$($Window.Height)"
    } finally {
        if ($hdc -ne [IntPtr]::Zero) { $graphics.ReleaseHdc($hdc) }
        $graphics.Dispose(); $bitmap.Dispose()
    }
}
try {
    $process = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 4
    $readyDeadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        $process.Refresh()
        if ($process.HasExited) { throw "Isolated Rainmeter exited during startup with code $($process.ExitCode); inspect $runRoot\Rainmeter.log" }
        $windows = @([ParallaxPreviewNative]::GetOwnWindows([uint32]$process.Id))
        $ready = $windows.Count -eq 2 -and @($windows | Where-Object { $_.Width -lt 1 -or $_.Height -lt 1 }).Count -eq 0
        if (-not $ready) { Start-Sleep -Milliseconds 250 }
    } while (-not $ready -and [DateTime]::UtcNow -lt $readyDeadline)
    if (-not $ready) {
        Write-Output ($windows | Select-Object Title,Width,Height | ConvertTo-Json -Compress)
        throw 'Main IO and settings windows did not finish their native layout before the capture deadline.'
    }
    if ($nameMode -in @('model','both')) {
        $namesDeadline = [DateTime]::UtcNow.AddSeconds(14)
        while (-not (Test-Path -LiteralPath $namesObservedPath) -and [DateTime]::UtcNow -lt $namesDeadline) { Start-Sleep -Milliseconds 250 }
        if (-not (Test-Path -LiteralPath $namesObservedPath)) { throw 'One-shot model query did not finish before the capture deadline.' }
    }
    foreach ($window in $windows) {
        $name = if ($window.Title -match 'IO[\\/]Settings') { 'IO-Settings' } elseif ($ReplayHover) { 'IO-hover' } else { 'IO' }
        Save-OwnWindowCapture $window $name
    }
    $quotaRecoveryExpected = $ExerciseSelection -and $Drives -eq 'none'
    $quotaRecoveryCaptured = $false
    $initialPopupHeight = ($windows | Where-Object { $_.Title -match 'IO[\\/]Settings' }).Height
    # The first opening has completed. Remove its test-only action before the
    # actual save refreshes the main skin, so it cannot reopen the popup.
    Write-RunFile $mainPath ([regex]::Replace($mainText, '(?m)^OnRefreshAction=[^\r\n]*\r?\n', ''))
    # Start action timing only after capture and removal of the reopen action.
    Write-RunFile $actionsReadyPath 'ready'
    # The optional new controls add independent main-skin refreshes and native
    # initialization. Allow their bounded work before the popup's close tick.
    $deadline = [DateTime]::UtcNow.AddSeconds($(if ($ExerciseSelection -or $ExerciseNames -or $ExerciseNumberInput) { 30 } else { 16 }))
    do {
        Start-Sleep -Milliseconds 250
        $remaining = @([ParallaxPreviewNative]::GetOwnWindows([uint32]$process.Id))
        if ($quotaRecoveryExpected -and -not $quotaRecoveryCaptured) {
            $restoredPopup = @($remaining | Where-Object {
                $_.Title -match 'IO[\\/]Settings' -and $_.Height -eq ($initialPopupHeight + 28 * [double]$Scale)
            })
            if ($restoredPopup.Count -eq 1) {
                Save-OwnWindowCapture $restoredPopup[0] 'IO-Settings-restored'
                $quotaRecoveryCaptured = $true
            }
        }
    } while ($remaining.Count -ne 1 -and [DateTime]::UtcNow -lt $deadline)
    if ($remaining.Count -ne 1 -or $remaining[0].Title -match 'IO[\\/]Settings') {
        throw 'Settings close did not leave the IO monitor running independently.'
    }
    if ($quotaRecoveryExpected -and -not $quotaRecoveryCaptured) {
        throw 'Explicit-none quota collapse did not restore its 28px settings row after selecting All.'
    }
    $report = Get-Content -LiteralPath $resultPath -Raw
    if ($LongNameFixture) {
        foreach ($fixtureResult in @($fixtureMainPath,$fixturePopupPath)) {
            if ((Get-Content -LiteralPath $fixtureResult -Raw) -ne 'PASS') { throw 'Long drive name did not retain the native single-line text height.' }
        }
        Write-Output 'PASS: TEST-ONLY long spaced drive names retain the same native height as short names in main and settings.'
    }
    Write-Output (($report -split '\r?\n' | Where-Object { $_ -match '^(PASS: \d+ assertions|SUMMARY:)' }) -join "`n")
    if ($report -notmatch '^PASS:') { throw 'Lua regression suite failed.' }
    $savedText = Get-Content -LiteralPath $userPath -Raw
    if ($ExerciseNumberInput) {
        $savedLimitText = [regex]::Match($savedText, '(?m)^IODiskMaxMiBs=([^\r\n]*)').Groups[1].Value
        $savedLimit = [double]::Parse($savedLimitText, [Globalization.CultureInfo]::InvariantCulture)
        if ([math]::Abs($savedLimit * 1.048576 - 123.4567) -gt 0.0000001 -or (Get-Content -LiteralPath $observedLimitPath -Raw) -ne $savedLimitText) {
            throw 'Numeric cap helper result did not persist or reach the refreshed monitor.'
        }
        Write-Output 'PASS: numeric center called the actual shared helper with TEST-ONLY ValidateOnly input; result persisted with exact MB/s conversion and main readback.'
    }
    if ($ExerciseNames) {
        $savedNames = [regex]::Match($savedText, '(?m)^IODriveNames=([^\r\n]*)').Groups[1].Value
        if ($savedNames -ne $expectedNames -or (Get-Content -LiteralPath $namesActionPath -Raw) -ne 'PASS') {
            throw 'Name style did not persist and reach the main monitor without refresh.'
        }
        Write-Output 'PASS: name style persisted and reached main; inventory refresh and name change did not reload the main or reset history.'
    }
    $savedUnits = [regex]::Match($savedText, '(?m)^IODiskUnits=([^\r\n]*)').Groups[1].Value
    if ($savedUnits -ne $expectedUnits -or (Get-Content -LiteralPath $observedPath -Raw) -ne $expectedUnits) {
        throw 'Native setting save or main IO refresh failed.'
    }
    if ($ExerciseSelection) {
        $savedDrives = [regex]::Match($savedText, '(?m)^IODiskDrives=([^\r\n]*)').Groups[1].Value
        $savedGraph = [regex]::Match($savedText, '(?m)^IOGraphMode=([^\r\n]*)').Groups[1].Value
        $observedSelection = Get-Content -LiteralPath $observedSelectionPath -Raw
        if ($savedDrives -ne 'all' -or $savedGraph -eq $initialGraphMode -or $savedGraph -notin @('c','combined','overlay','split') -or $observedSelection -ne "$savedDrives`n$savedGraph") {
            throw 'Native drive/graph setting save or main IO readback failed.'
        }
        Write-Output 'PASS: All drives and graph-mode controls persisted; refreshed main read back both choices.'
    }
    if ($HistorySeconds -gt 0) {
        # Let real counters populate history after the tested refresh. No data
        # is synthesized or injected into the monitor for the graph capture.
        Start-Sleep -Seconds $HistorySeconds
        $historyWindows = @([ParallaxPreviewNative]::GetOwnWindows([uint32]$process.Id))
        if ($historyWindows.Count -ne 1 -or $historyWindows[0].Title -match 'IO[\\/]Settings') {
            throw 'Expected only the isolated Disk Meter for the history capture.'
        }
        Save-OwnWindowCapture $historyWindows[0] 'IO-history'
    }
    $errors = @(Get-Content -LiteralPath (Join-Path $runRoot 'Rainmeter.log') | Where-Object { $_ -match '^ERRO' })
    if ($errors.Count) { throw ($errors -join "`n") }
    Write-Output 'PASS: gear target opened separate settings; units persisted and main IO refreshed; close left IO running; zero Rainmeter errors.'
    $barPreview = if ($PSBoundParameters.ContainsKey('DataBarThickness')) { $previewVariables.DataBarThickness } else { 'inherited' }
    Write-Output "Preview: $IOVariant; width=$ColumnWidth; scale=$Scale; columns=$Columns; typography=$Typography; title override=$TitleSize; data bar thickness=$barPreview; drives=$Drives; graph=$GraphMode; names=$nameMode; role colors=$RoleColors; surfaces=$Surfaces"
    Write-Output "Evidence: $runRoot"
} finally {
    if ($null -ne $process) {
        $process.Refresh()
        if (-not $process.HasExited) { Stop-Process -InputObject $process -Force; $null = $process.WaitForExit(5000) }
        $process.Dispose()
    }
}

# Native copied-source Media settings/accordion/typography tests. Synthetic data only.
# No helper executable, OAuth material, live queue or live Rainmeter config is used.
[CmdletBinding()]
param([string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),[switch]$TypographyStatusProbeOnly,[switch]$SourceIntegrationFocused,[switch]$ArtworkFocused,[switch]$HeaderFocused,[switch]$IdentityFocused,[switch]$IdentityIconsFocused,[switch]$TitleRowFocused,[switch]$QueueToggleFocused,[switch]$QueueToggleNarrowPlayerOnly,[switch]$QueueTogglePlayersOnly,[switch]$BarThicknessFocused,[switch]$BarThicknessThinOnly,[switch]$SettingsStepperFocused,[switch]$QueueEmptyFocused,[switch]$SettingsFocused,[switch]$SettingsNarrowOnly,[switch]$SettingsWideOnly,[switch]$PlayerNameFocused,[switch]$PlayerNameIconsFocused)
if ($QueueEmptyFocused) { $QueueToggleFocused=$true }
if ($PlayerNameIconsFocused) { $PlayerNameFocused=$true }
if ($PlayerNameFocused) { $IdentityFocused=$true }
if ($IdentityIconsFocused) { $IdentityFocused=$true }
if ($BarThicknessThinOnly) { $BarThicknessFocused=$true }
if ($SettingsStepperFocused -or $SettingsNarrowOnly -or $SettingsWideOnly) { $SettingsFocused=$true }
if ($QueueToggleNarrowPlayerOnly -or $QueueTogglePlayersOnly -or $BarThicknessFocused) { $QueueToggleFocused=$true }
$ErrorActionPreference = 'Stop'
$testProcess = $null
$moduleRoot = Split-Path -Parent $PSScriptRoot
$resourcesRoot = Split-Path -Parent (Split-Path -Parent $moduleRoot)
$skinSource = Split-Path -Parent $resourcesRoot
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$runRoot = [IO.Path]::GetFullPath((Join-Path $tempParent ('Parallax-MediaSettings-test-' + [Guid]::NewGuid().ToString('N'))))
if (-not $runRoot.StartsWith($tempParent.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Test root escapes temp parent.' }
if ((Get-Item -LiteralPath $tempParent).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Temp parent cannot be a junction.' }
if (Test-Path -LiteralPath $runRoot) { throw 'Test root must be fresh.' }
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter required; nothing is installed.' }
$skinRoot = Join-Path $runRoot 'Skins'
foreach ($directory in @($skinRoot,"$runRoot\Layouts","$runRoot\Plugins","$runRoot\Addons")) { $null = New-Item -ItemType Directory -Path $directory -Force }
function Write-TestFile([string]$Path,[string]$Content) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Write escapes test directory.' }
    [IO.File]::WriteAllText($Path,$Content,[Text.UTF8Encoding]::new($false))
}
$sourceMap = [ordered]@{
    'Media\Media.ini' = (Join-Path $skinSource 'Media\Media.ini')
    'Media\Setup.ini' = (Join-Path $skinSource 'Media\Setup.ini')
    'Media\Settings\Settings.ini' = (Join-Path $skinSource 'Media\Settings\Settings.ini')
    '@Resources\Defaults.inc' = (Join-Path $resourcesRoot 'Defaults.inc')
    '@Resources\Geometry.inc' = (Join-Path $resourcesRoot 'Geometry.inc')
    '@Resources\Styles.inc' = (Join-Path $resourcesRoot 'Styles.inc')
    '@Resources\UtilitySettingsNote.inc' = (Join-Path $resourcesRoot 'UtilitySettingsNote.inc')
    '@Resources\User\Settings.inc' = (Join-Path $resourcesRoot 'User\Settings.inc')
    '@Resources\User\Media.inc' = (Join-Path $resourcesRoot 'User\Media.inc')
}
if ($HeaderFocused -or $TitleRowFocused) { $sourceMap['Media\Queue\Queue.ini']=Join-Path $skinSource 'Media\Queue\Queue.ini' }
# Module includes/scripts only: exclude tests and the PowerShell service/auth code.
foreach ($file in Get-ChildItem -LiteralPath $moduleRoot -Recurse -File) {
    $relative = $file.FullName.Substring($moduleRoot.Length+1)
    if ($relative -match '(^|\\)tests\\|^Source\\' -or $file.Extension -notin @('.inc','.lua')) { continue }
    $sourceMap[('@Resources\Modules\Media\'+$relative)] = $file.FullName
}
foreach ($font in Get-ChildItem -LiteralPath (Join-Path $resourcesRoot 'Fonts') -Filter '*.ttf') { $sourceMap[('@Resources\Fonts\'+$font.Name)] = $font.FullName }
$sourceHashes = @{}
foreach ($path in $sourceMap.Values) { $sourceHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$harnessPath = Join-Path $runRoot 'MediaSettingsSuite.lua'
[IO.File]::WriteAllText($harnessPath,[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'MediaSettingsSuite.luatest')),[Text.Encoding]::Unicode)
$iniPath = Join-Path $runRoot 'Rainmeter.ini'
$settings = "[Rainmeter]`nSkinPath=$skinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
$cases = @()
$index = 0
function Write-TypographyFixture([string]$CaseRoot,[string]$Profile,[double]$FixtureScale=1,[double]$FixtureBarThickness=6) {
    $titleSize=if ($Profile -eq 'max') { 12 } elseif ($Profile -eq 'min') { 6 } else { 10 }
    $headerSize=if ($Profile -eq 'max') { 10 } else { 8 }
    $bodySize=if ($Profile -eq 'max') { 10 } else { 9 }
    $thickness=if ($Profile -eq 'max') { if ($FixtureScale -in @(0.75,1.5)) { 0 } else { 4 } } else { 1 }
    $barText=$FixtureBarThickness.ToString([Globalization.CultureInfo]::InvariantCulture)
    Write-TestFile (Join-Path $CaseRoot '@Resources\User\Settings.inc') "[Variables]`nTitleFontSize=$titleSize`nHeaderFontSize=$headerSize`nFontSize=$bodySize`nDataBarThickness=$barText`nTitleTextColor=211,181,249`nHeaderTextColor=110,218,175`nTextColor=234,210,145`nAccentColor=95,188,246`nAccentColor2=246,138,174`nBorderThickness=$thickness`nDividerThickness=$thickness`nDividerColor=219,122,81`n"
}
function Install-SettingsInputFixture([string]$CaseRoot) {
    # Replace the optional input plugin in every copied Settings entrypoint.
    # Its output remains data; the controller proxy never dispatches Run.
    $entryPath=Join-Path $CaseRoot 'Media\Settings\Settings.ini'
    $entry=[IO.File]::ReadAllText($entryPath)
    $replacement="[MeasureMediaSettingsInput]`nMeasure=Script`nScriptFile=#@#Modules\Media\SettingsInputFixture.lua`n`n"
    if ([regex]::Matches($entry,'(?m)^\[MeasureMediaSettingsInput\]$').Count -ne 1) { throw 'Expected exactly one fixed input measure.' }
    $entry=[regex]::Replace($entry,'(?ms)^\[MeasureMediaSettingsInput\]\r?\n.*?(?=^\[|\z)',$replacement)
    Write-TestFile $entryPath $entry
    $fixture=@'
local result=''
function Update() return result end
function Select(index)
    local values={
        'PARALLAX_INPUT_V1|ok|2','PARALLAX_INPUT_V1|ok|4','PARALLAX_INPUT_V1|ok|150',
        'PARALLAX_INPUT_V1|cancel|','PARALLAX_INPUT_V1|ok|151','PARALLAX_INPUT_V1|ok|1.5',
        'PARALLAX_INPUT_V1|ok|0150','PARALLAX_INPUT_V1|ok|150\nextra',
        'PARALLAX_INPUT_V1|ok|[!SetVariable FixtureInputSentinel escaped]',
        'PARALLAX_INPUT_V1|ok|30\r\n','PARALLAX_INPUT_V1|ok|120','PARALLAX_INPUT_V1|ok|1',
        'PARALLAX_INPUT_V1|ok|0','PARALLAX_INPUT_V1|ok|3','',
        'PARALLAX_INPUT_V1|ok|5','PARALLAX_INPUT_V1|ok|45'}
    result=assert(values[tonumber(index)])
end
'@
    Write-TestFile (Join-Path $CaseRoot '@Resources\Modules\Media\SettingsInputFixture.lua') $fixture
    $controllerPath=Join-Path $CaseRoot '@Resources\Modules\Media\Settings.lua'
    $controller=[IO.File]::ReadAllText($controllerPath)
    $proxy=@'
local fixtureNativeOs=os
local os=setmetatable({time=function(...)
    return fixtureNativeOs.time(...)+tonumber(SKIN:GetVariable('FixtureInputAge','0'))
end},{__index=fixtureNativeOs})
local function InstallSettingsFixtureProxy()
    local native=SKIN
    for _,name in ipairs({'FixtureInputRuns','FixtureSettingsWrites','FixtureSettingsRefreshes','FixtureInputAge'}) do native:Bang('!SetVariable',name,'0') end
    native:Bang('!SetVariable','FixtureInputSentinel','unchanged')
    native:Bang('!SetVariable','FixtureInputStatus','-1')
    local function count(name) native:Bang('!SetVariable',name,tonumber(native:GetVariable(name,'0'))+1) end
    SKIN={
        GetVariable=function(_,...) return native:GetVariable(...) end,
        GetMeter=function(_,...) return native:GetMeter(...) end,
        GetMeasure=function(_,name)
            local measure=native:GetMeasure(name)
            if name~='MeasureMediaSettingsInput' then return measure end
            return {GetValue=function() return tonumber(native:GetVariable('FixtureInputStatus','-1')) end,
                GetStringValue=function() return measure:GetStringValue() end}
        end,
        GetX=function(_,...) return native:GetX(...) end,
        GetY=function(_,...) return native:GetY(...) end,
        ParseFormula=function(_,...) return native:ParseFormula(...) end,
        ReplaceVariables=function(_,...) return native:ReplaceVariables(...) end,
        Bang=function(_,...)
            local args={...}
            if args[1]=='!CommandMeasure' then
                if args[2]=='MeasureMediaSettingsInput' and args[3]=='Run' then
                    count('FixtureInputRuns');native:Bang('!SetVariable','FixtureInputStatus','0');return
                end
                if (args[2]=='MeasureMediaSourceControl' or args[2]=='MeasureMediaQueueControl') and args[3]=='Run' then
                    return
                end
                error('Unexpected settings helper dispatch')
            end
            if args[1]=='!WriteKeyValue' then count('FixtureSettingsWrites') end
            if args[1]=='!Refresh' then count('FixtureSettingsRefreshes') end
            local allowed={['!SetVariable']=true,['!SetOption']=true,['!UpdateMeasure']=true,['!UpdateMeter']=true,
                ['!UpdateMeterGroup']=true,['!Redraw']=true,['!Refresh']=true,['!WriteKeyValue']=true}
            assert(allowed[args[1]],'Unexpected settings action '..tostring(args[1]))
            native:Bang(unpack(args))
        end
    }
end
'@
    $initialize=@'
local productionInitialize=Initialize
function Initialize() InstallSettingsFixtureProxy();productionInitialize() end
'@
    [IO.File]::WriteAllText($controllerPath,$proxy+"`n"+$controller+"`n"+$initialize,[Text.Encoding]::Unicode)
}
function Install-RunCommandFixtures([string]$CaseRoot) {
    # Provider controls are dormant in the visual scenarios, but replace every
    # copied RunCommand host so a fixture can never launch a real helper.
    Write-TestFile (Join-Path $CaseRoot '@Resources\Modules\Media\ProviderControlFixture.lua') "function Update() return 1 end`nfunction Run() end`n"
    $names=@('MeasureMediaSourceControl','MeasureMediaQueueControl','MeasureQueueProviderControl')
    foreach ($entryPath in Get-ChildItem -LiteralPath $CaseRoot -Recurse -Filter '*.ini' -File) {
        $entry=[IO.File]::ReadAllText($entryPath.FullName)
        $changed=$false
        foreach ($name in $names) {
            $pattern='(?ms)^\['+[regex]::Escape($name)+'\]\r?\n.*?(?=^\[|\z)'
            if ([regex]::IsMatch($entry,$pattern)) {
                $entry=[regex]::Replace($entry,$pattern,"[$name]`nMeasure=Script`nScriptFile=#@#Modules\Media\ProviderControlFixture.lua`nUpdateDivider=-1`n`n")
                $changed=$true
            }
        }
        if ($changed) { Write-TestFile $entryPath.FullName $entry }
    }
}
Add-Type -AssemblyName System.Drawing
function Write-SyntheticCover([string]$Path) {
    # Original, deterministic fixture only. Its quadrants make scaling and crop
    # visible without copying any album artwork or reading a player's metadata.
    $bitmap=[Drawing.Bitmap]::new(192,192)
    $graphics=[Drawing.Graphics]::FromImage($bitmap)
    try {
        $colors=@([Drawing.Color]::FromArgb(34,85,130),[Drawing.Color]::FromArgb(82,153,171),[Drawing.Color]::FromArgb(208,137,100),[Drawing.Color]::FromArgb(107,82,137))
        for ($quadrant=0;$quadrant -lt 4;$quadrant++) {
            $brush=[Drawing.SolidBrush]::new($colors[$quadrant])
            try { $graphics.FillRectangle($brush,($quadrant%2)*96,[int][math]::Floor($quadrant/2)*96,96,96) } finally { $brush.Dispose() }
        }
        $pen=[Drawing.Pen]::new([Drawing.Color]::FromArgb(232,226,202),8)
        try { $graphics.DrawEllipse($pen,36,36,120,120);$graphics.DrawLine($pen,48,144,144,48) } finally { $pen.Dispose() }
        # A transparent center exposes any stale No art label underneath a
        # populated image. The native suite also checks the label visibility.
        $graphics.CompositingMode=[Drawing.Drawing2D.CompositingMode]::SourceCopy
        $clear=[Drawing.SolidBrush]::new([Drawing.Color]::Transparent)
        try { $graphics.FillRectangle($clear,64,80,64,32) } finally { $clear.Dispose() }
        $bitmap.Save($Path,[Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose();$bitmap.Dispose() }
}
$kinds=if ($SettingsFocused) { @('Settings') } elseif ($QueueToggleFocused) { @('QueueToggleSetup','QueueTogglePlayer') } elseif ($TitleRowFocused) { foreach ($profile in @('Min','Default','Max')) { foreach ($variant in @('Player','Setup','Queue','Settings')) { "TitleRow$profile$variant" } } } elseif ($IdentityFocused) { @('IdentityPlayer','IdentityPlayerMax','IdentitySetup') } elseif ($HeaderFocused) { @('HeaderSetup','HeaderPlayer','HeaderQueue') } elseif ($ArtworkFocused) { @('ArtworkSetup','ArtworkPlayer','ArtworkPlayerMissing') } else { @('Accordion','Settings','TypographySetup','TypographySettings','TypographyPlayer','TypographyPlayerDefault') }
$widths=if ($HeaderFocused) { @(220) } elseif ($ArtworkFocused -or $BarThicknessFocused) { @(180,220,320) } else { @(180,220) }
foreach ($kind in $kinds) { foreach ($width in $widths) { foreach ($scale in @(0.75,1,1.25,1.5,2)) { foreach ($columns in @(1,2)) {
    if ($PlayerNameFocused) {
        if ($PlayerNameIconsFocused -and $kind -ne 'IdentityPlayerMax') { continue }
        $wanted=if ($kind -eq 'IdentityPlayer') { $width -eq 220 -and $scale -eq 1 -and $columns -eq 2 } else { ($width -eq 180 -and $scale -eq 0.75 -and $columns -eq 1) -or ($width -eq 220 -and $scale -eq 2 -and $columns -eq 2) }
        if (-not $wanted) { continue }
    }
    if ($SettingsFocused -and -not ($columns -eq 2 -and (($width -eq 180 -and $scale -eq 0.75) -or ($width -eq 220 -and $scale -eq $(if ($SettingsStepperFocused) {1} else {2}))))) { continue }
    if ($QueueEmptyFocused -and -not ($kind -eq 'QueueTogglePlayer' -and $width -eq 220 -and $scale -eq 1 -and $columns -eq 2)) { continue }
    if ($SettingsNarrowOnly -and $width -ne 180) { continue }
    if ($SettingsWideOnly -and $width -ne 220) { continue }
    if ($BarThicknessFocused -and -not ($kind -eq 'QueueTogglePlayer' -and (($width -eq 180 -and $scale -eq 0.75 -and $columns -eq 1) -or ($width -in @(220,320) -and $scale -eq 1 -and $columns -eq 2)))) { continue }
    if ($BarThicknessThinOnly -and $width -ne 180) { continue }
    if ($QueueToggleFocused -and -not $BarThicknessFocused -and -not ($scale -eq 1 -and (($width -eq 180 -and $columns -eq 1) -or ($width -eq 220 -and $columns -eq 2)))) { continue }
    if ($QueueToggleNarrowPlayerOnly -and -not ($kind -eq 'QueueTogglePlayer' -and $width -eq 180)) { continue }
    if ($QueueTogglePlayersOnly -and $kind -ne 'QueueTogglePlayer') { continue }
    if ($TitleRowFocused) {
        $wantedWidth=if ($kind.Contains('Default')) { 220 } else { 180 }
        $wantedScale=if ($kind.Contains('Min')) { 0.75 } elseif ($kind.Contains('Max')) { 2 } else { 1 }
        $wantedColumns=if ($kind.Contains('Default') -or $kind.EndsWith('Settings')) { 2 } else { 1 }
        if ($width -ne $wantedWidth -or $scale -ne $wantedScale -or $columns -ne $wantedColumns) { continue }
    }
    if ($IdentityIconsFocused -and -not ($kind -ne 'IdentitySetup' -and $width -eq 220 -and $scale -eq 1 -and $columns -eq 2)) { continue }
    if ($IdentityFocused -and $scale -notin @(0.75,1,2)) { continue }
    if ($kind -eq 'IdentitySetup' -and -not $PlayerNameFocused -and -not ($width -eq 220 -and $scale -eq 1 -and $columns -eq 2)) { continue }
    if ($HeaderFocused -and $scale -notin @(1,2)) { continue }
    if ($width -eq 320 -and -not $BarThicknessFocused -and -not ($kind -eq 'ArtworkPlayer' -and $columns -eq 2)) { continue }
    if ($ArtworkFocused -and $scale -notin @(0.75,1,2)) { continue }
    if ($TypographyStatusProbeOnly -and -not ($kind -eq 'TypographyPlayer' -and $width -eq 180 -and $scale -eq 1 -and $columns -eq 1)) { continue }
    if ($SourceIntegrationFocused -and ($kind -notin @('Settings','TypographySettings','TypographyPlayer','TypographyPlayerDefault') -or $scale -notin @(0.75,1,2))) { continue }
    $isSettings=$kind.EndsWith('Settings')
    $isTypography=$kind.StartsWith('Typography')
    $isPlayer=$kind.Contains('Player')
    if ($isSettings -and $columns -eq 1) { continue }
    if ($isTypography -and -not $isSettings -and $columns -eq 2) { continue }
    if ($isPlayer -and $width -eq 220 -and -not $ArtworkFocused -and -not $HeaderFocused -and -not $IdentityFocused -and -not $TitleRowFocused -and -not $QueueToggleFocused) { continue }
    $profile=if ($TitleRowFocused) { if ($kind.Contains('Min')) { 'min' } elseif ($kind.Contains('Max')) { 'max' } else { 'default' } } elseif (($PlayerNameFocused -and $kind -ne 'IdentityPlayer') -or $SettingsFocused -or $QueueToggleFocused -or $ArtworkFocused -or $kind -eq 'IdentityPlayerMax' -or ($isTypography -and $kind -ne 'TypographyPlayerDefault')) { 'max' } else { 'default' }
    if ($SettingsStepperFocused -and $width -eq 220) { $profile='default' }
    $index++
    $name = 'Case{0:D2}' -f $index
    $caseRoot = Join-Path $skinRoot $name
    foreach ($relative in $sourceMap.Keys) {
        $destination = Join-Path $caseRoot $relative
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
        Copy-Item -LiteralPath $sourceMap[$relative] -Destination $destination
    }
    $barThickness=if ($BarThicknessFocused) { if ($width -eq 180) { 1 } elseif ($width -eq 220) { 6.25 } else { 12 } } else { 6 }
    Write-TypographyFixture $caseRoot $profile $scale $barThickness
    Install-SettingsInputFixture $caseRoot
    Install-RunCommandFixtures $caseRoot
    if ($QueueEmptyFocused) {
        $optionsPath=Join-Path $caseRoot '@Resources\Modules\Media\MediaOptions.lua'
        $options=[IO.File]::ReadAllText($optionsPath)
        $traceProxy=@'
local function InstallQueueTraceProxy()
local fixtureNativeSkin=SKIN
SKIN={GetVariable=function(_,...) return fixtureNativeSkin:GetVariable(...) end,
    Bang=function(_,...)
        local args={...}
        if args[1]=='!WriteKeyValue' or args[1]=='!Refresh' then
            local f=assert(io.open(fixtureNativeSkin:GetVariable('@')..'User\\EmptyActions.trace','ab'))
            f:write(args[1]..'\n');f:close()
        end
        fixtureNativeSkin:Bang(unpack(args))
    end}
end
'@
        $traceInitialize="`nlocal productionInitialize=Initialize`nfunction Initialize() InstallQueueTraceProxy();productionInitialize() end`n"
        [IO.File]::WriteAllText($optionsPath,$traceProxy+"`n"+$options+$traceInitialize,[Text.Encoding]::Unicode)
        Write-TestFile (Join-Path $caseRoot '@Resources\User\EmptyActions.trace') ''
    }
    $scaleText = $scale.ToString([Globalization.CultureInfo]::InvariantCulture)
    $preferencesPath = Join-Path $caseRoot '@Resources\User\Media.inc'
    $expanded=if ($isTypography -and -not $isSettings) { 1 } else { 0 }
    $preferences = "[Variables]`nColumns=$columns`nPanelHeight=162`nMediaInterval=1000`nQueueExpanded=$expanded`nQueueRowLimit=5`nQueueShowDetails=1`nQueuePollSeconds=30`nScale=$scaleText`nColumnWidth=$width`nUnrelatedSentinel=preserve-me`n"
    Write-TestFile $preferencesPath $preferences
    $cache = Join-Path $runRoot ("synthetic-$name.snapshot")
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $snapshot = "PARALLAX_QUEUE_V2`nstate=ready`nobserved=$now`nvalid_until=$($now+240)`nretry_not_before=0`ncount=5`n"
    foreach ($row in 1..5) {
        $title = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes("Synthetic item $row")).Replace('-','')
        $detail = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes("Test artist $row")).Replace('-','')
        $snapshot += "title$row=$title`ndetail$row=$detail`n"
    }
    Write-TestFile $cache $snapshot
    $report = Join-Path $runRoot ("result-$name.txt")
    $stateFile = Join-Path $runRoot ("stage-$name.txt")
    Write-TestFile $stateFile '1'
    foreach ($scriptHost in Get-ChildItem -LiteralPath $caseRoot -Recurse -File | Where-Object { $_.Extension -in @('.ini','.inc') }) {
        $text = [IO.File]::ReadAllText($scriptHost.FullName)
        $readerLine = 'ScriptFile=#@#Modules\Media\Queue\QueueReader.lua'
        if ($text.Contains($readerLine)) { Write-TestFile $scriptHost.FullName ($text.Replace($readerLine,$readerLine+"`nQueueCachePath=$cache")) }
    }
    # Replace in every copied config, including unloaded variants, so a fixture
    # selection error can never access a real provider.
    if ($true) {
        # Replace the copied provider include with built-in, constant fixtures.
        # Official String measure: rainmeter/rainmeter-docs source/manual/measures/string.html.
        $synthetic=''
        $numeric=@{MeasureConnection=1;MeasureState=1;MeasurePosition=45;MeasureDuration=180;MeasureProgress=25;MeasureCanPrevious=1;MeasureCanPlayPause=1;MeasureCanNext=1}
        foreach ($measureName in $numeric.Keys) { $synthetic+="[$measureName]`nMeasure=Calc`nFormula=$($numeric[$measureName])`n`n" }
        $coverPath=Join-Path $caseRoot 'synthetic-cover.png'
        Write-SyntheticCover $coverPath
        $strings=@{MeasureTitle='Agpqy title';MeasureArtist='Agpqy artist';MeasureSourceArtist='Agpqy artist';MeasureAlbum='Agpqy album';MeasurePlayer='Windows Media Session';MeasureMediaSource='Spotify';MeasureCover=$coverPath}
        foreach ($measureName in $strings.Keys) {
            if ($measureName -eq 'MeasureCover' -and $kind -eq 'ArtworkPlayerMissing') {
                $synthetic+="[$measureName]`nMeasure=String`nString=__NO_ART__`nSubstitute=`"__NO_ART__`":`"`"`n`n"
            } else { $synthetic+="[$measureName]`nMeasure=String`nString=$($strings[$measureName])`n`n" }
        }
        if ($IdentityFocused -and $isPlayer) {
            # Script return values preserve literal # and [] input without
            # expanding it in Rainmeter's String-option parser first.
            $identityPath=Join-Path $caseRoot 'IdentityFixture.lua'
            $identityCode=@'
local current='Windows Media Session'
function Update() return current end
function Select(index)
    local values={'Windows Media Session','YouTube','YouTube','Windows Media Session','Quod Libet Player',
        'Literal #IdentitySentinel# [!SetVariable IdentitySentinel escaped] [&MeasurePlayer:Tripwire()] "player"',
        'Windows Media Session','Windows Media Session','Windows Media Session'}
    current=assert(values[tonumber(index)])
end
function Tripwire() SKIN:Bang('!SetVariable','IdentitySentinel','escaped'); return 'TRIPPED' end
'@
            [IO.File]::WriteAllText($identityPath,$identityCode,[Text.Encoding]::Unicode)
            $synthetic=[regex]::Replace($synthetic,'(?ms)\[MeasurePlayer\]\r?\nMeasure=String\r?\nString=[^\r\n]*\r?\n\r?\n',"[MeasurePlayer]`nMeasure=Script`nScriptFile=$identityPath`n`n")
            $titlePath=Join-Path $caseRoot 'IdentityTitleFixture.lua'
            [IO.File]::WriteAllText($titlePath,"function Update() if SKIN:GetVariable('FixtureIdle','0')=='1' then return '' end return 'Agpqy title' end",[Text.Encoding]::Unicode)
            $synthetic=[regex]::Replace($synthetic,'(?ms)\[MeasureTitle\]\r?\nMeasure=String\r?\nString=[^\r\n]*\r?\n\r?\n',"[MeasureTitle]`nMeasure=Script`nScriptFile=$titlePath`n`n")
        }
        $synthetic+="[MeasureMediaUI]`nMeasure=Script`nScriptFile=#@#Modules\Media\Media.lua`n"
        Write-TestFile (Join-Path $caseRoot '@Resources\Modules\Media\WebNowPlaying.inc') $synthetic
        if (($IdentityFocused -or $QueueToggleFocused) -and $isPlayer) {
            # Keep native meters/methods, but count and suppress any attempted
            # playback dispatch in this copy. Hover must leave the count at zero.
            $adapterPath=Join-Path $caseRoot '@Resources\Modules\Media\Media.lua'
            $adapter=[IO.File]::ReadAllText($adapterPath)
            $shim=@'
local function InstallFixtureDispatchProxy()
local nativeSkin, fixtureDispatches = SKIN, 0
nativeSkin:Bang('!SetVariable','FixturePlaybackCommands','0')
SKIN = {
    GetMeasure=function(_,name) return nativeSkin:GetMeasure(name) end,
    GetMeter=function(_,name) return nativeSkin:GetMeter(name) end,
    ReplaceVariables=function(_,value) return nativeSkin:ReplaceVariables(value) end,
    ParseFormula=function(_,value) return nativeSkin:ParseFormula(value) end,
    GetVariable=function(_,name,default)
        if default==nil then return nativeSkin:GetVariable(name) end
        return nativeSkin:GetVariable(name,default)
    end,
    Bang=function(_,...)
        local args={...}
        if args[1]=='!CommandMeasure' and args[2]=='MeasureConnection' then
            fixtureDispatches=fixtureDispatches+1
            nativeSkin:Bang('!SetVariable','FixturePlaybackCommands',tostring(fixtureDispatches))
            return
        end
        nativeSkin:Bang(unpack(args))
    end
}
end

'@
            $initializeShim=@'

local productionInitialize = Initialize
function Initialize()
    InstallFixtureDispatchProxy()
    productionInitialize()
end
'@
            [IO.File]::WriteAllText($adapterPath,$shim+"`n"+$adapter+"`n"+$initializeShim,[Text.Encoding]::Unicode)
        }
    }
    $entryRelative = if ($kind.EndsWith('Queue')) { 'Media\Queue\Queue.ini' } elseif ($isSettings) { 'Media\Settings\Settings.ini' } elseif ($isPlayer) { 'Media\Media.ini' } else { 'Media\Setup.ini' }
    $entryPath = Join-Path $caseRoot $entryRelative
    $entry = [IO.File]::ReadAllText($entryPath)
    # Settings is event-driven; this test-only observer needs timed checkpoints.
    if ($isSettings) { $entry = [regex]::Replace($entry,'(?m)^Update=-1\r?$', 'Update=1000') }
    $hoverEnter = [regex]::Match($entry,'(?m)^MouseOverAction=(.*)$').Groups[1].Value.Trim()
    $hoverLeave = [regex]::Match($entry,'(?m)^MouseLeaveAction=(.*)$').Groups[1].Value.Trim()
    $entry += @"

[MeasureMediaSettingsTest]
Measure=Script
ScriptFile=$harnessPath
Kind=$kind
EmptyQueueTransition=$([int]$QueueEmptyFocused.IsPresent)
TypographyProfile=$profile
StatusProbeOnly=$([int]$TypographyStatusProbeOnly.IsPresent)
SyntheticCachePath=$cache
ResultFile=$report
StageFile=$stateFile
PreferencesPath=$preferencesPath
HoverEnter=$hoverEnter
HoverLeave=$hoverLeave
EditSettingsAction=$([regex]::Match($entry,'(?m)^ContextAction2=(.*)$').Groups[1].Value.Trim())
ExpectedWidth=$width
ExpectedScale=$scaleText
ExpectedColumns=$columns
ExpectedBarThickness=$($barThickness.ToString([Globalization.CultureInfo]::InvariantCulture))
"@
    $probes=if ($isSettings) {
        @(@('MeterTitle','Media settings'),@('MeterQueueHeading','Spotify queue'),@('MeterQueuePollLabel','Queue refresh (s)'),
          @('MeterQueuePollValue','150'),@('MeterStatus','Use Restart to apply interval.'),@('MeterDisconnect','Disconnect'),
          @('MeterPlayerSetup','Player setup'),@('MeterClose','X'),@('MeterSourceLabel','Source detection'),@('MeterSourceStart','Start'),@('MeterSourceStop','Stop'),
          @('MeterSourceGuidance','Identifies Spotify locally; no sign-in needed.'),@('MeterQueueGuidance','Sign in starts polling. Restart applies changes.'),
          @('MeterUtilitySettingsNote','Media settings are found here.'),@('MeterUtilitySettingsGlobalLink','Global Settings are found here.'))
    } else {
        @(@('MeterHeading','Media Player'),@('MeterPlayerName',$(if($isPlayer){'Spotify'}else{'Setup'})),@('MeterQueueHeading','Queue'),@('MeterQueueStatus','Storage error'),@('MeterQueueRow1','Track / Artist'))
    }
    if ($IdentityFocused) { $probes=@(@('MeterHeading','Media Player'),@('MeterPlayerName',$(if ($isPlayer) { 'Spotify' } else { 'Setup' }))) }
    if ($TitleRowFocused) {
        if ($isSettings) { $probes=@(@('MeterTitle','Media settings'),@('MeterClose','X')) }
        elseif ($kind.EndsWith('Queue')) { $probes=@(@('MeterHeading','Spotify queue'),@('MeterQueueStatus','Next 5')) }
        elseif ($isPlayer) { $probes=@(@('MeterHeading','Media Player'),@('MeterPlayerName','Spotify')) }
        else { $probes=@(@('MeterHeading','Media Player'),@('MeterPlayerName','Setup'),@('MeterSetupStatus','Optional WebNowPlaying')) }
    }
    if ($isPlayer) { $probes+=@(@('MeterTrackTitle','Agpqy'),@('MeterArtist','Agpqy'),@('MeterAlbum','Agpqy'),@('MeterTiming','0:45 / 3:00'),@('MeterTimingUnavailable','-- / --'),@('MeterCoverLabel','N/A')) }
    elseif (-not $isSettings) { $probes+=@(@('MeterSetupInstructions','1. WNP plugin is bundled.#CRLF#2. Open a player.'),@('MeterDesktopNote','Browser: add extension.'),@('MeterWNPDocs','WNP docs'),@('MeterLoadPlayer','Load player')) }
    foreach ($probe in $probes) {
        $entry+="`n[Probe$($probe[0])]`nMeter=String`nGroup=TypographyProbes`nX=0`nY=0`nText=$($probe[1])`nClipString=0`nHidden=1`nFontColor=0,0,0,0`nPadding=0,0,0,0`nAntiAlias=1`n"
    }
    if (-not $isSettings) {
        $statusIndex=0
        foreach ($label in @('Storage unavailable','Spotify unavailable','Queue unavailable','App quota reached','Provider stopped')) {
            $statusIndex++
            $entry+="`n[ProbeStatus$statusIndex]`nMeter=String`nGroup=TypographyProbes`nX=0`nY=0`nText=$label`nClipString=0`nHidden=1`nFontColor=0,0,0,0`nPadding=0,0,0,0`nAntiAlias=1`n"
        }
    }
    Write-TestFile $entryPath $entry
    $configName = $name+'\'+(Split-Path -Parent $entryRelative)
    $variantNames=@(Get-ChildItem -LiteralPath (Split-Path -Parent $entryPath) -Filter '*.ini' | Sort-Object Name | ForEach-Object { $_.Name })
    $activeVariant=[Array]::IndexOf($variantNames,(Split-Path -Leaf $entryPath))+1
    if ($activeVariant -lt 1) { throw 'Cannot select exact copied config variant.' }
    $settings += "`n[$configName]`nActive=$activeVariant`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nSavePosition=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
    $cases += [pscustomobject]@{Name=$name;Kind=$kind;Profile=$profile;Width=$width;Scale=$scale;Columns=$columns;BarThickness=$barThickness;Report=$report;Preferences=$preferencesPath}
} } } }
# Fail closed before launching any fixture if a copied active or inactive variant
# could load a real player plugin or the private source-detection cache reader.
foreach ($fixture in Get-ChildItem -LiteralPath $skinRoot -Recurse -File | Where-Object { $_.Extension -in @('.ini','.inc') }) {
    $fixtureText=[IO.File]::ReadAllText($fixture.FullName)
    if ($fixtureText -match '(?m)^\s*Plugin\s*=' -or $fixtureText -match '(?im)^\s*ScriptFile=.*SourceReader\.lua') {
        throw 'A native UI fixture still contains a real provider or source reader.'
    }
}
Write-TestFile $iniPath $settings
Write-TestFile (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
# Register inert unloaded targets for the controller's fixed refresh bangs.
# This matches installed names while no live target or helper is ever loaded.
foreach ($inactive in @('Parallax\Media\Setup.ini','Parallax\Media\Queue\Queue.ini','Parallax\Media\Settings\Settings.ini')) {
    $inactivePath=Join-Path $skinRoot $inactive
    $null=New-Item -ItemType Directory -Path (Split-Path -Parent $inactivePath) -Force
    Write-TestFile $inactivePath "[Rainmeter]`nUpdate=-1`n[MeterBounds]`nMeter=Image`nW=1`nH=1`nSolidColor=0,0,0,0`n"
}
function Test-LabelSync {
    $syncProcess=$null
    $syncRoot=Join-Path $runRoot 'Sync'
    $syncSkinRoot=Join-Path $syncRoot 'Skins'
    $syncParallax=Join-Path $syncSkinRoot 'Parallax'
    foreach ($directory in @($syncParallax,"$syncRoot\Layouts","$syncRoot\Plugins","$syncRoot\Addons")) { $null=New-Item -ItemType Directory -Path $directory -Force }
    foreach ($relative in $sourceMap.Keys) {
        $destination=Join-Path $syncParallax $relative
        $null=New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
        Copy-Item -LiteralPath $sourceMap[$relative] -Destination $destination
    }
    Write-TypographyFixture $syncParallax 'default'
    Install-SettingsInputFixture $syncParallax
    Copy-Item -LiteralPath (Join-Path $skinRoot 'Case01\@Resources\Modules\Media\WebNowPlaying.inc') -Destination (Join-Path $syncParallax '@Resources\Modules\Media\WebNowPlaying.inc')
    $syncPrefs=Join-Path $syncParallax '@Resources\User\Media.inc'
    Write-TestFile $syncPrefs "[Variables]`nColumns=1`nPanelHeight=162`nMediaInterval=1000`nQueueExpanded=0`nQueueRowLimit=5`nQueueShowDetails=1`nQueuePollSeconds=30`nScale=1`nColumnWidth=200`nUnrelatedSentinel=preserve-me`n"
    $syncCache=Join-Path $syncRoot 'synthetic.snapshot'
    $syncNow=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $syncSnapshot="PARALLAX_QUEUE_V2`nstate=ready`nobserved=$syncNow`nvalid_until=$($syncNow+120)`nretry_not_before=0`ncount=5`n"
    foreach ($row in 1..5) {
        $title=[BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes("Synthetic item $row")).Replace('-','')
        $detail=[BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes("Test artist $row")).Replace('-','')
        $syncSnapshot+="title$row=$title`ndetail$row=$detail`n"
    }
    Write-TestFile $syncCache $syncSnapshot
    foreach ($scriptHost in Get-ChildItem -LiteralPath $syncParallax -Recurse -File | Where-Object { $_.Extension -in @('.ini','.inc') }) {
        $text=[IO.File]::ReadAllText($scriptHost.FullName)
        $readerLine='ScriptFile=#@#Modules\Media\Queue\QueueReader.lua'
        if ($text.Contains($readerLine)) { Write-TestFile $scriptHost.FullName ($text.Replace($readerLine,$readerLine+"`nQueueCachePath=$syncCache")) }
    }
    $syncReport=Join-Path $syncRoot 'result.txt'
    $syncStage=Join-Path $syncRoot 'stage.txt'
    $syncLabel=Join-Path $syncRoot 'settings-label.txt'
    Write-TestFile $syncStage '1'
    Write-TestFile $syncLabel 'not initialized'
    foreach ($kind in @('SyncMain','SyncSettings')) {
        $relative=if ($kind -eq 'SyncMain') { 'Media\Setup.ini' } else { 'Media\Settings\Settings.ini' }
        $entryPath=Join-Path $syncParallax $relative
        $entry=[IO.File]::ReadAllText($entryPath)
        if ($kind -eq 'SyncSettings') { $entry=[regex]::Replace($entry,'(?m)^Update=-1\r?$','Update=1000') }
        $hoverEnter=[regex]::Match($entry,'(?m)^MouseOverAction=(.*)$').Groups[1].Value.Trim()
        $hoverLeave=[regex]::Match($entry,'(?m)^MouseLeaveAction=(.*)$').Groups[1].Value.Trim()
        $entry+=@"

[MeasureMediaSettingsTest]
Measure=Script
ScriptFile=$harnessPath
Kind=$kind
SyntheticCachePath=$syncCache
ResultFile=$syncReport
StageFile=$syncStage
SyncLabelFile=$syncLabel
PreferencesPath=$syncPrefs
HoverEnter=$hoverEnter
HoverLeave=$hoverLeave
EditSettingsAction=$([regex]::Match($entry,'(?m)^ContextAction2=(.*)$').Groups[1].Value.Trim())
ExpectedWidth=200
ExpectedScale=1
ExpectedColumns=1
"@
        Write-TestFile $entryPath $entry
    }
    $inactiveQueue=Join-Path $syncParallax 'Media\Queue\Queue.ini'
    $null=New-Item -ItemType Directory -Path (Split-Path -Parent $inactiveQueue) -Force
    Write-TestFile $inactiveQueue "[Rainmeter]`nUpdate=-1`n[MeterBounds]`nMeter=Image`nW=1`nH=1`nSolidColor=0,0,0,0`n"
    $syncIni=Join-Path $syncRoot 'Rainmeter.ini'
    $syncSettings="[Rainmeter]`nSkinPath=$syncSkinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
    foreach ($configName in @('Parallax\Media','Parallax\Media\Settings')) {
        $activeVariant=if ($configName -eq 'Parallax\Media') { 2 } else { 1 }
        $syncSettings+="`n[$configName]`nActive=$activeVariant`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nSavePosition=0`nDraggable=0`nClickThrough=1`nAlphaValue=255`n"
    }
    Write-TestFile $syncIni $syncSettings
    Write-TestFile (Join-Path $syncRoot 'Rainmeter.data') "[Rainmeter]`n"
    try {
        $syncProcess=Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $syncIni) -WorkingDirectory $syncRoot -WindowStyle Hidden -PassThru
        $deadline=[DateTime]::UtcNow.AddSeconds(20)
        do { Start-Sleep -Milliseconds 200 } while (-not (Test-Path -LiteralPath $syncReport) -and [DateTime]::UtcNow -lt $deadline)
        if (-not (Test-Path -LiteralPath $syncReport)) { throw "No live-label sync report; inspect $syncRoot\Rainmeter.log" }
        $report=Get-Content -LiteralPath $syncReport -Raw
        $errors=@(Get-Content -LiteralPath (Join-Path $syncRoot 'Rainmeter.log') | Where-Object { $_ -match '^ERRO' })
        return [pscustomobject]@{Report=$report.Trim();LogErrors=$errors;OwnedPid=$syncProcess.Id;Evidence=$syncRoot}
    } finally {
        if ($null -ne $syncProcess) {
            $syncProcess.Refresh()
            if (-not $syncProcess.HasExited) { Stop-Process -InputObject $syncProcess -Force; $null=$syncProcess.WaitForExit(5000) }
            $syncProcess.Dispose()
        }
    }
}

Add-Type -AssemblyName System.Drawing
if (-not ('ParallaxMediaSettingsCapture' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class ParallaxMediaSettingsCapture {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
    public sealed class Window { public IntPtr Handle; public string Title; public int Width,Height; }
    private delegate bool Callback(IntPtr hwnd,IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumWindows(Callback callback,IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr hwnd,StringBuilder text,int count);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd,StringBuilder text,int count);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd,out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd,IntPtr destination,uint flags);
    public static Window[] OwnWindows(uint pid) {
        var result=new List<Window>();
        EnumWindows((hwnd,data)=>{
            uint owner;GetWindowThreadProcessId(hwnd,out owner);if(owner!=pid)return true;
            var cls=new StringBuilder(256);GetClassName(hwnd,cls,cls.Capacity);if(cls.ToString()!="RainmeterMeterWindow")return true;
            var title=new StringBuilder(1024);GetWindowText(hwnd,title,title.Capacity);
            RECT rect;if(GetWindowRect(hwnd,out rect))result.Add(new Window{Handle=hwnd,Title=title.ToString(),Width=rect.Right-rect.Left,Height=rect.Bottom-rect.Top});
            return true;
        },IntPtr.Zero);
        return result.ToArray();
    }
}
'@
}
function Measure-TitleInkGap([Drawing.Bitmap]$Bitmap,[object]$Case) {
    if (-not ($Case.Kind.EndsWith('Setup') -or $Case.Kind.EndsWith('Queue'))) { return $null }
    # These isolated fixtures deliberately give titles violet ink and status
    # rows yellow/tan ink. Read rendered pixels, not overlapping empty boxes.
    $queue=$Case.Kind.EndsWith('Queue')
    $inset=[math]::Floor(4*$Case.Scale+0.5)
    $offset=if ($queue) { 0 } else { [math]::Floor(12*($Case.Columns-1)*$Case.Scale+0.5) }
    $statusY=$inset+$offset+$(if ($queue) { 26 } else { 50 })*$Case.Scale
    $limit=[int][math]::Ceiling($statusY+18*$Case.Scale)
    $titleBottom=-1; $statusTop=$limit
    for ($y=0;$y -lt $limit;$y++) { for ($x=0;$x -lt $Bitmap.Width;$x++) {
        $pixel=$Bitmap.GetPixel($x,$y)
        if ($pixel.B -gt $pixel.R+5 -and $pixel.R -gt $pixel.G+5) { $titleBottom=[math]::Max($titleBottom,$y) }
        if ($pixel.R -gt $pixel.G+10 -and $pixel.G -gt $pixel.B+15) { $statusTop=[math]::Min($statusTop,$y) }
    } }
    if ($titleBottom -lt 0 -or $statusTop -eq $limit) { throw "Cannot identify title/status ink in $($Case.Name)." }
    $clear=$statusTop-$titleBottom-1
    if ($clear -lt 1) { throw "Title/status glyphs collide in $($Case.Name): title bottom $titleBottom, status top $statusTop." }
    return [ordered]@{TitleBottom=$titleBottom;StatusTop=$statusTop;ClearRows=$clear}
}
function Save-ViewCaptures([uint32]$OwnedPid) {
    $captures=@()
    foreach ($window in [ParallaxMediaSettingsCapture]::OwnWindows($OwnedPid)) {
        $captureCases=@('Case13','Case27','Case31','Case32','Case42','Case52','Case57')
        $case=@($cases | Where-Object { $window.Title.Contains($_.Name+'\Media') })
        if ($case.Count -ne 1) { continue }
        if ($PlayerNameFocused -or $TitleRowFocused -or $QueueToggleFocused -or $SettingsFocused) {
            # The bounded title-row matrix is itself the capture subset.
        } elseif ($IdentityFocused) {
            $wideRepresentative=$case[0].Columns -eq 2 -and $case[0].Scale -eq 1
            $compactRepresentative=$case[0].Kind -eq 'IdentityPlayerMax' -and $case[0].Width -eq 180 -and $case[0].Columns -eq 1 -and $case[0].Scale -eq 1
            if (-not ($wideRepresentative -or $compactRepresentative)) { continue }
        } elseif ($ArtworkFocused) {
            $wideRepresentative=$case[0].Columns -eq 2 -and $case[0].Scale -eq 1
            $compactRepresentative=$case[0].Kind -eq 'ArtworkPlayer' -and $case[0].Width -eq 180 -and $case[0].Columns -eq 1 -and $case[0].Scale -in @(0.75,2)
            if (-not ($wideRepresentative -or $compactRepresentative)) { continue }
        } elseif ($SourceIntegrationFocused) {
            if ($case[0].Width -ne 180 -or $case[0].Scale -ne 1) { continue }
        } elseif ($case[0].Name -notin $captureCases) { continue }
        $case=$case[0]
        if ($window.Width -lt 1 -or $window.Height -lt 1 -or $window.Width -gt 2048 -or $window.Height -gt 2048) { throw 'Unexpected capture dimensions.' }
        $bitmap=[Drawing.Bitmap]::new($window.Width,$window.Height,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics=[Drawing.Graphics]::FromImage($bitmap)
        $hdc=[IntPtr]::Zero
        try {
            $graphics.Clear([Drawing.Color]::Magenta)
            $hdc=$graphics.GetHdc()
            $printed=[ParallaxMediaSettingsCapture]::PrintWindow($window.Handle,$hdc,2)
            $graphics.ReleaseHdc($hdc);$hdc=[IntPtr]::Zero
            $colors=[Collections.Generic.HashSet[int]]::new()
            for ($x=0;$x -lt $bitmap.Width;$x+=2) { for ($y=0;$y -lt $bitmap.Height;$y+=2) { $null=$colors.Add($bitmap.GetPixel($x,$y).ToArgb()) } }
            if (-not $printed -or $colors.Count -le 16) { throw 'Native capture is blank/unsupported.' }
            $artworkPixels=$null
            if ($ArtworkFocused -and $case.Columns -eq 2 -and $case.Scale -eq 1) {
                # Test fixture has Gutter=8: tile origin(4,4), proportional
                # size75% of its former90%-column size, radius10 at scale1.
                # The top-left corner is clear of the surface at x100, so an
                # unmasked rectangular cover cannot accidentally pass here.
                $artSize=[int][math]::Floor([math]::Floor($case.Width*0.9+0.5)*0.75+0.5)
                $artMiddle=4+[int][math]::Floor($artSize/2)
                $corner=$bitmap.GetPixel(5,5)
                $top=$bitmap.GetPixel($artMiddle,4)
                $left=$bitmap.GetPixel(4,$artMiddle)
                $inside=$bitmap.GetPixel(14,14)
                $artworkPixels=[ordered]@{Corner=@($corner.R,$corner.G,$corner.B);TopBorder=@($top.R,$top.G,$top.B);LeftBorder=@($left.R,$left.G,$left.B);Inside=@($inside.R,$inside.G,$inside.B)}
                if ([math]::Max($corner.R,[math]::Max($corner.G,$corner.B)) -gt 5) { throw "Artwork corner is not clipped in $($case.Name): $($artworkPixels | ConvertTo-Json -Compress)" }
                foreach ($edge in @($top,$left)) {
                    if ([math]::Min($edge.R,[math]::Min($edge.G,$edge.B)) -lt 220 -or [math]::Max($edge.R,[math]::Max($edge.G,$edge.B))-[math]::Min($edge.R,[math]::Min($edge.G,$edge.B)) -gt 5) { throw "Artwork white border not rendered in $($case.Name): $($artworkPixels | ConvertTo-Json -Compress)" }
                }
                if ([math]::Max($inside.R,[math]::Max($inside.G,$inside.B)) -lt 15) { throw "Artwork interior missing in $($case.Name)." }
            }
            $label="$($case.Kind)-$($case.Profile)-w$($case.Width)-s$($case.Scale)-c$($case.Columns)"
            $file=Join-Path $runRoot ("synthetic-$label.png")
            $bitmap.Save($file,[Drawing.Imaging.ImageFormat]::Png)
            $metadataPixels=$null
            $transportPixels=$null
            $headerPixels=$null
            if ($IdentityFocused -and $case.Kind -ne 'IdentitySetup') {
                # A Shape may restore its nominal W/H while its cached drawing
                # stays blank. Check actual neutral icon pixels after the
                # disconnected -> idle -> playing transition as well.
                $metadataPixels=[ordered]@{}
                $wide=$case.Columns -eq 2
                $inset=[math]::Floor(4*$case.Scale+0.5)
                $unit=[math]::Floor($case.Width*$case.Scale+0.5)
                $art=[math]::Floor($unit*0.9+0.5)
                $contentX=$inset+$(if ($wide) { $art+8*$case.Scale } else { [math]::Floor(6*$case.Scale+0.5) })
                $iconX=[int]($contentX+$(if ($wide) { 0 } else { 54*$case.Scale }))
                $iconY=$inset+$(if ($wide) { [math]::Floor(12*$case.Scale+0.5) } else { 0 })+55*$case.Scale
                $row=0
                foreach ($iconName in @('Song','Artist','Album')) {
                    $count=0; $top=[int]($iconY+24*$row*$case.Scale)
                    for ($x=$iconX;$x -lt $iconX+14*$case.Scale;$x++) { for ($y=$top;$y -lt $top+14*$case.Scale;$y++) {
                        $pixel=$bitmap.GetPixel($x,$y)
                        if ($pixel.R -ge 80 -and $pixel.R -le 210 -and [math]::Abs($pixel.R-$pixel.G) -le 2 -and [math]::Abs($pixel.R-$pixel.B) -le 2) { $count++ }
                    } }
                    $metadataPixels[$iconName]=$count
                    if ($count -lt 3) { throw "Metadata $iconName icon is visually blank after identity transitions in $label; capture $file" }
                    $row++
                }
                $transportPixels=[ordered]@{}
                $nativeReport=[IO.File]::ReadAllText($case.Report)
                foreach ($controlName in @('Previous','PlayPause','Next')) {
                    $position=[regex]::Match($nativeReport,"Meter${controlName}:([0-9.]+),([0-9.]+),([0-9.]+),([0-9.]+)")
                    if (-not $position.Success) { throw 'Missing native transport bounds for pixel verification.' }
                    $coordinates=@(1..4 | ForEach-Object { [double]::Parse($position.Groups[$_].Value,[Globalization.CultureInfo]::InvariantCulture) })
                    $count=0; $left=[int][math]::Floor($coordinates[0]);$controlTop=[int][math]::Floor($coordinates[1])
                    for ($x=$left;$x -lt $left+$coordinates[2];$x++) { for ($y=$controlTop;$y -lt $controlTop+$coordinates[3];$y++) {
                        $pixel=$bitmap.GetPixel($x,$y)
                        if ($pixel.G -gt $pixel.R+20 -and $pixel.B -gt $pixel.G+20) { $count++ }
                    } }
                    $transportPixels[$controlName]=$count
                    if ($count -lt 3) { throw "Transport $controlName icon is visually blank after identity transitions in $label; capture $file" }
                }
                $headerPixels=[ordered]@{}
                foreach ($iconName in @('Media','Player')) {
                    $position=[regex]::Match($nativeReport,"Meter${iconName}Icon:([0-9.]+),([0-9.]+),([0-9.]+),([0-9.]+)")
                    if (-not $position.Success) { throw 'Missing native title/player icon bounds.' }
                    $coordinates=@(1..4 | ForEach-Object { [double]::Parse($position.Groups[$_].Value,[Globalization.CultureInfo]::InvariantCulture) })
                    $count=0; $left=[int][math]::Floor($coordinates[0]);$top=[int][math]::Floor($coordinates[1])
                    for ($x=$left;$x -lt $left+$coordinates[2];$x++) { for ($y=$top;$y -lt $top+$coordinates[3];$y++) {
                        $pixel=$bitmap.GetPixel($x,$y)
                        if ($pixel.G -gt $pixel.R+20 -and $pixel.B -gt $pixel.G+20) { $count++ }
                    } }
                    $headerPixels[$iconName]=$count
                    if ($count -lt 3) { throw "Title/player $iconName icon is visually blank in $label; capture $file" }
                }
            }
            $queuePixels=$null
            if ($QueueToggleFocused -and -not $BarThicknessFocused) {
                # The four fixtures finish in paired expanded Setup / collapsed
                # Player states. Sample the vertical plus above/below the
                # horizontal stroke, so nominal bounds alone cannot pass.
                $wide=$case.Columns -eq 2
                $baseArt=if ($wide) { [math]::Floor($case.Width*0.9+0.5) } else { 48 }
                $art=[math]::Floor($baseArt*0.75+0.5)
                $offset=if ($wide) { 12 } else { 0 }
                $barHeight=[math]::Max(1,[math]::Floor($case.BarThickness+0.5))
                # Body is the larger of the frozen legacy anchor and the current
                # section-gap layout; the latter now wins at standard width.
                $legacyControls=$offset+122+[math]::Max(2,6-$barHeight/2)+$barHeight+8
                $controls=$offset+$(if ($wide) { 112 } else { 134 })+$barHeight+8
                $legacyArtBottom=if ($wide) { $art } else { 44+$art }
                $artBottom=if ($wide) { 96+54 } else { 44+$art }
                $legacyBody=[math]::Max(162+$offset,[math]::Ceiling([math]::Max($legacyArtBottom,$legacyControls+26)+37))
                $body=[math]::Max($legacyBody,[math]::Ceiling([math]::Max($artBottom,$controls+26)+37))
                $left=4+$(if ($wide) { 96 } else { 0 })+6+44
                $top=4+$body-21
                $vertical=0; $list=0
                for ($x=0;$x -lt 18;$x++) { for ($y=0;$y -lt 18;$y++) {
                    $pixel=$bitmap.GetPixel($left+$x,$top+$y)
                    if ($pixel.G -gt $pixel.R+20 -and $pixel.G -gt $pixel.B+10) {
                        $list++
                        if ($x -in @(12,13) -and $y -in @(7,10)) { $vertical++ }
                    }
                } }
                $expanded=$case.Kind.EndsWith('Setup')
                $queuePixels=[ordered]@{Expanded=$expanded;X=$left;Y=$top;ListPixels=$list;PlusVerticalPixels=$vertical}
                if ($list -lt 15 -or ($expanded -and $vertical -ne 0) -or (-not $expanded -and $vertical -lt 1)) {
                    throw "Queue plus/minus pixels disagree with persisted state in $label`: $($queuePixels | ConvertTo-Json -Compress); capture $file"
                }
            }
            $titleInkGap=if ($TitleRowFocused) { Measure-TitleInkGap $bitmap $case } else { $null }
            $barPixels=$null
            if ($BarThicknessFocused) {
                $s=$case.Scale; $wide=$case.Columns -eq 2
                $inset=[math]::Floor(4*$s+0.5); $padding=[math]::Floor(6*$s+0.5)
                $art=[math]::Floor([math]::Floor([math]::Floor($case.Width*$s+0.5)*0.9+0.5)*0.75+0.5)
                $offset=if ($wide) { [math]::Floor(12*$s+0.5) } else { 0 }
                $barHeight=[math]::Max(1,[math]::Floor($case.BarThickness*$s+0.5))
                $barTop=$inset+$offset+$(if ($wide) { 112 } else { 134 })*$s
                $barLeft=$inset+$(if ($wide) { $art+4*$s } else { $padding })
                $sampleX=[int][math]::Floor($barLeft+6*$s)
                $paintedRows=@()
                for ($y=[int][math]::Floor($barTop)-2;$y -lt [math]::Ceiling($barTop)+$barHeight+2;$y++) {
                    $pixel=$bitmap.GetPixel($sampleX,$y)
                    if ($pixel.B -gt $pixel.G+20 -and $pixel.G -gt $pixel.R+20) { $paintedRows+=$y }
                }
                $barPixels=[ordered]@{LogicalThickness=$case.BarThickness;ExpectedPixelHeight=$barHeight;ExpectedTop=$barTop;SampleX=$sampleX;PaintedRows=$paintedRows}
                if ($paintedRows.Count -ne $barHeight) { throw "Native bar painted height differs in $label`: $($barPixels | ConvertTo-Json -Compress); capture $file" }
            }
            $captures+=[pscustomobject]@{File=$file;Synthetic=$true;Width=$window.Width;Height=$window.Height;Colors=$colors.Count;ArtworkPixels=$artworkPixels;MetadataPixels=$metadataPixels;TransportPixels=$transportPixels;PlayerHeaderPixels=$headerPixels;TitleInkGap=$titleInkGap;QueuePixels=$queuePixels;BarPixels=$barPixels}
        } finally {
            if ($hdc -ne [IntPtr]::Zero) { $graphics.ReleaseHdc($hdc) }
            $graphics.Dispose();$bitmap.Dispose()
        }
    }
    $expectedCaptures=if ($QueueEmptyFocused) { 1 } elseif ($PlayerNameIconsFocused) { 2 } elseif ($PlayerNameFocused) { 5 } elseif ($SettingsNarrowOnly -or $SettingsWideOnly) { 1 } elseif ($SettingsFocused) { 2 } elseif ($BarThicknessThinOnly) { 1 } elseif ($BarThicknessFocused) { 3 } elseif ($QueueToggleNarrowPlayerOnly) { 1 } elseif ($QueueTogglePlayersOnly) { 2 } elseif ($QueueToggleFocused) { 4 } elseif ($TitleRowFocused) { 12 } elseif ($IdentityIconsFocused) { 2 } elseif ($IdentityFocused) { 6 } elseif ($ArtworkFocused) { 9 } elseif ($SourceIntegrationFocused) { 4 } else { 7 }
    if ($captures.Count -ne $expectedCaptures) { throw "Expected $expectedCaptures representative default/max typography captures." }
    if (@($captures.File | Sort-Object -Unique).Count -ne $expectedCaptures) { throw 'Capture files must be distinct.' }
    return $captures
}
try {
    $testProcess = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(50)
    do { Start-Sleep -Milliseconds 250; $reports = @(Get-ChildItem -LiteralPath $runRoot -Filter 'result-*.txt') } while ($reports.Count -lt $cases.Count -and [DateTime]::UtcNow -lt $deadline)
    if ($reports.Count -ne $cases.Count) { throw "Only $($reports.Count)/$($cases.Count) native reports; inspect $runRoot\Rainmeter.log" }
    $failed = @()
    foreach ($case in $cases) {
        $report = Get-Content -LiteralPath $case.Report -Raw
        Write-Output $report.TrimEnd()
        if ($report -notmatch '^PASS ') { $failed += $case.Name }
    }
    $captures=@(); $sync=$null
    if (-not $TypographyStatusProbeOnly -and -not $HeaderFocused) {
        $captures=@(Save-ViewCaptures ([uint32]$testProcess.Id))
        if (-not $SettingsWideOnly -and -not $SourceIntegrationFocused -and -not $ArtworkFocused -and -not $IdentityFocused -and -not $TitleRowFocused -and -not $QueueToggleFocused) { $sync=Test-LabelSync; Write-Output $sync.Report }
    }
    $errors = @()
    $log = Join-Path $runRoot 'Rainmeter.log'
    if (Test-Path -LiteralPath $log) { $errors = @(Get-Content -LiteralPath $log | Where-Object { $_ -match '^ERRO' }) }
    if ($null -ne $sync) {
        if ($sync.Report -notmatch '^PASS ') { $failed+='LabelSync' }
        $errors+=@($sync.LogErrors)
    }
    $evidence = [ordered]@{Synthetic=$true;Cases=$cases.Count;FailedCases=$failed;LogErrors=$errors;OwnedPid=$testProcess.Id;SourceHashes=$sourceHashes;Captures=$captures;LabelSync=$sync;
        RainmeterVersion=(Get-Item -LiteralPath $RainmeterPath).VersionInfo.ProductVersion;
        Limits='Copied-source native Settings/accordion/player UI. Every WNP include, raw artist and source reader measure is replaced with inert Calc/String fixtures; identity mode uses test-owned Script returns for literal names and empty titles, and a SKIN:Bang proxy that counts/suppresses playback dispatches while forwarding native UI operations. Source scripts are excluded. Typed input uses an inert Script output/status proxy and suppressed Run dispatch; real overlay typing is not exercised. Synthetic queue and temporary preferences; no helper, auth, live settings, real queue or performance test.'}
    Write-TestFile (Join-Path $runRoot 'media-settings-evidence.json') ($evidence | ConvertTo-Json -Depth 4)
    Write-Output "Evidence retained at $runRoot"
    foreach ($path in $sourceHashes.Keys) { if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $sourceHashes[$path]) { throw 'Source changed during native run; rerun for coherent evidence.' } }
    if ($failed.Count -or $errors.Count) { $errors | Write-Output; throw "$($failed.Count) native cases failed; $($errors.Count) Rainmeter error entries." }
    if ($TypographyStatusProbeOnly) { Write-Output 'PASS: compact footer substitutions and native max-font player glyph checks.' }
    elseif ($SettingsFocused) { Write-Output "PASS: $($cases.Count) focused settings layouts, saved preferences and $($captures.Count) synthetic endpoint captures." }
    elseif ($QueueToggleFocused) { Write-Output "PASS: $($cases.Count) focused queue-toggle persistence layouts and $($captures.Count) synthetic expanded/collapsed captures." }
    elseif ($TitleRowFocused) { Write-Output "PASS: $($cases.Count) focused title-row layouts and $($captures.Count) synthetic centered-title captures." }
    elseif ($IdentityFocused) { Write-Output "PASS: $($cases.Count) focused player-identity layouts/transitions and $($captures.Count) synthetic header captures." }
    elseif ($HeaderFocused) { Write-Output "PASS: $($cases.Count) focused Media/Setup/standalone Queue gear positions and hover visibility cases." }
    elseif ($ArtworkFocused) { Write-Output "PASS: $($cases.Count) focused artwork layouts, populated/missing cover states, collapsed/expanded queue and $($captures.Count) synthetic owned-window captures." }
    elseif ($SourceIntegrationFocused) { Write-Output "PASS: $($cases.Count) focused source UI layouts and $($captures.Count) synthetic owned-window captures." }
    else { Write-Output "PASS: $($cases.Count) native Media settings/accordion/player layouts, open-label sync and $($captures.Count) synthetic owned-window captures." }
} finally {
    if ($null -ne $testProcess) {
        $testProcess.Refresh()
        if (-not $testProcess.HasExited) { Stop-Process -InputObject $testProcess -Force; $null=$testProcess.WaitForExit(5000) }
        $testProcess.Dispose()
    }
    # Retain evidence; never kill by process name or dispatch CLI bangs to Rainmeter.
}

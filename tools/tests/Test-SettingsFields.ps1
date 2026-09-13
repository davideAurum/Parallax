#requires -Version 5.1
# Actual Settings actions, bundled RunCommand and persistence; only the isolated
# input-helper copy is replaced with deterministic noninteractive stdout.
[CmdletBinding()]
param([string]$RainmeterPath=(Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$sourceRoot=Join-Path $projectRoot 'Skins\Parallax'
$runRoot=Join-Path $projectRoot ('build\settings-fields-test-'+[Guid]::NewGuid().ToString('N'))
$skinRoot=Join-Path $runRoot 'Skins'
$parallaxRoot=Join-Path $skinRoot 'Parallax'
$encoding=[Text.UTF8Encoding]::new($false)
$process=$null
if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'Existing Rainmeter installation required; nothing is installed.' }
foreach ($parent in @($projectRoot,(Join-Path $projectRoot 'build'),$sourceRoot)) {
    if ((Test-Path -LiteralPath $parent) -and ((Get-Item -LiteralPath $parent).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Test roots must not be junctions.' }
}
foreach ($relative in @('','Skins','Skins\Parallax','Skins\Parallax\Settings','Skins\Parallax\@Resources','Skins\Parallax\@Resources\User','Skins\Parallax\@Resources\Scripts','Skins\FieldsWitness','Skins\FieldsControl','Layouts','Plugins','Addons')) {
    $null=New-Item -ItemType Directory -Path (Join-Path $runRoot $relative)
}
function Write-Isolated([string]$Path,[string]$Content) {
    if (-not [IO.Path]::GetFullPath($Path).StartsWith($runRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Write outside isolated field test.' }
    [IO.File]::WriteAllText($Path,$Content,$encoding)
}
function Read-Values([string]$Path) {
    $values=@{}
    foreach ($line in Get-Content -LiteralPath $Path) { if ($line -match '^([^;\[=]+)=(.*)$') { $values[$matches[1]]=$matches[2] } }
    return $values
}
function Require([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Transparency([string]$BackgroundColor) {
    $channels=$BackgroundColor.Split(',')
    Require ($channels.Count -eq 4) 'Test background must be canonical RGBA.'
    $percent=[Math]::Round(100*(1-[int]$channels[3]/255.0),2)
    return $percent.ToString('0.##',[Globalization.CultureInfo]::InvariantCulture)
}
function Get-Initial($Expected,[string]$Key) {
    if ($Key -eq 'Scale') { return ([double]::Parse($Expected.Scale,[Globalization.CultureInfo]::InvariantCulture)*100).ToString('0.##',[Globalization.CultureInfo]::InvariantCulture) }
    if ($Key -eq 'BackgroundTransparency') { return Get-Transparency $Expected.BackgroundColor }
    return $Expected[$Key]
}
function Await-Report([string]$Path,[int]$TimeoutMs=15000) {
    $watcher=[IO.FileSystemWatcher]::new((Split-Path -Parent $Path))
    $watcher.NotifyFilter=[IO.NotifyFilters]::FileName -bor [IO.NotifyFilters]::LastWrite
    $watcher.EnableRaisingEvents=$true
    $clock=[Diagnostics.Stopwatch]::StartNew()
    try {
        while ($true) {
            if (Test-Path -LiteralPath $Path) {
                $content=[IO.File]::ReadAllText($Path)
                if ($content -match '^(PASS|FAIL)\r?\n') {
                    if ($content -match '^FAIL') { throw $content }
                    return (Read-Values $Path)
                }
            }
            $remaining=$TimeoutMs-[int]$clock.ElapsedMilliseconds
            if ($remaining -le 0) { throw "Timed out waiting for $Path; inspect $runRoot\Rainmeter.log" }
            $null=$watcher.WaitForChanged([IO.WatcherChangeTypes]::All,[Math]::Min($remaining,1000))
        }
    } finally { $watcher.Dispose(); $clock.Stop() }
}
function Assert-State($Native,$Expected,[int]$Generation) {
    Require ($Native.Generation -eq "$Generation") 'Unexpected native refresh generation.'
    foreach ($key in 'Scale','ColumnWidth','Gutter','CornerRadius','TitleFontSize','HeaderFontSize','FontSize','BackgroundColor','BorderThickness','DividerThickness','TableHeaderBorderThickness','DataBarThickness') { Require ($Native[$key] -eq $Expected[$key]) "Native setting mismatch: $key" }
    Require ($Native.Columns -eq '2') 'Settings must retain two columns.'
    Require ($Native.PanelHeight -eq '758') 'Unexpected Global Settings panel height.'
    Require ($Native.BackgroundTransparencyVariable -eq '<unset>') 'Transparency must derive from BackgroundColor, not a separate variable.'
    $scale=[double]::Parse($Expected.Scale,[Globalization.CultureInfo]::InvariantCulture)
    $single=[int][Math]::Floor([int]$Expected.ColumnWidth*$scale+0.5)
    $gap=2*[int][Math]::Floor([int]$Expected.Gutter*$scale/2+0.5)
    $height=[int][Math]::Floor([double]$Native.PanelHeight*$scale+0.5)+$gap
    Require ([int]$Native.Width -eq 2*($single+$gap) -and [int]$Native.Height -eq $height) 'Native bounds do not reflect persisted geometry.'
    $percent=($scale*100).ToString('0.####',[Globalization.CultureInfo]::InvariantCulture)
    Require ($Native.ScaleText -eq ($percent+'%')) 'Scale field did not update.'
    foreach ($key in 'ColumnWidth','Gutter','CornerRadius','BorderThickness','DividerThickness','TableHeaderBorderThickness','DataBarThickness') { Require ($Native[$key+'Text'] -eq ($Expected[$key]+' px')) "$key field did not update." }
    foreach ($key in 'TitleFontSize','HeaderFontSize','FontSize') { Require ($Native[$key+'Text'] -eq ($Expected[$key]+' pt')) "$key field did not update." }
    Require ($Native.BackgroundTransparencyText -eq ((Get-Transparency $Expected.BackgroundColor)+'%')) 'Transparency field did not reflect persisted alpha.'
    $geometry='Panels: {0} / {1} px   Gap: {2} px   Scale: {3}%' -f $single,($single*2+$gap),$gap,$percent
    Require ($Native.MeterGeometry -eq $geometry) 'Geometry summary differs from actual persisted values.'
    Require ($Native.MeterAccentValue -eq '#89BEFA') 'Accent hex changed unexpectedly.'
    $backgroundHex='#'+(($Expected.BackgroundColor.Split(',') | ForEach-Object { '{0:X2}' -f [int]$_ }) -join '')
    Require ($Native.MeterBackgroundColorValue -eq $backgroundHex) 'Background color hex did not reflect persisted alpha.'
}

$sourceFiles=@('Settings\Settings.ini','@Resources\Defaults.inc','@Resources\Geometry.inc','@Resources\Styles.inc','@Resources\User\Settings.inc','@Resources\Scripts\Settings.lua','@Resources\Scripts\SettingsInput.ps1')
$sourceHashes=@{}
foreach ($relative in $sourceFiles) {
    $source=Join-Path $sourceRoot $relative
    $sourceHashes[$relative]=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    Copy-Item -LiteralPath $source -Destination (Join-Path $parallaxRoot $relative)
}
Copy-Item -LiteralPath "$sourceRoot\@Resources\Fonts" -Destination "$parallaxRoot\@Resources\Fonts" -Recurse
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'SettingsFieldsHarness.lua') -Destination (Join-Path $runRoot 'Harness.lua')
$scripts=Join-Path $parallaxRoot '@Resources\Scripts'
Copy-Item -LiteralPath (Join-Path $scripts 'SettingsInput.ps1') -Destination (Join-Path $scripts 'SettingsFieldsProductionInput.ps1')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'SettingsFieldsInputStub.ps1') -Destination (Join-Path $scripts 'SettingsInput.ps1')
Write-Isolated (Join-Path $scripts 'SettingsFieldsRunRoot.txt') $runRoot
$settingsPath=Join-Path $parallaxRoot 'Settings\Settings.ini'
$settings=Get-Content -LiteralPath $settingsPath -Raw
Require ($settings -match '(?m)^FinishAction=\[!UpdateMeasure MeasureSettingsInput\]\[!CommandMeasure MeasureSettings "CommitInput\(\)"\]\r?$') 'Source fixed FinishAction changed; review the adapter test.'
$settings=[regex]::Replace($settings,'(?m)^Update=-1\r?$','Update=100')
$settings+="`n[MeasureSettingsFieldsHarness]`nMeasure=Script`nScriptFile=$runRoot\Harness.lua`nReportDirectory=$runRoot\`nRole=settings`n"
Write-Isolated $settingsPath $settings
$userPath=Join-Path $parallaxRoot '@Resources\User\Settings.inc'
$user=Get-Content -LiteralPath $userPath -Raw
$expected=@{Scale='1';ColumnWidth='220';Gutter='8';CornerRadius='3';AccentColor='137,190,250';TitleFontSize='10';HeaderFontSize='8';FontSize='9';BackgroundColor='15,15,15,255';BorderThickness='1';DividerThickness='1';TableHeaderBorderThickness='1';DataBarThickness='6'}
foreach ($key in $expected.Keys) {
    Require ($user -match ('(?im)^'+$key+'=')) "Missing persisted default: $key"
    $user=[regex]::Replace($user,('(?im)^'+$key+'=[^\r\n]*'),($key+'='+$expected[$key]))
}
Write-Isolated $userPath $user
$baseline=Read-Values $userPath
Require (-not $baseline.ContainsKey('BackgroundTransparency')) 'Source settings must not persist a separate transparency key.'
foreach ($witness in @(@{Name='FieldsWitness';Group='Parallax';Role='witness'},@{Name='FieldsControl';Group='FieldsTestOnly';Role='control'})) {
    Write-Isolated (Join-Path $skinRoot ($witness.Name+'\'+$witness.Name+'.ini')) "[Rainmeter]`nUpdate=100`nGroup=$($witness.Group)`n[MeasureWitness]`nMeasure=Script`nScriptFile=$runRoot\Harness.lua`nReportDirectory=$runRoot\`nRole=$($witness.Role)`n[MeterBounds]`nMeter=Image`nW=1`nH=1`nSolidColor=0,0,0,1`n"
}
$iniPath=Join-Path $runRoot 'Rainmeter.ini'
$ini="[Rainmeter]`nSkinPath=$skinRoot\`nDisableVersionCheck=1`nDisableAutoUpdate=1`nLogging=1`nLanguage=1033`nTrayIcon=0`n"
foreach ($config in 'Parallax\Settings','FieldsWitness','FieldsControl') {
    $ini+="`n[$config]`nActive=1`nWindowX=-20000`nWindowY=-20000`nKeepOnScreen=0`nDraggable=0`nClickThrough=1`nAlphaValue=0`n"
}
Write-Isolated $iniPath $ini
Write-Isolated (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
Write-Isolated (Join-Path $runRoot 'TEST-ONLY.txt') "Instrumented disposable field QA. Do not distribute. No live Rainmeter configuration is used.`n"
$cases=[Collections.Generic.List[object]]::new()
$fieldKeys=@('Scale','ColumnWidth','Gutter','CornerRadius','TitleFontSize','HeaderFontSize','FontSize','BackgroundTransparency','BorderThickness','DividerThickness','TableHeaderBorderThickness','DataBarThickness')
foreach ($entry in @(
    @('Scale','112.5','1.125','112.50 %','Scale'),@('ColumnWidth','237','237','237px','ColumnWidth'),
    @('Gutter','5','5','5 PX','Gutter'),@('CornerRadius','14','14','14 px','CornerRadius'),
    @('TitleFontSize','11.25','11.25','11.25 pt','TitleFontSize'),@('HeaderFontSize','9.5','9.5','9.50 PT','HeaderFontSize'),
    @('FontSize','6.75','6.75','6.75pt','FontSize'),@('BackgroundTransparency','37.5','15,15,15,159','37.50 %','BackgroundColor'),
    @('BorderThickness','2.25','2.25','2.25 px','BorderThickness'),@('DividerThickness','0.5','0.5','0.50 PX','DividerThickness'),
    @('TableHeaderBorderThickness','0.25','0.25','0.25 px','TableHeaderBorderThickness'),
    @('DataBarThickness','8.75','8.75','8.75 PX','DataBarThickness')
)) {
    $cases.Add([pscustomobject]@{Key=$entry[0];Response=('PARALLAX_INPUT_V1|ok|'+$entry[1]);Saved=$entry[2];Input=$entry[3];SavedKey=$entry[4];Kind='valid'})
}
foreach ($key in $fieldKeys) {
    $cases.Add([pscustomobject]@{Key=$key;Response='PARALLAX_INPUT_V1|cancel|';Saved='';Input='';SavedKey='';Kind='cancel'})
}
foreach ($entry in @(
    @('Scale','PARALLAX_INPUT_V1|ok|999'),@('ColumnWidth','PARALLAX_INPUT_V1|ok|237][!Quit]'),
    @('Gutter','PARALLAX_INPUT_V1|ok|5|extra'),@('CornerRadius',"PARALLAX_INPUT_V1|ok|14`nextra"),
    @('TitleFontSize','PARALLAX_INPUT_V1|ok|12.01'),@('HeaderFontSize','PARALLAX_INPUT_V1|ok|9.001'),
    @('FontSize','PARALLAX_INPUT_V1|ok|6.75;os.execute("calc")'),@('BackgroundTransparency','PARALLAX_INPUT_V1|ok|100.01'),
    @('BorderThickness','PARALLAX_INPUT_V1|ok|4.01'),@('DividerThickness','PARALLAX_INPUT_V1|ok|0.5|cancel|'),
    @('TableHeaderBorderThickness','PARALLAX_INPUT_V1|ok|0.001'),
    @('DataBarThickness','PARALLAX_INPUT_V1|ok|0')
)) {
    $cases.Add([pscustomobject]@{Key=$entry[0];Response=$entry[1];Saved='';Input='';SavedKey='';Kind='malformed'})
}
$records=[Collections.Generic.List[object]]::new()
$generation=1
$sequence=0
try {
    # Existing absolute private INI and SkinPath create a separate Rainmeter instance.
    # There are no CLI bangs, live config writes, screenshots or desktop interactions.
    $process=Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    $native=Await-Report (Join-Path $runRoot 'ready-1.txt')
    Assert-State $native $expected $generation
    foreach ($case in $cases) {
        $sequence++
        $beforeHash=(Get-FileHash -LiteralPath $userPath -Algorithm SHA256).Hash
        $initial=Get-Initial $expected $case.Key
        Write-Isolated (Join-Path $runRoot 'helper-case.json') (@{Sequence=$sequence;Key=$case.Key;Initial=$initial;Input=$case.Input;Kind=$case.Kind;Response=$case.Response}|ConvertTo-Json)
        Write-Isolated (Join-Path $runRoot 'expected-response.txt') $case.Response
        Write-Isolated (Join-Path $runRoot 'request.txt') "$sequence|$($case.Key)"
        if ($case.Kind -eq 'valid') {
            $generation++
            $native=Await-Report (Join-Path $runRoot "ready-$generation.txt")
            $expected[$case.SavedKey]=$case.Saved
        } else {
            $native=Await-Report (Join-Path $runRoot "result-$sequence.txt")
            Require ((Get-FileHash -LiteralPath $userPath -Algorithm SHA256).Hash -eq $beforeHash) 'Cancelled or malformed result changed UserSettings bytes.'
            if ($case.Kind -eq 'malformed') { Require ($native.MeterInputStatus -eq 'Value was not applied. Click the field to try again.') 'Malformed result did not show the production error state.' }
        }
        Assert-State $native $expected $generation
        $actual=Read-Values $userPath
        foreach ($key in $baseline.Keys) {
            $expectedValue=if ($expected.ContainsKey($key)) { $expected[$key] } else { $baseline[$key] }
            Require ($actual[$key] -eq $expectedValue) "Unexpected persisted value for $key."
        }
        Require ($actual.Count -eq $baseline.Count) 'Field commit added unrelated settings.'
        Require (-not $actual.ContainsKey('BackgroundTransparency')) 'Transparency commit introduced a separate persisted key.'
        $launch=Get-Content -LiteralPath (Join-Path $runRoot "helper-$sequence.json") -Raw | ConvertFrom-Json
        Require ($launch.Status -eq 'PASS' -and $launch.InitialProtocol -eq ('PARALLAX_INPUT_V1|ok|'+$initial)) 'Real helper validator or launch arguments failed.'
        if ($case.Kind -eq 'valid') { Require ($launch.InputProtocol -eq $case.Response) 'Real helper validator did not produce the expected canonical submitted value.' }
        $before=Read-Values (Join-Path $runRoot "before-$sequence.txt")
        $launchBounds=(@($launch.X,$launch.Y,$launch.Width,$launch.Height)-join ',')
        Require ($launchBounds -eq $before[$case.Key+'Bounds']) 'BeginEdit did not pass actual native field bounds to RunCommand.'
        Require ([double]::Parse($launch.Scale,[Globalization.CultureInfo]::InvariantCulture) -eq [double]::Parse($before.Scale,[Globalization.CultureInfo]::InvariantCulture)) 'Helper scale argument differs from native scale.'
        # A quiet interval catches duplicate/looped refreshes after asynchronous completion.
        Start-Sleep -Milliseconds 400
        Require ([IO.File]::ReadAllText((Join-Path $runRoot 'settings-generation.txt')) -eq "$generation") 'Settings refreshed an unexpected number of times.'
        Require ([IO.File]::ReadAllText((Join-Path $runRoot 'witness-generation.txt')) -eq "$generation") 'Parallax group witness did not refresh exactly once per save.'
        Require ([IO.File]::ReadAllText((Join-Path $runRoot 'control-generation.txt')) -eq '1') 'Field save refreshed an unrelated skin group.'
        $savedKey=if ($case.Key -eq 'BackgroundTransparency') { 'BackgroundColor' } else { $case.Key }
        $records.Add([pscustomobject]@{Sequence=$sequence;Key=$case.Key;Kind=$case.Kind;Generation=$generation;Initial=$initial;SavedKey=$savedKey;Saved=$expected[$savedKey];Displayed=$native[$case.Key+'Text'];Width=$native.Width;Height=$native.Height;UserSettingsSHA256=(Get-FileHash -LiteralPath $userPath -Algorithm SHA256).Hash})
    }
    $logPath=Join-Path $runRoot 'Rainmeter.log'
    if (Test-Path -LiteralPath $logPath) {
        $errors=@(Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^ERRO' })
        Require ($errors.Count -eq 0) ('Native Rainmeter errors: '+($errors -join "`n"))
    }
    Require ((Get-FileHash -LiteralPath (Join-Path $scripts 'Settings.lua') -Algorithm SHA256).Hash -eq $sourceHashes['@Resources\Scripts\Settings.lua']) 'Copied production Settings.lua changed during the test.'
    Require ((Get-FileHash -LiteralPath (Join-Path $scripts 'SettingsFieldsProductionInput.ps1') -Algorithm SHA256).Hash -eq $sourceHashes['@Resources\Scripts\SettingsInput.ps1']) 'Copied production validator bytes changed.'
    $report=[ordered]@{Status='PASS';RainmeterVersion=(Get-Item -LiteralPath $RainmeterPath).VersionInfo.FileVersion;SourceSHA256=$sourceHashes;Cases=$records.ToArray();ValidSaves=12;Cancelled=12;Malformed=12;SettingsGenerations=$generation;GroupWitnessGenerations=$generation;UnrelatedGenerations=1;Limitations='All twelve native source actions, bundled RunCommand, fixed FinishAction, production helper validation/Lua and actual isolated writes verified. Transparency persists only background RGBA alpha. Textbox GUI, mouse hit testing, mixed DPI and the live user configuration are not exercised.'}
    Write-Isolated (Join-Path $runRoot 'report.json') ($report|ConvertTo-Json -Depth 6)
    [pscustomobject]@{Status='PASS';Cases=$records.Count;RunRoot=$runRoot;SettingsGenerations=$generation;GroupWitnessGenerations=$generation;UnrelatedGenerations=1}
} finally {
    if ($null -ne $process) {
        $process.Refresh()
        if (-not $process.HasExited) { Stop-Process -InputObject $process -Force; $null=$process.WaitForExit(5000) }
        $process.Dispose()
    }
}

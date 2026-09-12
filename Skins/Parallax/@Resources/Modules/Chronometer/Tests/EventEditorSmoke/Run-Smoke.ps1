[CmdletBinding()]
param(
    [string]$RainmeterPath = (Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'),
    [ValidateRange(30, 240)][int]$TimeoutSeconds = 180,
    [switch]$AutomatedForm,
    [string]$CompilerPath = (Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe')
)

$ErrorActionPreference = 'Stop'
$smokeRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$moduleRoot = Split-Path -Parent (Split-Path -Parent $smokeRoot)
$resourceRoot = Split-Path -Parent (Split-Path -Parent $moduleRoot)
$suiteRoot = Split-Path -Parent $resourceRoot
$runtimeRoot = Join-Path $smokeRoot '.runtime'
$runRoot = Join-Path $runtimeRoot ('run-' + [guid]::NewGuid().ToString('N'))
$testProcess = $null
$stagedEditor = $null

function Assert-WithinRun([string]$Path) {
    $resolved = [IO.Path]::GetFullPath($Path)
    if ($resolved -ne $runRoot -and -not $resolved.StartsWith($runRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing operation outside generated editor smoke run: $resolved"
    }
}
function Write-Utf8([string]$Path, [string]$Contents) {
    Assert-WithinRun $Path
    [IO.File]::WriteAllText($Path, $Contents, (New-Object Text.UTF8Encoding($false)))
}
function Copy-IntoRun([string]$Source, [string]$Target) {
    Assert-WithinRun $Target
    Copy-Item -LiteralPath $Source -Destination $Target
}

if (-not (Test-Path -LiteralPath $RainmeterPath -PathType Leaf)) { throw 'An existing Rainmeter installation is required.' }
$editorSource = Join-Path $moduleRoot 'EventEditor.exe'
if (-not $AutomatedForm -and -not (Test-Path -LiteralPath $editorSource -PathType Leaf)) { throw 'Build the original EventEditor.exe before starting interactive QA; this harness does not build the production helper.' }
if ($AutomatedForm -and -not (Test-Path -LiteralPath $CompilerPath -PathType Leaf)) { throw 'Automated form QA requires an existing .NET Framework C# compiler; nothing is installed.' }
if ((Test-Path -LiteralPath $runtimeRoot) -and ((Get-Item -LiteralPath $runtimeRoot -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'Editor smoke runtime root must not be a junction or symbolic link.'
}

try {
    $skinRoot = Join-Path $runRoot 'Skins'
    $skinDirectory = Join-Path $skinRoot 'Parallax\Chronometer'
    $resources = Join-Path $skinRoot 'Parallax\@Resources'
    $scripts = Join-Path $resources 'Modules\Chronometer'
    foreach ($directory in @($skinDirectory, $scripts, (Join-Path $resources 'User'),
        (Join-Path $runRoot 'Layouts'), (Join-Path $runRoot 'Plugins'), (Join-Path $runRoot 'Addons'))) {
        Assert-WithinRun $directory
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    foreach ($name in @('Defaults.inc', 'Geometry.inc', 'Styles.inc')) {
        Copy-IntoRun (Join-Path $resourceRoot $name) (Join-Path $resources $name)
    }
    foreach ($name in @('Core.lua', 'Store.lua', 'Chronometer.lua', 'Event.lua', 'EventCore.lua', 'Defaults.inc', 'Layout.inc', 'Styles.inc')) {
        Copy-IntoRun (Join-Path $moduleRoot $name) (Join-Path $scripts $name)
    }
    if ($AutomatedForm) {
        $stagedEditor = [IO.Path]::GetFullPath((Join-Path $scripts 'EventEditorFormTests.exe'))
        Assert-WithinRun $stagedEditor
        $formSources = @((Join-Path $moduleRoot 'EventEditor.cs'), (Join-Path $moduleRoot 'EventEditorForm.cs'),
            (Join-Path $moduleRoot 'Tests\EventEditorFormTests.cs'))
        foreach ($source in $formSources) { if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing form test source: $source" } }
        & $CompilerPath /nologo /target:winexe /optimize+ '/reference:System.Windows.Forms.dll,System.Drawing.dll' "/out:$stagedEditor" '/main:Parallax.Chronometer.EventEditorFormTests' @formSources
        if ($LASTEXITCODE -ne 0) { throw 'Test-only form entrypoint compilation failed.' }
    }
    else {
        $stagedEditor = [IO.Path]::GetFullPath((Join-Path $scripts 'EventEditor.exe'))
        Copy-IntoRun $editorSource $stagedEditor
    }
    Copy-IntoRun (Join-Path $smokeRoot 'Smoke.lua') (Join-Path $scripts 'EventEditorSmoke.lua')
    foreach ($name in @('Settings.inc', 'Chronometer.inc')) {
        Copy-IntoRun (Join-Path $resourceRoot ('User\' + $name)) (Join-Path $resources ('User\' + $name))
    }
    $sourceFonts = Join-Path $resourceRoot 'Fonts'
    if (Test-Path -LiteralPath $sourceFonts -PathType Container) {
        $targetFonts = Join-Path $resources 'Fonts'
        Assert-WithinRun $targetFonts
        New-Item -ItemType Directory -Path $targetFonts -Force | Out-Null
        foreach ($font in Get-ChildItem -LiteralPath $sourceFonts -File) {
            if ($font.Extension -in @('.ttf', '.otf')) { Copy-IntoRun $font.FullName (Join-Path $targetFonts $font.Name) }
        }
    }
    $resultPath = Join-Path $runRoot 'results.txt'
    $productionIni = Get-Content -LiteralPath (Join-Path $suiteRoot 'Chronometer\Chronometer.ini') -Raw
    if ($AutomatedForm) {
        $editorSection = [regex]::Match($productionIni, '(?ms)^\[MeasureEventEditor\]\r?\n.*?(?=^\[|\z)').Value
        $programLine = [regex]::Match($editorSection, '(?m)^Program=.*$').Value
        if (-not $editorSection -or -not $programLine) { throw 'Production editor RunCommand definition is missing.' }
        # Override only the copied Program. Parameter and FinishAction stay production-exact.
        $replacement = $editorSection.Replace($programLine, ('Program=""' + $stagedEditor + '""'))
        $productionIni = $productionIni.Replace($editorSection, $replacement)
    }
    $automatedFlag = if ($AutomatedForm) { '1' } else { '0' }
    Write-Utf8 (Join-Path $skinDirectory 'Chronometer.ini') ($productionIni + "`n" + @"
[MeasureEventEditorSmoke]
Measure=Script
ScriptFile=#@#Modules\Chronometer\EventEditorSmoke.lua
ResultPath=$resultPath
TimeoutSeconds=$TimeoutSeconds
EditorExecutable=$stagedEditor
AutomatedForm=$automatedFlag
"@)
    $iniPath = Join-Path $runRoot 'Rainmeter.ini'
    Write-Utf8 $iniPath @"
[Rainmeter]
SkinPath=$skinRoot\
DisableVersionCheck=1
DisableAutoUpdate=1
Logging=1
Language=1033
TrayIcon=0

[Parallax\Chronometer]
Active=1
WindowX=0
WindowY=0
Draggable=0
ClickThrough=1
AlphaValue=0
"@
    Write-Utf8 (Join-Path $runRoot 'Rainmeter.data') "[Rainmeter]`n"
    if (-not (Test-Path -LiteralPath $skinRoot -PathType Container)) { throw 'Missing isolated SkinPath; refusing launch.' }
    if ($AutomatedForm) { Write-Output 'Automated form QA: test-only entrypoint invokes the unshown production form Save handler; no OS input or GUI interaction.' }
    else { Write-Output 'Interactive QA: in the Chronometer event form, enter Release party, choose a future date/time, then Save.' }
    Write-Output "Isolated run: $runRoot"
    $testProcess = Start-Process -FilePath $RainmeterPath -ArgumentList ('"{0}"' -f $iniPath) -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
    Write-Output "Isolated Rainmeter PID: $($testProcess.Id); timeout: $TimeoutSeconds seconds."
    if (-not $testProcess.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-Process -InputObject $testProcess -Force
        $testProcess.WaitForExit(5000) | Out-Null
        throw 'Interactive editor QA timed out.'
    }
    $testProcess.Dispose()
    $testProcess = $null
    $logPath = Join-Path $runRoot 'Rainmeter.log'
    $log = if (Test-Path -LiteralPath $logPath) { Get-Content -LiteralPath $logPath -Raw } else { '' }
    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) { Write-Output $log; throw 'Interactive editor QA report missing.' }
    $result = Get-Content -LiteralPath $resultPath -Raw
    Write-Output $result
    if ($result -notmatch 'SUMMARY: (\d+) checks, 0 failed') { Write-Output $log; throw 'Interactive editor QA failed.' }
    if ($log -match '(?m)^ERRO|\bError:|Script:.*(not valid|error)') { Write-Output $log; throw 'Rainmeter logged an interactive editor error.' }
    Write-Output 'Editor integration QA passed with no Rainmeter errors.'
}
finally {
    if ($null -ne $testProcess) {
        $testProcess.Refresh()
        if (-not $testProcess.HasExited) { Stop-Process -InputObject $testProcess -Force; $testProcess.WaitForExit(5000) | Out-Null }
        $testProcess.Dispose()
    }
    # Only a leftover helper loaded from this exact, unique copied executable is ours.
    # Never terminate another EventEditor or any other live Rainmeter instance.
    if ($stagedEditor) {
        Assert-WithinRun $stagedEditor
        $editorProcessName = [IO.Path]::GetFileNameWithoutExtension($stagedEditor)
        foreach ($editorProcess in Get-Process -Name $editorProcessName -ErrorAction SilentlyContinue) {
            if ($editorProcess.Path -and [IO.Path]::GetFullPath($editorProcess.Path) -eq $stagedEditor) {
                Stop-Process -InputObject $editorProcess -Force
                $editorProcess.WaitForExit(5000) | Out-Null
            }
        }
    }
    if (Test-Path -LiteralPath $runRoot) {
        $resolvedRun = [IO.Path]::GetFullPath((Get-Item -LiteralPath $runRoot -Force).FullName)
        $expectedRuntime = [IO.Path]::GetFullPath($runtimeRoot) + '\'
        if (-not $resolvedRun.StartsWith($expectedRuntime, [StringComparison]::OrdinalIgnoreCase) -or
            (Split-Path -Leaf $resolvedRun) -notmatch '^run-[a-f0-9]{32}$' -or
            ((Get-Item -LiteralPath $runRoot -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'Refusing cleanup outside exact generated editor smoke run.'
        }
        Remove-Item -LiteralPath $resolvedRun -Recurse -Force
    }
}

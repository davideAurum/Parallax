#requires -Version 5.1
# Isolated behavioral fixtures. Never loads Rainmeter or removes a directory.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$toolsRoot = Split-Path -Parent $PSScriptRoot
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('Parallax-ToolTests-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot
function Put-File([string]$Path, [string]$Content) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { $null = New-Item -ItemType Directory -Path $parent }
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($true))
}
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "Fixture assertion failed: $Message" }
}
function Assert-Fails([scriptblock]$Action, [string]$Message) {
    $failed = $false
    try { $null = & $Action } catch { $failed = $true }
    Assert-True $failed $Message
}
function New-Fixture([string]$Name) {
    $project = Join-Path $fixtureRoot $Name
    $skin = Join-Path $project 'Skins\Parallax'
    Put-File (Join-Path $skin 'Settings\Settings.ini') @'
[Rainmeter]
Update=1000
@Include=#@#Defaults.inc
@Include2=#@#User\Settings.inc
@Include3=#@#Styles.inc
[Metadata]
Name=Fixture
[MeterText]
Meter=String
MeterStyle=StyleText
Text=Fixture
'@
    Put-File (Join-Path $skin '@Resources\Defaults.inc') "[Variables]`nColor=255,255,255`n"
    Put-File (Join-Path $skin '@Resources\User\Settings.inc') "[Variables]`nColor=200,200,200`n"
    Put-File (Join-Path $skin '@Resources\Styles.inc') "[StyleText]`nFontColor=#Color#`n"
    return [pscustomobject]@{ Project = $project; Skin = $skin }
}

$valid = New-Fixture 'valid'
$result = & (Join-Path $toolsRoot 'Test-Parallax.ps1') -SkinRoot $valid.Skin
Assert-True ($result.Errors -eq 0) 'Layered Variables should validate.'
Assert-True ($result.Warnings -eq 8) 'Eight missing utilities, including Network, should be reported for the Settings-only fixture.'
Assert-Fails { & (Join-Path $toolsRoot 'Test-Parallax.ps1') -SkinRoot $valid.Skin -RequireAllModules } 'Required missing modules must fail.'
Put-File (Join-Path $valid.Skin '@Resources\Cache\cover.png') 'Not a real image; must never ship.'
Put-File (Join-Path $valid.Skin '@Resources\Runtime\state.json') '{"state":"test"}'
Put-File (Join-Path $valid.Skin '@Resources\access-token.json') '{"token":"fixture-only"}'
Put-File (Join-Path $valid.Skin '@Resources\unreviewed.dll') 'Not a real DLL; must never ship.'
$first = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $valid.Project -Version 'test'
$second = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $valid.Project -Version 'test'
Assert-True ($first.StageRoot -ne $second.StageRoot) 'Repeated staging must create fresh paths.'
Assert-True (Test-Path -LiteralPath $first.StageRoot) 'Original stage must remain intact.'
Assert-True ($first.Excluded -eq 4) 'Cache, runtime, token, and DLL fixtures must be excluded.'
Assert-True ($first.VariablesFiles -eq 'Parallax\@Resources\User\Settings.inc') 'Preservation field must contain exact root-prefixed path.'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $first.SkinRoot '@Resources\Cache'))) 'Cache path must not be staged.'
$manifest = Get-Content -LiteralPath (Join-Path $first.StageRoot 'stage-manifest.json') -Raw | ConvertFrom-Json
Assert-True ($manifest.Files.Count -eq 4) 'Manifest must list only shipped fixture files.'
foreach ($entry in $manifest.Files) {
    $hash = (Get-FileHash -LiteralPath (Join-Path $first.StageRoot $entry.Path) -Algorithm SHA256).Hash
    Assert-True ($hash -eq $entry.SHA256) 'Manifest hash must match actual staged bytes.'
}

$mediaHelpers = New-Fixture 'media-helper-exact-paths'
$helperSource = Join-Path (Split-Path -Parent $toolsRoot) 'Skins\Parallax\@Resources\Modules\Media\Queue'
$helperRelativeRoot = '@Resources\Modules\Media\Queue'
$helperNames = @('QueueProvider.ps1','QueueCore.psm1','QueueAuth.psm1')
foreach ($name in $helperNames) {
    $destination = Join-Path $mediaHelpers.Skin "$helperRelativeRoot\$name"
    Put-File $destination ''
    # Copy production bytes as data only. No helper is imported or executed.
    Copy-Item -LiteralPath (Join-Path $helperSource $name) -Destination $destination
}
$excludedHelperCopies = @(
    '@Resources\Modules\Media\Queue\Scripts\QueueProvider.ps1',
    '@Resources\Modules\CPU\QueueProvider.ps1',
    '@Resources\Modules\Media\Queue\QueueProvider.experimental.ps1',
    '@Resources\Modules\Media\Queue\QueueCore.ps1',
    '@Resources\Modules\Media\Queue\QueueAuth.psm1.ps1',
    '@Resources\Modules\Media\Queue\Tests\QueueProvider.ps1',
    '@Resources\Modules\Media\Queue\Fixtures\QueueCore.psm1',
    '@Resources\Modules\Media\Queue\Private\QueueAuth.psm1',
    '@Resources\Modules\Media\Queue\Runtime\QueueProvider.ps1',
    '@Resources\Modules\Media\Queue\Cache\QueueCore.psm1',
    '@Resources\User\QueueProvider.ps1',
    '@Resources\Modules\Media\Queue\queue.snapshot',
    '@Resources\Modules\Media\Queue\client.json',
    '@Resources\Modules\Media\Queue\tokens.dpapi',
    '@Resources\Modules\Media\Queue\queue.retry.json'
)
foreach ($path in $excludedHelperCopies) { Put-File (Join-Path $mediaHelpers.Skin $path) '# Synthetic packaging exclusion fixture only.' }
$helperStage = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $mediaHelpers.Project -Version 'test-media-helpers'
$helperManifest = Get-Content -LiteralPath (Join-Path $helperStage.StageRoot 'stage-manifest.json') -Raw | ConvertFrom-Json
Assert-True ($helperManifest.Files.Count -eq 7) 'Only baseline skin files and the three exact Media helpers may ship.'
foreach ($name in $helperNames) {
    $relative = "$helperRelativeRoot\$name"
    $entries = @($helperManifest.Files | Where-Object { $_.Path -eq "Skins\Parallax\$relative" })
    Assert-True ($entries.Count -eq 1) "Missing exact helper manifest entry: $name"
    $sourceHash = (Get-FileHash -LiteralPath (Join-Path $helperSource $name) -Algorithm SHA256).Hash
    $stagedHash = (Get-FileHash -LiteralPath (Join-Path $helperStage.SkinRoot $relative) -Algorithm SHA256).Hash
    Assert-True ($entries[0].SHA256 -eq $sourceHash -and $stagedHash -eq $sourceHash) "Source, staged bytes, and manifest must agree for $name"
}
foreach ($path in $excludedHelperCopies) {
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $helperStage.SkinRoot $path))) "Unexpected packaged helper copy or runtime data: $path"
}
$hiddenHelperDirectory = Join-Path $mediaHelpers.Skin $helperRelativeRoot
[IO.File]::SetAttributes($hiddenHelperDirectory, ([IO.File]::GetAttributes($hiddenHelperDirectory) -bor [IO.FileAttributes]::Hidden))
$hiddenHelperStage = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $mediaHelpers.Project -Version 'test-hidden-media-helpers'
Assert-True ($hiddenHelperStage.Files -eq 4) 'An exact helper allowlist must never override a hidden parent exclusion.'

$sourceObserver = New-Fixture 'media-source-observer-exact-path'
$sourceObserverRoot = '@Resources\Modules\Media\Source'
$sourceObserverFiles = @('SourceProvider.ps1','SourceReader.lua')
foreach ($name in $sourceObserverFiles) {
    $relative = "$sourceObserverRoot\$name"
    $source = Join-Path (Split-Path -Parent $toolsRoot) "Skins\Parallax\$relative"
    $destination = Join-Path $sourceObserver.Skin $relative
    Put-File $destination ''
    # Copy inert bytes only. Never import the provider, launch its worker, or
    # read native sessions / LOCALAPPDATA snapshots during packaging tests.
    Copy-Item -LiteralPath $source -Destination $destination
}
$excludedObserverCopies = @(
    "$sourceObserverRoot\SourceProvider.extra.ps1",
    "$sourceObserverRoot\SourceProvider.psm1",
    "$sourceObserverRoot\SourceProvider.ps1.ps1",
    "$sourceObserverRoot\SourceProvider.ps1.txt",
    "$sourceObserverRoot\SourceProvider.ps1.txt.txt",
    "$sourceObserverRoot\Nested\SourceProvider.ps1",
    '@Resources\Modules\Media\Queue\SourceProvider.ps1',
    '@Resources\Modules\CPU\SourceProvider.ps1',
    '@Resources\User\SourceProvider.ps1',
    "$sourceObserverRoot\source.snapshot",
    "$sourceObserverRoot\stop.request",
    "$sourceObserverRoot\source.snapshot.synthetic.tmp"
)
foreach ($folder in 'Tests','Fixtures','Private','Runtime','Cache','.runtime') {
    $excludedObserverCopies += "$sourceObserverRoot\$folder\SourceProvider.ps1"
    $excludedObserverCopies += "$sourceObserverRoot\$folder\source.snapshot"
}
foreach ($path in $excludedObserverCopies) { Put-File (Join-Path $sourceObserver.Skin $path) '# Synthetic packaging exclusion fixture only.' }
$observerStage = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $sourceObserver.Project -Version 'test-media-source-observer'
$observerManifest = Get-Content -LiteralPath (Join-Path $observerStage.StageRoot 'stage-manifest.json') -Raw | ConvertFrom-Json
Assert-True ($observerManifest.Files.Count -eq 6) 'Only baseline files, the exact source observer and its passive reader may ship.'
foreach ($name in $sourceObserverFiles) {
    $relative = "$sourceObserverRoot\$name"
    $entries = @($observerManifest.Files | Where-Object { $_.Path -eq "Skins\Parallax\$relative" })
    Assert-True ($entries.Count -eq 1) "Missing exact source observer/reader manifest entry: $name"
    $source = Join-Path (Split-Path -Parent $toolsRoot) "Skins\Parallax\$relative"
    $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    $stagedHash = (Get-FileHash -LiteralPath (Join-Path $observerStage.SkinRoot $relative) -Algorithm SHA256).Hash
    Assert-True ($entries[0].SHA256 -eq $sourceHash -and $stagedHash -eq $sourceHash) "Source, staged bytes, and manifest must agree for $name"
}
$observerReaderBytes = [IO.File]::ReadAllBytes((Join-Path $observerStage.SkinRoot "$sourceObserverRoot\SourceReader.lua"))
Assert-True ($observerReaderBytes.Length -ge 2 -and $observerReaderBytes[0] -eq 255 -and $observerReaderBytes[1] -eq 254) 'The native Unicode SourceReader must retain its UTF-16LE BOM.'
foreach ($path in $excludedObserverCopies) {
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $observerStage.SkinRoot $path))) "Unexpected packaged source observer copy or runtime data: $path"
}
$hiddenObserverDirectory = Join-Path $sourceObserver.Skin $sourceObserverRoot
[IO.File]::SetAttributes($hiddenObserverDirectory, ([IO.File]::GetAttributes($hiddenObserverDirectory) -bor [IO.FileAttributes]::Hidden))
$hiddenObserverStage = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $sourceObserver.Project -Version 'test-hidden-media-source'
Assert-True ($hiddenObserverStage.Files -eq 4) 'The source observer exception must never override a hidden parent exclusion.'

$settingsInput = New-Fixture 'settings-input-exact-path'
$settingsInputRelative = '@Resources\Scripts\SettingsInput.ps1'
$settingsInputSource = Join-Path (Split-Path -Parent $toolsRoot) "Skins\Parallax\$settingsInputRelative"
$settingsInputDestination = Join-Path $settingsInput.Skin $settingsInputRelative
Put-File $settingsInputDestination ''
# Preserve the production helper bytes without loading its validation or UI code.
Copy-Item -LiteralPath $settingsInputSource -Destination $settingsInputDestination
$excludedInputCopies = @(
    '@Resources\Scripts\SettingsInput.extra.ps1',
    '@Resources\Scripts\SettingsInput.psm1',
    '@Resources\Scripts\SettingsInput.ps1.ps1',
    '@Resources\Scripts\Nested\SettingsInput.ps1',
    '@Resources\Modules\Settings\SettingsInput.ps1',
    '@Resources\Scripts\Tests\SettingsInput.ps1',
    '@Resources\Scripts\Fixtures\SettingsInput.ps1',
    '@Resources\Scripts\Private\SettingsInput.ps1',
    '@Resources\Scripts\Runtime\SettingsInput.ps1',
    '@Resources\Scripts\Cache\SettingsInput.ps1',
    '@Resources\User\SettingsInput.ps1'
)
foreach ($path in $excludedInputCopies) { Put-File (Join-Path $settingsInput.Skin $path) '# Synthetic packaging exclusion fixture only.' }
$inputStage = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $settingsInput.Project -Version 'test-settings-input'
$inputManifest = Get-Content -LiteralPath (Join-Path $inputStage.StageRoot 'stage-manifest.json') -Raw | ConvertFrom-Json
Assert-True ($inputManifest.Files.Count -eq 5) 'Only baseline skin files and the exact Settings input helper may ship.'
$inputEntries = @($inputManifest.Files | Where-Object { $_.Path -eq "Skins\Parallax\$settingsInputRelative" })
Assert-True ($inputEntries.Count -eq 1) 'The exact Settings input helper must have one manifest entry.'
$inputSourceHash = (Get-FileHash -LiteralPath $settingsInputSource -Algorithm SHA256).Hash
$inputStagedHash = (Get-FileHash -LiteralPath (Join-Path $inputStage.SkinRoot $settingsInputRelative) -Algorithm SHA256).Hash
Assert-True ($inputEntries[0].SHA256 -eq $inputSourceHash -and $inputStagedHash -eq $inputSourceHash) 'Source, staged bytes, and manifest must agree for SettingsInput.ps1.'
foreach ($path in $excludedInputCopies) {
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $inputStage.SkinRoot $path))) "Unexpected packaged Settings input helper copy: $path"
}
$hiddenInputDirectory = Split-Path -Parent $settingsInputDestination
[IO.File]::SetAttributes($hiddenInputDirectory, ([IO.File]::GetAttributes($hiddenInputDirectory) -bor [IO.FileAttributes]::Hidden))
$hiddenInputStage = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $settingsInput.Project -Version 'test-hidden-settings-input'
Assert-True ($hiddenInputStage.Files -eq 4) 'The Settings input exception must never override a hidden parent exclusion.'

$cpuDiscovery = New-Fixture 'cpu-discovery-exact-path'
$cpuDiscoveryRelative = '@Resources\Modules\CPU\DiscoverSensors.ps1'
$cpuDiscoverySource = Join-Path (Split-Path -Parent $toolsRoot) "Skins\Parallax\$cpuDiscoveryRelative"
$cpuDiscoveryDestination = Join-Path $cpuDiscovery.Skin $cpuDiscoveryRelative
Put-File $cpuDiscoveryDestination ''
# Copy source bytes only: running or dot-sourcing this helper would read live registry exports.
Copy-Item -LiteralPath $cpuDiscoverySource -Destination $cpuDiscoveryDestination
$excludedDiscoveryCopies = @(
    '@Resources\Modules\CPU\DiscoverSensors.extra.ps1',
    '@Resources\Modules\CPU\DiscoverSensors.psm1',
    '@Resources\Modules\CPU\DiscoverSensors.ps1.ps1',
    '@Resources\Modules\CPU\Scripts\DiscoverSensors.ps1',
    '@Resources\Modules\GPU\DiscoverSensors.ps1',
    '@Resources\Scripts\DiscoverSensors.ps1',
    '@Resources\Modules\CPU\Tests\DiscoverSensors.ps1',
    '@Resources\Modules\CPU\Fixtures\DiscoverSensors.ps1',
    '@Resources\Modules\CPU\Private\DiscoverSensors.ps1',
    '@Resources\Modules\CPU\Runtime\DiscoverSensors.ps1',
    '@Resources\Modules\CPU\Cache\DiscoverSensors.ps1',
    '@Resources\User\DiscoverSensors.ps1',
    '@Resources\Modules\CPU\discovered-sensors.json',
    '@Resources\Modules\CPU\sensor-output.log'
)
foreach ($path in $excludedDiscoveryCopies) { Put-File (Join-Path $cpuDiscovery.Skin $path) '# Synthetic packaging exclusion fixture only.' }
$discoveryStage = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $cpuDiscovery.Project -Version 'test-cpu-discovery'
$discoveryManifest = Get-Content -LiteralPath (Join-Path $discoveryStage.StageRoot 'stage-manifest.json') -Raw | ConvertFrom-Json
Assert-True ($discoveryManifest.Files.Count -eq 5) 'Only baseline skin files and the exact CPU discovery helper may ship.'
$discoveryEntries = @($discoveryManifest.Files | Where-Object { $_.Path -eq "Skins\Parallax\$cpuDiscoveryRelative" })
Assert-True ($discoveryEntries.Count -eq 1) 'The exact CPU discovery helper must have one manifest entry.'
$discoverySourceHash = (Get-FileHash -LiteralPath $cpuDiscoverySource -Algorithm SHA256).Hash
$discoveryStagedHash = (Get-FileHash -LiteralPath (Join-Path $discoveryStage.SkinRoot $cpuDiscoveryRelative) -Algorithm SHA256).Hash
Assert-True ($discoveryEntries[0].SHA256 -eq $discoverySourceHash -and $discoveryStagedHash -eq $discoverySourceHash) 'Source, staged bytes, and manifest must agree for DiscoverSensors.ps1.'
foreach ($path in $excludedDiscoveryCopies) {
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $discoveryStage.SkinRoot $path))) "Unexpected packaged CPU discovery copy or output: $path"
}
$hiddenDiscoveryDirectory = Split-Path -Parent $cpuDiscoveryDestination
[IO.File]::SetAttributes($hiddenDiscoveryDirectory, ([IO.File]::GetAttributes($hiddenDiscoveryDirectory) -bor [IO.FileAttributes]::Hidden))
$hiddenDiscoveryStage = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $cpuDiscovery.Project -Version 'test-hidden-cpu-discovery'
Assert-True ($hiddenDiscoveryStage.Files -eq 4) 'The CPU discovery exception must never override a hidden parent exclusion.'

$textHelpers = New-Fixture 'reviewed-text-suffix-helpers'
$textHelperPaths = @(
    '@Resources\Modules\GPU\DiscoverExports.ps1.txt',
    '@Resources\Modules\GPU\AdapterInfo.cs.txt',
    '@Resources\Modules\RAM\MemoryInfo.ps1.txt'
)
$textHelperSources = @{}
$excludedTextHelpers = @()
foreach ($relative in $textHelperPaths) {
    $source = Join-Path (Split-Path -Parent $toolsRoot) "Skins\Parallax\$relative"
    $destination = Join-Path $textHelpers.Skin $relative
    Put-File $destination ''
    # These are executable/helper/build sources despite .txt. Copy inert bytes:
    # never evaluate ScriptBlock, compile C#, call CIM, or query registry exports.
    Copy-Item -LiteralPath $source -Destination $destination
    $textHelperSources[$relative] = $source
    $parent = Split-Path -Parent $relative
    $name = Split-Path -Leaf $relative
    $variant = $name -replace '\.(ps1|cs)\.txt$', '.extra.$1.txt'
    $excludedTextHelpers += @(
        "$parent\$variant", "$parent\$name.txt",
        "$parent\$($name.Substring(0,$name.Length-4))",
        "@Resources\Modules\Other\$name", "@Resources\User\$name"
    )
    foreach ($folder in 'Tests','Fixtures','Private','Runtime','Cache','.runtime') {
        $excludedTextHelpers += "$parent\$folder\$name"
    }
}
foreach ($extension in 'ps1','psm1','psd1','cs','vb','fs','py','rb','sh','exe','dll','com','scr','cpl','bat','cmd','msi','msp','hta','vbs','vbe','js','jse','wsf','wsh') {
    $excludedTextHelpers += "@Resources\Unreviewed\extra.$extension.txt"
}
foreach ($path in $excludedTextHelpers) { Put-File (Join-Path $textHelpers.Skin $path) 'Synthetic exclusion fixture; must not be executed.' }
Put-File (Join-Path $textHelpers.Skin '@Resources\Notes.txt') 'Ordinary text documentation remains distributable.'
$textStage = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $textHelpers.Project -Version 'test-reviewed-text-helpers'
$textManifest = Get-Content -LiteralPath (Join-Path $textStage.StageRoot 'stage-manifest.json') -Raw | ConvertFrom-Json
Assert-True ($textManifest.Files.Count -eq 8) 'Only baseline files, ordinary documentation and the three reviewed text-suffix sources may ship.'
foreach ($relative in $textHelperPaths) {
    $entries = @($textManifest.Files | Where-Object { $_.Path -eq "Skins\Parallax\$relative" })
    Assert-True ($entries.Count -eq 1) "Missing exact reviewed text-suffix source: $relative"
    $sourceHash = (Get-FileHash -LiteralPath $textHelperSources[$relative] -Algorithm SHA256).Hash
    $stagedHash = (Get-FileHash -LiteralPath (Join-Path $textStage.SkinRoot $relative) -Algorithm SHA256).Hash
    Assert-True ($entries[0].SHA256 -eq $sourceHash -and $stagedHash -eq $sourceHash) "Source, staged bytes and manifest must agree for $relative"
}
foreach ($path in $excludedTextHelpers) {
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $textStage.SkinRoot $path))) "Unreviewed executable text-suffix copy shipped: $path"
}
Assert-True (Test-Path -LiteralPath (Join-Path $textStage.SkinRoot '@Resources\Notes.txt')) 'Ordinary documentation must still ship.'
$compoundExclusion = @($textManifest.Excluded | Where-Object { $_.Path -eq '@Resources\Unreviewed\extra.ps1.txt' })
Assert-True ($compoundExclusion.Count -eq 1 -and $compoundExclusion[0].Reason -match 'exact reviewed path') 'Manifest must explain the text-suffix helper exclusion.'
foreach ($relative in $textHelperPaths) {
    $hiddenPath = Join-Path $textHelpers.Skin $relative
    [IO.File]::SetAttributes($hiddenPath, ([IO.File]::GetAttributes($hiddenPath) -bor [IO.FileAttributes]::Hidden))
}
$hiddenTextStage = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $textHelpers.Project -Version 'test-hidden-text-helpers'
Assert-True ($hiddenTextStage.Files -eq 5) 'Reviewed text-suffix exceptions must not override hidden-file exclusions.'

$eventEditor = New-Fixture 'event-editor-exact-paths'
$eventRelativeRoot = '@Resources\Modules\Chronometer'
$eventSource = Join-Path (Split-Path -Parent $toolsRoot) "Skins\Parallax\$eventRelativeRoot"
$eventNames = @('EventEditor.exe','EventEditor.cs','EventEditorForm.cs','Build-EventEditor.ps1')
foreach ($name in $eventNames) {
    $destination = Join-Path $eventEditor.Skin "$eventRelativeRoot\$name"
    Put-File $destination ''
    # The existing binary and its build inputs are inert fixture bytes only.
    # This test never loads the assembly, executes the EXE, or runs the compiler.
    Copy-Item -LiteralPath (Join-Path $eventSource $name) -Destination $destination
}
$excludedEventCopies = @(
    '@Resources\Modules\Chronometer\EventEditor.extra.exe',
    '@Resources\Modules\Chronometer\EventEditor.exe.exe',
    '@Resources\Modules\Chronometer\EventEditor.dll',
    '@Resources\Modules\Chronometer\EventEditor.extra.cs',
    '@Resources\Modules\Chronometer\EventEditorForm.extra.cs',
    '@Resources\Modules\Chronometer\Build-EventEditor.extra.ps1',
    '@Resources\Modules\Chronometer\Scripts\EventEditor.exe',
    '@Resources\Modules\CPU\EventEditor.exe',
    '@Resources\Modules\CPU\EventEditor.cs',
    '@Resources\Modules\CPU\EventEditorForm.cs',
    '@Resources\Modules\CPU\Build-EventEditor.ps1',
    '@Resources\User\EventEditor.exe',
    '@Resources\Modules\Chronometer\Parallax-Chronometer-event-v1.state',
    '@Resources\Modules\Chronometer\.Parallax-Chronometer-event-test.tmp'
)
foreach ($folder in 'Tests','Fixtures','Private','Runtime','Cache','.runtime') {
    foreach ($name in $eventNames) { $excludedEventCopies += "$eventRelativeRoot\$folder\$name" }
}
foreach ($path in $excludedEventCopies) { Put-File (Join-Path $eventEditor.Skin $path) 'Synthetic packaging exclusion fixture only.' }
$eventStage = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $eventEditor.Project -Version 'test-event-editor'
$eventManifest = Get-Content -LiteralPath (Join-Path $eventStage.StageRoot 'stage-manifest.json') -Raw | ConvertFrom-Json
Assert-True ($eventManifest.Files.Count -eq 8) 'Only baseline skin files and the four exact Event editor payload/build files may ship.'
foreach ($name in $eventNames) {
    $relative = "$eventRelativeRoot\$name"
    $entries = @($eventManifest.Files | Where-Object { $_.Path -eq "Skins\Parallax\$relative" })
    Assert-True ($entries.Count -eq 1) "Missing exact Event editor manifest entry: $name"
    $sourceHash = (Get-FileHash -LiteralPath (Join-Path $eventSource $name) -Algorithm SHA256).Hash
    $stagedHash = (Get-FileHash -LiteralPath (Join-Path $eventStage.SkinRoot $relative) -Algorithm SHA256).Hash
    Assert-True ($entries[0].SHA256 -eq $sourceHash -and $stagedHash -eq $sourceHash) "Source, staged bytes, and manifest must agree for $name"
}
foreach ($path in $excludedEventCopies) {
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $eventStage.SkinRoot $path))) "Unexpected packaged Event editor copy or state: $path"
}
$hiddenEventDirectory = Join-Path $eventEditor.Skin $eventRelativeRoot
[IO.File]::SetAttributes($hiddenEventDirectory, ([IO.File]::GetAttributes($hiddenEventDirectory) -bor [IO.FileAttributes]::Hidden))
$hiddenEventStage = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $eventEditor.Project -Version 'test-hidden-event-editor'
Assert-True ($hiddenEventStage.Files -eq 4) 'Event editor payload and build exceptions must never override a hidden parent exclusion.'

$duplicate = New-Fixture 'duplicate'
Put-File (Join-Path $duplicate.Skin '@Resources\Defaults.inc') "[Variables]`nA=1`n[Variables]`nB=2`n"
Assert-Fails { & (Join-Path $toolsRoot 'Test-Parallax.ps1') -SkinRoot $duplicate.Skin } 'Duplicate local Variables sections must fail.'

$developer = New-Fixture 'developer-pruning'
$ignoredRelativePaths = @(
    '@Resources\Modules\Chronometer\Tests\Smoke\.runtime\case\Rainmeter.ini',
    '@Resources\Modules\CPU\QA\Transient.inc',
    '@Resources\Fixtures\Invalid.inc',
    '@Resources\Runtime\Invalid.inc',
    '@Resources\Cache\Invalid.inc',
    '@Resources\.scratch\Invalid.inc',
    'Settings\Test\Invalid.ini'
)
foreach ($relativePath in $ignoredRelativePaths) {
    Put-File (Join-Path $developer.Skin $relativePath) "[Variables]`nA=1`n[Variables]`nB=2`n"
}
$hiddenPath = Join-Path $developer.Skin '@Resources\HiddenWork\Invalid.inc'
Put-File $hiddenPath "[Variables]`nA=1`n[Variables]`nB=2`n"
$hiddenParent = Split-Path -Parent $hiddenPath
[IO.File]::SetAttributes($hiddenParent, ([IO.File]::GetAttributes($hiddenParent) -bor [IO.FileAttributes]::Hidden))
$lockedPath = Join-Path $developer.Skin $ignoredRelativePaths[0]
$lock = [IO.File]::Open($lockedPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
try {
    # The former validator tried to read this locked Rainmeter.ini. Pruned
    # discovery must not open transient QA files or count them as configs.
    $result = & (Join-Path $toolsRoot 'Test-Parallax.ps1') -SkinRoot $developer.Skin
    Assert-True ($result.Errors -eq 0 -and $result.Files -eq 4 -and $result.Configs -eq 1) 'Developer and hidden trees must be pruned before INI discovery.'
    $prunedStage = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $developer.Project -Version 'test'
    $prunedManifest = Get-Content -LiteralPath (Join-Path $prunedStage.StageRoot 'stage-manifest.json') -Raw | ConvertFrom-Json
    Assert-True ($prunedManifest.Files.Count -eq 4) 'Staging must use the same production tree as validation.'
    $prunedDirectories = @($prunedManifest.Excluded | Where-Object { $_.Kind -eq 'Directory' })
    Assert-True ($prunedDirectories.Count -eq 8) 'Manifest must record excluded directory roots without traversing their contents.'
    $baseConfig = Get-Content -LiteralPath (Join-Path $developer.Skin 'Settings\Settings.ini') -Raw
    foreach ($module in 'Chronometer','CPU','RAM','GPU','IO','Network','Media','Visualizer') {
        Put-File (Join-Path $developer.Skin "$module\$module.ini") $baseConfig
    }
    $releaseStage = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $developer.Project -Version 'test-complete' -RequireAllModules
    Assert-True ($releaseStage.Files -eq 12) 'RequireAllModules staging must pass for complete production configs while the QA file remains locked.'
} finally { $lock.Dispose() }

$unusedProduction = New-Fixture 'unused-production'
Put-File (Join-Path $unusedProduction.Skin '@Resources\UnusedProduction.inc') "[Variables]`nA=1`n[Variables]`nB=2`n"
Assert-Fails { & (Join-Path $toolsRoot 'Test-Parallax.ps1') -SkinRoot $unusedProduction.Skin } 'Unreferenced production includes must still be validated.'

$relative = New-Fixture 'nested-relative'
Put-File (Join-Path $relative.Skin '@Resources\Styles.inc') "[StyleText]`n@Include=sub\Nested.inc`n"
Put-File (Join-Path $relative.Skin '@Resources\sub\Nested.inc') "[StyleNested]`nFontSize=10`n"
$result = & (Join-Path $toolsRoot 'Test-Parallax.ps1') -SkinRoot $relative.Skin
Assert-True ($result.Errors -eq 0) 'Nested relative includes must use the including file directory.'

$precedence = New-Fixture 'precedence'
Put-File (Join-Path $precedence.Skin '@Resources\Defaults.inc') "[Variables]`nStyleChoice=AbsentStyle`n"
Put-File (Join-Path $precedence.Skin 'Settings\Settings.ini') @'
[Rainmeter]
Update=1000
[Metadata]
Name=Precedence fixture
[Variables]
@Include=#@#Defaults.inc
@Include2=#@#Styles.inc
StyleChoice=StyleText
[MeterText]
Meter=String
MeterStyle=#StyleChoice#
Text=Fixture
'@
$result = & (Join-Path $toolsRoot 'Test-Parallax.ps1') -SkinRoot $precedence.Skin
Assert-True ($result.Errors -eq 0) 'Local keys after includes must override included defaults.'

$missing = New-Fixture 'missing'
Put-File (Join-Path $missing.Skin '@Resources\Styles.inc') "[StyleText]`n@Include=#@#Absent.inc`n"
Assert-Fails { & (Join-Path $toolsRoot 'Test-Parallax.ps1') -SkinRoot $missing.Skin } 'Missing includes must fail.'

$cycle = New-Fixture 'cycle'
Put-File (Join-Path $cycle.Skin '@Resources\Styles.inc') "[StyleText]`n@Include=#@#Styles.inc`n"
Assert-Fails { & (Join-Path $toolsRoot 'Test-Parallax.ps1') -SkinRoot $cycle.Skin } 'Circular includes must fail.'

$outside = New-Fixture 'outside'
Put-File (Join-Path $outside.Skin '@Resources\Styles.inc') "[StyleText]`n@Include=..\..\outside.inc`n"
Assert-Fails { & (Join-Path $toolsRoot 'Test-Parallax.ps1') -SkinRoot $outside.Skin } 'Includes outside the suite must fail.'

$omitted = New-Fixture 'omitted'
Put-File (Join-Path $omitted.Skin '@Resources\Styles.inc') "[StyleText]`n@Include=#@#Cache\Required.inc`n"
Put-File (Join-Path $omitted.Skin '@Resources\Cache\Required.inc') "[StyleExtra]`nFontSize=12`n"
Assert-Fails { & (Join-Path $toolsRoot 'Test-Parallax.ps1') -SkinRoot $omitted.Skin } 'A production include targeting an excluded tree must fail explicitly.'
Assert-Fails { & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $omitted.Project -Version 'test' } 'An excluded but required include must fail staging.'

$unknown = New-Fixture 'unknown'
Put-File (Join-Path $unknown.Skin '@Resources\Styles.inc') "[DifferentStyle]`nFontSize=12`n"
Assert-Fails { & (Join-Path $toolsRoot 'Test-Parallax.ps1') -SkinRoot $unknown.Skin } 'Unknown style references must fail.'

$credential = New-Fixture 'credential'
Put-File (Join-Path $credential.Skin '@Resources\User\Settings.inc') "[Variables]`nSpotifyAccessToken=fixture-only`n"
Assert-Fails { & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $credential.Project -Version 'test' } 'Nonempty credential defaults must fail staging.'

Write-Host "Packaging tool fixtures passed. Inspect retained fixtures at: $fixtureRoot"

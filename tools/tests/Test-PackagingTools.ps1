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
Assert-True ($result.Warnings -eq 9) 'Nine missing components, including Network and Welcome, should be reported for the Settings-only fixture.'
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

$lucide = New-Fixture 'lucide-attribution'
$lucideSource = Join-Path (Split-Path -Parent $toolsRoot) 'Skins\Parallax'
$lucideGroups = @(
    @{ Module='Media'; Names=@('LICENSE','README.md','music.svg','user-round-group.svg','disc-3.svg','play.svg','pause.svg','play-off.svg','rewind.svg','fast-forward.svg','list-plus.svg','list-minus.svg','monitor-play.svg','step-forward.svg','audio-lines.svg') },
    @{ Module='GPU'; Names=@('LICENSE.txt','README.md','gpu.svg') },
    @{ Module='RAM'; Names=@('LICENSE','README.md','memory-stick.svg') },
    @{ Module='IO'; Names=@('LICENSE','README.md','hard-drive.svg') },
    @{ Module='Visualizer'; Names=@('LICENSE','README.md','speaker.svg') }
)
$lucideFiles = @(foreach ($group in $lucideGroups) {
    foreach ($name in $group.Names) { '@Resources\Modules\{0}\Icons\Lucide\{1}' -f $group.Module,$name }
})
foreach ($relative in $lucideFiles) {
    $destination = Join-Path $lucide.Skin $relative
    Put-File $destination ''
    Copy-Item -LiteralPath (Join-Path $lucideSource $relative) -Destination $destination
}
$excludedLucideFiles = @(foreach ($module in 'Media','RAM','IO','Visualizer') {
    '@Resources\Modules\{0}\Icons\LICENSE' -f $module
    '@Resources\Modules\{0}\Icons\Lucide\Private\LICENSE' -f $module
})
foreach ($relative in $excludedLucideFiles) { Put-File (Join-Path $lucide.Skin $relative) 'Synthetic unrelated or private extensionless fixture.' }
$lucideStage = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $lucide.Project -Version 'test-lucide-attribution'
$lucideManifest = Get-Content -LiteralPath (Join-Path $lucideStage.StageRoot 'stage-manifest.json') -Raw | ConvertFrom-Json
Assert-True ($lucideManifest.Files.Count -eq 31) 'All seventeen Media/GPU/RAM/IO/Visualizer SVGs, five provenance READMEs and five full licenses must ship alongside baseline files.'
foreach ($relative in $lucideFiles) {
    $entries = @($lucideManifest.Files | Where-Object { $_.Path -eq "Skins\Parallax\$relative" })
    Assert-True ($entries.Count -eq 1) "Missing Lucide provenance or license entry: $relative"
    $sourceHash = (Get-FileHash -LiteralPath (Join-Path $lucideSource $relative) -Algorithm SHA256).Hash
    $stagedHash = (Get-FileHash -LiteralPath (Join-Path $lucideStage.SkinRoot $relative) -Algorithm SHA256).Hash
    Assert-True ($entries[0].SHA256 -eq $sourceHash -and $stagedHash -eq $sourceHash) "Lucide source, stage and manifest bytes must agree: $relative"
}
foreach ($relative in $excludedLucideFiles) {
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $lucideStage.SkinRoot $relative))) "Unrelated/private extensionless file must remain excluded: $relative"
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
    '@Resources\Modules\Media\Queue\enabled.intent',
    '@Resources\Modules\Media\Queue\launch.id',
    '@Resources\Modules\Media\Queue\stop.request',
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
    "$sourceObserverRoot\enabled.intent",
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

$mediaLifecycle = New-Fixture 'media-lifecycle-source'
$lifecyclePaths = @('@Resources\Modules\Media\MediaLifecycle.lua', '@Resources\Modules\Media\Lifecycle.inc')
foreach ($relative in $lifecyclePaths) {
    $destination = Join-Path $mediaLifecycle.Skin $relative
    Put-File $destination ''
    Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $toolsRoot) "Skins\Parallax\$relative") -Destination $destination
}
$lifecycleStage = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $mediaLifecycle.Project -Version 'test-media-lifecycle'
$lifecycleManifest = Get-Content -LiteralPath (Join-Path $lifecycleStage.StageRoot 'stage-manifest.json') -Raw | ConvertFrom-Json
Assert-True ($lifecycleManifest.Files.Count -eq 6) 'Lifecycle Lua/include use normal source allowances alongside four baseline files.'
foreach ($relative in $lifecyclePaths) {
    $sourceHash = (Get-FileHash -LiteralPath (Join-Path (Split-Path -Parent $toolsRoot) "Skins\Parallax\$relative") -Algorithm SHA256).Hash
    $stagedHash = (Get-FileHash -LiteralPath (Join-Path $lifecycleStage.SkinRoot $relative) -Algorithm SHA256).Hash
    $entries = @($lifecycleManifest.Files | Where-Object { $_.Path -eq "Skins\Parallax\$relative" })
    Assert-True ($entries.Count -eq 1 -and $entries[0].SHA256 -eq $sourceHash -and $stagedHash -eq $sourceHash) "Lifecycle source, staged bytes and manifest must agree: $relative"
}

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
$updateInstall = New-Fixture 'update-install-exact-path'
$updateInstallRelative = '@Resources\Scripts\UpdateInstall.ps1'
$updateInstallSource = Join-Path (Split-Path -Parent $toolsRoot) "Skins\Parallax\$updateInstallRelative"
$updateInstallDestination = Join-Path $updateInstall.Skin $updateInstallRelative
Put-File $updateInstallDestination ''
# Preserve the production helper bytes without running its network code.
Copy-Item -LiteralPath $updateInstallSource -Destination $updateInstallDestination
$excludedUpdateCopies = @(
    '@Resources\Scripts\UpdateInstall.old.ps1',
    '@Resources\Scripts\UpdateInstall.ps1.ps1',
    '@Resources\Scripts\Nested\UpdateInstall.ps1',
    '@Resources\Modules\Welcome\UpdateInstall.ps1',
    '@Resources\Scripts\Tests\UpdateInstall.ps1',
    '@Resources\Scripts\Runtime\UpdateInstall.ps1',
    '@Resources\User\UpdateInstall.ps1'
)
foreach ($path in $excludedUpdateCopies) { Put-File (Join-Path $updateInstall.Skin $path) '# Synthetic packaging exclusion fixture only.' }
$updateStage = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $updateInstall.Project -Version 'test-update-install'
$updateManifest = Get-Content -LiteralPath (Join-Path $updateStage.StageRoot 'stage-manifest.json') -Raw | ConvertFrom-Json
Assert-True ($updateManifest.Files.Count -eq 5) 'Only baseline skin files and the exact update helper may ship.'
$updateEntries = @($updateManifest.Files | Where-Object { $_.Path -eq "Skins\Parallax\$updateInstallRelative" })
$updateSourceHash = (Get-FileHash -LiteralPath $updateInstallSource -Algorithm SHA256).Hash
$updateStagedHash = (Get-FileHash -LiteralPath (Join-Path $updateStage.SkinRoot $updateInstallRelative) -Algorithm SHA256).Hash
Assert-True ($updateEntries.Count -eq 1 -and $updateEntries[0].SHA256 -eq $updateSourceHash -and $updateStagedHash -eq $updateSourceHash) 'Source, staged bytes, and manifest must agree for UpdateInstall.ps1.'
foreach ($path in $excludedUpdateCopies) {
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $updateStage.SkinRoot $path))) "Unexpected packaged update helper copy: $path"
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

$threadColors = New-Fixture 'cpu-thread-color-exact-path'
$threadColorRelative = '@Resources\Modules\CPU\ThreadColorInput.ps1'
$threadColorSource = Join-Path (Split-Path -Parent $toolsRoot) "Skins\Parallax\$threadColorRelative"
$threadColorDestination = Join-Path $threadColors.Skin $threadColorRelative
Put-File $threadColorDestination ''
# Copy inert bytes only; the helper's WinForms overlay is never started here.
Copy-Item -LiteralPath $threadColorSource -Destination $threadColorDestination
$excludedThreadColorCopies = @(
    '@Resources\Modules\CPU\ThreadColorInput.extra.ps1',
    '@Resources\Modules\CPU\ThreadColorInput.psm1',
    '@Resources\Modules\CPU\ThreadColorInput.ps1.ps1',
    '@Resources\Modules\CPU\ThreadColorInput.ps1.txt',
    '@Resources\Modules\CPU\Scripts\ThreadColorInput.ps1',
    '@Resources\Modules\GPU\ThreadColorInput.ps1',
    '@Resources\Scripts\ThreadColorInput.ps1',
    '@Resources\User\ThreadColorInput.ps1'
)
foreach ($folder in 'Tests','Fixtures','Private','Runtime','Cache','.runtime') {
    $excludedThreadColorCopies += "@Resources\Modules\CPU\$folder\ThreadColorInput.ps1"
}
foreach ($path in $excludedThreadColorCopies) { Put-File (Join-Path $threadColors.Skin $path) '# Synthetic packaging exclusion fixture only.' }
$threadColorStage = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $threadColors.Project -Version 'test-cpu-thread-color'
$threadColorManifest = Get-Content -LiteralPath (Join-Path $threadColorStage.StageRoot 'stage-manifest.json') -Raw | ConvertFrom-Json
Assert-True ($threadColorManifest.Files.Count -eq 5) 'Only baseline skin files and the exact CPU thread color helper may ship.'
$threadColorEntries = @($threadColorManifest.Files | Where-Object { $_.Path -eq "Skins\Parallax\$threadColorRelative" })
Assert-True ($threadColorEntries.Count -eq 1) 'The exact CPU thread color helper must have one manifest entry.'
$threadColorSourceHash = (Get-FileHash -LiteralPath $threadColorSource -Algorithm SHA256).Hash
$threadColorStagedHash = (Get-FileHash -LiteralPath (Join-Path $threadColorStage.SkinRoot $threadColorRelative) -Algorithm SHA256).Hash
Assert-True ($threadColorEntries[0].SHA256 -eq $threadColorSourceHash -and $threadColorStagedHash -eq $threadColorSourceHash) 'Source, staged bytes, and manifest must agree for ThreadColorInput.ps1.'
foreach ($path in $excludedThreadColorCopies) {
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $threadColorStage.SkinRoot $path))) "Unexpected packaged CPU thread color helper copy: $path"
}
$hiddenThreadColorDirectory = Split-Path -Parent $threadColorDestination
[IO.File]::SetAttributes($hiddenThreadColorDirectory, ([IO.File]::GetAttributes($hiddenThreadColorDirectory) -bor [IO.FileAttributes]::Hidden))
$hiddenThreadColorStage = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $threadColors.Project -Version 'test-hidden-cpu-thread-color'
Assert-True ($hiddenThreadColorStage.Files -eq 4) 'The CPU thread color exception must never override a hidden parent exclusion.'

$textHelpers = New-Fixture 'reviewed-text-suffix-helpers'
$textHelperPaths = @(
    '@Resources\Modules\GPU\DiscoverExports.ps1.txt',
    '@Resources\Modules\GPU\AdapterInfo.cs.txt',
    '@Resources\Modules\GPU\DriverTemperature.cs.txt',
    '@Resources\Modules\IO\DriveModels.ps1.txt',
    '@Resources\Modules\RAM\MemoryInfo.ps1.txt',
    '@Resources\Modules\RAM\PageFileHost.cs.txt'
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
Assert-True ($textManifest.Files.Count -eq 11) 'Only baseline files, ordinary documentation and the six reviewed text-suffix sources may ship.'
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
    foreach ($module in 'Chronometer','CPU','RAM','GPU','IO','Network','Media','Visualizer','Welcome') {
        $entrypoint = if ($module -eq 'IO') { 'IO-Disk.ini' } else { "$module.ini" }
        Put-File (Join-Path $developer.Skin "$module\$entrypoint") $baseConfig
    }
    $releaseStage = & (Join-Path $toolsRoot 'Stage-Parallax.ps1') -ProjectRoot $developer.Project -Version 'test-complete' -RequireAllModules
    Assert-True ($releaseStage.Files -eq 13) 'RequireAllModules staging must pass for complete production configs while the QA file remains locked.'
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

# .rmskin packaging: a complete fixture suite is packaged, re-read and rejected when tampered.
# Nothing here launches Rainmeter or Skin Installer.
foreach ($assembly in 'System.IO.Compression', 'System.IO.Compression.FileSystem') {
    try { Add-Type -AssemblyName $assembly -ErrorAction Stop } catch { }
}
function Write-FixtureBitmap([string]$Path, [int]$Width, [int]$Height) {
    # Minimal uncompressed 24-bit Windows bitmap; only the header fields matter to the packager.
    $rowBytes = [int]([Math]::Ceiling(($Width * 3) / 4) * 4)
    $pixelBytes = $rowBytes * $Height
    $bytes = New-Object byte[] (54 + $pixelBytes)
    $bytes[0] = 0x42; $bytes[1] = 0x4D
    [Array]::Copy([BitConverter]::GetBytes([int32](54 + $pixelBytes)), 0, $bytes, 2, 4)
    [Array]::Copy([BitConverter]::GetBytes([int32]54), 0, $bytes, 10, 4)
    [Array]::Copy([BitConverter]::GetBytes([int32]40), 0, $bytes, 14, 4)
    [Array]::Copy([BitConverter]::GetBytes([int32]$Width), 0, $bytes, 18, 4)
    [Array]::Copy([BitConverter]::GetBytes([int32]$Height), 0, $bytes, 22, 4)
    [Array]::Copy([BitConverter]::GetBytes([int16]1), 0, $bytes, 26, 2)
    [Array]::Copy([BitConverter]::GetBytes([int16]24), 0, $bytes, 28, 2)
    [Array]::Copy([BitConverter]::GetBytes([int32]$pixelBytes), 0, $bytes, 34, 4)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { $null = New-Item -ItemType Directory -Path $parent }
    [IO.File]::WriteAllBytes($Path, $bytes)
}
function Write-FixtureDll([string]$Path, [uint16]$Machine) {
    # Minimal MZ + PE header carrying the requested machine type; never a loadable module.
    $bytes = New-Object byte[] 128
    $bytes[0] = 0x4D; $bytes[1] = 0x5A
    [Array]::Copy([BitConverter]::GetBytes([int32]64), 0, $bytes, 60, 4)
    $bytes[64] = 0x50; $bytes[65] = 0x45
    [Array]::Copy([BitConverter]::GetBytes($Machine), 0, $bytes, 68, 2)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { $null = New-Item -ItemType Directory -Path $parent }
    [IO.File]::WriteAllBytes($Path, $bytes)
}
$package = New-Fixture 'package'
$packageBaseConfig = Get-Content -LiteralPath (Join-Path $package.Skin 'Settings\Settings.ini') -Raw
foreach ($module in 'Chronometer','CPU','RAM','GPU','IO','Network','Media','Visualizer','Welcome') {
    $entrypoint = if ($module -eq 'IO') { 'IO-Disk.ini' } else { "$module.ini" }
    Put-File (Join-Path $package.Skin "$module\$entrypoint") $packageBaseConfig
    if ($module -ne 'Welcome') { Put-File (Join-Path $package.Skin "@Resources\User\$module.inc") "[Variables]`n${module}Option=1`n" }
}
Put-File (Join-Path $package.Skin '@Resources\Licenses\FixturePlugin-LICENSE.txt') 'Synthetic plugin license notice.'
Put-File (Join-Path $package.Skin '@Resources\Version.inc') "[Variables]`r`nParallaxVersion=test-package`r`n"
$fixturePluginRoot = Join-Path $package.Project 'packaging\Plugins\FixturePlugin\1.2.3.4'
Write-FixtureDll (Join-Path $fixturePluginRoot '32bit\FixturePlugin.dll') 0x14C
Write-FixtureDll (Join-Path $fixturePluginRoot '64bit\FixturePlugin.dll') 0x8664
Put-File (Join-Path $package.Project 'packaging\release.json') ([ordered]@{
    name = 'Parallax'; author = 'Fixture Author'; version = 'test-package'
    minimumRainmeter = '4.5.26'; minimumWindows = '10.0'; loadType = 'Skin'
    loadSkin = 'Parallax\Settings\Settings.ini'; mergeSkins = $false; headerImage = 'packaging\RMSKIN.bmp'; releaseRepository = 'fixture-owner/Fixture.Repo'
    plugins = @([ordered]@{ name = 'FixturePlugin'; version = '1.2.3.4'; directory = 'packaging\Plugins\FixturePlugin\1.2.3.4'; license = '@Resources\Licenses\FixturePlugin-LICENSE.txt' })
} | ConvertTo-Json -Depth 5)
Write-FixtureBitmap (Join-Path $package.Project 'packaging\RMSKIN.bmp') 400 60
$built = & (Join-Path $toolsRoot 'Package-Parallax.ps1') -ProjectRoot $package.Project
Assert-True (Test-Path -LiteralPath $built.Package) 'Packager must write the .rmskin file.'
Assert-True ((Split-Path -Leaf $built.Package) -eq 'Parallax_test-package.rmskin') 'Package file name must follow Name_Version.rmskin.'
$packageBytes = [IO.File]::ReadAllBytes($built.Package)
$trailer = $packageBytes[($packageBytes.Length - 16)..($packageBytes.Length - 1)]
Assert-True ($packageBytes[0] -eq 0x50 -and $packageBytes[1] -eq 0x4B) 'Package must begin with a ZIP local file header.'
Assert-True ([Text.Encoding]::ASCII.GetString($trailer, 9, 7) -eq "RMSKIN`0") 'Package must end with the RMSKIN key.'
Assert-True ([BitConverter]::ToInt64($trailer, 0) -eq ($packageBytes.Length - 16) -and $trailer[8] -eq 0) 'Trailer must record the archive length with zero flags.'
$verified = & (Join-Path $toolsRoot 'Test-ParallaxPackage.ps1') -PackagePath $built.Package -StageManifest (Join-Path $built.StageRoot 'stage-manifest.json') -ExpectedName 'Parallax' -ExpectedVersion 'test-package' -ExpectedSkinRoot 'Parallax' -RequireHeaderImage
Assert-True ($verified.SkinFiles -eq 23 -and $verified.Entries -eq 27) 'Package must contain RMSKIN.ini, RMSKIN.bmp, both plugin builds and every staged file.'
# The update feed describes exactly this package; Version.inc must match the package version.
$feed = Get-Content -LiteralPath $built.UpdateFeed -Raw | ConvertFrom-Json
Assert-True ((Split-Path -Leaf $built.UpdateFeed) -eq 'parallax-update.json') 'The update feed must be written beside the package.'
Assert-True ($feed.schema -eq 1 -and $feed.name -eq 'Parallax' -and $feed.version -eq 'test-package') 'The update feed must record schema, name and version.'
Assert-True ($feed.sha256 -eq $built.SHA256.ToLowerInvariant()) 'The update feed checksum must equal the package hash.'
Assert-True ($feed.url -eq 'https://github.com/fixture-owner/Fixture.Repo/releases/download/vtest-package/Parallax_test-package.rmskin') 'The update feed must point at the tagged release asset.'
Assert-True ($feed.notes -eq 'https://github.com/fixture-owner/Fixture.Repo/releases/tag/vtest-package') 'The update feed must link the release notes.'
Assert-Fails { & (Join-Path $toolsRoot 'Package-Parallax.ps1') -ProjectRoot $package.Project -Version 'test-mismatch' -OutputDirectory (Join-Path $package.Project 'dist-mismatch') } 'A package whose version differs from Version.inc must fail.'
Assert-True ($verified.PluginEntries -eq 2 -and @($verified.Plugins).Count -eq 1 -and $verified.Plugins -contains 'FixturePlugin.dll') 'Package must carry the bundled plugin for both architectures.'
Assert-True (@($built.Plugins).Count -eq 1 -and $built.Plugins -contains 'FixturePlugin') 'Packager output must name the bundled plugin.'
Assert-True ($verified.LoadType -eq 'Skin' -and $verified.Load -eq 'Parallax\Settings\Settings.ini') 'RMSKIN.ini must load the Settings config after installation.'
Assert-True ($verified.VariableFiles.Count -eq 9 -and ($verified.VariableFiles -contains 'Parallax\@Resources\User\Settings.inc')) 'RMSKIN.ini must list every User include for preservation.'
Assert-True ($verified.Author -eq 'Fixture Author' -and $verified.MinimumRainmeter -eq '4.5.26' -and $verified.MinimumWindows -eq '10.0') 'RMSKIN.ini must carry the release metadata.'
Assert-True ($verified.Warnings.Count -eq 0 -and $verified.ManifestMatched) 'A complete package must verify against its manifest without warnings.'
Assert-True ((Get-Content -LiteralPath $built.Checksum -Raw) -match '^[0-9a-f]{64}  Parallax_test-package\.rmskin\n$') 'Checksum file must use sha256sum format.'
$packageRecord = Get-Content -LiteralPath $built.Record -Raw | ConvertFrom-Json
Assert-True ($packageRecord.SHA256 -eq $built.SHA256 -and @($packageRecord.RmskinIni.VariableFiles).Count -eq 9) 'Package record must match the built file.'
$packageArchive = [IO.Compression.ZipFile]::OpenRead($built.Package)
try {
    $iniEntry = $packageArchive.GetEntry('RMSKIN.ini')
    Assert-True ($null -ne $iniEntry) 'RMSKIN.ini must be an archive root entry.'
    $iniStream = $iniEntry.Open()
    $iniMemory = [IO.MemoryStream]::new()
    $iniStream.CopyTo($iniMemory)
    $iniStream.Dispose()
    $iniBytes = $iniMemory.ToArray()
    Assert-True ($iniBytes.Length -gt 2 -and $iniBytes[0] -eq 0xFF -and $iniBytes[1] -eq 0xFE) 'RMSKIN.ini must be UTF-16LE with a byte-order mark.'
    Assert-True (@($packageArchive.Entries | Where-Object { $_.FullName.Contains('\') -or $_.FullName.EndsWith('/') }).Count -eq 0) 'Entries must use forward slashes and contain no directory records.'
    Assert-True (@($packageArchive.Entries | Where-Object { $_.FullName -like 'Skins/Parallax/*' }).Count -eq 23) 'Every skin file must sit under Skins/Parallax/.'
    Assert-True (($null -ne $packageArchive.GetEntry('Plugins/32bit/FixturePlugin.dll')) -and ($null -ne $packageArchive.GetEntry('Plugins/64bit/FixturePlugin.dll'))) 'Plugin builds must use the Plugins/<arch>/<name>.dll layout.'
} finally { $packageArchive.Dispose() }
$packageRecordPlugins = @($packageRecord.Plugins)
Assert-True ($packageRecordPlugins.Count -eq 2 -and ($packageRecordPlugins | Where-Object { $_.Entry -eq 'Plugins/64bit/FixturePlugin.dll' -and $_.Version -eq '1.2.3.4' -and $_.License -eq '@Resources\Licenses\FixturePlugin-LICENSE.txt' })) 'Package record must describe each plugin build.'
Assert-Fails { & (Join-Path $toolsRoot 'Package-Parallax.ps1') -ProjectRoot $package.Project } 'An existing package must not be overwritten without -Force.'
$rebuilt = & (Join-Path $toolsRoot 'Package-Parallax.ps1') -ProjectRoot $package.Project -StageRoot $built.StageRoot -Force
Assert-True ($rebuilt.Entries -eq 27 -and (Test-Path -LiteralPath $rebuilt.Package)) '-Force must rebuild the package from a reused stage.'
Assert-Fails { & (Join-Path $toolsRoot 'Package-Parallax.ps1') -ProjectRoot $package.Project -StageRoot $built.StageRoot -Version 'other' -Force } 'A reused stage must match the package version.'
$noAuthorRelease = Join-Path $package.Project 'packaging\release-no-author.json'
Put-File $noAuthorRelease ([ordered]@{ name = 'Parallax'; version = 'test-package'; minimumRainmeter = '4.5.26'; minimumWindows = '10.0'; loadSkin = 'Parallax\Settings\Settings.ini' } | ConvertTo-Json)
Assert-Fails { & (Join-Path $toolsRoot 'Package-Parallax.ps1') -ProjectRoot $package.Project -ReleaseFile $noAuthorRelease -StageRoot $built.StageRoot -Force } 'Packaging without an author must fail.'
Assert-Fails { & (Join-Path $toolsRoot 'Package-Parallax.ps1') -ProjectRoot $package.Project -StageRoot $built.StageRoot -MinimumWindows 'ten' -Force } 'Non-numeric minimum versions must fail.'
Assert-Fails { & (Join-Path $toolsRoot 'Package-Parallax.ps1') -ProjectRoot $package.Project -StageRoot $built.StageRoot -LoadSkin 'Parallax\Missing\Missing.ini' -Force } 'The load skin must exist in the stage.'
Write-FixtureBitmap (Join-Path $package.Project 'packaging\wrong.bmp') 10 10
Assert-Fails { & (Join-Path $toolsRoot 'Package-Parallax.ps1') -ProjectRoot $package.Project -StageRoot $built.StageRoot -HeaderImage (Join-Path $package.Project 'packaging\wrong.bmp') -Force } 'Header images must be exactly 400x60.'
$noPlugins = & (Join-Path $toolsRoot 'Package-Parallax.ps1') -ProjectRoot $package.Project -StageRoot $built.StageRoot -NoPlugins -Force
Assert-True ($noPlugins.Entries -eq 25 -and @($noPlugins.Plugins).Count -eq 0) '-NoPlugins must omit every plugin build.'
$fixturePlugin64 = Join-Path $fixturePluginRoot '64bit\FixturePlugin.dll'
Rename-Item -LiteralPath $fixturePlugin64 -NewName 'FixturePlugin.dll.absent'
Assert-Fails { & (Join-Path $toolsRoot 'Package-Parallax.ps1') -ProjectRoot $package.Project -StageRoot $built.StageRoot -Force } 'A plugin without its 64-bit build must fail.'
Rename-Item -LiteralPath ($fixturePlugin64 + '.absent') -NewName 'FixturePlugin.dll'
$fixturePlugin32 = Join-Path $fixturePluginRoot '32bit\FixturePlugin.dll'
[IO.File]::WriteAllBytes($fixturePlugin32, [Text.Encoding]::ASCII.GetBytes('Synthetic bytes without an MZ header; must never be packaged as a plugin.'))
Assert-Fails { & (Join-Path $toolsRoot 'Package-Parallax.ps1') -ProjectRoot $package.Project -StageRoot $built.StageRoot -Force } 'A plugin file without a PE header must fail.'
Write-FixtureDll $fixturePlugin32 0x8664
Assert-Fails { & (Join-Path $toolsRoot 'Package-Parallax.ps1') -ProjectRoot $package.Project -StageRoot $built.StageRoot -Force } 'A 64-bit image in the 32bit folder must fail.'
Write-FixtureDll $fixturePlugin32 0x14C
$ignoredPluginRelease = Join-Path $package.Project 'packaging\release-ignored-plugin.json'
Put-File $ignoredPluginRelease ([ordered]@{
    name = 'Parallax'; author = 'Fixture Author'; version = 'test-package'; minimumRainmeter = '4.5.26'; minimumWindows = '10.0'; loadSkin = 'Parallax\Settings\Settings.ini'
    plugins = @([ordered]@{ name = 'RunCommand'; version = '1.0.0.0'; directory = 'packaging\Plugins\FixturePlugin\1.2.3.4'; license = '@Resources\Licenses\FixturePlugin-LICENSE.txt' })
} | ConvertTo-Json -Depth 5)
Assert-Fails { & (Join-Path $toolsRoot 'Package-Parallax.ps1') -ProjectRoot $package.Project -ReleaseFile $ignoredPluginRelease -StageRoot $built.StageRoot -Force } 'Bundling one of Rainmeter''s own plugins must fail.'
$unlicensedPluginRelease = Join-Path $package.Project 'packaging\release-unlicensed-plugin.json'
Put-File $unlicensedPluginRelease ([ordered]@{
    name = 'Parallax'; author = 'Fixture Author'; version = 'test-package'; minimumRainmeter = '4.5.26'; minimumWindows = '10.0'; loadSkin = 'Parallax\Settings\Settings.ini'
    plugins = @([ordered]@{ name = 'FixturePlugin'; version = '1.2.3.4'; directory = 'packaging\Plugins\FixturePlugin\1.2.3.4'; license = '@Resources\Licenses\Absent-LICENSE.txt' })
} | ConvertTo-Json -Depth 5)
Assert-Fails { & (Join-Path $toolsRoot 'Package-Parallax.ps1') -ProjectRoot $package.Project -ReleaseFile $unlicensedPluginRelease -StageRoot $built.StageRoot -Force } 'A plugin whose license is not staged must fail.'
$noHeader = & (Join-Path $toolsRoot 'Package-Parallax.ps1') -ProjectRoot $package.Project -StageRoot $built.StageRoot -NoHeaderImage -Force
Assert-True ($noHeader.Entries -eq 26) '-NoHeaderImage must omit RMSKIN.bmp.'
$tampered = Join-Path $package.Project 'tampered.rmskin'
$tamperedBytes = [IO.File]::ReadAllBytes($noHeader.Package)
$tamperedBytes[$tamperedBytes.Length - 7] = 0x58
[IO.File]::WriteAllBytes($tampered, $tamperedBytes)
Assert-Fails { & (Join-Path $toolsRoot 'Test-ParallaxPackage.ps1') -PackagePath $tampered } 'A package without the RMSKIN key must fail verification.'
$plainZip = Join-Path $package.Project 'plain.rmskin'
[IO.File]::WriteAllBytes($plainZip, $tamperedBytes[0..($tamperedBytes.Length - 17)])
Assert-Fails { & (Join-Path $toolsRoot 'Test-ParallaxPackage.ps1') -PackagePath $plainZip } 'A plain ZIP renamed to .rmskin must fail verification.'
$shortTrailer = Join-Path $package.Project 'short.rmskin'
$shortBytes = [IO.File]::ReadAllBytes($noHeader.Package)
[Array]::Copy([BitConverter]::GetBytes([int64]($shortBytes.Length - 17)), 0, $shortBytes, $shortBytes.Length - 16, 8)
[IO.File]::WriteAllBytes($shortTrailer, $shortBytes)
Assert-Fails { & (Join-Path $toolsRoot 'Test-ParallaxPackage.ps1') -PackagePath $shortTrailer } 'A trailer whose length disagrees with the archive must fail verification.'
Add-Content -LiteralPath (Join-Path $built.StageRoot 'Skins\Parallax\Settings\Settings.ini') -Value '; tampered after staging'
Assert-Fails { & (Join-Path $toolsRoot 'Package-Parallax.ps1') -ProjectRoot $package.Project -StageRoot $built.StageRoot -Force } 'A stage whose bytes changed after its manifest must not be packaged.'

Write-Host "Packaging tool fixtures passed. Inspect retained fixtures at: $fixtureRoot"

#requires -Version 5.1
# Fixtures for the XMOD-04 rule in tools/Test-Parallax.ps1
# (tools/Parallax.LuaScan.psm1): an unconditional !Redraw, !UpdateMeterGroup or
# !UpdateMeter * directly in a skin Lua Update() is an error; conditional,
# helper and event-path bangs are not. Never loads Rainmeter. Removes its own
# temp folder.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$toolsRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $toolsRoot 'Parallax.LuaScan.psm1') -Force
$script:assertions = 0
function Assert-True([bool]$Condition, [string]$Message) {
    $script:assertions++
    if (-not $Condition) { throw "Assertion failed: $Message" }
}
function Find([string]$Lua) { @(Find-ParallaxUpdateRepaint -Text ($Lua -replace "`r?`n", "`n")) }
function Expect([string]$Name, [string]$Lua, [string[]]$Bangs) {
    $found = Find $Lua
    Assert-True ((@($found | ForEach-Object Bang) -join ',') -eq ($Bangs -join ',')) "$Name (expected [$($Bangs -join ',')], got [$(@($found | ForEach-Object Bang) -join ',')])"
    $found
}

# Flagged: direct statements of Update().
$hit = Expect 'direct !Redraw' @'
function Initialize() end
function Update()
    local value = SELF:GetOption('X')
    SKIN:Bang('!SetOption', 'MeterA', 'Text', value)
    SKIN:Bang('!Redraw')
    return 0
end
'@ @('!Redraw')
Assert-True ($hit[0].Line -eq 5) "the finding names its line (got $($hit[0].Line))"
$null = Expect 'group update with its group as a second argument' "function Update()`n  SKIN:Bang('!UpdateMeterGroup', 'CPUUI')`nend" @('!UpdateMeterGroup')
$null = Expect 'group update in one string' "function Update()`n  SKIN:Bang(`"!UpdateMeterGroup CPUUI`")`nend" @('!UpdateMeterGroup')
$null = Expect 'every meter, two arguments' "function Update()`n  SKIN:Bang('!UpdateMeter', '*')`nend" @('!UpdateMeter *')
$null = Expect 'every meter, one string' "function Update()`n  SKIN:Bang('!UpdateMeter *')`nend" @('!UpdateMeter *')
$null = Expect 'bangs are case-insensitive' "function Update()`n  SKIN:Bang('!redraw')`nend" @('!Redraw')
$null = Expect 'a bracketed bang list' "function Update()`n  SKIN:Bang('[!SetOption A Text 1][!UpdateMeterGroup Rows][!Redraw]')`nend" @('!UpdateMeterGroup', '!Redraw')
$null = Expect 'a long-bracket string' "function Update()`n  SKIN:Bang([[!Redraw]])`nend" @('!Redraw')
$null = Expect 'a do block runs unconditionally' "function Update()`n  do`n    SKIN:Bang('!Redraw')`n  end`nend" @('!Redraw')
$null = Expect 'a concatenated bang keeps its literal head' "function Update()`n  SKIN:Bang('!UpdateMeterGroup ' .. group)`nend" @('!UpdateMeterGroup')
$null = Expect 'Update assigned as a function' "Update = function()`n  SKIN:Bang('!Redraw')`nend" @('!Redraw')
$null = Expect 'after strings and comments that look like code' @'
function Update()
    local s = "end" .. 'function' .. [[ if then end ]]
    -- end end end
    --[==[ if x then
    end ]==]
    SKIN:Bang('!Redraw')
end
'@ @('!Redraw')
$null = Expect 'one-line Update' "function Update() SKIN:Bang('!Redraw'); return 0 end" @('!Redraw')

# Not flagged.
$null = Expect 'inside if' "function Update()`n  if changed then`n    SKIN:Bang('!Redraw')`n  end`nend" @()
$null = Expect 'inside else' "function Update()`n  if a then x() else SKIN:Bang('!UpdateMeterGroup G') end`nend" @()
$null = Expect 'inside for' "function Update()`n  for i = 1, 3 do SKIN:Bang('!UpdateMeter *') end`nend" @()
$null = Expect 'inside while' "function Update()`n  while busy() do SKIN:Bang('!Redraw') end`nend" @()
$null = Expect 'behind and/or' "function Update()`n  local _ = dirty and SKIN:Bang('!Redraw')`n  local _ = clean or SKIN:Bang('!Redraw')`nend" @()
$null = Expect 'in a nested function' "function Update()`n  local function paint() SKIN:Bang('!Redraw') end`n  return 0`nend" @()
$null = Expect 'in a helper (event paths call it too)' "local function redraw() SKIN:Bang('!Redraw') end`nfunction Update()`n  redraw()`nend" @()
$null = Expect 'in an event handler' "function Update() return 0 end`nfunction Page() SKIN:Bang('!UpdateMeterGroup Rows'); SKIN:Bang('!Redraw') end" @()
$null = Expect 'a single named meter' "function Update()`n  SKIN:Bang('!UpdateMeter', 'MeterTotal')`n  SKIN:Bang('!UpdateMeter MeterTotal')`nend" @()
$null = Expect 'a computed bang' "function Update()`n  SKIN:Bang(bang)`nend" @()
$null = Expect 'other bangs' "function Update()`n  SKIN:Bang('!SetOption', 'A', 'B', 'C')`n  SKIN:Bang('!UpdateMeasure', 'M')`nend" @()
$null = Expect 'a local Update is not the skin entry point' "local function Update()`n  SKIN:Bang('!Redraw')`nend" @()
$null = Expect 'code after Update ends' "function Update()`n  return 0`nend`nSKIN:Bang('!Redraw')" @()
$null = Expect 'a method named Update' "function M:Update()`n  SKIN:Bang('!Redraw')`nend" @()

# Encodings: UTF-16LE with mixed line endings, UTF-16BE, UTF-8 with BOM.
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('pxrr-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
try {
    $null = New-Item -ItemType Directory -Path $fixture
    $mixed = "-- caf$([char]0xE9)`r`nfunction Initialize() end`nfunction Update()`r`n  SKIN:Bang('!SetOption', 'A', 'Text', '1')`n  SKIN:Bang('!Redraw')`r`nend`n"
    $le = Join-Path $fixture 'le.lua'
    [IO.File]::WriteAllBytes($le, [byte[]](@(0xFF, 0xFE) + [Text.Encoding]::Unicode.GetBytes($mixed)))
    $be = Join-Path $fixture 'be.lua'
    [IO.File]::WriteAllBytes($be, [byte[]](@(0xFE, 0xFF) + [Text.Encoding]::BigEndianUnicode.GetBytes($mixed)))
    $u8 = Join-Path $fixture 'u8.lua'
    [IO.File]::WriteAllText($u8, $mixed, [Text.UTF8Encoding]::new($true))
    foreach ($path in $le, $be, $u8) {
        $text = Read-ParallaxScriptText $path
        Assert-True ($text -ceq $mixed) "decoded text is exact ($(Split-Path -Leaf $path))"
        $found = @(Find-ParallaxUpdateRepaint -Text $text)
        Assert-True ($found.Count -eq 1 -and $found[0].Line -eq 5) "UTF-16/UTF-8 source flagged on line 5 ($(Split-Path -Leaf $path))"
    }

    # End to end through the validator on a minimal skin.
    $skin = Join-Path $fixture 'Skins\Parallax'
    $put = {
        param([string]$Relative, [string]$Content)
        $path = Join-Path $skin $Relative
        $parent = Split-Path -Parent $path
        if (-not (Test-Path -LiteralPath $parent)) { $null = New-Item -ItemType Directory -Path $parent -Force }
        [IO.File]::WriteAllText($path, $Content, [Text.UTF8Encoding]::new($true))
    }
    & $put 'Settings\Settings.ini' "[Rainmeter]`nUpdate=1000`n@Include=#@#Defaults.inc`n[Metadata]`nName=Fixture`n[MeasureScript]`nMeasure=Script`nScriptFile=#@#Scripts\Clean.lua`n[MeterText]`nMeter=String`nText=Fixture`n"
    & $put '@Resources\Defaults.inc' "[Variables]`nColor=255,255,255`n"
    & $put '@Resources\Scripts\Clean.lua' "function Update()`n  if changed then SKIN:Bang('!Redraw') end`n  return 0`nend`n"
    & $put '@Resources\Modules\Fixture\tests\Harness.lua' "function Update()`n  SKIN:Bang('!Redraw')`nend`n"
    $validator = Join-Path $toolsRoot 'Test-Parallax.ps1'
    $clean = & $validator -SkinRoot $skin 6>$null
    Assert-True ($clean.Errors -eq 0) 'conditional repaints and test harnesses pass the validator'
    [IO.File]::WriteAllBytes((Join-Path $skin '@Resources\Scripts\Wide.lua'), [byte[]](@(0xFF, 0xFE) + [Text.Encoding]::Unicode.GetBytes($mixed)))
    $output = [Collections.Generic.List[string]]::new()
    $failed = $false
    try { & $validator -SkinRoot $skin 6>&1 | ForEach-Object { $output.Add("$_") } } catch { $failed = $true }
    Assert-True $failed 'an unconditional repaint in Update() fails the validator'
    Assert-True (@($output | Where-Object { $_ -match '^ERROR: @Resources\\Scripts\\Wide\.lua:5: XMOD-04: Update\(\) sends !Redraw' }).Count -eq 1) "the error names the UTF-16 file and line (got: $($output -join ' | '))"
}
finally {
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-Host "Test-RepaintRule: $script:assertions assertions passed." -ForegroundColor Green

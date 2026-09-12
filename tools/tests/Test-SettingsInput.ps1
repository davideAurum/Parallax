[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$scriptPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Skins\Parallax\@Resources\Scripts\SettingsInput.ps1'))
. $scriptPath
$assertions = 0
function Assert-Equal($Actual, $Expected, [string]$Message) {
    if ($Actual -cne $Expected) { throw "$Message : expected '$Expected', got '$Actual'." }
    $script:assertions++
}
foreach ($case in @(
    @('Scale', '75', '75'), @('Scale', '200%', '200'), @('Scale', '113.50 %', '113.5'),
    @('Scale', ' 125.25% ', '125.25'), @('Scale', '00100.00', '100'),
    @('ColumnWidth', '180px', '180'), @('ColumnWidth', '320 PX', '320'),
    @('Gutter', '0', '0'), @('Gutter', '16 px', '16'), @('CornerRadius', '24', '24'),
    @('TitleFontSize', '6', '6'), @('TitleFontSize', '12pt', '12'), @('TitleFontSize', '11.25 pt', '11.25'),
    @('HeaderFontSize', '6pt', '6'), @('HeaderFontSize', '10 PT', '10'), @('HeaderFontSize', ' 9.50 pt ', '9.5'),
    @('FontSize', '0006.00pt', '6'), @('FontSize', '10', '10'), @('FontSize', '9.99', '9.99'),
    @('BackgroundTransparency', '000.00%', '0'), @('BackgroundTransparency', '100', '100'), @('BackgroundTransparency', '37.25 %', '37.25'),
    @('BorderThickness', '0px', '0'), @('BorderThickness', '4 PX', '4'), @('BorderThickness', '0.01 px', '0.01'),
    @('DividerThickness', '0', '0'), @('DividerThickness', '4.00px', '4'), @('DividerThickness', ' 3.75 PX ', '3.75')
)) {
    $parsed = ConvertTo-ParallaxInputValue $case[0] $case[1]
    Assert-Equal $parsed.Valid $true 'Accepted numeric input'
    Assert-Equal $parsed.Value $case[2] 'Canonical numeric value'
    Assert-Equal (Get-ParallaxInputResponse $case[0] $case[1]) ('PARALLAX_INPUT_V1|ok|' + $case[2]) 'Accepted protocol'
}
foreach ($case in @(
    @('Scale', '74.99'), @('Scale', '200.01'), @('Scale', '100.001'), @('Scale', '100,5'),
    @('Scale', '1e2'), @('Scale', '+100'), @('Scale', '100px'), @('Scale', 'NaN'),
    @('ColumnWidth', '179'), @('ColumnWidth', '321'), @('ColumnWidth', '200.0'),
    @('Gutter', '-1'), @('Gutter', '17'), @('Gutter', '1.5px'), @('CornerRadius', '25'), @('CornerRadius', '10%'), @('CornerRadius', '1.5px'),
    @('Scale', ''), @('Unknown', '100'), @('Scale', '100 125'),
    @('Scale', ('1' * 65)), @('Scale', "100`n125"),
    @('Scale', '100"][!Quit]'), @('Scale', '[&MeasureSettings:Apply()]'),
    @('Scale', '100; os.execute("calc")'), @('Scale', '100|ok|200'),
    @('Scale', '$(Start-Process calc)'), @('Scale', '#CURRENTCONFIG#'),
    @('Scale', '100""" [!SetVariable Pwned 1]'), @('Gutter', '[!RefreshGroup *]')
)) {
    $parsed = ConvertTo-ParallaxInputValue $case[0] $case[1]
    Assert-Equal $parsed.Valid $false 'Rejected unsafe or invalid input'
    Assert-Equal $parsed.Value '' 'Rejected text is never reflected'
    Assert-Equal (Get-ParallaxInputResponse $case[0] $case[1]) 'PARALLAX_INPUT_V1|cancel|' 'Rejected protocol'
}
foreach ($fontKey in @('TitleFontSize', 'HeaderFontSize', 'FontSize')) {
    $upperBound = if ($fontKey -eq 'TitleFontSize') { '12.01pt' } else { '10.01pt' }
    foreach ($invalidText in @(
        '5.99pt', $upperBound, '8.001pt', '8,5pt', '8px', '8%', '8p t', '8pts', '8e0pt', '+8pt',
        '-8pt', '8.pt', '.8pt', '', 'NaN', ('8' * 65), "8`n9", '8pt|ok|12', '8pt"][!Quit]',
        '[&MeasureSettings:Apply()]', '8; os.execute("calc")', '$(Start-Process calc)', '#CURRENTCONFIG#',
        '8""" [!SetVariable Pwned 1]', '[!RefreshGroup *]'
    )) {
        $parsed = ConvertTo-ParallaxInputValue $fontKey $invalidText
        Assert-Equal $parsed.Valid $false ('Rejected font input for ' + $fontKey)
        Assert-Equal $parsed.Value '' 'Rejected font text is never reflected'
        Assert-Equal (Get-ParallaxInputResponse $fontKey $invalidText) 'PARALLAX_INPUT_V1|cancel|' 'Rejected font protocol'
    }
    Assert-Equal (Get-ParallaxInputResponse -InputKey $fontKey -Text '8.5pt' -Cancelled) 'PARALLAX_INPUT_V1|cancel|' 'Cancel never applies font text'
    Assert-Equal (Get-ParallaxInputResponse -InputKey $fontKey -Text '[!Quit]' -Cancelled) 'PARALLAX_INPUT_V1|cancel|' 'Cancel never reflects font text'
}
foreach ($surfaceKey in @('BackgroundTransparency', 'BorderThickness', 'DividerThickness')) {
    $upperBound = if ($surfaceKey -eq 'BackgroundTransparency') { '100.01' } else { '4.01' }
    $wrongSuffix = if ($surfaceKey -eq 'BackgroundTransparency') { '1px' } else { '1%' }
    foreach ($invalidText in @(
        '-0.01', $upperBound, '1.001', '1,5', $wrongSuffix, '1pt', '1p x', '1e0', '+1',
        '1.', '.1', '', 'NaN', ('1' * 65), "1`n2", '1|ok|4', '1"][!Quit]',
        '[&MeasureSettings:Apply()]', '1; os.execute("calc")', '$(Start-Process calc)', '#CURRENTCONFIG#',
        '1""" [!SetVariable Pwned 1]', '[!RefreshGroup *]'
    )) {
        $parsed = ConvertTo-ParallaxInputValue $surfaceKey $invalidText
        Assert-Equal $parsed.Valid $false ('Rejected surface input for ' + $surfaceKey)
        Assert-Equal $parsed.Value '' 'Rejected surface text is never reflected'
        Assert-Equal (Get-ParallaxInputResponse $surfaceKey $invalidText) 'PARALLAX_INPUT_V1|cancel|' 'Rejected surface protocol'
    }
    Assert-Equal (Get-ParallaxInputResponse -InputKey $surfaceKey -Text '1.5' -Cancelled) 'PARALLAX_INPUT_V1|cancel|' 'Cancel never applies surface text'
    Assert-Equal (Get-ParallaxInputResponse -InputKey $surfaceKey -Text '[!Quit]' -Cancelled) 'PARALLAX_INPUT_V1|cancel|' 'Cancel never reflects surface text'
}
Assert-Equal (Get-ParallaxInputResponse -InputKey Scale -Text '100' -Cancelled) 'PARALLAX_INPUT_V1|cancel|' 'Cancel never applies current text'
Assert-Equal (Get-ParallaxInputResponse -InputKey Scale -Text '[!Quit]' -Cancelled) 'PARALLAX_INPUT_V1|cancel|' 'Cancel never reflects text'
$savedCulture = [Threading.Thread]::CurrentThread.CurrentCulture
try {
    [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo('de-DE')
    Assert-Equal (Get-ParallaxInputResponse Scale '113.50%') 'PARALLAX_INPUT_V1|ok|113.5' 'Invariant decimal protocol'
    Assert-Equal (Get-ParallaxInputResponse Scale '113,5%') 'PARALLAX_INPUT_V1|cancel|' 'Culture does not enable comma decimals'
    foreach ($fontKey in @('TitleFontSize', 'HeaderFontSize', 'FontSize')) {
        Assert-Equal (Get-ParallaxInputResponse $fontKey '8.50 pt') 'PARALLAX_INPUT_V1|ok|8.5' 'Invariant font decimal protocol'
        Assert-Equal (Get-ParallaxInputResponse $fontKey '8,5 pt') 'PARALLAX_INPUT_V1|cancel|' 'Culture does not enable font comma decimals'
    }
    foreach ($surfaceKey in @('BackgroundTransparency', 'BorderThickness', 'DividerThickness')) {
        Assert-Equal (Get-ParallaxInputResponse $surfaceKey '1.50') 'PARALLAX_INPUT_V1|ok|1.5' 'Invariant surface decimal protocol'
        Assert-Equal (Get-ParallaxInputResponse $surfaceKey '1,5') 'PARALLAX_INPUT_V1|cancel|' 'Culture does not enable surface comma decimals'
    }
}
finally { [Threading.Thread]::CurrentThread.CurrentCulture = $savedCulture }

# Run the public offline entry point in Windows PowerShell 5.1, without creating a form.
$powershellExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$output = @(& $powershellExe -NoProfile -NonInteractive -STA -File $scriptPath -Key Scale -ValidateOnly -Value '113.50%')
Assert-Equal $LASTEXITCODE 0 'Offline helper exit code'
Assert-Equal $output.Count 1 'Exactly one stdout line'
Assert-Equal $output[0] 'PARALLAX_INPUT_V1|ok|113.5' 'Public validation protocol'
$output = @(& $powershellExe -NoProfile -NonInteractive -STA -File $scriptPath -Key Scale -ValidateOnly -Value '[!Quit]')
Assert-Equal $output.Count 1 'Rejected entry point emits one line'
Assert-Equal $output[0] 'PARALLAX_INPUT_V1|cancel|' 'Public invalid protocol'
$output = @(& $powershellExe -NoProfile -NonInteractive -STA -File $scriptPath -Cancel)
Assert-Equal $output[0] 'PARALLAX_INPUT_V1|cancel|' 'Public cancellation protocol'
foreach ($publicCase in @(
    @('TitleFontSize', '8.50 pt', '8.5'), @('HeaderFontSize', '8.50 pt', '8.5'), @('FontSize', '8.50 pt', '8.5'),
    @('BackgroundTransparency', '37.50%', '37.5'), @('BorderThickness', '2.50px', '2.5'), @('DividerThickness', '0.50 px', '0.5')
)) {
    $output = @(& $powershellExe -NoProfile -NonInteractive -STA -File $scriptPath -Key $publicCase[0] -ValidateOnly -Value $publicCase[1])
    Assert-Equal $LASTEXITCODE 0 'Offline decimal setting helper exit code'
    Assert-Equal $output.Count 1 'Decimal setting helper emits exactly one stdout line'
    Assert-Equal $output[0] ('PARALLAX_INPUT_V1|ok|' + $publicCase[2]) 'Public decimal setting validation protocol'
    $output = @(& $powershellExe -NoProfile -NonInteractive -STA -File $scriptPath -Key $publicCase[0] -ValidateOnly -Value '1"][!Quit]')
    Assert-Equal $output.Count 1 'Rejected decimal setting entry point emits one line'
    Assert-Equal $output[0] 'PARALLAX_INPUT_V1|cancel|' 'Public invalid decimal setting protocol'
}
foreach ($options in @(
    @{ Key = 'Scale'; Initial = '100'; Width = 'bad' },
    @{ Key = 'Scale'; Initial = '100'; Scale = 'NaN' },
    @{ Key = 'Scale'; Initial = '[!Quit]' },
    @{ Key = 'TitleFontSize'; Initial = '12.01' },
    @{ Key = 'HeaderFontSize'; Initial = '[!Quit]' },
    @{ Key = 'FontSize'; Initial = '5.99' },
    @{ Key = 'BackgroundTransparency'; Initial = '100.01' },
    @{ Key = 'BorderThickness'; Initial = '4.01' },
    @{ Key = 'DividerThickness'; Initial = '[!Quit]' }
)) {
    $output = @(& $powershellExe -NoProfile -NonInteractive -STA -File $scriptPath @options)
    Assert-Equal $output.Count 1 'Invalid launch parameters emit one line'
    Assert-Equal $output[0] 'PARALLAX_INPUT_V1|cancel|' 'Invalid launch parameters cancel before UI'
}

# Construct real WinForms HWNDs and invoke their own events without showing a window.
# Only the modal boundary is replaced. No global mouse, keyboard or other windows are used.
$source = [IO.File]::ReadAllText($scriptPath)
$modalBoundary = '$null = $form.ShowDialog()'
Assert-Equal ([regex]::Matches($source, [regex]::Escape($modalBoundary))).Count 1 'Unique modal UI boundary'
$headlessBoundary = @'
if ($form.FormBorderStyle -ne [Windows.Forms.FormBorderStyle]::None -or $form.ShowInTaskbar) { throw 'Unexpected editor window.' }
if ($form.Controls.Count -ne 1 -or $box.Text -ne $scenario.InitialExpected) { throw 'Unexpected editor field.' }
$null = $form.Handle
$null = $box.Handle
$form.PerformLayout()
$boxScreen = $box.PointToScreen([Drawing.Point]::Empty)
if ($form.Location.X -ne 100 -or $form.Location.Y -ne 120 -or $form.Width -ne $scenario.Width -or $form.Height -ne 20) { throw ('Unexpected form HWND bounds: ' + $form.Bounds.ToString() + ', expected width ' + $scenario.Width) }
if ($boxScreen.X -ne 101 -or $boxScreen.Y -ne 121 -or $box.Width -ne ($scenario.Width - 2) -or $box.Height -ne 18) { throw 'Unexpected TextBox HWND bounds.' }
$box.Text = $scenario.Text
$tip.Active = $false
$onKeyDown = $box.GetType().GetMethod('OnKeyDown', [Reflection.BindingFlags]'Instance,NonPublic')
if ($scenario.Action -eq 'deactivate') {
    $form.Tag.Active = $true
    $onDeactivate = $form.GetType().GetMethod('OnDeactivate', [Reflection.BindingFlags]'Instance,NonPublic')
    $null = $onDeactivate.Invoke($form, [object[]]@([EventArgs]::Empty))
}
else {
    $keyCode = if ($scenario.Action -eq 'escape') { [Windows.Forms.Keys]::Escape } else { [Windows.Forms.Keys]::Enter }
    $keyEvent = New-Object Windows.Forms.KeyEventArgs($keyCode)
    $null = $onKeyDown.Invoke($box, [object[]]@($keyEvent.PSObject.BaseObject))
    if ($scenario.Action.StartsWith('invalid')) {
        if ($form.IsDisposed -or $form.BackColor.R -ne 230 -or $form.Tag.Response -ne 'PARALLAX_INPUT_V1|cancel|') { throw 'Invalid input did not remain open with an error.' }
        $escapeEvent = New-Object Windows.Forms.KeyEventArgs([Windows.Forms.Keys]::Escape)
        $null = $onKeyDown.Invoke($box, [object[]]@($escapeEvent.PSObject.BaseObject))
    }
}
'@
$headlessSource = $source.Replace($modalBoundary, $headlessBoundary).Replace(
    '# No user text or exception detail is reflected into the command channel.', 'throw')
foreach ($uiScale in @('1', '0.75')) {
    foreach ($uiCase in @(
        @{ Key = 'Scale'; Initial = '113.50'; InitialExpected = '113.5'; ValidText = '125.25%'; Value = '125.25'; InvalidText = '200.01%' },
        @{ Key = 'TitleFontSize'; Initial = '10.00'; InitialExpected = '10'; ValidText = '11.25 pt'; Value = '11.25'; InvalidText = '12.01pt' },
        @{ Key = 'HeaderFontSize'; Initial = '8.00'; InitialExpected = '8'; ValidText = '9.50pt'; Value = '9.5'; InvalidText = '10.01pt' },
        @{ Key = 'FontSize'; Initial = '9.00'; InitialExpected = '9'; ValidText = '6.75 PT'; Value = '6.75'; InvalidText = '5.99pt' },
        @{ Key = 'BackgroundTransparency'; Initial = '0.00'; InitialExpected = '0'; ValidText = '37.50%'; Value = '37.5'; InvalidText = '100.01%' },
        @{ Key = 'BorderThickness'; Initial = '1.00'; InitialExpected = '1'; ValidText = '2.25 PX'; Value = '2.25'; InvalidText = '4.01px' },
        @{ Key = 'DividerThickness'; Initial = '1.00'; InitialExpected = '1'; ValidText = '0.50 px'; Value = '0.5'; InvalidText = '-0.01px' }
    )) {
        foreach ($action in @('enter', 'escape', 'deactivate', 'invalidRange', 'invalidPaste')) {
            $scenario = @{
                Action = $action
                InitialExpected = $uiCase.InitialExpected
                Width = $(if ($uiScale -eq '1') { 320 } else { 240 })
                Text = $(if ($action -eq 'invalidPaste') { '[!Quit]' } elseif ($action -eq 'invalidRange') { $uiCase.InvalidText } else { $uiCase.ValidText })
            }
            $expected = if ($action -eq 'enter') { 'PARALLAX_INPUT_V1|ok|' + $uiCase.Value } else { 'PARALLAX_INPUT_V1|cancel|' }
            $savedConsole = [Console]::Out
            $capturedConsole = New-Object IO.StringWriter
            try {
                [Console]::SetOut($capturedConsole)
                $scriptBlock = [scriptblock]::Create($headlessSource)
                & $scriptBlock -Key $uiCase.Key -Initial $uiCase.Initial -X 100 -Y 120 -Width $scenario.Width -Height 20 -Scale $uiScale
            }
            finally { [Console]::SetOut($savedConsole) }
            Assert-Equal $capturedConsole.ToString().Trim() $expected ('Actual WinForms ' + $uiCase.Key + ' ' + $action + ' handler and HWND bounds at scale ' + $uiScale)
            $capturedConsole.Dispose()
        }
    }
}
Write-Output ('PASS: {0} SettingsInput assertions, including Scale, font and surface keys with real WinForms HWND geometry and Enter/Escape/deactivation/invalid handlers at 100% and 75% suite scale. No UI shown; visual and mixed-monitor DPI alignment still require live QA.' -f $assertions)

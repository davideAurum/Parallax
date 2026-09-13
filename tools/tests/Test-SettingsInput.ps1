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
    @('DividerThickness', '0', '0'), @('DividerThickness', '4.00px', '4'), @('DividerThickness', ' 3.75 PX ', '3.75'),
    @('TableHeaderBorderThickness', '0px', '0'), @('TableHeaderBorderThickness', '4.00 PX', '4'), @('TableHeaderBorderThickness', ' 0.25 px ', '0.25'),
    @('DataBarThickness', '6', '6'), @('DataBarThickness', '1px', '1'), @('DataBarThickness', '12.00 PX', '12'),
    @('DataBarThickness', ' 6.25 px ', '6.25'), @('DataBarThickness', '0006.00', '6')
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
foreach ($surfaceKey in @('BackgroundTransparency', 'BorderThickness', 'DividerThickness', 'TableHeaderBorderThickness', 'DataBarThickness')) {
    $upperBound = if ($surfaceKey -eq 'BackgroundTransparency') { '100.01' } elseif ($surfaceKey -eq 'DataBarThickness') { '12.01' } else { '4.01' }
    $lowerBound = if ($surfaceKey -eq 'DataBarThickness') { '0.99px' } else { '-0.01' }
    $wrongSuffix = if ($surfaceKey -eq 'BackgroundTransparency') { '1px' } else { '1%' }
    foreach ($invalidText in @(
        $lowerBound, $upperBound, '1.001', '1,5', $wrongSuffix, '1pt', '1p x', '1e0', '+1',
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
foreach ($invalidText in @('0', '0px', '-1px', '12.01px', '6.001px')) {
    $parsed = ConvertTo-ParallaxInputValue 'DataBarThickness' $invalidText
    Assert-Equal $parsed.Valid $false 'Rejected data-bar thickness outside range or precision'
    Assert-Equal $parsed.Value '' 'Rejected data-bar text is never reflected'
    Assert-Equal (Get-ParallaxInputResponse 'DataBarThickness' $invalidText) 'PARALLAX_INPUT_V1|cancel|' 'Rejected data-bar protocol'
}
Assert-Equal (Get-ParallaxInputResponse -InputKey Scale -Text '100' -Cancelled) 'PARALLAX_INPUT_V1|cancel|' 'Cancel never applies current text'
Assert-Equal (Get-ParallaxInputResponse -InputKey Scale -Text '[!Quit]' -Cancelled) 'PARALLAX_INPUT_V1|cancel|' 'Cancel never reflects text'

# Utility ranges are per-call data. Signed values never enable units or expressions.
foreach ($case in @(
    @('-10', '10', '0', '-10', '-10'), @('-10', '10', '0', '+10', '10'),
    @('-10', '10', '0', '-000', '0'), @('-10', '10', '0', " `t+0009 `t", '9'),
    @('-1.5', '2.5', '1', '-1.5', '-1.5'), @('-1.5', '2.5', '1', '+2.5', '2.5'),
    @('-10.25', '10.25', '2', '-09.50', '-9.5'), @('-10.25', '10.25', '2', '+000.00', '0'),
    @('-0.125', '0.125', '3', '-0.125', '-0.125'), @('-0.125', '0.125', '3', '0.001', '0.001'),
    @('-0.0001', '0.0001', '4', '-0.0001', '-0.0001'), @('-0.0001', '0.0001', '4', '+0.0001', '0.0001'),
    @('-1000000000', '1000000000', '4', '-1000000000.0000', '-1000000000'),
    @('-1000000000', '1000000000', '4', '+1000000000.0000', '1000000000'),
    @('7', '7', '0', '7', '7'), @('-2.5000', '-2.5000', '4', '-2.5', '-2.5')
)) {
    $options = @{ InputKey = 'UtilityNumber'; Minimum = $case[0]; Maximum = $case[1]; DecimalPlaces = $case[2]; Text = $case[3] }
    $parsed = ConvertTo-ParallaxInputValue @options
    Assert-Equal $parsed.Valid $true 'Accepted bounded utility number'
    Assert-Equal $parsed.Value $case[4] 'Canonical utility number'
    Assert-Equal (Get-ParallaxInputResponse @options) ('PARALLAX_INPUT_V1|ok|' + $case[4]) 'Utility numeric protocol'
}
foreach ($precision in @('0', '1', '2', '3', '4')) {
    foreach ($invalidText in @(
        '', ' ', '+', '-', '.1', '1.', '1,5', '1e0', '1E+0', 'NaN', 'Infinity',
        '0x1', '1px', '1pt', '1%', '1 / 2', '1+2', '--1', '+-1', '1 2',
        '11', '-11', ('9' * 64), ('0' * 65), '79228162514264337593543950336',
        "1`n", "`n1", "1`r`n2", "1`0", ([string][char]0x2212 + '1'),
        ([string][char]0xFF11), ('1' + [char]0x00A0),
        '1|ok|2', '1"][!Quit]', '[&MeasureSettings:Apply()]', '$(Start-Process calc)',
        '#CURRENTCONFIG#', '1; os.execute("calc")', '[!RefreshGroup *]',
        ('1.' + ('0' * ([int]$precision + 1)))
    )) {
        $options = @{ InputKey = 'UtilityNumber'; Minimum = '-10'; Maximum = '10'; DecimalPlaces = $precision; Text = $invalidText }
        $parsed = ConvertTo-ParallaxInputValue @options
        Assert-Equal $parsed.Valid $false 'Rejected utility input outside grammar/range'
        Assert-Equal $parsed.Value '' 'Invalid utility text is never reflected'
        Assert-Equal (Get-ParallaxInputResponse @options) 'PARALLAX_INPUT_V1|cancel|' 'Rejected utility protocol'
    }
}
foreach ($case in @(
    @('', '10', '0'), @('-10', '', '0'), @('-10', '10', ''),
    @('-10', '10', '-1'), @('-10', '10', '5'), @('-10', '10', '2.0'),
    @('-10', '10', '02'), @('-10', '10', '+2'), @('-10', '10', ' 2'),
    @('-10', '10', "2`n"), @('-10', '10', '1e0'), @('-10', '10', '[!Quit]'),
    @('2', '1', '0'), @('-1.5', '10', '0'), @('-10', '1.25', '1'),
    @('-10.00000', '10', '4'), @('-10', '10.00000', '4'),
    @('-1000000000.0001', '10', '4'), @('-10', '1000000000.0001', '4'),
    @('-1000000001', '10', '0'), @('-10', '1000000001', '0'),
    @('NaN', '10', '2'), @('-10', 'Infinity', '2'), @('-1e1', '10', '2'),
    @('-10', '1e1', '2'), @('-10', '10px', '2'), @(' -10', '10', '2'),
    @('-10', "10`n", '2'), @('-10', '10,0', '2'), @('-.1', '10', '2'),
    @('-10', '10.', '2'), @(('9' * 64), '10', '0'),
    @('-10', '79228162514264337593543950336', '0'),
    @('$(Start-Process calc)', '10', '2'), @('-10', '10"][!Quit]', '2')
)) {
    $options = @{ InputKey = 'UtilityNumber'; Minimum = $case[0]; Maximum = $case[1]; DecimalPlaces = $case[2]; Text = '0' }
    $parsed = ConvertTo-ParallaxInputValue @options
    Assert-Equal $parsed.Valid $false 'Rejected malformed utility range'
    Assert-Equal $parsed.Value '' 'Invalid range never returns a value'
    Assert-Equal $parsed.Error 'Invalid numeric range.' 'Invalid range text is never reflected'
    Assert-Equal (Get-ParallaxInputResponse @options) 'PARALLAX_INPUT_V1|cancel|' 'Invalid utility range protocol'
}
Assert-Equal (Get-ParallaxInputResponse -InputKey UtilityNumber -Text '-1.25' -Minimum '-2' -Maximum '2' -DecimalPlaces '2') 'PARALLAX_INPUT_V1|ok|-1.25' 'Explicit utility range works'
Assert-Equal (Get-ParallaxInputResponse -InputKey UtilityNumber -Text '-1.25') 'PARALLAX_INPUT_V1|cancel|' 'A prior range cannot leak into the next call'
Assert-Equal (Get-ParallaxInputResponse -InputKey UtilityNumber -Text '1' -Minimum '0' -Maximum '2' -DecimalPlaces '0' -Cancelled) 'PARALLAX_INPUT_V1|cancel|' 'Cancel never applies a utility value'
Assert-Equal (Get-ParallaxInputResponse -InputKey UtilityNumber -Text '[!Quit]' -Minimum '[!Quit]' -Cancelled) 'PARALLAX_INPUT_V1|cancel|' 'Cancel never reflects utility values or range'
Assert-Equal (Get-ParallaxInputResponse -InputKey 'utilitynumber' -Text '1' -Minimum '0' -Maximum '2' -DecimalPlaces '0') 'PARALLAX_INPUT_V1|cancel|' 'Utility key spelling is fixed'
foreach ($case in @(
    @('Scale', '113.50%', '113.5'), @('ColumnWidth', '220px', '220'), @('Gutter', '8', '8'),
    @('CornerRadius', '3', '3'), @('TitleFontSize', '10.25pt', '10.25'), @('HeaderFontSize', '8.5pt', '8.5'),
    @('FontSize', '9pt', '9'), @('BackgroundTransparency', '25.5%', '25.5'),
    @('BorderThickness', '1.25px', '1.25'), @('DividerThickness', '0.5px', '0.5'),
    @('TableHeaderBorderThickness', '2px', '2'), @('DataBarThickness', '6.5px', '6.5')
)) {
    Assert-Equal (Get-ParallaxInputResponse -InputKey $case[0] -Text $case[1] -Minimum '[!Quit]' -Maximum 'NaN' -DecimalPlaces '5') ('PARALLAX_INPUT_V1|ok|' + $case[2]) 'Utility-only parameters do not change global rules'
}
$savedCulture = [Threading.Thread]::CurrentThread.CurrentCulture
try {
    [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo('de-DE')
    Assert-Equal (Get-ParallaxInputResponse Scale '113.50%') 'PARALLAX_INPUT_V1|ok|113.5' 'Invariant decimal protocol'
    Assert-Equal (Get-ParallaxInputResponse Scale '113,5%') 'PARALLAX_INPUT_V1|cancel|' 'Culture does not enable comma decimals'
    Assert-Equal (Get-ParallaxInputResponse -InputKey UtilityNumber -Text '-1.2500' -Minimum '-2.5' -Maximum '2.5' -DecimalPlaces '4') 'PARALLAX_INPUT_V1|ok|-1.25' 'Invariant signed utility protocol'
    Assert-Equal (Get-ParallaxInputResponse -InputKey UtilityNumber -Text '-1,25' -Minimum '-2.5' -Maximum '2.5' -DecimalPlaces '4') 'PARALLAX_INPUT_V1|cancel|' 'Culture does not enable utility comma decimals'
    foreach ($fontKey in @('TitleFontSize', 'HeaderFontSize', 'FontSize')) {
        Assert-Equal (Get-ParallaxInputResponse $fontKey '8.50 pt') 'PARALLAX_INPUT_V1|ok|8.5' 'Invariant font decimal protocol'
        Assert-Equal (Get-ParallaxInputResponse $fontKey '8,5 pt') 'PARALLAX_INPUT_V1|cancel|' 'Culture does not enable font comma decimals'
    }
    foreach ($surfaceKey in @('BackgroundTransparency', 'BorderThickness', 'DividerThickness', 'TableHeaderBorderThickness', 'DataBarThickness')) {
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
    @('BackgroundTransparency', '37.50%', '37.5'), @('BorderThickness', '2.50px', '2.5'), @('DividerThickness', '0.50 px', '0.5'),
    @('TableHeaderBorderThickness', '0.25 px', '0.25'), @('DataBarThickness', '6.25 px', '6.25')
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
    @{ Key = 'DividerThickness'; Initial = '[!Quit]' },
    @{ Key = 'TableHeaderBorderThickness'; Initial = '4.01' },
    @{ Key = 'DataBarThickness'; Initial = '0' },
    @{ Key = 'DataBarThickness'; Initial = '12.01' }
)) {
    $output = @(& $powershellExe -NoProfile -NonInteractive -STA -File $scriptPath @options)
    Assert-Equal $output.Count 1 'Invalid launch parameters emit one line'
    Assert-Equal $output[0] 'PARALLAX_INPUT_V1|cancel|' 'Invalid launch parameters cancel before UI'
}
foreach ($publicCase in @(
    @{ Minimum = '-10'; Maximum = '10'; DecimalPlaces = '0'; Value = '-10'; Expected = 'PARALLAX_INPUT_V1|ok|-10' },
    @{ Minimum = '-10.25'; Maximum = '10.25'; DecimalPlaces = '2'; Value = '+001.50'; Expected = 'PARALLAX_INPUT_V1|ok|1.5' },
    @{ Minimum = '-1'; Maximum = '1'; DecimalPlaces = '4'; Value = '-0.0001'; Expected = 'PARALLAX_INPUT_V1|ok|-0.0001' },
    @{ Minimum = '-10'; Maximum = '10'; DecimalPlaces = '0'; Value = '1.0'; Expected = 'PARALLAX_INPUT_V1|cancel|' },
    @{ Minimum = '-10'; Maximum = '10'; DecimalPlaces = '4'; Value = '1e0'; Expected = 'PARALLAX_INPUT_V1|cancel|' },
    @{ Minimum = '-10'; Maximum = '10'; DecimalPlaces = '2'; Value = '[!Quit]'; Expected = 'PARALLAX_INPUT_V1|cancel|' },
    @{ Minimum = '-10'; Maximum = '10'; DecimalPlaces = '5'; Value = '0'; Expected = 'PARALLAX_INPUT_V1|cancel|' },
    @{ Minimum = '-10'; Maximum = '1000000001'; DecimalPlaces = '0'; Value = '0'; Expected = 'PARALLAX_INPUT_V1|cancel|' },
    @{ Minimum = '[!Quit]'; Maximum = '10'; DecimalPlaces = '0'; Value = '0'; Expected = 'PARALLAX_INPUT_V1|cancel|' }
)) {
    $options = @{ Minimum = $publicCase.Minimum; Maximum = $publicCase.Maximum; DecimalPlaces = $publicCase.DecimalPlaces; Value = $publicCase.Value }
    $output = @(& $powershellExe -NoProfile -NonInteractive -STA -File $scriptPath -Key UtilityNumber -ValidateOnly @options)
    Assert-Equal $LASTEXITCODE 0 'Offline utility helper exit code'
    Assert-Equal $output.Count 1 'Utility helper emits exactly one stdout line'
    Assert-Equal $output[0] $publicCase.Expected 'Public bounded utility validation protocol'
}
foreach ($options in @(
    @{ Key = 'UtilityNumber'; Initial = '0' },
    @{ Key = 'UtilityNumber'; Initial = '0'; Minimum = '-10'; Maximum = '10'; DecimalPlaces = '5' },
    @{ Key = 'UtilityNumber'; Initial = '-10.01'; Minimum = '-10'; Maximum = '10'; DecimalPlaces = '2' },
    @{ Key = 'UtilityNumber'; Initial = '1.0'; Minimum = '-10'; Maximum = '10'; DecimalPlaces = '0' },
    @{ Key = 'UtilityNumber'; Initial = '[!Quit]'; Minimum = '-10'; Maximum = '10'; DecimalPlaces = '2' },
    @{ Key = 'UtilityNumber'; Initial = '0'; Minimum = '-10'; Maximum = '[!Quit]'; DecimalPlaces = '2' }
)) {
    $output = @(& $powershellExe -NoProfile -NonInteractive -STA -File $scriptPath @options)
    Assert-Equal $LASTEXITCODE 0 'Invalid utility launch exits normally'
    Assert-Equal $output.Count 1 'Invalid utility launch emits one line'
    Assert-Equal $output[0] 'PARALLAX_INPUT_V1|cancel|' 'Invalid utility launch cancels before UI'
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
        @{ Key = 'DividerThickness'; Initial = '1.00'; InitialExpected = '1'; ValidText = '0.50 px'; Value = '0.5'; InvalidText = '-0.01px' },
        @{ Key = 'TableHeaderBorderThickness'; Initial = '1.00'; InitialExpected = '1'; ValidText = '0.25 px'; Value = '0.25'; InvalidText = '4.01px' },
        @{ Key = 'DataBarThickness'; Initial = '6.00'; InitialExpected = '6'; ValidText = '8.25 px'; Value = '8.25'; InvalidText = '12.01px' },
        @{ Key = 'UtilityNumber'; Minimum = '-10'; Maximum = '10'; DecimalPlaces = '0'; Initial = '-001'; InitialExpected = '-1'; ValidText = '+9'; Value = '9'; InvalidText = '1.0' },
        @{ Key = 'UtilityNumber'; Minimum = '-10'; Maximum = '10'; DecimalPlaces = '2'; Initial = '-1.50'; InitialExpected = '-1.5'; ValidText = '-2.25'; Value = '-2.25'; InvalidText = '-10.01' },
        @{ Key = 'UtilityNumber'; Minimum = '-0.0001'; Maximum = '0.0001'; DecimalPlaces = '4'; Initial = '0.0000'; InitialExpected = '0'; ValidText = '-0.0001'; Value = '-0.0001'; InvalidText = '0.00001' }
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
                $rangeOptions = @{}
                if ($uiCase.Key -eq 'UtilityNumber') {
                    $rangeOptions = @{ Minimum = $uiCase.Minimum; Maximum = $uiCase.Maximum; DecimalPlaces = $uiCase.DecimalPlaces }
                }
                & $scriptBlock -Key $uiCase.Key -Initial $uiCase.Initial -X 100 -Y 120 -Width $scenario.Width -Height 20 -Scale $uiScale @rangeOptions
            }
            finally { [Console]::SetOut($savedConsole) }
            Assert-Equal $capturedConsole.ToString().Trim() $expected ('Actual WinForms ' + $uiCase.Key + ' ' + $action + ' handler and HWND bounds at scale ' + $uiScale)
            $capturedConsole.Dispose()
        }
    }
}
Write-Output ('PASS: {0} SettingsInput assertions, including all global keys and signed bounded UtilityNumber ranges with real WinForms HWND geometry and Enter/Escape/deactivation/invalid handlers at 100% and 75% suite scale. No UI shown; visual and mixed-monitor DPI alignment still require live QA.' -f $assertions)

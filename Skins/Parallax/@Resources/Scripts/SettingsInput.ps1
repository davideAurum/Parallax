# One-shot numeric overlay. User input is data, never a Rainmeter/PowerShell command.
# This helper writes no files; the caller owns validated persistence.
[CmdletBinding()]
param(
    [string]$Key,
    [string]$Initial,
    [string]$X = '0',
    [string]$Y = '0',
    [string]$Width = '80',
    [string]$Height = '22',
    [string]$Scale = '1',
    [switch]$ValidateOnly,
    [string]$Value,
    [switch]$Cancel
)

function ConvertTo-ParallaxInputValue {
    param([string]$InputKey, [AllowNull()][string]$Text)
    $limits = @{
        Scale = @(75, 200)
        ColumnWidth = @(180, 320)
        Gutter = @(0, 16)
        CornerRadius = @(0, 24)
        TitleFontSize = @(6, 12)
        HeaderFontSize = @(6, 10)
        FontSize = @(6, 10)
        BackgroundTransparency = @(0, 100)
        BorderThickness = @(0, 4)
        DividerThickness = @(0, 4)
    }
    if (-not $limits.ContainsKey($InputKey)) {
        return [pscustomobject]@{ Valid = $false; Value = ''; Error = 'Unknown setting.' }
    }
    $isFontSize = $InputKey -in @('TitleFontSize', 'HeaderFontSize', 'FontSize')
    $isPercent = $InputKey -in @('Scale', 'BackgroundTransparency')
    $isDecimalPixel = $InputKey -in @('BorderThickness', 'DividerThickness')
    $message = if ($isPercent) { 'Enter {0} to {1}%, with up to 2 decimals.' -f $limits[$InputKey][0], $limits[$InputKey][1] }
        elseif ($isFontSize) { 'Enter {0} to {1} pt, with up to 2 decimals.' -f $limits[$InputKey][0], $limits[$InputKey][1] }
        elseif ($isDecimalPixel) { 'Enter {0} to {1} px, with up to 2 decimals.' -f $limits[$InputKey][0], $limits[$InputKey][1] }
        else { 'Enter {0} to {1} whole pixels.' -f $limits[$InputKey][0], $limits[$InputKey][1] }
    if ($null -eq $Text -or $Text.Length -gt 64) {
        return [pscustomobject]@{ Valid = $false; Value = ''; Error = $message }
    }
    $pattern = if ($isPercent) { '\A([0-9]+(?:\.[0-9]{1,2})?)[ \t]*%?\z' }
        elseif ($isFontSize) { '\A([0-9]+(?:\.[0-9]{1,2})?)[ \t]*(?:pt)?\z' }
        elseif ($isDecimalPixel) { '\A([0-9]+(?:\.[0-9]{1,2})?)[ \t]*(?:px)?\z' }
        else { '\A([0-9]+)[ \t]*(?:px)?\z' }
    $match = [regex]::Match($Text.Trim(), $pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $number = [decimal]0
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $valid = $match.Success -and [decimal]::TryParse($match.Groups[1].Value,
        [Globalization.NumberStyles]::AllowDecimalPoint, $culture, [ref]$number)
    if (-not $valid -or $number -lt $limits[$InputKey][0] -or $number -gt $limits[$InputKey][1]) {
        return [pscustomobject]@{ Valid = $false; Value = ''; Error = $message }
    }
    return [pscustomobject]@{ Valid = $true; Value = $number.ToString('0.##', $culture); Error = '' }
}

function Get-ParallaxInputResponse {
    param([string]$InputKey, [AllowNull()][string]$Text, [switch]$Cancelled)
    if (-not $Cancelled) {
        $parsed = ConvertTo-ParallaxInputValue -InputKey $InputKey -Text $Text
        if ($parsed.Valid) { return 'PARALLAX_INPUT_V1|ok|' + $parsed.Value }
    }
    return 'PARALLAX_INPUT_V1|cancel|'
}

# Dot-sourcing exposes only passive validation functions for offline tests.
if ($MyInvocation.InvocationName -eq '.') { return }

$ErrorActionPreference = 'Stop'
$response = 'PARALLAX_INPUT_V1|cancel|'
$form = $null
$inputFont = $null
$tip = $null
try {
    if ($Cancel) {
        $response = Get-ParallaxInputResponse -Cancelled
    }
    elseif ($ValidateOnly) {
        $response = Get-ParallaxInputResponse -InputKey $Key -Text $Value
    }
    else {
        $initialValue = ConvertTo-ParallaxInputValue -InputKey $Key -Text $Initial
        if (-not $initialValue.Valid) { throw 'Invalid initial setting.' }
        $culture = [Globalization.CultureInfo]::InvariantCulture
        $positions = @{}
        foreach ($entry in @(@('X', $X, -100000, 100000), @('Y', $Y, -100000, 100000),
                @('Width', $Width, 24, 2048), @('Height', $Height, 12, 512))) {
            $integer = 0
            if (-not [int]::TryParse($entry[1], [Globalization.NumberStyles]::AllowLeadingSign,
                    $culture, [ref]$integer) -or $integer -lt $entry[2] -or $integer -gt $entry[3]) {
                throw 'Invalid editor bounds.'
            }
            $positions[$entry[0]] = $integer
        }
        $uiScale = [decimal]0
        if (-not [decimal]::TryParse($Scale, [Globalization.NumberStyles]::AllowDecimalPoint,
                $culture, [ref]$uiScale) -or $uiScale -lt 0.75 -or $uiScale -gt 2) {
            throw 'Invalid editor scale.'
        }
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        [Windows.Forms.Application]::EnableVisualStyles()
        $form = New-Object Windows.Forms.Form
        $form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::None
        # Override Windows' normal minimum top-level window height for a one-line overlay.
        $form.MinimumSize = New-Object Drawing.Size(1, 1)
        $form.StartPosition = [Windows.Forms.FormStartPosition]::Manual
        $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None
        $form.Location = New-Object Drawing.Point($positions.X, $positions.Y)
        $form.ClientSize = New-Object Drawing.Size($positions.Width, $positions.Height)
        $form.ShowInTaskbar = $false
        $form.TopMost = $true
        $form.BackColor = [Drawing.Color]::FromArgb(137, 190, 250)
        $form.Padding = New-Object Windows.Forms.Padding(1)
        $form.KeyPreview = $true
        $form.Text = 'Parallax setting'
        $form.Tag = [pscustomobject]@{ Response = $response; Active = $false }

        $box = New-Object Windows.Forms.TextBox
        $box.AutoSize = $false
        $box.Multiline = $false
        $box.BorderStyle = [Windows.Forms.BorderStyle]::None
        $box.Dock = [Windows.Forms.DockStyle]::Fill
        $box.BackColor = [Drawing.Color]::FromArgb(25, 25, 25)
        $box.ForeColor = [Drawing.Color]::FromArgb(220, 220, 220)
        $box.TextAlign = [Windows.Forms.HorizontalAlignment]::Center
        $box.MaxLength = 64
        $inputFont = New-Object Drawing.Font('Segoe UI', [single](9 * $uiScale), [Drawing.FontStyle]::Regular)
        $box.Font = $inputFont
        $box.Text = $initialValue.Value
        $box.AccessibleName = 'Parallax ' + $Key
        $box.AccessibleDescription = 'Enter applies. Escape cancels.'
        $form.Controls.Add($box)
        $tip = New-Object Windows.Forms.ToolTip
        $tip.IsBalloon = $false
        $tip.ToolTipTitle = ''

        $form.add_Shown({
            $form.Tag.Active = $true
            $form.Activate()
            $box.Focus() | Out-Null
            $box.SelectAll()
        })
        $form.add_Deactivate({
            if ($form.Tag.Active) { $form.Close() }
        })
        $box.add_KeyDown({
            param($sender, $eventArgs)
            if ($eventArgs.KeyCode -eq [Windows.Forms.Keys]::Escape) {
                $eventArgs.SuppressKeyPress = $true
                $form.Close()
            }
            elseif ($eventArgs.KeyCode -eq [Windows.Forms.Keys]::Enter) {
                $eventArgs.SuppressKeyPress = $true
                $submitted = ConvertTo-ParallaxInputValue -InputKey $Key -Text $box.Text
                if ($submitted.Valid) {
                    $form.Tag.Response = Get-ParallaxInputResponse -InputKey $Key -Text $submitted.Value
                    $form.Close()
                }
                else {
                    $form.BackColor = [Drawing.Color]::FromArgb(230, 90, 90)
                    $tip.Show($submitted.Error, $box, 0, $box.Height + 3, 3500)
                    $box.AccessibleDescription = $submitted.Error + ' Escape cancels.'
                }
            }
        })
        $box.add_TextChanged({
            $form.BackColor = [Drawing.Color]::FromArgb(137, 190, 250)
            $tip.Hide($box)
        })
        $null = $form.ShowDialog()
        $response = [string]$form.Tag.Response
    }
}
catch {
    # No user text or exception detail is reflected into the command channel.
    $response = 'PARALLAX_INPUT_V1|cancel|'
}
finally {
    if ($null -ne $tip) { $tip.Dispose() }
    if ($null -ne $form) { $form.Dispose() }
    if ($null -ne $inputFont) { $inputFont.Dispose() }
}
[Console]::WriteLine($response)

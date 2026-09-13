# One-shot RGB-hex overlay for CPU thread colors. It validates data and writes
# nothing; ThreadColors.lua owns persistence and the immediate CPU apply event.
[CmdletBinding()]
param(
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

function ConvertTo-ParallaxCpuColor {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text -or $Text.Length -gt 64) {
        return [pscustomobject]@{ Valid = $false; Value = ''; Error = 'Enter #RRGGBB.' }
    }
    $match = [regex]::Match($Text.Trim(), '\A#?([0-9a-fA-F]{6})\z')
    if (-not $match.Success) {
        return [pscustomobject]@{ Valid = $false; Value = ''; Error = 'Enter #RRGGBB.' }
    }
    $hex = $match.Groups[1].Value.ToUpperInvariant()
    return [pscustomobject]@{
        Valid = $true
        Value = ('{0},{1},{2}' -f [Convert]::ToInt32($hex.Substring(0, 2), 16), [Convert]::ToInt32($hex.Substring(2, 2), 16), [Convert]::ToInt32($hex.Substring(4, 2), 16))
        Error = ''
    }
}

function Get-ParallaxCpuColorResponse {
    param([AllowNull()][string]$Text, [switch]$Cancelled)
    if (-not $Cancelled) {
        $parsed = ConvertTo-ParallaxCpuColor -Text $Text
        if ($parsed.Valid) { return 'PARALLAX_CPU_COLOR_V1|ok|' + $parsed.Value }
    }
    return 'PARALLAX_CPU_COLOR_V1|cancel|'
}

# Dot-sourcing exposes only validation helpers for offline tests.
if ($MyInvocation.InvocationName -eq '.') { return }

$ErrorActionPreference = 'Stop'
$response = 'PARALLAX_CPU_COLOR_V1|cancel|'
$form = $null
$inputFont = $null
$tip = $null
try {
    if ($Cancel) {
        $response = Get-ParallaxCpuColorResponse -Cancelled
    }
    elseif ($ValidateOnly) {
        $response = Get-ParallaxCpuColorResponse -Text $Value
    }
    else {
        $initialValue = ConvertTo-ParallaxCpuColor -Text $Initial
        if (-not $initialValue.Valid) { throw 'Invalid initial color.' }
        $culture = [Globalization.CultureInfo]::InvariantCulture
        $positions = @{}
        foreach ($entry in @(@('X', $X, -100000, 100000), @('Y', $Y, -100000, 100000),
                @('Width', $Width, 72, 2048), @('Height', $Height, 12, 512))) {
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
        $form.Text = 'CPU thread color'
        $form.Tag = [pscustomobject]@{ Response = $response; Active = $false }

        $box = New-Object Windows.Forms.TextBox
        $box.AutoSize = $false
        $box.Multiline = $false
        $box.BorderStyle = [Windows.Forms.BorderStyle]::None
        $box.Dock = [Windows.Forms.DockStyle]::Fill
        $box.BackColor = [Drawing.Color]::FromArgb(25, 25, 25)
        $box.ForeColor = [Drawing.Color]::FromArgb(220, 220, 220)
        $box.TextAlign = [Windows.Forms.HorizontalAlignment]::Center
        $box.MaxLength = 7
        $inputFont = New-Object Drawing.Font('Segoe UI', [single](9 * $uiScale), [Drawing.FontStyle]::Regular)
        $box.Font = $inputFont
        $box.Text = '#' + (($initialValue.Value -split ',' | ForEach-Object { '{0:X2}' -f [int]$_ }) -join '')
        $box.AccessibleName = 'CPU thread color'
        $box.AccessibleDescription = 'Enter applies a hex color. Escape cancels.'
        $form.Controls.Add($box)
        $tip = New-Object Windows.Forms.ToolTip

        $form.add_Shown({
            $form.Tag.Active = $true
            $form.Activate()
            $box.Focus() | Out-Null
            $box.SelectAll()
        })
        $form.add_Deactivate({ if ($form.Tag.Active) { $form.Close() } })
        $box.add_KeyDown({
            param($sender, $eventArgs)
            if ($eventArgs.KeyCode -eq [Windows.Forms.Keys]::Escape) {
                $eventArgs.SuppressKeyPress = $true
                $form.Close()
            }
            elseif ($eventArgs.KeyCode -eq [Windows.Forms.Keys]::Enter) {
                $eventArgs.SuppressKeyPress = $true
                $submitted = ConvertTo-ParallaxCpuColor -Text $box.Text
                if ($submitted.Valid) {
                    $form.Tag.Response = Get-ParallaxCpuColorResponse -Text $box.Text
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
    $response = 'PARALLAX_CPU_COLOR_V1|cancel|'
}
finally {
    if ($null -ne $tip) { $tip.Dispose() }
    if ($null -ne $form) { $form.Dispose() }
    if ($null -ne $inputFont) { $inputFont.Dispose() }
}
[Console]::WriteLine($response)

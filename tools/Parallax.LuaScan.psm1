#requires -Version 5.1
# Lightweight Lua source checks for tools/Test-Parallax.ps1.
#
# XMOD-04 (docs/PERFORMANCE-REVIEW.md): a skin's Lua Update() runs inside the
# measure phase of every update, and SKIN:Bang runs synchronously. A !Redraw,
# !UpdateMeterGroup or !UpdateMeter * sent there forces an extra meter pass or
# a full-window paint before the engine's own end-of-cycle redraw, every tick.
# Find-ParallaxUpdateRepaint reports such a bang only when it is a direct,
# unconditional statement of the global Update() body: not inside if/for/while
# blocks, not inside nested or helper functions (event paths call those), not
# behind an 'and'/'or' short circuit, and not after a 'return' of Update()
# that sits inside a block (an early-return guard such as
# 'if not dirty then return 0 end' makes every later statement conditional).
# do...end and repeat...until blocks run unconditionally and do not hide a
# call. Update() definitions are found outside comments and strings only, so
# commented-out or quoted code is never scanned.

Set-StrictMode -Version Latest

# Decodes a script by its byte-order mark: UTF-16LE/BE (several Parallax Lua
# files), UTF-8 with or without BOM. Line endings are left as they are.
function Read-ParallaxScriptText {
    param([Parameter(Mandatory)][string]$Path)
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { return [Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2) }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) { return [Text.Encoding]::BigEndianUnicode.GetString($bytes, 2, $bytes.Length - 2) }
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { return [Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3) }
    [Text.Encoding]::UTF8.GetString($bytes)
}

$script:LuaToken = [regex]::new(@'
(?<lcomment>--\[(?<lce>=*)\[[\s\S]*?\]\k<lce>\])
|(?<comment>--[^\r\n]*)
|(?<lstring>\[(?<lse>=*)\[[\s\S]*?\]\k<lse>\])
|(?<string>"(?:\\z\s*|\\\r?\n|\\[\s\S]|[^"\\\r\n])*"|'(?:\\z\s*|\\\r?\n|\\[\s\S]|[^'\\\r\n])*')
|(?<name>[A-Za-z_][A-Za-z0-9_]*)
|(?<number>0[xX][0-9A-Fa-f]+|\d+(?:\.\d*)?(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?)
|(?<op>\.\.\.|\.\.|==|~=|<=|>=|::|[-+*/%^\#&~|<>=(){}\[\];:,.])
|(?<ws>\s+)
|(?<other>.)
'@, [Text.RegularExpressions.RegexOptions]::IgnorePatternWhitespace)

# Tokens (comments and whitespace dropped) from Start. With -OneBlock, stops
# after the end that closes the first block opened (a whole function).
function Get-ParallaxLuaTokens {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text, [int]$Start = 0, [switch]$OneBlock)
    $tokens = [Collections.Generic.List[object]]::new()
    $depth = 0; $opened = $false; $pendingDo = 0
    $match = $script:LuaToken.Match($Text, $Start)
    while ($match.Success) {
        $kind = $null
        foreach ($group in 'name', 'string', 'lstring', 'op', 'number', 'other') {
            if ($match.Groups[$group].Success) { $kind = $group; break }
        }
        if ($null -ne $kind) {
            $tokens.Add([pscustomobject]@{ Kind = $kind; Text = $match.Value; Index = $match.Index })
            if ($OneBlock -and $kind -eq 'name') {
                switch -CaseSensitive ($match.Value) {
                    { $_ -in 'function', 'if', 'repeat' } { $depth++; $opened = $true }
                    { $_ -in 'for', 'while' } { $depth++; $pendingDo++; $opened = $true }
                    'do' { if ($pendingDo) { $pendingDo-- } else { $depth++; $opened = $true } }
                    { $_ -in 'end', 'until' } { $depth-- }
                }
                if ($opened -and $depth -le 0) { break }
            }
        }
        $match = $match.NextMatch()
    }
    $tokens
}

# The content of a Lua string literal token, without delimiters.
function Get-ParallaxLuaStringValue($Token) {
    if ($Token.Kind -eq 'string') { return $Token.Text.Substring(1, $Token.Text.Length - 2) }
    if ($Token.Kind -eq 'lstring') {
        $open = $Token.Text.IndexOf('[', 1) + 1
        $value = $Token.Text.Substring($open, $Token.Text.Length - 2 * $open)
        if ($value.StartsWith("`r`n")) { return $value.Substring(2) }
        if ($value.StartsWith("`n")) { return $value.Substring(1) }
        return $value
    }
    $null
}

# Repaint bangs named by a literal SKIN:Bang argument list.
function Get-ParallaxRepaintBangs([string]$First, [string]$Second) {
    $found = [Collections.Generic.List[string]]::new()
    $text = $First.Trim()
    if ($text.StartsWith('[')) {
        foreach ($match in [regex]::Matches($text, '(?i)\[\s*!(Redraw|UpdateMeterGroup|UpdateMeter)\b([^\]]*)')) {
            $bang = $match.Groups[1].Value
            if ($bang -ieq 'UpdateMeter' -and $match.Groups[2].Value.Trim().Trim('"', "'").Split(' ')[0] -ne '*') { continue }
            $found.Add('!' + $bang)
        }
        return $found
    }
    if ($text -match '(?i)^!(Redraw|UpdateMeterGroup|UpdateMeter)\b(.*)$') {
        $bang = $Matches[1]; $rest = $Matches[2].Trim()
        if ($bang -ieq 'UpdateMeter') {
            $target = if ($rest) { $rest.Trim('"', "'").Split(' ')[0] } elseif ($null -ne $Second) { $Second.Trim().Trim('"', "'") } else { '' }
            if ($target -ne '*') { return $found }
            $found.Add('!UpdateMeter *')
        } else {
            $found.Add('!' + $bang)
        }
    }
    $found
}

# Comments and strings (as in $script:LuaToken), or an Update() definition:
# 'function Update(' or 'Update = function' at the start of a line. Scanning
# left to right consumes every comment and string whole, so an 'anchor' match
# is always code. Only the matches are enumerated, not every token.
$script:UpdateAnchor = [regex]::new(@'
(?<skip>--\[(?<lce>=*)\[[\s\S]*?\]\k<lce>\]
|--[^\r\n]*
|\[(?<lse>=*)\[[\s\S]*?\]\k<lse>\]
|"(?:\\z\s*|\\\r?\n|\\[\s\S]|[^"\\\r\n])*"|'(?:\\z\s*|\\\r?\n|\\[\s\S]|[^'\\\r\n])*')
|(?<anchor>(?m:^)[\t\x20]*(?:function[\t\x20]+Update[\t\x20]*\(|Update[\t\x20]*=[\t\x20]*function\b))
'@, [Text.RegularExpressions.RegexOptions]::IgnorePatternWhitespace)

# Each global Update() definition outside comments and strings (not 'local'),
# tokenized to its own end.
function Find-ParallaxUpdateRepaint {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $findings = [Collections.Generic.List[object]]::new()
    $anchors = [Collections.Generic.List[int]]::new()
    foreach ($match in $script:UpdateAnchor.Matches($Text)) { if ($match.Groups['anchor'].Success) { $anchors.Add($match.Index) } }
    foreach ($anchor in $anchors) {
        $tokens = @(Get-ParallaxLuaTokens -Text $Text -Start $anchor -OneBlock)
        foreach ($finding in (Find-ParallaxRepaintInTokens -Text $Text -Tokens $tokens)) { $findings.Add($finding) }
    }
    $findings
}

function Find-ParallaxRepaintInTokens {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text, [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Tokens)
    $tokens = $Tokens
    $lineStarts = [Collections.Generic.List[int]]::new()
    $lineStarts.Add(0)
    for ($i = $Text.IndexOf("`n"); $i -ge 0; $i = $Text.IndexOf("`n", $i + 1)) { $lineStarts.Add($i + 1) }
    $starts = $lineStarts.ToArray()
    $findings = [Collections.Generic.List[object]]::new()
    # Frames: Kind function|if|loop|do|repeat; Update marks the global Update(),
    # Guarded that it has passed a 'return' of its own inside a block.
    $stack = [Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $tokens.Count; $i++) {
        $token = $tokens[$i]
        if ($token.Kind -eq 'name') {
            switch -CaseSensitive ($token.Text) {
                'function' {
                    $isUpdate = $false
                    if ($stack.Count -eq 0) {
                        $next = if ($i + 2 -lt $tokens.Count) { $tokens[$i + 1] } else { $null }
                        $after = if ($i + 2 -lt $tokens.Count) { $tokens[$i + 2] } else { $null }
                        $before = if ($i -ge 1) { $tokens[$i - 1] } else { $null }
                        $declared = ($null -ne $next -and $next.Text -ceq 'Update' -and $after.Text -eq '(' -and -not ($before -and $before.Text -ceq 'local'))
                        $assigned = ($i -ge 2 -and $tokens[$i - 1].Text -eq '=' -and $tokens[$i - 2].Text -ceq 'Update' -and
                            -not ($i -ge 3 -and $tokens[$i - 3].Text -in '.', ':', 'local'))
                        $isUpdate = $declared -or $assigned
                    }
                    $stack.Add([pscustomobject]@{ Kind = 'function'; Update = $isUpdate; Guarded = $false; PendingDo = $false })
                }
                'if' { $stack.Add([pscustomobject]@{ Kind = 'if'; Update = $false; Guarded = $false; PendingDo = $false }) }
                'for' { $stack.Add([pscustomobject]@{ Kind = 'loop'; Update = $false; Guarded = $false; PendingDo = $true }) }
                'while' { $stack.Add([pscustomobject]@{ Kind = 'loop'; Update = $false; Guarded = $false; PendingDo = $true }) }
                'do' {
                    if ($stack.Count -and $stack[$stack.Count - 1].Kind -eq 'loop' -and $stack[$stack.Count - 1].PendingDo) { $stack[$stack.Count - 1].PendingDo = $false }
                    else { $stack.Add([pscustomobject]@{ Kind = 'do'; Update = $false; Guarded = $false; PendingDo = $false }) }
                }
                'repeat' { $stack.Add([pscustomobject]@{ Kind = 'repeat'; Update = $false; Guarded = $false; PendingDo = $false }) }
                'until' { if ($stack.Count) { $stack.RemoveAt($stack.Count - 1) } }
                'end' { if ($stack.Count) { $stack.RemoveAt($stack.Count - 1) } }
                'return' {
                    # A return of Update() itself (not of a nested function).
                    # Lua allows return only as a block's last statement, so a
                    # return directly in Update() ends it; one inside an if, a
                    # loop or a block is an early exit that every later
                    # statement depends on.
                    for ($f = $stack.Count - 1; $f -ge 0; $f--) {
                        if ($stack[$f].Kind -ne 'function') { continue }
                        if ($stack[$f].Update) { $stack[$f].Guarded = $true }
                        break
                    }
                }
                'SKIN' {
                    if ($i + 3 -ge $tokens.Count -or $tokens[$i + 1].Text -ne ':' -or $tokens[$i + 2].Text -cne 'Bang' -or $tokens[$i + 3].Text -ne '(') { break }
                    if ($i -ge 1 -and $tokens[$i - 1].Text -cin 'and', 'or') { break }
                    if ($i -ge 1 -and $tokens[$i - 1].Text -in '.', ':') { break }
                    # The innermost frame that can skip the call must be Update() itself.
                    $owner = $null
                    for ($f = $stack.Count - 1; $f -ge 0; $f--) {
                        if ($stack[$f].Kind -in 'do', 'repeat') { continue }
                        $owner = $stack[$f]; break
                    }
                    if ($null -eq $owner -or -not $owner.Update -or $owner.Guarded) { break }
                    $first = if ($i + 4 -lt $tokens.Count) { Get-ParallaxLuaStringValue $tokens[$i + 4] } else { $null }
                    if ($null -eq $first) { break }   # a computed bang cannot be judged statically
                    $second = $null
                    if ($i + 6 -lt $tokens.Count -and $tokens[$i + 5].Text -eq ',') { $second = Get-ParallaxLuaStringValue $tokens[$i + 6] }
                    foreach ($bang in (Get-ParallaxRepaintBangs $first $second)) {
                        $line = [array]::BinarySearch($starts, $token.Index)
                        if ($line -lt 0) { $line = (-bnot $line) - 1 }
                        $findings.Add([pscustomobject]@{ Line = $line + 1; Bang = $bang; Statement = ($Text.Substring($token.Index, [math]::Min(80, $Text.Length - $token.Index)).Split("`n")[0].TrimEnd()) })
                    }
                }
            }
        }
    }
    $findings
}

Export-ModuleMember -Function Read-ParallaxScriptText, Get-ParallaxLuaTokens, Find-ParallaxUpdateRepaint

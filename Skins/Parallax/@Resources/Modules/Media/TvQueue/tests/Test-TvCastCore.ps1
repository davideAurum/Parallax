# Developer-only offline tests for the cast core (M7): address rule, mDNS
# parsing, Cast messages and frames, the TLS channel against a stand-in device
# on 127.0.0.1, status parsing, the DPAPI cast key, the switch, the state file
# and the snapshot's source line. No packet leaves this PC: discovery is never
# started here (Set-CastForTest is not even needed for parsing), and the only
# socket is to the stand-in. All data is made up.
# Host: Windows PowerShell 5.1 (powershell.exe), a normal user (DPAPI).
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-TvCastCore.ps1
#requires -Version 5.1
#requires -PSEdition Desktop
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $here 'TvLounge.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $here 'TvStore.psm1') -Force -DisableNameChecking
. (Join-Path $PSScriptRoot 'TvCastStandIn.ps1')
$script:checks = 0
function Assert-Check { param([bool]$Value, [string]$Message); if (-not $Value) { throw "FAILED: $Message" }; $script:checks++ }
function Throws { param([scriptblock]$Block); try { & $Block; return $false } catch { return $true } }
$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('Parallax-TvCast-test-' + [Guid]::NewGuid().ToString('N'))

# ------------------------------------------------------------ addresses
foreach ($good in @('192.168.1.20', '10.0.0.5', '172.16.0.1', '172.31.255.254', '169.254.10.10')) { Assert-Check (Test-CastAddress $good) "private address $good is allowed" }
foreach ($bad in @('8.8.8.8', '172.32.0.1', '127.0.0.1', '0.0.0.0', '224.0.0.251', '192.168.1', '192.168.1.300', 'fe80::1', '', $null, 5)) { Assert-Check (-not (Test-CastAddress $bad)) "not a private IPv4 address: $bad" }
Assert-Check (Throws { $null = Open-CastLink '8.8.8.8' 8009 }) 'a public address is refused before any connection'
Assert-Check (Throws { $null = Open-CastLink '127.0.0.1' 8009 }) 'loopback is refused outside tests'

# ------------------------------------------------------------ mDNS
Assert-Check ((New-CastMdnsQuery).Length -eq 12 + 24 + 4 -and (New-CastMdnsQuery)[5] -eq 1) 'the query asks one PTR question'
function Add-Name($list, [string]$name) { foreach ($label in $name.Split('.')) { $b = [Text.Encoding]::UTF8.GetBytes($label); $list.Add([byte]$b.Length); $list.AddRange([byte[]]$b) }; $list.Add([byte]0) }
function Add-U16($list, [int]$v) { $list.Add([byte]($v -shr 8)); $list.Add([byte]($v -band 255)) }
function Add-Record($list, [string]$owner, [int]$type, [byte[]]$data) { Add-Name $list $owner; Add-U16 $list $type; Add-U16 $list 1; foreach ($x in 0, 0, 0, 120) { $list.Add([byte]$x) }; Add-U16 $list $data.Length; $list.AddRange($data) }
function New-Answer([string]$address, [string]$friendly = 'Sample TV') {
    $p = [Collections.Generic.List[byte]]::new()
    foreach ($x in 0, 0, 0x84, 0, 0, 0, 0, 4, 0, 0, 0, 0) { $p.Add([byte]$x) }
    $instance = 'Sample-abc._googlecast._tcp.local'
    $ptr = [Collections.Generic.List[byte]]::new(); Add-Name $ptr $instance
    Add-Record $p '_googlecast._tcp.local' 12 $ptr.ToArray()
    $srv = [Collections.Generic.List[byte]]::new(); Add-U16 $srv 0; Add-U16 $srv 0; Add-U16 $srv 8009; Add-Name $srv 'sample-host.local'
    Add-Record $p $instance 33 $srv.ToArray()
    $txt = [Collections.Generic.List[byte]]::new()
    foreach ($entry in @('id=abc123', "fn=$friendly", 'md=Sample')) { $b = [Text.Encoding]::UTF8.GetBytes($entry); $txt.Add([byte]$b.Length); $txt.AddRange([byte[]]$b) }
    Add-Record $p $instance 16 $txt.ToArray()
    Add-Record $p 'sample-host.local' 1 ([byte[]]($address.Split('.') | ForEach-Object { [byte]$_ }))
    return ,$p.ToArray()
}
$records = @(Read-CastMdnsRecords (New-Answer '192.168.1.20'))
$devices = @(Get-CastDevicesFromRecords -Records $records)
Assert-Check ($devices.Count -eq 1 -and $devices[0].Name -ceq 'Sample TV' -and $devices[0].Id -ceq 'abc123' -and $devices[0].Address -ceq '192.168.1.20' -and $devices[0].Port -eq 8009) 'an answer gives the device name, id, address and port'
$devices = @(Get-CastDevicesFromRecords -Records @(Read-CastMdnsRecords (New-Answer '203.0.113.9')))
Assert-Check ($devices.Count -eq 0) 'a device answering with a public address is never kept'
$noA = @($records | Where-Object { $_.Type -cne 'A' })
$devices = @(Get-CastDevicesFromRecords -Records $noA -From @{ 'Sample-abc._googlecast._tcp.local' = '10.1.2.3' })
Assert-Check ($devices.Count -eq 1 -and $devices[0].Address -ceq '10.1.2.3') 'without an A record the answering address is used'
$loop = [byte[]](0, 0, 0x84, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0xC0, 12)
Assert-Check (Throws { $null = @(Read-CastMdnsRecords $loop) }) 'a compression loop is refused'
$full = New-Answer '192.168.1.20'
Assert-Check (Throws { $null = @(Read-CastMdnsRecords ([byte[]]$full[0..($full.Length - 3)])) }) 'a cut-off answer is refused'
$text = Get-CastDevicesFromRecords -Records @(Read-CastMdnsRecords (New-Answer '192.168.1.20' ("Bad" + [char]0x202E + "name")))
Assert-Check (-not $text.Name.Contains([char]0x202E)) 'device names lose bidi overrides'

# ------------------------------------------------------------ messages and frames
$message = ConvertTo-CastMessage 'sender-0' 'receiver-0' 'urn:x-cast:com.google.cast.receiver' '{"type":"GET_STATUS","requestId":1}'
$back = ConvertFrom-CastMessage $message
Assert-Check ($back.Source -ceq 'sender-0' -and $back.Destination -ceq 'receiver-0' -and $back.Namespace -ceq 'urn:x-cast:com.google.cast.receiver' -and $back.Payload -ceq '{"type":"GET_STATUS","requestId":1}') 'a Cast message round-trips'
$frame = ConvertTo-CastFrame $message
$buffer = [IO.MemoryStream]::new()
$buffer.Write($frame, 0, 3)
Assert-Check ((Read-CastFrames $buffer).Count -eq 0) 'a frame split before its length is kept'
$buffer.Write($frame, 3, $frame.Length - 3); $buffer.Write($frame, 0, 10)
$got = Read-CastFrames $buffer
Assert-Check ($got.Count -eq 1 -and $buffer.Length -eq 10) 'one whole frame out, the start of the next kept'
$huge = [IO.MemoryStream]::new(); $huge.Write([byte[]](0x7F, 0, 0, 0), 0, 4)
Assert-Check (Throws { $null = Read-CastFrames $huge }) 'an unreasonable frame length is refused'
Assert-Check (Throws { $null = ConvertFrom-CastMessage ([byte[]](0x12, 0x50, 0x41)) }) 'a field running past the message is refused'

# ------------------------------------------------------------ status parsing
$apps = Get-CastApps @{ type = 'RECEIVER_STATUS'; status = @{ applications = [object[]]@((New-TvCastYouTubeApp), @{ appId = 'E8C28D3C'; displayName = 'Backdrop'; namespaces = [object[]]@() }, 'junk') } }
Assert-Check ($apps.Count -eq 2 -and $null -ne (Select-CastYouTube $apps) -and (Select-CastYouTube $apps).TransportId -ceq 'transport-1') 'the running YouTube app is found by id and its remote-control namespace'
Assert-Check ($null -eq (Select-CastYouTube @($apps[1]))) 'another app is not YouTube'
$noMdx = New-TvCastYouTubeApp; $noMdx.namespaces = [object[]]@(@{ name = 'urn:x-cast:com.google.cast.media' })
Assert-Check ($null -eq (Select-CastYouTube (Get-CastApps @{ type = 'RECEIVER_STATUS'; status = @{ applications = [object[]]@($noMdx) } }))) 'a YouTube app without its remote-control namespace is not used'
$picture = New-CastPicture
Merge-CastMediaStatus $picture @{ type = 'MEDIA_STATUS'; status = [object[]]@(@{ playerState = 'PLAYING'; currentTime = 12.5; media = @{ contentId = 'vid00000001'; duration = 200.25; metadata = @{ title = 'Sample song'; subtitle = 'Sample channel' } } }) } 1000000
Assert-Check ($picture.Loaded -and $picture.VideoId -ceq 'vid00000001' -and (Get-TvPlayName $picture.State) -ceq 'playing' -and $picture.PositionMs -eq 12500 -and $picture.DurationMs -eq 200250 -and $picture.Title -ceq 'Sample song' -and $picture.Subtitle -ceq 'Sample channel') 'media status gives the video, state, position, length, title and channel'
Assert-Check ((Get-TvPositionMs $picture 1002000) -eq 14500) 'a playing cast moves on between statuses'
Merge-CastMediaStatus $picture @{ type = 'MEDIA_STATUS'; status = [object[]]@(@{ playerState = 'PAUSED'; currentTime = 20 }) } 1003000
Assert-Check ($picture.Title -ceq 'Sample song' -and (Get-TvPlayName $picture.State) -ceq 'paused' -and $picture.PositionMs -eq 20000) 'a status without media keeps what was known'
Merge-CastMediaStatus $picture @{ type = 'MEDIA_STATUS'; status = [object[]]@(@{ playerState = 'IDLE'; idleReason = 'FINISHED' }) }
Assert-Check ((Get-TvPlayName $picture.State) -ceq 'ended' -and $picture.Loaded) 'the end of a video reads ended'
Merge-CastMediaStatus $picture @{ type = 'MEDIA_STATUS'; status = [object[]]@(@{ playerState = 'BUFFERING'; media = @{ contentId = 'vid00000002' } }) }
Assert-Check ($picture.VideoId -ceq 'vid00000002' -and -not $picture.Title -and (Get-TvPlayName $picture.State) -ceq 'loading') 'a new video drops the old title'
Merge-CastMediaStatus $picture @{ type = 'MEDIA_STATUS'; status = [object[]]@(@{ playerState = 'PLAYING'; media = @{ contentId = 'not an id' } }) }
Assert-Check ($picture.VideoId -ceq 'vid00000002') 'an invalid content id is ignored'
Merge-CastMediaStatus $picture @{ type = 'MEDIA_STATUS'; status = [object[]]@() }
Assert-Check (-not $picture.Loaded -and -not $picture.VideoId) 'an empty status: nothing loaded'
Assert-Check ((Get-CastScreenId @{ type = 'mdxSessionStatus'; data = @{ screenId = 'CAST-SCREEN-1' } }) -ceq 'CAST-SCREEN-1') 'the screen id is read from mdxSessionStatus'
Assert-Check ((Get-CastScreenId @{ type = 'mdxSessionStatus'; data = @{ screenId = "bad id`n" } }) -ceq '' -and (Get-CastScreenId @{ type = 'other' }) -ceq '') 'anything else gives no screen id'

# ------------------------------------------------------------ the channel, against a stand-in device
$stand = Start-TvCastStandIn
try {
    Set-CastForTest @($stand.Device)
    Assert-Check (Throws { Set-CastForTest @([pscustomobject]@{ Address = '192.168.1.2' }) }) 'test devices must be on 127.0.0.1'
    Set-CastForTest @($stand.Device)
    $null = $stand.State.Apps.Add((New-TvCastYouTubeApp))
    $null = $stand.State.Media.Add(@{ playerState = 'PLAYING'; currentTime = 3; media = @{ contentId = 'vid00000003'; duration = 100; metadata = @{ title = 'Stand-in title' } } })
    $stand.State.CastScreen = 'CAST-SCREEN-SECRET'
    $before = [Net.ServicePointManager]::ServerCertificateValidationCallback
    $link = Open-CastLink '127.0.0.1' $stand.State.Port
    Assert-Check ([object]::ReferenceEquals($before, [Net.ServicePointManager]::ServerCertificateValidationCallback)) 'accepting the device certificate changes no process-wide HTTPS setting'
    Send-CastJson $link 'receiver-0' 'urn:x-cast:com.google.cast.receiver' @{ type = 'GET_STATUS' }
    $deadline = [DateTime]::UtcNow.AddSeconds(5); $status = $null
    while ($null -eq $status -and [DateTime]::UtcNow -lt $deadline) { foreach ($m in (Step-CastLink $link 50).Messages) { if ($m.Body['type'] -ceq 'RECEIVER_STATUS') { $status = $m.Body } } }
    Assert-Check ($null -ne $status -and (Select-CastYouTube (Get-CastApps $status)).TransportId -ceq 'transport-1') 'receiver status over TLS'
    foreach ($type in @('LAUNCH', 'STOP', 'PLAY', 'PAUSE', 'SET_VOLUME', 'QUEUE_NEXT', 'LOAD')) { Assert-Check (Throws { Send-CastJson $link 'receiver-0' 'urn:x-cast:com.google.cast.receiver' @{ type = $type } }) "never sends $type" }
    Send-CastJson $link 'transport-1' 'urn:x-cast:com.google.cast.tp.connection' @{ type = 'CONNECT' }
    Send-CastJson $link 'transport-1' 'urn:x-cast:com.google.cast.media' @{ type = 'GET_STATUS' }
    Send-CastJson $link 'transport-1' 'urn:x-cast:com.google.youtube.mdx' @{ type = 'getMdxSessionStatus' }
    $null = $stand.State.Push.Add(@('receiver-0', 'urn:x-cast:com.google.cast.tp.heartbeat', @{ type = 'PING' }))
    $picture = New-CastPicture; $screen = ''
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    while ((-not $screen -or -not $picture.Loaded -or -not @($stand.State.Seen | Where-Object { $_.Type -ceq 'PONG' }).Count) -and [DateTime]::UtcNow -lt $deadline) {
        foreach ($m in (Step-CastLink $link 50).Messages) { Merge-CastMediaStatus $picture $m.Body; $id = Get-CastScreenId $m.Body; if ($id) { $screen = $id } }
    }
    Assert-Check ($picture.Title -ceq 'Stand-in title' -and $screen -ceq 'CAST-SCREEN-SECRET') 'media status and the screen id arrive over the channel'
    Assert-Check (@($stand.State.Seen | Where-Object { $_.Type -ceq 'PONG' -and $_.Destination -ceq 'receiver-0' }).Count -ge 1) 'the device''s PING is answered with PONG'
    $types = @($stand.State.Seen | ForEach-Object { $_.Type } | Sort-Object -Unique)
    Assert-Check (@($types | Where-Object { $_ -cnotin @('CONNECT', 'GET_STATUS', 'PING', 'PONG', 'getMdxSessionStatus') }).Count -eq 0) ('only CONNECT, GET_STATUS, PING, PONG and getMdxSessionStatus reached the device: ' + ($types -join ','))
    $stand.State.Drop = $true
    $deadline = [DateTime]::UtcNow.AddSeconds(5); $ended = $null
    while ($null -eq $ended -and [DateTime]::UtcNow -lt $deadline) { $step = Step-CastLink $link 50; if ($step.Ended) { $ended = $step.Kind } }
    Assert-Check ($ended -cin @('closed', 'broken')) 'a device that closes the channel ends the link'
    Close-CastLink $link
    $discovery = Start-CastDiscovery
    $found = Step-CastDiscovery $discovery
    Assert-Check ($found.Count -eq 1 -and $found[0].Port -eq $stand.State.Port -and $discovery.Clients.Count -eq 0) 'in tests discovery returns the stand-in and opens no socket'
    Assert-Check ($stand.State.Errors.Count -eq 0) ('the stand-in saw no errors: ' + (@($stand.State.Errors) -join '; '))
} finally { Stop-TvCastStandIn $stand }

# ------------------------------------------------------------ cast key, switch, state, snapshot
try {
    $root = Initialize-TvPrivateDirectory (Join-Path $runRoot 'data')
    Assert-Check ($null -eq (Read-TvCastKey $root) -and -not (Test-TvCastIntent $root)) 'nothing stored before casts are switched on'
    Save-TvCastKey $root (New-TvCastKey -ScreenId 'CAST-SCREEN-SECRET' -LoungeToken 'CAST-TOKEN-SECRET')
    $key = Read-TvCastKey $root
    Assert-Check ($key.ScreenId -ceq 'CAST-SCREEN-SECRET' -and $key.LoungeToken -ceq 'CAST-TOKEN-SECRET' -and [Guid]::TryParse($key.DeviceId, [ref][Guid]::Empty)) 'the cast key round-trips'
    $raw = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes((Join-Path $root 'cast.dpapi')))
    Assert-Check (-not $raw.Contains('CAST-SCREEN') -and -not $raw.Contains('CAST-TOKEN')) 'the cast key file is sealed (no plain screen id or token)'
    Save-TvCastKey $root (New-TvCastKey -ScreenId 'CAST-SCREEN-2')
    Assert-Check ((Read-TvCastKey $root).LoungeToken -ceq '' -and (Read-TvCastKey $root).ScreenId -ceq 'CAST-SCREEN-2') 'a key may wait for its token'
    Copy-Item (Join-Path $root 'cast.dpapi') (Join-Path $root 'pairing.dpapi')
    Assert-Check ($null -eq (Read-TvPairing $root)) 'a cast key never opens as the TV pairing (own DPAPI entropy)'
    Remove-Item (Join-Path $root 'pairing.dpapi')
    [IO.File]::WriteAllBytes((Join-Path $root 'cast.dpapi'), [byte[]](1, 2, 3))
    Assert-Check ($null -eq (Read-TvCastKey $root)) 'a damaged key reads as none'
    Set-TvCastIntent $root $true
    Assert-Check (Test-TvCastIntent $root) 'the switch on'
    Set-TvCastIntent $root $false
    Assert-Check (-not (Test-TvCastIntent $root)) 'the switch off'
    Publish-TvCastStatus $root following 1234
    $seen = Read-TvCastStatus $root
    Assert-Check ($seen.State -ceq 'following' -and $seen.ValidUntil -eq 1234) 'the cast state file round-trips'
    Assert-Check (Throws { Publish-TvCastStatus $root 'Living Room TV' 1 }) 'only fixed words go in the state file'
    Set-TvCastIntent $root $true
    Save-TvCastKey $root (New-TvCastKey -ScreenId 'CAST-SCREEN-3')
    Remove-TvCastData $root
    Assert-Check (-not (Test-Path (Join-Path $root 'cast.dpapi')) -and -not (Test-Path (Join-Path $root 'cast.intent')) -and -not (Test-Path (Join-Path $root 'cast.status'))) 'Forget removes the key, the switch and the state'
    $text = ConvertTo-TvSnapshotText (New-TvSnapshot -State ready -Observed 100 -ValidUntil 200 -Play playing -UpNext unknown -List none -CurrentTitle 'T' -Source cast)
    Assert-Check ($text.Contains("`ncover=`nsource=cast`n")) 'a cast snapshot says source=cast after the thumbnail slot'
    Assert-Check ((ConvertTo-TvSnapshotText (New-TvSnapshot -State ready -Observed 100 -ValidUntil 200 -Play playing -UpNext none -List none)).Contains("`nsource=tv`n")) 'the TV''s own app says source=tv'
    Assert-Check ((ConvertTo-TvSnapshotText (New-TvSnapshot -State offline -Source cast)).Contains("`nsource=`n")) 'outside ready the source is empty'
} finally { if ([IO.Directory]::Exists($runRoot)) { [IO.Directory]::Delete($runRoot, $true) } }
Write-Output "TV cast core: $script:checks checks passed."

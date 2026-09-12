# Offline synthetic tests. No HTTP, accounts, tokens, or live Rainmeter access.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot '..\QueueCore.psm1') -Force
$script:checks = 0
function Check([bool]$Condition, [string]$Label) { if (-not $Condition) { throw "FAILED: $Label" }; $script:checks++ }
function Reject([scriptblock]$Action, [string]$Label) {
    $failed = $false
    try { & $Action | Out-Null } catch { $failed = $true }
    Check $failed $Label
}
$now = 1800000000L
$payload = ConvertFrom-QueueJson '{"currently_playing":null,"queue":[{"type":"track","name":"Synthetic title","artists":[{"name":"Artist"}]},{"type":"track","name":"Synthetic title","artists":[{"name":"Artist"}]},{"type":"episode","name":"Episode","show":{"name":"Show"}}]}'
$normalized = ConvertTo-QueueItems $payload
Check ($normalized.Items.Count -eq 3) 'track, duplicate, and episode retained'
Check ($normalized.Items[0].Title -ceq $normalized.Items[1].Title) 'duplicate order preserved'
Check ($normalized.Items[2].Detail -ceq 'Show') 'episode show source'
$text = ConvertTo-QueueSnapshotText (New-QueueSnapshot -State ready -Items $normalized.Items -Now $now)
Check ($text.StartsWith("PARALLAX_QUEUE_V2`nstate=ready`n")) 'versioned inert snapshot'
Check ($text.Contains('count=3')) 'display count'
Check ($text.Contains("title4=`ndetail4=`ntitle5=`ndetail5=`n")) 'unused rows blank'
Check ($text -notmatch 'Synthetic title|Artist|Episode') 'display metadata encoded, not Rainmeter syntax'
Check (($text -split "`n").Count -eq 17) 'exact bounded field count'

$empty = ConvertTo-QueueItems (ConvertFrom-QueueJson '{"currently_playing":null,"queue":[]}')
Check ($empty.Items.Count -eq 0) 'real empty list accepted'
$emptyText = ConvertTo-QueueSnapshotText (New-QueueSnapshot -State ready -Items $empty.Items -Now $now)
Check ($emptyText.Contains('state=ready') -and $emptyText.Contains('count=0')) 'measured empty distinguished'
foreach ($bad in @('{}','{"queue":[]}','{"currently_playing":null,"queue":null}','{"currently_playing":0,"queue":[]}','{"currently_playing":null,"queue":[null]}','{"currently_playing":null,"queue":[{"type":"unknown","name":"x"}]}','{"currently_playing":null,"queue":[{"type":"track","name":7}]}')) {
    Reject { ConvertTo-QueueItems (ConvertFrom-QueueJson $bad) } 'invalid queue not empty'
}
Reject { ConvertFrom-QueueJson ('[' * 30 + '0' + ']' * 30) } 'nested JSON bounded'
Reject { ConvertFrom-QueueJson ('x' * 1048577) } 'oversized response bounded'

$long = [char]::ConvertFromUtf32(0x1F3B5) * 400
$bounded = Limit-QueueText $long
$utf8 = [Text.UTF8Encoding]::new($false,$true)
Check ($utf8.GetByteCount($bounded) -eq 512) 'UTF8 byte cap preserves whole characters'
Check ((Limit-QueueText "one`nline`tlabel") -ceq 'one line label') 'control characters normalized'
$hostile = '#CURRENTCONFIG# [!Quit] %1'
$hostileItems = @([pscustomobject]@{Title=$hostile;Detail='artist'})
$hostileSnapshot = ConvertTo-QueueSnapshotText (New-QueueSnapshot -State ready -Items $hostileItems -Now $now)
Check ($hostileSnapshot -notmatch '\[!Quit\]|#CURRENTCONFIG#|%1') 'metacharacters never executable cache'
$many = @{ currently_playing=$null; queue=@() }
for ($index=0; $index -lt 8; $index++) { $many.queue += @{type='track';name="Synthetic $index";artists=@()} }
Check ((ConvertTo-QueueItems $many).Items.Count -eq 5) 'display bounded to next five'

foreach ($state in @('onboarding_required','connecting','reauth_required','forbidden','rate_limited','quota_exceeded','offline','service_unavailable','error','stopped')) {
    $snapshot = New-QueueSnapshot -State $state -Now $now
    Check ($snapshot.Items.Count -eq 0 -and $snapshot.Observed -eq 0 -and $snapshot.ValidUntil -eq 0) 'nonlive states clear listening data'
    Reject { New-QueueSnapshot -State $state -Items $normalized.Items -Now $now } 'nonlive data rejected'
}
Reject { New-QueueSnapshot -State unknown -Now $now } 'unknown state rejected'
Check ((Get-QueueResponseDecision 200 -Now $now).State -eq 'response_requires_validation') 'HTTP200 still needs body validation'
Check ((Get-QueueResponseDecision 204 -Now $now).State -eq 'error') 'HTTP204 not fake empty'
Check ((Get-QueueResponseDecision 401 -Now $now).Pause) '401 pauses after refresh exhausted'
Check ((Get-QueueResponseDecision 403 -Now $now).State -eq 'forbidden') '403 not guessed reason'
Check ((Get-QueueResponseDecision 503 -Now $now).State -eq 'service_unavailable') '5xx distinguished'
Check ((Get-QueueResponseDecision 0 -Now $now).State -eq 'offline') 'connection failure distinguished'
$quota = Get-QueueResponseDecision 429 -Body '{"error":{"reason":"QUOTA_EXCEEDED"}}' -RetryAfter '20' -Now $now
Check ($quota.State -eq 'quota_exceeded' -and $quota.Pause -and $quota.RetryNotBefore -eq 0) 'quota exhaustion never invents reset'
foreach ($wait in @(1,120,86401,999999999999L)) {
    $decision = Get-QueueResponseDecision 429 -RetryAfter ([string]$wait) -Now $now
    Check ($decision.RetryNotBefore -ge [Math]::Min($now+$wait,253402300000L)) 'server wait never shortened'
}
Check ((Get-QueueResponseDecision 429 -RetryAfter 'garbage' -Now $now -FailureCount 4).RetryNotBefore -eq $now+300) 'bounded fallback backoff'
$date = [DateTime]::new(1970,1,1,0,0,0,[DateTimeKind]::Utc).AddSeconds($now+200).ToString('r',[Globalization.CultureInfo]::InvariantCulture)
Check ((Get-QueueResponseDecision 429 -RetryAfter $date -Now $now).RetryNotBefore -eq $now+200) 'HTTP-date retry preserved'

$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('Parallax-QueueCore-test-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $runRoot
Publish-QueueSnapshot $runRoot (New-QueueSnapshot -State ready -Items $normalized.Items -Now $now)
Publish-QueueSnapshot $runRoot (New-QueueSnapshot -State stopped -Now $now)
$written = [IO.File]::ReadAllText((Join-Path $runRoot 'queue.snapshot'))
Check ($written.Contains('state=stopped') -and -not $written.Contains('53796E746865746963')) 'atomic replacement clears stale rows'
Check (@(Get-ChildItem -LiteralPath $runRoot -Filter '*.tmp' -Force).Count -eq 0) 'atomic temporary files cleaned'
Write-Output "PASS: $script:checks offline queue core assertions. Synthetic evidence retained at $runRoot"

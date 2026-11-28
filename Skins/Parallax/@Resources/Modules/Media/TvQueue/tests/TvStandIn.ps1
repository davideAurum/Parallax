# Developer-only: a stand-in for YouTube's TV remote endpoints and oEmbed,
# listening on 127.0.0.1 only, for the offline TV tests. All data is made up.
# Dot-source it, then: $standIn = Start-TvStandIn; ... ; Stop-TvStandIn $standIn
# The server runs in its own runspace and handles one request at a time,
# while keeping any number of event streams (long polls) open.
#requires -Version 5.1

$script:TvStandInServer = {
    param($State, $Listener)
    $ErrorActionPreference = 'Stop'
    Add-Type -AssemblyName System.Web.Extensions
    $json = [Web.Script.Serialization.JavaScriptSerializer]::new()
    $polls = [Collections.Generic.List[object]]::new()
    $ascii = [Text.Encoding]::ASCII
    $utf8 = [Text.UTF8Encoding]::new($false)

    function Send-Raw($Stream, [string]$Text) { $bytes = $utf8.GetBytes($Text); $Stream.Write($bytes, 0, $bytes.Length); $Stream.Flush() }
    function Send-Reply($Client, [int]$Status, [string]$Body, [string]$Type = 'text/plain') {
        $bytes = $utf8.GetBytes($Body)
        $head = "HTTP/1.1 $Status X`r`nContent-Type: $Type`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
        $stream = $Client.GetStream()
        $h = $ascii.GetBytes($head); $stream.Write($h, 0, $h.Length); $stream.Write($bytes, 0, $bytes.Length); $stream.Flush()
        $Client.Close()
    }
    function ConvertFrom-Form([string]$Text) {
        $map = @{}
        foreach ($pair in $Text.Split('&')) {
            if (-not $pair) { continue }
            $at = $pair.IndexOf('=')
            if ($at -lt 0) { $map[[Uri]::UnescapeDataString($pair)] = ''; continue }
            $map[[Uri]::UnescapeDataString($pair.Substring(0, $at))] = [Uri]::UnescapeDataString($pair.Substring($at + 1).Replace('+', ' '))
        }
        return $map
    }
    function New-Frame([object[]]$Events) {
        # Events: @(name, data) pairs, numbered from the stand-in's own counter.
        $entries = [Collections.Generic.List[object]]::new()
        foreach ($item in $Events) {
            $State.Aid++
            $body = [Collections.Generic.List[object]]::new()
            $body.Add($item[0])
            if ($item.Count -gt 1 -and $null -ne $item[1]) { $body.Add($item[1]) }
            $entries.Add([object[]]@($State.Aid, $body.ToArray()))
        }
        $text = $json.Serialize($entries.ToArray())
        return "$($text.Length)`n$text"
    }
    function Send-Chunk($Poll, [string]$Text) {
        $bytes = $utf8.GetBytes($Text)
        $head = $ascii.GetBytes(('{0:x}' -f $bytes.Length) + "`r`n")
        $Poll.Stream.Write($head, 0, $head.Length); $Poll.Stream.Write($bytes, 0, $bytes.Length)
        $tail = $ascii.GetBytes("`r`n"); $Poll.Stream.Write($tail, 0, 2); $Poll.Stream.Flush()
    }
    function Push-Events([object[]]$Events) {
        if ($Events.Count -eq 0) { return }
        $live = @($polls | Where-Object { $_.Sid -ceq $State.Sid })
        # Held (and numbered only when sent) until a stream is open.
        if ($live.Count -eq 0) { foreach ($e in $Events) { $null = $State.Backlog.Add($e) }; return }
        $frame = New-Frame $Events
        foreach ($poll in $live) { try { Send-Chunk $poll $frame } catch {} }
    }
    function Close-Polls {
        foreach ($poll in @($polls)) { try { Send-Raw $poll.Stream "0`r`n`r`n"; $poll.Client.Close() } catch {} }
        $polls.Clear()
    }

    while (-not $State.Quit) {
        # Events queued by the test, and stream closes it asked for.
        while ($State.Outbox.Count -gt 0) {
            $batch = $State.Outbox[0]; $State.Outbox.RemoveAt(0)
            Push-Events $batch
        }
        if ($State.ClosePolls) { $State.ClosePolls = $false; Close-Polls }
        if (-not $Listener.Pending()) { Start-Sleep -Milliseconds 5; continue }
        $client = $Listener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $stream.ReadTimeout = 5000
            $buffer = New-Object byte[] 65536
            $text = ''
            while ($text.IndexOf("`r`n`r`n") -lt 0) {
                $n = $stream.Read($buffer, 0, $buffer.Length); if ($n -le 0) { break }
                $text += $ascii.GetString($buffer, 0, $n)
            }
            $split = $text.IndexOf("`r`n`r`n")
            $head = $text.Substring(0, $split); $body = $text.Substring($split + 4)
            $lines = $head.Split("`n") | ForEach-Object { $_.TrimEnd("`r") }
            $first = $lines[0].Split(' ')
            $method = $first[0]; $target = $first[1]
            $headers = @{}
            foreach ($line in $lines | Select-Object -Skip 1) { $at = $line.IndexOf(':'); if ($at -gt 0) { $headers[$line.Substring(0, $at).Trim().ToLowerInvariant()] = $line.Substring($at + 1).Trim() } }
            $length = if ($headers.ContainsKey('content-length')) { [int]$headers['content-length'] } else { 0 }
            while ($utf8.GetByteCount($body) -lt $length) { $n = $stream.Read($buffer, 0, $buffer.Length); if ($n -le 0) { break }; $body += $ascii.GetString($buffer, 0, $n) }
            $path = $target; $query = @{}
            $q = $target.IndexOf('?'); if ($q -ge 0) { $path = $target.Substring(0, $q); $query = ConvertFrom-Form $target.Substring($q + 1) }
            $form = ConvertFrom-Form $body
            $token = if ($headers.ContainsKey('x-youtube-loungeid-token')) { $headers['x-youtube-loungeid-token'] } else { '' }
            $null = $State.Log.Add([pscustomobject]@{ Method = $method; Path = $path; Query = $query; Form = $form; Token = $token; Agent = $headers['user-agent']; At = [DateTime]::UtcNow })

            if ($path -ceq '/api/lounge/pairing/get_screen') {
                if ($form['pairing_code'] -ceq $State.Code) { Send-Reply $client 200 $json.Serialize(@{ screen = @{ screenId = $State.ScreenId; loungeToken = $State.Token; name = 'Stand-in TV'; expiration = 0 } }) 'application/json' }
                else { Send-Reply $client 404 'no' }
                continue
            }
            if ($path -ceq '/api/lounge/pairing/get_lounge_token_batch') {
                if ($form['screen_ids'] -cne $State.ScreenId -or $State.TokenStatus -ne 200) { Send-Reply $client $(if ($State.TokenStatus -ne 200) { $State.TokenStatus } else { 400 }) 'no'; continue }
                $State.Token = $State.NextToken
                Send-Reply $client 200 $json.Serialize(@{ screens = @(@{ screenId = $State.ScreenId; loungeToken = $State.Token }) }) 'application/json'
                continue
            }
            if ($path -ceq '/oembed') {
                $watch = [string]$query['url']
                $id = if ($watch -match 'v=([A-Za-z0-9_-]{11})$') { $Matches[1] } else { '' }
                $channel = if ($State.Channels.ContainsKey($id)) { $State.Channels[$id] } else { 'x' }
                if ($id -and $State.Titles.ContainsKey($id)) { Send-Reply $client 200 $json.Serialize(@{ title = $State.Titles[$id]; author_name = $channel }) 'application/json' }
                else { Send-Reply $client 404 'Not Found' }
                continue
            }
            if ($path -cmatch '\A/vi/([A-Za-z0-9_-]{11})/mqdefault\.jpg\z') {
                # Thumbnails: the test's made-up bytes, or 404.
                $id = $Matches[1]
                if ($State.Thumbs.ContainsKey($id)) {
                    $bytes = [byte[]]$State.Thumbs[$id]
                    $h = $ascii.GetBytes("HTTP/1.1 200 X`r`nContent-Type: image/jpeg`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n")
                    $s = $client.GetStream(); $s.Write($h, 0, $h.Length); $s.Write($bytes, 0, $bytes.Length); $s.Flush(); $client.Close()
                } else { Send-Reply $client 404 'Not Found' }
                continue
            }
            if ($path -cne '/api/lounge/bc/bind') { Send-Reply $client 404 'no'; continue }
            if ($method -eq 'POST' -and -not $query.ContainsKey('SID')) {
                # A new session.
                if ($State.BindStatus -ne 200) { Send-Reply $client $State.BindStatus 'no'; continue }
                if ($token -cne $State.Token -or $form['loungeIdToken'] -cne $State.Token) { Send-Reply $client 401 'Unauthorized'; continue }
                $State.Binds++
                Close-Polls
                $State.Sid = 'SID-' + $State.Binds
                $State.Backlog.Clear()
                $events = @(, @('c', $State.Sid)) + @(, @('S', ('GS-' + $State.Binds)))
                foreach ($e in $State.BindEvents) { $events += , $e }
                Send-Reply $client 200 (New-Frame $events)
                continue
            }
            if ($query['SID'] -cne $State.Sid) { Send-Reply $client 400 'Unknown SID'; continue }
            if ($method -eq 'GET') {
                if ($State.PollStatus -ne 200) { Send-Reply $client $State.PollStatus 'no'; continue }
                $State.Polls++
                Send-Raw $stream "HTTP/1.1 200 OK`r`nContent-Type: text/plain`r`nTransfer-Encoding: chunked`r`nConnection: close`r`n`r`n"
                $poll = [pscustomobject]@{ Client = $client; Stream = $stream; Sid = $State.Sid }
                $polls.Add($poll)
                if ($State.Backlog.Count -gt 0) { $backlog = @($State.Backlog); $State.Backlog.Clear(); Push-Events $backlog }
                $client = $null
                continue
            }
            if ($form['TYPE'] -ceq 'terminate') { $State.Leaves++; Send-Reply $client 200 'ok'; Close-Polls; $State.Sid = ''; continue }
            $command = [string]$form['req0__sc']
            $fields = @{}
            foreach ($key in @($form.Keys)) { if ($key -like 'req0_*' -and $key -cne 'req0__sc') { $fields[$key.Substring(5)] = $form[$key] } }
            $null = $State.Commands.Add([pscustomobject]@{ Name = $command; Sid = $query['SID']; Ofs = $form['ofs']; Rid = $query['RID']; Aid = $query['AID']; Fields = $fields })
            if ($State.CommandStatus -ne 200) { Send-Reply $client $State.CommandStatus 'no'; continue }
            Send-Reply $client 200 'ok'
            if ($State.Reactions.ContainsKey($command)) { Push-Events @($State.Reactions[$command]) }
        } catch {
            $null = $State.Errors.Add($_.Exception.Message)
        } finally {
            if ($null -ne $client) { try { $client.Close() } catch {} }
        }
    }
    Close-Polls
}

function Start-TvStandIn {
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $state = [hashtable]::Synchronized(@{
        Quit = $false; Port = $listener.LocalEndpoint.Port
        Code = '123456789012'; ScreenId = 'SCREEN-SECRET-0001'; Token = 'TOKEN-SECRET-A'; NextToken = 'TOKEN-SECRET-B'
        TokenStatus = 200; BindStatus = 200; PollStatus = 200; CommandStatus = 200
        Sid = ''; Aid = 0; Binds = 0; Polls = 0; Leaves = 0
        BindEvents = [Collections.ArrayList]::Synchronized([Collections.ArrayList]::new())
        Reactions = [hashtable]::Synchronized(@{})
        Titles = [hashtable]::Synchronized(@{})
        Channels = [hashtable]::Synchronized(@{})
        Thumbs = [hashtable]::Synchronized(@{})
        Outbox = [Collections.ArrayList]::Synchronized([Collections.ArrayList]::new())
        Backlog = [Collections.ArrayList]::Synchronized([Collections.ArrayList]::new())
        ClosePolls = $false
        Log = [Collections.ArrayList]::Synchronized([Collections.ArrayList]::new())
        Commands = [Collections.ArrayList]::Synchronized([Collections.ArrayList]::new())
        Errors = [Collections.ArrayList]::Synchronized([Collections.ArrayList]::new())
    })
    $shell = [PowerShell]::Create()
    $null = $shell.AddScript($script:TvStandInServer).AddArgument($state).AddArgument($listener)
    $handle = $shell.BeginInvoke()
    return [pscustomobject]@{ State = $state; Listener = $listener; Shell = $shell; Handle = $handle
        LoungeBase = "http://127.0.0.1:$($state.Port)/api/lounge"; TitleBase = "http://127.0.0.1:$($state.Port)/oembed" }
}

function Push-TvStandIn {
    # Queues events for the open stream: each item is @(name, data).
    param($StandIn, [object[]]$Events)
    $null = $StandIn.State.Outbox.Add(@($Events))
}

function Stop-TvStandIn {
    param($StandIn)
    $StandIn.State.Quit = $true
    try { $null = $StandIn.Handle.AsyncWaitHandle.WaitOne(3000) } catch {}
    try { $StandIn.Listener.Stop() } catch {}
    try { $StandIn.Shell.Dispose() } catch {}
}

# Developer-only: a stand-in Google Cast device for the offline cast tests,
# listening on 127.0.0.1 only, speaking the Cast v2 channel over TLS with a
# throwaway certificate made in memory (never added to any certificate store).
# All data is made up. Dot-source it, then:
#   $cast = Start-TvCastStandIn; ...; Stop-TvCastStandIn $cast
#requires -Version 5.1

$script:TvCastStandInServer = {
    param($State, $Listener, $Certificate, $Module)
    $ErrorActionPreference = 'Stop'
    Import-Module $Module -Force -DisableNameChecking
    Add-Type -AssemblyName System.Web.Extensions
    $json = [Web.Script.Serialization.JavaScriptSerializer]::new()
    $client = $null; $ssl = $null; $read = $null
    $bytes = New-Object byte[] 16384
    $buffer = [IO.MemoryStream]::new()
    function Send-Message([string]$Source, [string]$Namespace, $Body) {
        $frame = ConvertTo-CastFrame (ConvertTo-CastMessage $Source 'sender-0' $Namespace ($json.Serialize($Body)))
        $ssl.Write($frame, 0, $frame.Length); $ssl.Flush()
    }
    function Close-Client {
        if ($null -ne $ssl) { try { $ssl.Dispose() } catch {} }
        if ($null -ne $client) { try { $client.Close() } catch {} }
        $script:client = $null; $script:ssl = $null; $script:read = $null
        $buffer.SetLength(0)
    }
    while (-not $State.Quit) {
        try {
            if ($null -eq $client) {
                if (-not $Listener.Pending()) { Start-Sleep -Milliseconds 5; continue }
                $client = $Listener.AcceptTcpClient()
                $State.Connections++
                if ($State.Refuse) { $client.Close(); $client = $null; continue }
                $ssl = [Net.Security.SslStream]::new($client.GetStream(), $false)
                $ssl.AuthenticateAsServer($Certificate, $false, [Security.Authentication.SslProtocols]::Tls12, $false)
                $read = $ssl.ReadAsync($bytes, 0, $bytes.Length)
            }
            if ($State.Drop) { $State.Drop = $false; Close-Client; continue }
            while ($State.Push.Count -gt 0) {
                $item = $State.Push[0]; $State.Push.RemoveAt(0)
                Send-Message $item[0] $item[1] $item[2]
            }
            if (-not $read.Wait(10)) { continue }
            $count = $read.Result
            if ($count -le 0) { Close-Client; continue }
            $buffer.Write($bytes, 0, $count)
            $read = $ssl.ReadAsync($bytes, 0, $bytes.Length)
            foreach ($frame in (Read-CastFrames $buffer)) {
                $message = ConvertFrom-CastMessage $frame
                $body = $json.DeserializeObject($message.Payload)
                $type = [string]$body['type']
                $null = $State.Seen.Add([pscustomobject]@{ Namespace = $message.Namespace; Type = $type; Destination = $message.Destination; Source = $message.Source })
                $id = $body['requestId']
                switch -CaseSensitive ($type) {
                    'PING' { Send-Message $message.Destination $message.Namespace @{ type = 'PONG' } }
                    'GET_STATUS' {
                        if ($message.Namespace -ceq 'urn:x-cast:com.google.cast.receiver') {
                            Send-Message 'receiver-0' $message.Namespace @{ type = 'RECEIVER_STATUS'; requestId = $id; status = @{ applications = [object[]]@($State.Apps) } }
                        } elseif ($message.Namespace -ceq 'urn:x-cast:com.google.cast.media' -and $State.MediaAnswers) {
                            Send-Message $message.Destination $message.Namespace @{ type = 'MEDIA_STATUS'; requestId = $id; status = [object[]]@($State.Media) }
                        }
                    }
                    'getMdxSessionStatus' {
                        if ($State.CastScreen) { Send-Message $message.Destination $message.Namespace @{ type = 'mdxSessionStatus'; data = @{ screenId = $State.CastScreen; deviceId = 'SAMPLE' } } }
                    }
                }
            }
        } catch {
            $null = $State.Errors.Add($_.Exception.Message)
            Close-Client
        }
    }
    Close-Client
}

function New-TvCastYouTubeApp {
    param([string]$Session = 'session-1', [string]$Transport = 'transport-1')
    return @{ appId = '233637DE'; displayName = 'YouTube'; sessionId = $Session; transportId = $Transport
        namespaces = [object[]]@(@{ name = 'urn:x-cast:com.google.cast.media' }, @{ name = 'urn:x-cast:com.google.youtube.mdx' }) }
}

function Start-TvCastStandIn {
    $rsa = [Security.Cryptography.RSA]::Create(2048)
    $request = [Security.Cryptography.X509Certificates.CertificateRequest]::new('CN=sample-cast', $rsa, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $selfSigned = $request.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddDays(1))
    $pfx = [byte[]]$selfSigned.Export([Security.Cryptography.X509Certificates.X509ContentType]::Pfx, 'sample')
    $certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new($pfx, 'sample')
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $state = [hashtable]::Synchronized(@{
        Quit = $false; Port = $listener.LocalEndpoint.Port; Connections = 0; Refuse = $false; Drop = $false
        Apps = [Collections.ArrayList]::Synchronized([Collections.ArrayList]::new())
        Media = [Collections.ArrayList]::Synchronized([Collections.ArrayList]::new())
        MediaAnswers = $true; CastScreen = ''
        Push = [Collections.ArrayList]::Synchronized([Collections.ArrayList]::new())
        Seen = [Collections.ArrayList]::Synchronized([Collections.ArrayList]::new())
        Errors = [Collections.ArrayList]::Synchronized([Collections.ArrayList]::new())
    })
    $module = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\TvLounge.psm1'))
    $shell = [PowerShell]::Create()
    $null = $shell.AddScript($script:TvCastStandInServer).AddArgument($state).AddArgument($listener).AddArgument($certificate).AddArgument($module)
    $handle = $shell.BeginInvoke()
    return [pscustomobject]@{ State = $state; Listener = $listener; Shell = $shell; Handle = $handle; Certificate = $certificate; Rsa = $rsa
        Device = [pscustomobject]@{ Name = 'Sample Cast'; Id = 'sample1'; Address = '127.0.0.1'; Port = $state.Port } }
}

function Stop-TvCastStandIn {
    param($StandIn)
    $StandIn.State.Quit = $true
    try { $null = $StandIn.Handle.AsyncWaitHandle.WaitOne(3000) } catch {}
    try { $StandIn.Listener.Stop() } catch {}
    try { $StandIn.Shell.Dispose() } catch {}
    try { $StandIn.Certificate.Dispose(); $StandIn.Rsa.Dispose() } catch {}
}

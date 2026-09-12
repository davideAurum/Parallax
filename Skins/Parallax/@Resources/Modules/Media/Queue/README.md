# Optional Spotify queue

Implemented 2026-09-11. This original Parallax helper reads the next five Spotify
queue entries for the account you authorize. It preserves order and duplicates
and supports tracks and episodes. Playback controls remain with WebNowPlaying,
which may be displaying a different player. The queue helper cannot add, remove,
reorder, or play items.

## Connect your app

1. Open the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard),
   select your app, and open Settings / Edit Settings.
2. Add `http://127.0.0.1/callback` to Redirect URIs and save. Use the exact numeric
   address. Spotify permits a dynamic port for registered loopback addresses;
   `localhost` is not accepted.
3. Copy the public **Client ID**, not the client secret.
4. Hover the Media header, click its gear, then click **Sign in**. Enter the
   Client ID when prompted and approve read access on Spotify's browser page.
   The separate `Parallax\Media\Queue` panel also has a Sign in button.
5. Start playback in Spotify to populate its queue. After consent the helper
   starts in the background and Rainmeter reads its local cache.

The runtime is Windows PowerShell 5.1 with built-in .NET Framework. No Python,
downloaded executable, client secret, Rainmeter plugin, or service is needed for
the queue. WebNowPlaying is optional and separate. Managed computers may disallow
PowerShell scripts; the skin does not change system execution policy.

From the repository root (adjust the path for an installed skin):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\Skins\Parallax\@Resources\Modules\Media\Queue\QueueProvider.ps1' -Command Connect
```

The execution-policy argument applies only to this process. Sign-in opens a
browser and waits up to three minutes. It uses PKCE S256, random single-use state,
and a listener bound only to `127.0.0.1` on an ephemeral port. Callback host, path,
state, grammar, size, and deadline are validated; the listener closes before code
exchange. The only requested scope is `user-read-currently-playing`.

Sources: [Spotify apps](https://developer.spotify.com/documentation/web-api/concepts/apps),
[PKCE](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow),
[redirects](https://developer.spotify.com/documentation/web-api/concepts/redirect_uri),
[queue endpoint](https://developer.spotify.com/documentation/web-api/reference/get-queue),
[scopes](https://developer.spotify.com/documentation/web-api/concepts/scopes).

Development Mode requires owner Premium and allows five allowlisted users.
Spotify enforces app/account access and developer quota. HTTP403 does not identify
one definitive cause: check Premium, allowlisting, scopes, and dashboard access.
A package supplies no shared Client ID or guarantee of API access.
Source: [quota modes](https://developer.spotify.com/documentation/web-api/concepts/quota-modes).

## Display settings and expansion

Click **Queue +** at the bottom of Media or Setup to expand the queue beneath
the player; click **Queue -** to collapse it. This state is remembered, and
collapsing the section does not stop the helper.

The header gear opens Media settings: panel width, expanded/collapsed queue,
1/3/5 visible items, artist/show details, and polling interval presets of
30/60/120 seconds. Choices save immediately. Use **Restart** after changing the
poll interval; changing a display preference never launches a helper. The
separate queue panel remains available through **Open queue** in settings.
After adding this revision to an existing installation, use Rainmeter's
**Refresh all** once so it discovers the new settings config.

## Start, stop, and disconnect

**Start** launches one hidden background helper. A named mutex prevents another
worker for the same Windows user and data directory. Default polling is every 30
seconds; `-PollSeconds` accepts 30 through 150. Rainmeter reads its local snapshot
every second and never launches a process for polling.

**Stop** asks the helper to exit and clears rows after the in-flight request.
**Disconnect** in the context menu stops it, deletes local tokens, and replaces
the cache with an empty onboarding state. Public app configuration and retry
barriers remain. Access can also be revoked in Spotify account app settings.
Closing the skin alone does not stop the helper; use Stop when finished. There
is no automatic startup task, service, or change to live Rainmeter settings.

CLI commands: `Help`, `Configure`, `Connect`, `Start`, `Run`, `Stop`,
`Disconnect`, `Restart`. `Run -Once` makes at most one cycle subject to saved waits.
HTTP401 gets exactly one forced token refresh and one queue retry, then pauses
if still unauthorized. Returned token scopes may be a superset of the requested
permission; the required scope must still be present. Refresh tokens rotate or are retained as specified by
Spotify. The six-month refresh deadline remains tied to original authorization.
Source: [refreshing tokens](https://developer.spotify.com/documentation/web-api/tutorials/refreshing-tokens).

HTTP429 waits survive restarts and sign-in attempts. `Retry-After` accepts seconds
or an HTTP date; absent/invalid values use 30-second exponential backoff capped at
five minutes. `QUOTA_EXCEEDED` pauses without inventing a reset date. After
resolving quota, use **Retry after resolving quota** or `-ResumeAfterQuota` with
Start, Run, or Connect. This never overrides a future server Retry-After.
Source: [rate limits](https://developer.spotify.com/documentation/web-api/concepts/rate-limits).

## Status and freshness

| Status | Meaning / next step |
| --- | --- |
| Setup required | Configure and sign in. Missing data is unavailable, not empty. |
| Connecting | Finish browser consent within three minutes. |
| Sign in again | Authorization expired, was revoked, or was not granted. |
| Access denied | Check app/account access; HTTP403 is ambiguous. |
| Rate limited | Wait for Spotify's retry time. |
| App quota reached | Resolve quota, then explicitly retry. |
| Offline / Spotify unavailable | The request failed; transient retries use backoff. |
| Queue unavailable | Malformed response/cache or another local error. |
| Provider stopped | Click Start to resume. |
| Queue stale | Start or reconnect the helper. Expired rows are hidden. |
| Next N / Queue empty | A validated, unexpired response with N displayed entries or no entries. |

Unavailable states suppress rows. A successful snapshot lasts 90 seconds at the
default cadence; twice the poll interval is clamped to 90–300 seconds. After a crash, the
reader hides it at expiry even if the writer cannot publish an error. Clock
rollback more than five seconds behind the observation also rejects the cache.
Rows clip title and artist/show to one line; double width provides more space.

## Storage and data boundary

Runtime files stay outside skins in `%LOCALAPPDATA%\Parallax\Media\Spotify\`:

- `client.json`: public Client ID only.
- `tokens.dpapi`: tokens encrypted for the current Windows user.
- `queue.snapshot`: up to five titles and artists/shows, status, and expiry.
- `queue.retry.json`: retry time and quota pause.
- `auth.lock`, `stop.request`: coordination.

The directory uses a current-user-only ACL. Storage rejects reparse paths and
unsafe profile/skin roots. Atomic replacement keeps no plaintext token backup.
Tokens and raw service errors are never printed or written into the display
cache. DPAPI protects stored data for this Windows user; it does not isolate it
from other software running as that user.
Source: [Windows DPAPI](https://learn.microsoft.com/en-us/windows/win32/api/dpapi/nf-dpapi-cryptprotectdata).

The reader accepts only bounded inert ASCII `PARALLAX_QUEUE_V2`: header; state,
observed, valid_until, retry_not_before, count; and exactly five titleN/detailN
pairs encoded as UTF-8 hex. Unused fields are empty. Nonready states contain no
rows or observation/expiry. Unknown/duplicate keys, invalid Unicode, oversized
files/fields, and invalid timestamps are rejected. Limits: 32KiB snapshot,
512 UTF-8 bytes per title/detail, 1MiB API JSON, depth 24. Metadata is never
interpreted as INI, Lua, actions, or URLs. Controls and bidi characters are filtered;
Rainmeter metacharacters are neutralized before literal meter text is set.

## Developer validation and packaging

Run these developer tests with Windows PowerShell 5.1 from this folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\tests\Test-QueueAuth.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\tests\Test-QueueCore.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\tests\Test-QueueProvider.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\tests\Test-QueueReader.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\tests\Test-QueueView.ps1'
```

Auth tests need normal-user DPAPI; restricted sandboxes can prevent DPAPI itself
from working. All fixtures are synthetic, stored in isolated temporary folders.
Native reader/view tests use an existing Rainmeter installation and their own
absolute config, skin copy, and process; live skins are not altered.

On 2026-09-11, auth passed 63 cases, core passed 59 assertions, and provider passed 68
assertions. Coverage includes callback rejection/replay/deadline, token rotation,
six-month expiry, corruption/ACL/reparse checks, malformed JSON, duplicates,
episodes, scopes/401/403/429, persisted waits, duplicate worker prevention, stop
during a response, disconnect cleanup, restart cadence and server waits received
during Stop. See the module report for native view
checks. Synthetic tests do not prove Spotify entitlement, real HTTP behavior,
cross-user DPAPI isolation, mixed-DPI rendering, or steady-state CPU/memory cost.

Packaging needs exactly three script exceptions in this directory:
`QueueProvider.ps1`, `QueueCore.psm1`, `QueueAuth.psm1`. The Lua reader, include,
and Queue.ini are normal runtime assets. Exclude all tests/ descendants and
developer fixtures. Never package runtime settings, tokens, snapshots, retries,
or listening data. Shared packaging and release decisions belong to the root
coordinating task. No ModernGadgets code/assets were imported.


The Lua reader must retain its UTF-16LE BOM: Rainmeter 4.5 uses it to enable
Unicode Lua API strings. Native validation passed 1,804 reader assertions in
22 scenarios. The initial UI baseline passed 4,120 checks over 20 Queue layouts
and 6,506 Media settings assertions. The later shared typography revision uses
18-pixel queue rows and the selected body font without reducing its size; its
focused standalone Queue pass adds 845 assertions over four default/maximum-font
layouts, with independent colors and zero/four-pixel divider/border thickness.
Synthetic captures verify glyphs and intentional clipping of long metadata.
See the module report for the final shared appearance checks and evidence paths.
The callback handler ignores bounded OAuth extension parameters while retaining state,
code/error, duplicate, and request-size checks, as required by
[OAuth 2.0 section 4.1.2](https://www.rfc-editor.org/rfc/rfc6749#section-4.1.2).


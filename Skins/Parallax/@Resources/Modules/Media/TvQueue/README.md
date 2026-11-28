# Optional TV queue (YouTube on the TV)

Media's drawer reads the snapshot (`QueueReader.lua`). Loading Media's player resumes a worker you started earlier and did not stop. Pair, Start, Stop and Forget are on the Connections panel's TV row (`docs/CONNECTIONS.md`), or run from Windows PowerShell (below). Nothing touches the network until a TV is paired or the worker is started.

Media's queue drawer is to show the up next of YouTube playing in the **TV's own
app**, Mixes included. The TV is reached through YouTube's unofficial Lounge
remote-control API, paired by the TV's **Link with TV code**. The API is
undocumented and can change without notice; everything read is parsed
defensively and shown as an honest state when it is missing. A Chrome cast is
a different screen and gives no up next.

Written for Parallax from protocol facts: [what early live tests showed](#what-early-live-tests-showed)
and the [sources](#sources). No code from GPL projects (pyytlounge).

## Files

| File | What it does |
|---|---|
| `TvLounge.psm1` | Protocol: stream framing, session ids, request shapes, merging partial events into one player picture, up next from the id list, HTTP and the long poll. Import touches nothing. |
| `TvStore.psm1` | Disk: the private data folder, the DPAPI-sealed pairing, the snapshot, the request file, control files and the opt-in diagnostics log. Import touches nothing. |
| `TvProvider.ps1` | The opt-in worker and its commands (below). One long-lived process holds one remote session for both the TV's events and the commands sent to it. |
| `tests/` | Offline tests and a stand-in server on 127.0.0.1. Never packaged. |

Runtime: Windows PowerShell 5.1 and the .NET Framework that comes with Windows.
No downloads, plugins or helpers.

## Data

Everything is in `%LOCALAPPDATA%\Parallax\Media\YouTube`, a folder only the
current Windows user can open (protected DACL, owner-only, no links along the
path, never inside a skin folder):

- `pairing.dpapi`: the TV's name, screen id and token, sealed together with
  DPAPI for this Windows account. The screen id and token can control the TV.
  They are never written anywhere else, logged or put in a snapshot.
- `tv.snapshot`: what Media's reader shows (format below). Titles only, no ids.
- `tv.request`: one pending request from a control process to the worker.
- `tv.cover1.jpg`, `tv.cover2.jpg`: the current video's thumbnail from YouTube's
  public thumbnail host (`i.ytimg.com/vi/<id>/mqdefault.jpg`), JPEG-checked, at
  most 256 KB, written to the slot not shown so a reader never sees half a file.
  Only the current video's; removed by Forget, Stop and a clean worker end.
- `enabled.intent`, `stop.request`, `launch.id`: worker lifecycle. `worker.stamp`,
  `upgrade.marker`: which code a running worker is from ([Updates](#updates)).
- `cast.intent`, `cast.dpapi`, `cast.status`: casts ([Casts](#casts-opt-in-stage-3-lane-tv-cast-link)): the switch,
  the sealed cast key, the state Connections shows.
- `events.log` (and `events.old.log`): only with diagnostics switched on. Event
  and field names, state numbers, list lengths and HTTP statuses; no ids,
  titles, tokens or addresses.

## Up next

The TV's `nowPlaying` event carries `mdxExpandedReceiverVideoIdList`, a list of
video ids including the current one; up next is what follows the current video
in it, at most 20 rows. The latest list always wins: a Mix's list grows (25 or 50,
then about 100) and its next entry can change while it settles. A list of only the
current video (seen once live) or one without the current video is **not known
yet**, never an empty queue. The last listed video has nothing listed after it.

Events are partial: `onStateChange` has no video id, some `nowPlaying` events
carry only a list id, and the duration is 0 while loading. Each event changes only
what it carries. Player states seen live: 3 loading, 1 playing, 2 paused, 0 the
end of a video (not buffering), -1 around starts and reconnects.

## Snapshot `PARALLAX_TV_V1`

ASCII lines, `key=value`, in this order: `state`, `observed`, `valid_until`,
`retry_at`, `play`, `position_ms`, `position_at_ms`, `duration_ms`, `upnext`,
`list`, `total`, `count`, `notice`, `current_title`, `current_channel`, `cover`,
then `title1`..`titleN` (N = count, at most 20). `current_channel` (hex, from
oEmbed's author name) and `cover` (`1`, `2` or empty: the thumbnail slot) were
added in stage 3; the reader also takes a snapshot without them, from a worker
started before an update. `source` (`tv` or `cast` while ready, else empty) follows
`cover` since the cast lane; a snapshot without it is the TV's own app.

- `state`: `not_paired`, `connecting`, `ready`, `no_screen` (the TV's YouTube app
  is not in the session: off or closed), `offline`, `pair_again`, `error`,
  `stopped`. Only `ready` carries anything about what plays.
- `observed`: unix seconds when the rows were read; a row is named by its number
  and this time. `valid_until`: the worker rewrites the snapshot at least this
  often; later than this the worker is gone.
- `play`: `playing`, `paused`, `loading`, `ended`, `idle`, `cued`, `ad`,
  `unknown`. The position is `position_ms` at `position_at_ms` (unix ms);
  a reader advances it itself while playing.
- `upnext`: `known` (rows follow), `unknown` (not known yet), `end` (nothing listed
  after the current video), `none` (nothing loaded). `list`: `list` when the TV names the list it plays from, else
  `none`. It never says Mix or playlist: the list id does not tell them apart (a Mix in the live gate had an id the `RD` prefix rule reads as a playlist). `total`: entries after the current one.
- `notice`: outcome of the last request, shown once: `sent` (YouTube accepted it,
  which is not proof the TV obeyed), `failed`, `queue_changed`, `not_connected`.
- Titles are UTF-8 as hex. An empty title is not known (yet).

## Requests

`tv.request` holds `PARALLAX_TV_REQUEST_V1|<kind>|<row>|<observed>|<created>`:
`refresh`, `pause`, `play`, `next`, or `jump` with a row and the snapshot's
observed time. It is consumed once and dropped when older than 15 seconds. A
request is sent once and never resent.

## Worker

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\TvProvider.ps1 -Command Pair
```

- `Pair [-Code n] [-NoStart] [-Diagnostics]`: sends the code from the TV's
  **Link with TV code** to YouTube, seals the answer, and starts the worker.
- `Start [-Diagnostics]`, `Stop`: the user's switch. Stop leaves a barrier that
  `Resume` (Media's player loading) never lifts.
- `Resume`: starts the worker only when the user started it before, it was not
  stopped, and a TV is paired. Otherwise it reads nothing and creates nothing.
- `Forget`: stops the worker and removes the pairing and diagnostics.
- `Send -Action refresh|pause|play|next` or `-Action jump -Row n -Observed t`:
  hands one request to the running worker; no network of its own.
- `Status`: states and counts only.
- `CastOn`, `CastOff`, `CastForget`: the Casts switch ([below](#casts-opt-in-stage-3-lane-tv-cast-link)).

The worker binds a session (renewing a refused token once, then asking to pair
again), asks what is playing (`getNowPlaying`, which changes nothing), and keeps
one long poll open, stepping every quarter second to take requests and notice
Stop. Commands go on that same session, once each. When the screen leaves
(`loungeScreenDisconnected`) it rejoins after at least 10 s; failures in a row
wait 5, 10, 20 ... up to 300 s. Titles come from public oEmbed, one lookup per
pass, only for the current video and the shown rows, remembered in memory only.
A worker started from Rainmeter exits with it (`ProviderOwner.psm1`); one started from a shell runs until Stop. It never
launches a process to poll.

A jump sends `setPlaylist` with the clicked video, its index in the TV's list,
and the list id when known, otherwise the id list itself. In the live gate (2026-11-27, one TV, a Mix) the TV obeyed and the list kept its order after the jump.


## Casts (opt-in, stage 3, lane tv-cast-link)

A cast from Chrome plays on the TV under a different screen from the one paired by
code, and the casting tab goes stale (live try, 2026-11-27). With **Connections >
Casts > Turn on** (`-Command CastOn`) the worker also follows a cast directly on
the TV. Off by default: nothing below runs, is sent or is stored before that.

- **Finding the TV.** mDNS (`_googlecast._tcp.local`, one question per private
  IPv4 network, answers collected for 3 s without blocking the worker); again
  after 30 s, 60 s, 120 s, then every 5 min while none is found, and every 15 min
  when nothing is followed; a device that is found but keeps refusing makes the
  wait grow the same way. Only private (10/8, 172.16/12, 192.168/16) and
  link-local (169.254/16) addresses are ever connected to. At most 4 devices.
- **Which device.** The one whose Cast name equals the TV-code pairing's name, if
  exactly one does; otherwise the single device running YouTube. Two or more
  running YouTube: state `several`, none followed, no key asked.
- **The Cast channel** (`Open-CastLink`, TLS on the device's port, normally 8009):
  one long-lived connection per device, a PING after 5 s of silence, PONG to the
  device's PING, receiver status every 20 s, media status every 5 s while
  following (and whatever the device pushes). Only `CONNECT`, `GET_STATUS`,
  `PING`, `PONG` and `getMdxSessionStatus` can be sent (`Send-CastJson` refuses
  anything else): nothing launches an app, plays, pauses or changes the volume
  over Cast.
- **Certificate risk.** Cast devices present a self-signed certificate. The
  worker accepts the device's certificate for that one `SslStream` only (never
  `ServicePointManager`, so every HTTPS request to YouTube keeps its full checks).
  The channel is encrypted but the device is not authenticated: another device
  on the home network that answers mDNS as a Cast device could read the few
  messages above and report a false status or screen id. It would get no
  credential (none is ever sent to a device); at worst the card shows its false
  status and play/pause/next go to the screen it named.
- **The cast key.** Once per cast session the worker asks the running YouTube cast
  app for its screen id (`getMdxSessionStatus`). The same screen as the TV-code
  pairing means the TV's own app (state `tv_app`), left to the TV session. A new
  screen is stored sealed (`cast.dpapi`, own DPAPI entropy); its Lounge token is
  asked of YouTube (`get_lounge_token_batch`) only at the first command.
- **Commands.** While the snapshot shows the cast, `pause`, `play` and `next` from
  `tv.request` bind a Lounge session with the cast key, send the command once and
  leave (this route was obeyed in an early live test). A refused key is asked for again from
  the cast app; the command is not resent. `jump` says `queue_changed`, `refresh`
  asks the TV for its media status.
- **On the card.** A followed cast counts as the TV (`QueueReader.castView`), with or
  without a casting tab here, so a cast from a phone to this TV shows too; the stale
  casting tab (YouTube here not itself playing) never wins over it.
- **Snapshot.** `source=cast`, `upnext=unknown`, no rows; title and channel from the
  TV's media status (oEmbed only when missing), the thumbnail as for the TV app.
  When the cast ends, the snapshot shows the TV session again at once.
- **Switch and Forget.** `CastOn` saves `cast.intent`, sets the worker's intent and
  starts it (lifting a Stop); a running worker picks the switch up within 2 s.
  `CastOff` clears it (and stops the worker if no TV is paired by code).
  `CastForget` does the same and removes `cast.intent`, `cast.dpapi` and
  `cast.status`; the TV's `Forget` removes them too. Switched off, the worker
  closes every Cast channel, drops the key from memory and writes no cast state.
  It saves a key (a new screen id, a token, a renewal) only while the switch is
  on, checked under the control lock those commands hold while they remove it.
- **cast.status** (`PARALLAX_TV_CASTSTATE_V1|<state>|<valid_until>`) for Connections:
  `off`, `searching`, `no_device`, `several`, `waiting`, `following`, `tv_app`,
  `no_key`, `error`. Fixed words only.

## Updates

A worker writes `worker.stamp`, a hash of its four code files, when it starts.
`Resume` (Media's player loading) compares a running worker's stamp with the files
on disk; a different stamp, or none (a worker from before stamps), starts a new
worker with `-Takeover` and returns at once. That worker asks the old one to stop
(`stop.request`), waits for it (at most 2 min), clears the request when the user's
switch is still on and then runs; a Stop pressed meanwhile keeps its barrier. So a
Resume cut off by its host's timeout leaves nothing half done. Once per code stamp
(`upgrade.marker`), so it never loops, and only when the switch is on and Stop was
not pressed. `Start` leaves a running worker alone. A restarted worker runs without
`-Diagnostics`.

## In Media's drawer

`Queue\QueueReader.lua` reads `tv.snapshot` in Media.ini's drawer only
(`TvQueue=1` in `Common.inc`; Setup and the standalone Queue never do):

- **The drawer follows the player card** (stage 3, `QueueReader.screen`): this PC
  while it plays; else a TV that plays; else whichever was shown last. On this PC:
  Spotify's queue as before, *Up next is not available while casting* for a Chrome
  tab casting to the TV, and *YouTube up next is not available yet* for other
  YouTube playback (a player name containing YouTube).
- When the card shows the TV (a ready, unexpired snapshot with something loaded),
  the rows are the TV's up next. The note says *On the TV* (or *TV 1-5 of
  N* while scrolling); untitled rows say *Title unavailable*. A list not known yet,
  and the last listed video, are one line each. Any other TV state leaves the drawer
  as it was.
- No Mix or playlist label: the list id does not tell them apart.
- The Playlists tab stays (stage 3, M5); opened while the rows are YouTube's or the
  TV's it says *Playlists are not supported for YouTube yet* inside the tab, and no
  playlists or playlist-start request is sent. A change of source returns to the
  queue view.
- A row click writes `tv.request` (`jump`, the row's place and the snapshot's
  observed time); the row says *Starting* until new rows or a notice arrive. The
  Refresh icon writes `refresh`. The worker sends the command; the reader never
  launches anything.

## On Media's player card (stage 3)

`MeasureTvCard` (`TvCard.inc`) is a second instance of `QueueReader.lua` with
`TvCard=1`: it reads `tv.snapshot` and the player's measures, applies the rule
above and packs the screen, play state, title, channel, thumbnail path, time and
progress for the `TvField.lua` measures. It writes nothing. The card's play/pause
and next call the drawer reader's `TvControl`, which writes `pause`, `play` or
`next` to `tv.request` once, only while the card shows a ready TV. There is no
previous command. See the Media module doc, *Player card on the TV*.

## Tests

From this folder, with Windows PowerShell 5.1 as a normal user:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-TvCore.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-TvWorker.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-TvLua.ps1      # drawer, Connections TV controller, resume; needs an installed Rainmeter, runs its own isolated instance
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-TvUpgrade.ps1  # restart after an update
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-TvCastCore.ps1 # cast core against a TLS stand-in device
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-TvCastWorker.ps1 # following a cast
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-TvCastLua.ps1  # reader cast rule, Connections' Casts row; isolated Rainmeter
```

All data is made up; HTTP and the Cast channel go only to stand-ins on 127.0.0.1, and discovery returns the stand-ins (no mDNS packet is sent). The tests do not
show that the real API behaves the same: that takes a live check on a real TV.

## What early live tests showed

Read-only and command tests of 2026-11-27, before the worker was written, against
one smart TV. One short run on one device says nothing certain about other TVs or
app versions.

**The TV's own app (TV-code pairing).**

- Events carry the video id, state, position and duration, never a title; titles
  come from oEmbed. Pause, resume, seek and a skip made on the TV were reported.
  No regular position updates were seen.
- The screen left the session several times while the TV was in use and could be
  joined again. Causes unknown.
- During a Chrome cast this pairing sees nothing: the paired screen disconnects.
- Starting a Mix (`setPlaylist` with the list and a video id), `pause` and `next`
  were obeyed.
- A command sent from a second connection left the listening one without events.
  The cause is a guess; it is why the worker sends on the session it listens on.
- One list reading held only the current video, about a minute after a Mix was
  started by command.

**A Chrome cast.**

- Cast status on the local network gives player state, position, duration, video
  id, title, artwork and the current index, but no queue items.
- A session with the screen id asked from the cast app reports video, state,
  position and duration, and obeyed `setPlaylist` (with a video id), `next`,
  `pause` and `play`. It sends no list of ids, so there is no up next.
- The casting Chrome page's list is not a substitute: the page and the TV drifted
  apart, and the TV then played something other than the listed next entry.

**Not tried:** a Cast speaker or display; `setPlaylist` with a list id alone;
private playlists, shuffle and loop; queue edits from a phone; whether a cast key
survives a new cast or a TV restart; how long a pairing or token lasts.

## Sources

The code is original. These were read for protocol facts only (endpoint,
parameter, field and message names); no code was copied.

| Source | License | Used for |
|---|---|---|
| [pyytlounge](https://github.com/FabioGNR/pyytlounge) (`wrapper.py`, `events.py`, `models.py`) | GPL-3.0 | Pairing, bind, long poll, framing, commands, event fields, state numbers |
| [casttube](https://github.com/ur1katz/casttube) | MIT | Token request, bind, `setPlaylist` fields |
| [yt-cast-receiver](https://github.com/patrickkfkan/yt-cast-receiver) (`Message.ts`, `Playlist.ts`) | MIT per its README; GitHub detects no license file | What a screen sends and reads |
| [pychromecast](https://github.com/home-assistant-libs/pychromecast) (`controllers/youtube.py`) | MIT | `getMdxSessionStatus`, `mdxSessionStatus`, where `screenId` sits |
| [node-castv2](https://github.com/thibauts/node-castv2) README | MIT | Cast framing, `CastMessage` fields |
| [Cast media messages](https://developers.google.com/cast/docs/media/messages) | Google developer documentation | `GET_STATUS`, media status |
| RFC 6762 / 6763 | IETF | mDNS query and records |

pyytlounge is GPL-3.0: later work on this protocol must likewise be written
independently of its code.

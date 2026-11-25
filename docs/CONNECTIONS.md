# Connections panel

## Dependencies

Inherit the [shared platform and bundling requirements](DEPENDENCIES.md#shared-requirements). Keep this table current when the panel changes its implementation.

| Component | Classification | Feature, lifecycle and unavailable behavior |
| --- | --- | --- |
| Rainmeter Script/Lua and native Shape/String/Image meters; shared Parallax includes; `Connections.ini`, `Modules/Connections/Connections.lua` | Required; supplied by Rainmeter or bundled | Draws the panel and reads its states every 2 s while it is open. No preference file: it saves nothing. Missing source is an incomplete installation. |
| Rainmeter's built-in Process and Registry measures | Required for the HWiNFO row; supplied by Rainmeter | Is `HWiNFO64.exe` running, and do `HKCU`/`HKLM\SOFTWARE\HWiNFO64\VSB` list a sensor. Read every 10 s; nothing is installed. Not running reads `Not running`. |
| Media's optional Spotify helpers ([Media](modules/Media.md#dependencies)) | Optional | Their status files in `%LOCALAPPDATA%\Parallax\Media` are read; the queue helper's own `Connect` and `Disconnect` commands run on a click. Without them the rows read `Not set up` and `Off`. |
| Rainmeter's standard RunCommand plugin; Windows PowerShell 5.1 | Required for Disconnect and Sign in only; host/Windows components | One hidden launch per confirmed Disconnect; Sign in opens the helper's own console. If blocked, neither completes and the saved sign-in is unchanged. |
| WebNowPlaying plugin 2.0.7.0 | Optional; bundled in the `.rmskin` | Only whether `Plugins\WebNowPlaying.dll` exists, looked up once per load. The plugin is not loaded here. |
| IBM Plex Sans fonts | Bundled, skin-local; SIL OFL 1.1 | Panel typography. |

The panel uses no network, account or third-party plugin of its own. Help opens the bundled queue guide, and Setup guide opens WebNowPlaying's page in the browser.

## What it is for

User request, 2026-11-25: one place, reached from Global Settings, for what Parallax connects to. Spotify is the only account. The rest (Spotify detection, WebNowPlaying, HWiNFO, the update check) needs no sign-in, so the panel is named Connections rather than Accounts.

`Parallax\Connections\Connections.ini` is its own small panel (two columns, 318 logical px: 456 × 326 at the default size) because Global Settings is already 997 px tall, which fills a 1080-pixel screen at 100%. It opens from **Connections** beside Global Settings' layout summary or in its context menu, from **Spotify sign-in: Connections** in Media settings, and from the queue drawer where it asks for a sign-in ([Media](modules/Media.md#never-started-helpers)). The first time, it opens near the middle of the primary screen; Rainmeter remembers where it is moved. The cross closes only this panel.

## Accounts

| Spotify row | Means |
| --- | --- |
| `Not set up` | No app ID and no sign-in is saved. The line below says the queue is experimental and needs Spotify Premium; Help explains how to make the app. |
| `Not signed in` | An app ID is saved, or the last sign-in did not finish. |
| `Signing in` | The helper waits for the browser, for up to 200 s; after that the console was closed and it reads `Not signed in` or `Sign in again`. |
| `Signed in` | A sign-in is saved. Green while the queue helper reads; the line below names what it may do, or why nothing is read (helper off, offline, rate limited, quota). |
| `Sign in again` | Spotify needs a new sign-in, or it lacks playback control or playlists, which the line names. |
| `Access denied` | Spotify refused the account or app. |

- **What the line can know.** Playback control comes from the queue status. Playlists are read only when Media's Playlists view is opened, so until then it says `Playlists not checked yet` instead of guessing.
- **Sign in** / **Sign in again** runs the queue helper's `Connect` in a visible console with Media's saved polling interval, read again as the button goes down. It stops the queue until the sign-in completes, as it always has.
- **Disconnect** shows only while a sign-in is saved. The first click turns it into `Disconnect?` for 8 s; a second click runs the helper's `Disconnect` hidden and the status line says whether the sign-in is gone. Spotify keeps listing the app until you remove it in Spotify's own account settings.

Sign in and Disconnect were in Media settings until 2026-11-25; Start, Stop and Restart stay there, since they run Media's helper rather than manage the account. The standalone Queue keeps its own Sign in button and Disconnect context action. Where the sign-in is stored did not change, so nobody has to sign in again.

## On this PC

| Row | States |
| --- | --- |
| Spotify detection | `On` while its status is live; `Not running` when it is meant to run but is not; `Unavailable`; `Off` (stopped or never started). |
| WebNowPlaying | `Plugin installed` or `Plugin missing`. Whether a player is connected is Media's to show. |
| HWiNFO | `Running`, `Open Sensors` (running, but nothing is exported, which a closed Sensors window causes) or `Not running`. A frozen export is not detected here; CPU Meter detects it after a minute. |
| Update check | `Daily, GitHub`, `Off` or `Custom`, as saved in Global Settings; a change there reloads this panel. The developer copy is made with its own check off and reads `Off in this copy` (2026-11-25; it read `Off`, which looked like a contradiction beside the release's Global Settings). |

## Data boundary

`Connections.lua` opens files for reading only: whether `tokens.dpapi` and `client.json` exist (never what is in them), at most the first 1024 bytes of `queue.snapshot`, `playlists.snapshot` and `source.snapshot`, `enabled.intent`, and `User\Media.inc` for the interval. Only the state, time and permission fields of a status file are used. Those first bytes can include encoded track or playlist names, which are never decoded or shown; every text it shows is a fixed string. An unknown format, state or repeated field is not interpreted. Nothing is written.

## Validation report

2026-11-25, Surface laptop, Rainmeter 4.5.28.3936.

- `Modules/Connections/tests/Test-Connections.ps1` (isolated Rainmeter, synthetic `LOCALAPPDATA`): 176 mocked assertions covering every helper state, unusable files, sign-in in progress and abandoned, the two-click Disconnect and its failures, the interval, and the allowlists of files, bangs and launches; the real panel against synthetic status files, and a changed Auto check shown after the suite refresh Global Settings makes; and the width of every text it can show, at width 220 / 9 pt and width 180 / 10 pt, the latter also at 75%. The fullest text uses 79%, 88% and 89% of its space. No log errors or warnings.
- In the developer copy on the live desktop: the panel showed the real state (`Signed in`, queue, playback control and playlists; detection on; plugin installed; HWiNFO running), and one Disconnect click asked and lapsed after 8 s with the sign-in still saved.
- Media's and Global Settings' affected checks are in [Media.md](modules/Media.md#connections-panel-2026-11-25) and [SETTINGS.md](SETTINGS.md#connections).
- **Real Disconnect and Sign in (2026-11-25).** The owner clicked both in the developer copy's panel and said they worked; the status files were watched, not the tokens. Disconnect (01:54:41): the saved sign-in and the playlist list gone, the queue status `onboarding_required`. Sign in: `connecting` at 01:55:13, sign-in saved at 01:55:19, queue `ready` with playback control at 01:55:24, and the helper polling a minute later.

Not verified: physical clicks on the links, the panel's own wording during that sign-in, the playlists permission after it, the rows for a machine without HWiNFO or the plugin on a live desktop, mixed DPI, and the first-open position on several monitors.

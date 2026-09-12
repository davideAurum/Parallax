# Media module prototype — layered player, settings and queue

Implemented 2026-09-11 within the Media-owned paths. This is an original Parallax
implementation. No ModernGadgets code or assets were used, and no plugins,
dependencies, live Rainmeter settings, or releases were changed by
this module task. Spotify sign-in is now an explicit user-authorized option.
The authorized revision follows `docs/APPEARANCE.md` revision 2:
the [ModernGadgets preview](https://raw.githubusercontent.com/raiguard/ModernGadgets/master/Wiki/preview.png)
and [stylesheet](https://github.com/raiguard/ModernGadgets/blob/master/Skins/ModernGadgets/%40Resources/StyleSheet.inc)
were inspected for density and hierarchy; the meters and note icon are original.

## Delivered

- `Skins/Parallax/Media/Setup.ini`: dependency-free onboarding and fallback.
- `Skins/Parallax/Media/Media.ini`: optional WebNowPlaying player with title,
  artist, album, player name, cover, reported position/duration, and progress.
- Previous, play/pause, and next controls use WNP capability measures. Unsupported
  controls appear muted, explain why in tooltips, and send no command. Lua checks
  connection/support again when clicked. Compact `|<`, `>` / `||`, and `>|`
  symbols retain descriptive tooltips; play/pause reflects the provider state.
- Standard and double player/queue widths share one persistent `Columns` setting.
  These variants use the suite include order, `Group=Parallax`, settings context action,
  fixed bounds, scaled geometry, and transparent snap gutters. Every rendered
  meter declares `Meter`; styles do not. Local button padding is zero so the
  shared style's padding cannot expand the declared hit area.
- `Skins/Parallax/Media/Queue/Queue.ini`: optional Spotify queue with five compact
  rows, state/freshness handling, and explicit Sign in / Start / Stop actions.
- A native Windows PowerShell 5.1 helper provides public-client PKCE sign-in,
  current-user DPAPI token storage, one background polling process, and an inert
  local snapshot. No client secret or external dependency is needed.
- Media and Setup show queue status through a passive Lua reader. Their Queue
  row expands/collapses an inline section below the player and remembers that
  choice. Expansion adjusts the window height; it does not start/stop Spotify.
- A hover gear in Media, Setup and the separate Queue panel opens
  `Media/Settings/Settings.ini`. This independent two-pitch panel controls
  width, queue expansion, visible item count, artist/show details, polling
  interval and explicit Spotify connection actions.
- An optional local Windows media-session observer identifies Spotify desktop
  when exactly one session matches the current WNP title, raw artist and state.
  Start/Stop controls live in Media settings; Spotify sign-in is unnecessary.
- At two columns, a 144-pixel album tile overhangs the left side of a narrower
  panel. Track details, progress and the entire inline queue share a right column.
  The composition retains the suite's double-width snapping bounds.

## Load and configure

1. Start with `Parallax\Media`, `Setup.ini` in Rainmeter Manage. This variant has
   no external plugin measures. Its passive Lua reader reads only the queue's local
   display cache. It does not probe, install, or load WNP.
2. If desired, manually install the [official WebNowPlaying Rainmeter plugin](https://wnp.keifufu.dev/rainmeter/getting-started), version 2.x or newer.
   Its setup guide includes the plugin's example skin for connection testing.
3. Open a supported player, then choose **Load player**. WNP supports Spotify
   Desktop without Spicetify; browser playback needs its browser extension.
   WNP's desktop integration uses Windows media sessions and supports only the
   capabilities exposed by each player. Desktop support is normally enabled.
   Sources: [Desktop players](https://wnp.keifufu.dev/desktop-players),
   [Spicetify guidance](https://wnp.keifufu.dev/spicetify).
4. Choose **Media: standard width** or **Media: double width** in the context
   menu. Both actions persist `Columns` in `@Resources/User/Media.inc` and refresh
   only the current config. **Parallax settings** opens the independent shared
   settings skin. **Setup** replaces the player variant and unloads its measures.

The user file ships these defaults in `[Variables]`:

| Setting | Default | Purpose |
| --- | --- | --- |
| `Columns` | `1` | Use `1` for compact art or `2` for the large overhanging tile. Saved choices are preserved. |
| `PanelHeight` | `162` | Logical painted height. Keep at least 162 for this layout. |
| `MediaInterval` | `1000` | Skin update milliseconds. Does not throttle WNP's internal work. |
| `QueueExpanded` | `0` | Remember the inline queue section as collapsed or expanded. |
| `QueueRowLimit` | `5` | Maximum shown entries, 1–5; menu presets are 1, 3 and 5. |
| `QueueShowDetails` | `1` | Show artist/podcast details beside titles; 0 hides them. |
| `QueuePollSeconds` | `30` | Spotify request interval, 30–150; menu presets 30, 60 and 120. |

Global colors, font, and scale flow through the shared defaults/settings; a user
can add local overrides to `User/Media.inc`. The shipped layouts target the
default `ColumnWidth=200`, `FontSize=9`, `PanelPadding=6`, and support painted
widths 180/200/240/280/320 at scales 0.75/1/1.25/1.5/2, with either Columns value.
FontFace is inherited; this module does not provision fonts. Shared neutral
black/gray surfaces and the inside border frame the small MediaColor note icon,
48-pixel compact or 144-pixel double-width artwork, 18-pixel metadata rows, and
2-pixel progress bar. Panel titles
inherit `TitleFontSize`/`TitleTextColor`; the inline Queue and settings section
headings inherit `HeaderFontSize`/`HeaderTextColor`. Metadata, statuses, queue
rows and actions use the chosen body `FontSize` without subtracting a point.
Actions have 18-pixel height and zero local padding. Primary actions use
`AccentColor`; the gear, documentation, Stop and secondary settings/navigation actions
use `AccentColor2`. Metric icons and queue status retain `MediaColor`, and
unavailable actions remain muted. The double layout provides more metadata/time
space; transport hit regions stay compact. Setup uses the same panel and queue row.

All four panels inherit the shared background RGBA and outer `BorderThickness`
through `StylePanel`. Their section separators inherit `DividerColor` and
`DividerThickness` through `StyleRule`, including zero thickness. No local
separator replaces the shared color or width. The title/header/body settings
are independent; supported maxima are 12/10/10 points, with no local size clamp.

Extreme custom sizes or fonts may clip; text has fixed bounds and never expands
the skin. Covers preserve aspect ratio while cropping. Preserved user files may
still contain the earlier 332-pixel height: set `PanelHeight=162` and refresh to
adopt the compact default; the entrypoints never override saved preferences.

At the default base height/column/gutter values, with the inline queue collapsed:

| Suite scale | Standard window | Double window | Transparent gutter total |
| --- | --- | --- | --- |
| 75% | 156 × 128 | 312 × 128 | 6 |
| 100% | 208 × 170 | 416 × 170 | 8 |
| 125% | 260 × 213 | 520 × 213 | 10 |
| 150% | 312 × 255 | 624 × 255 | 12 |
| 200% | 416 × 340 | 832 × 340 | 16 |

Each double window equals two single window pitches. These are computed bounds,
not observed physical dimensions on mixed-DPI displays.

## Gear and expandable queue

Hover the Media or Queue header to reveal the original suite gear. Click it for
Media settings. Display preferences save on explicit clicks and apply to the
active player/queue while leaving the settings panel open. Unrelated module
preferences and the user's base `PanelHeight` remain intact. Existing saved
`Columns=2` choices are preserved.

Click **Queue +** in Media or Setup to expand the section; **Queue -** collapses it.
The expanded panel adds `8 + 18 * QueueRowLimit` logical pixels to its base height
(98 at five rows). The extra rows are read from the same validated Spotify cache.
Collapsed and unused rows move inside the existing bounds as well as being hidden,
because Rainmeter includes hidden meter positions in its dynamic window size.
The independent Queue config remains available from the settings panel.
The compact Media footer shortens long status phrases to Storage error,
Spotify error, Queue error, Quota reached or Stopped so they fit at the maximum
body size. The standalone Queue panel retains the full status wording.

The settings panel is always two pitches wide and 360 logical pixels tall.
Its controls offer one/two columns, collapsed/expanded queue, 1/3/5 items, details
shown/hidden, and 30/60/120-second polling. Valid custom row limits of 2/4 and
polling values within 30–150 seconds display accurately and cycle to the next
preset. Fixed selections and verified per-key writes avoid executable user input.

Changing the polling preference does not launch a process. Click **Restart**
to stop the existing worker, wait for its lock, and start one replacement at the
saved interval. Server Retry-After and quota pauses remain intact. Sign in,
Start, Stop and Disconnect are also explicit buttons. Opening/closing the menu
or expanding/collapsing the section never authenticates or starts a helper.

## Provider behavior and limits

WNP's documented `Status`, `State`, `SupportsPlayPause`, `SupportsSkipPrevious`,
and `SupportsSkipNext` measures drive the UI. The skin sends only the documented
`Previous`, `PlayPause`, and `Next` commands. Metadata is bound directly to meters
and never inserted into command strings. The Lua adapter has no file I/O,
networking, timers, subprocesses, or persistent runtime data.
Source: [WNP usage](https://wnp.keifufu.dev/rainmeter/usage).

The source label preserves specific player names reported by WNP. Its 2.0.7
native desktop adapter supplies the generic `Windows Media Session` name;
Parallax displays the shorter `Windows` unless the optional observer below can
confirm a unique Spotify match. The separate Spotify queue is never used to
infer the active playback source.

| Evidence | Display/behavior |
| --- | --- |
| Connection not 1 | WNP disconnected; track data hidden; controls inactive. |
| Connected, blank title | WNP idle; no invented title or cover. |
| Connected title and state 0/1/2 | Stopped / Playing / Paused. |
| Unknown numeric state | State unknown. |
| Missing artist/album/cover | Explicit unavailable text or neutral cover placeholder. |
| Positive duration and nonnegative position | Provider-reported progress and time. |
| Missing/invalid duration or position | Time unavailable; timeline hidden. |
| No positive capability signal | Control inactive, with explanatory tooltip. |

The WNP connection flag alone cannot distinguish a missing/failed plugin from
an inactive connection. Opening the player without the plugin may log Rainmeter
plugin errors; choose Setup to unload it. The UI does not pretend to diagnose
that ambiguity. WNP also exposes no reliable heartbeat timestamp here, so a
stalled provider retaining old data cannot be detected as stale. Native position
may be estimated by WNP, and transport commands have no success acknowledgement
in this interface. The skin never claims a command succeeded on click.

This milestone does not add seek, volume, rating, repeat, shuffle, player
selection, or audio capture. Desktop volume/rating are unsupported by WNP's
Windows API path. The separate Visualizer config owns mixed output capture;
Media neither loads nor controls it.

## Optional Spotify source detection

Open the Media gear and choose **Start** on the **Source detection** row.
This explicitly launches one hidden Windows PowerShell 5.1 observer. **Stop**
requests its exit and clears the observation. Opening settings, refreshing a
skin or expanding the queue never launches it. Closing a skin leaves it running;
there is no startup task or service. The observer uses built-in Windows APIs,
with no Spotify request, credentials, sign-in, browser inspection or playback action.

WNP 2.0.7 selects from all Windows sessions using its own activity ordering;
Windows' current-session pointer does not necessarily select the same session.
The observer therefore enumerates all sessions, checks their identities and
metadata twice for consistency, and publishes a complete bounded observation.
Source IDs are classified by exact case-insensitive matches to `Spotify.exe`,
`Spotify`, or `SpotifyAB.SpotifyMusic_zpdnekdrzrea0!Spotify`; all others remain
`other`. Merely having Spotify open does not change the label.

The passive `SourceReader.lua` compares WNP's exact nonblank title and raw
artist to every observation. Multiple matching sessions remain ambiguous even
when they belong to the same app or have different playback states. Only one
match classified as Spotify, with matching state, produces **Spotify**. Native
WNP maps Windows Playing to state 1 and other statuses to state 2. Incomplete,
unmatched, ambiguous, unavailable, stopped or expired observations retain
**Windows**, with a fixed explanatory tooltip. Specific WNP names, such as a
browser extension's player name, bypass the local observation.

One process collects every two seconds, with a four-second asynchronous work
budget and no overlapping pending requests. Observations expire six seconds
after collection begins; future timestamps more than one second ahead are
rejected. A stalled synchronous Windows call cannot be forcibly interrupted,
but its old observation still expires. Start and Stop serialize their actions;
only explicit Start clears an earlier stop request, so a delayed worker cannot
restart collection after Stop completes. Stop uses bounded waits for control
and worker ownership, up to twenty seconds total, and does not kill unrelated
processes. This is conservative correlation, not a
guarantee against a provider retaining obsolete metadata.

The current-user-only directory `%LOCALAPPDATA%\Parallax\Media\Source\` holds
`source.snapshot` and a stop request. Atomic replacement prevents partial reads.
No app IDs, tokens or credentials enter the snapshot; title/artist data remain
local runtime data and must never be distributed. The strict ASCII
`PARALLAX_SOURCE_V1` envelope carries state, observation/expiry timestamps and
up to 16 records of source classification, uppercase UTF-8 hex title/artist,
and playing state. Each field is limited to 1,024 UTF-8 bytes and the file to
128 KiB; invalid UTF-8/NUL, incomplete collections and excess limits fail closed.
Nonready snapshots contain no metadata. The helper also offers a one-observation
`Once` developer command, and restricts custom storage to dedicated temp roots.
`SourceReader.lua` must retain its **UTF-16LE BOM**, just like QueueReader, so
Rainmeter's native Lua APIs preserve Unicode metadata.

Primary implementation references:
[WNP 2.0.7 native adapter](https://github.com/keifufu/WebNowPlaying-Rainmeter/blob/2.0.7/src/WNPReduxAdapterLibraryExtensions/WNPReduxNative.cs),
[WNP session selection](https://github.com/keifufu/WebNowPlaying-Rainmeter/blob/2.0.7/src/WNPReduxAdapterLibrary/WNPRedux.cs),
[Windows GetSessions](https://learn.microsoft.com/en-us/uwp/api/windows.media.control.globalsystemmediatransportcontrolssessionmanager.getsessions),
[SourceAppUserModelId](https://learn.microsoft.com/en-us/uwp/api/windows.media.control.globalsystemmediatransportcontrolssession.sourceappusermodelid).

## Large artwork layout

The user's later Media-only revision uses large artwork for the existing
`Columns=2` choice and preserves the compact one-column variant. Relative to
the painted origin, the 144-pixel square starts at `(0,9)`. The black surface
starts at x=96, so artwork overhangs it by 96 pixels and overlaps it by 48.
Right-side content starts at x=156, leaving 12 pixels after the cover. The
shorter progress bar, queue heading/status, divider and every expanded queue
row use those same content bounds. Expanding the queue extends the surface
downward while the cover stays anchored.
The missing-art label hides when a cover is present, including transparent
images, and restores correctly after artwork disappears or playback reconnects.

At default width/scale, the full composition paints 408 pixels inside the
unchanged 416-pixel window; the black surface is 312 pixels wide. Thus the cover's
left edge and panel's right edge align with two standard utilities. All values
scale with the suite and retain its transparent snapping gutters. Idle, missing
art and Setup use an identically sized neutral tile. This layout changes no
saved height, width, expansion, detail, row-count or polling preferences.

## Optional Spotify queue

See the [queue setup guide](../../Skins/Parallax/@Resources/Modules/Media/Queue/README.md)
for app configuration, lifecycle commands, status meanings, storage, and protocol.
Register `http://127.0.0.1/callback` in your Spotify app, copy the public Client ID,
and click Sign in in `Parallax\Media\Queue`. The helper opens Spotify consent,
uses PKCE S256 with a dynamic numeric loopback callback, and requests only
`user-read-currently-playing`. In live acceptance, Spotify included
`user-read-playback-state` in the refreshed grant. No additional scopes are
requested. Validation accepts Spotify's returned scope set when it contains the
required permission; the helper only calls the queue endpoint.
Sources: [queue endpoint](https://developer.spotify.com/documentation/web-api/reference/get-queue),
[PKCE](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow),
[redirects](https://developer.spotify.com/documentation/web-api/concepts/redirect_uri).

The helper reads up to five tracks/episodes from the authorized Spotify account,
preserving order and duplicates. A valid empty response says Queue empty.
Unavailable, malformed, expired, or failed responses suppress rows. Successful
data expires after twice the configured polling interval, clamped to 90–300
seconds. The account's Spotify queue may differ from WNP's player.
Queue display does not add playback/write scopes or item manipulation.

Windows PowerShell 5.1 and built-in .NET provide HTTP, callback listener, locking,
and DPAPI. A single opt-in process polls every 30 seconds by default; Rainmeter
reads its local snapshot each second without polling subprocesses. Stop and
Disconnect are explicit actions. Closing the queue skin alone leaves the helper
running. There is no startup task or service.

Tokens are DPAPI protected; the public Client ID, tokens, snapshot, retry state,
and coordination files stay under `%LOCALAPPDATA%\Parallax\Media\Spotify\`
with a current-user-only ACL. No runtime user data belongs in skins or packaging.
Disconnect stops the process, deletes tokens, and clears display rows. It retains
the public app configuration and quota/retry barriers.

One HTTP401 allows one forced refresh and one retry. HTTP403 pauses with Access
denied without guessing the cause. HTTP429 Retry-After persists across restarts
and sign-in attempts; quota exhaustion pauses for explicit recovery without an
invented reset. The queue guide documents safe recovery. Development Mode needs
owner Premium and allowlisting, and shares developer quota.
Sources: [quota modes](https://developer.spotify.com/documentation/web-api/concepts/quota-modes),
[rate limits](https://developer.spotify.com/documentation/web-api/concepts/rate-limits).

## Validation report

The source-detection revision passed **124 synthetic provider assertions** in
Windows PowerShell 5.1, covering exact IDs, complete/double reads, duplicate
sessions, Unicode/NUL and size limits, deadlines, private ACL/atomic storage,
unsafe paths, mutex ownership, Stop/Once and hidden Start arguments. The final
lifecycle regressions verify that a delayed Start child performs zero collections
after a completed Stop, a later intentional Start resumes collection, and control
actions cannot overlap the launch boundary. Tests made
no native calls or network requests. Evidence:
`%TEMP%\Parallax-SourceProvider-test-828beb6872d64ae69ad6094324389938\`.
Provider SHA256: `E86AB13530D92935DA4AA9A563115884FA2AEAFFBABDDB773E761C4BFB16F150`.

The reader passed **133 assertions in 13 isolated native Lua scenarios**,
including strict protocol decoding, Unicode, raw artist binding, duplicate
ambiguity, stale/future data, unavailable I/O and direct provider passthrough.
The native binding case loads the unchanged UTF-16 script bytes against
synthetic Unicode String measures; no real listening data are used. Evidence:
`%TEMP%\Parallax-SourceReader-test-793472c0043c4d0b9c22c830e039dba6\`.
Reader SHA256: `695ECAB016E691622BE3896280B072BC4E1EAE18C4FD3D1BBED01760ADD683AE`.
The detection UI separately passed **2,707 assertions in 18 native layouts**,
with inert WNP/source fixtures and zero Rainmeter errors. Evidence:
`%TEMP%\Parallax-MediaSettings-test-01daff091b2d4a8a8f70a722e349498a\`.

One normal-user, read-only native observation returned **ready**, one session
and one Spotify classification in 369 ms. It printed only state/counts, saved
no metadata, and started no worker. This confirms native enumeration on the
current machine; real WNP-to-observer correlation and sustained observer cost
remain runtime checks. The user's live Rainmeter configuration was not changed.

The large-art visibility revision passed **302 native Lua adapter assertions
in 14 scenarios**, including cover availability, group/reconnect transitions,
both widths and suppression of the missing-art text beneath transparent covers.
Evidence: `%TEMP%\Parallax-Media-test-97de53c21aa245b4b10229d847c8678e\`.
Current `Media.lua` SHA256:
`A8B73D5CA2380FB9F2279EFE0EDFD64B41372F5CB83E6055454753BF1632B020`.

The final artwork pass completed **10 source checks** covering 1,100 layout
states, 160 typography/surface variants and 200 layered-art states, followed by
**9,003 assertions across 36 native layouts** with zero Rainmeter errors.
Player with populated/transparent artwork, missing artwork and Setup were
checked at widths 180/200, both Columns values, and scales 0.75/1/2 with maximum
font sizes. Every case exercises queue collapse and expansion. Eight synthetic
captures verify the smaller surface, clear right-side queue/progress, cover
labels and correct Queue +/- state. Representative expanded, collapsed and
compact captures were inspected after the final adapter fix. Evidence:
`%TEMP%\Parallax-MediaSettings-test-76b24dafdc58444ab4c4e105f07d08b2\media-settings-evidence.json`.
These fixtures load no real WNP plugin, observer, listening data or user config.

Executed on 2026-09-11 with the existing bundled Python runtime, using `-B` so no
bytecode caches are created. The first gear/accordion baseline is recorded below;
the later shared appearance revision has its own focused results after it:

- **8 Media contract tests passed over 1,100 layout states.** Coverage includes
  all four entrypoints, both Columns values, five widths (180/200/240/280/320),
  five scales (0.75/1/1.25/1.5/2), all five row limits and both accordion states.
  Checks resolve include trees, passive Setup/settings, WNP measure order,
  geometry/hit areas, and exact helper commands confined to explicit
  click/context actions. These are structural and arithmetic checks, not a renderer.
- **63 auth cases, 59 core assertions, and 68 provider assertions passed** in
  Windows PowerShell 5.1 with synthetic fixtures. Auth used normal-user DPAPI;
  the restricted sandbox cannot exercise that encryption. Coverage includes
  callback grammar/state/replay/deadline, ignored OAuth response extensions,
  tokens/rotation/six-month expiry,
  corruption/ACL/reparse boundaries, tracks/episodes/duplicates, malformed JSON,
  one 401 refresh/retry, persisted token/API Retry-After, quota pause, duplicate
  workers, stop during a response, disconnect cleanup, explicit restart cadence,
  and preserving a server wait that arrives during Stop. No live network or
  browser request occurs in these tests. Retained evidence:
  `%TEMP%\Parallax-QueueAuth-test-5261bfe9508947c296248eb5d342e443\`,
  `%TEMP%\Parallax-QueueCore-test-7171bdf6ec88466ba42dd08ef3c971b2\`,
  `%TEMP%\Parallax-QueueProvider-test-089e8dd5a4db48ff9fb881bd25835e22\`.
- **1,804 assertions passed in 22 native queue-reader scenarios.** Coverage
  includes protocol/UTF-8 parsing, metadata filtering, missing/stale/error
  suppression, file-handle closure, row limits, detail preferences, collapse,
  and inline positioning. No Spotify access occurs in these tests. Evidence:
  `%TEMP%\Parallax-QueueReader-test-a33a93b3c7fc420da0128be031a37afc\`.
- **4,120 baseline checks passed across 20 actual Queue skin layouts**, using an isolated
  Rainmeter instance and synthetic snapshots: widths 180/200, both Columns
  values, and five scales. Six screenshots were visually inspected. Accents and
  fullwidth text render correctly; long rows clip; headings/status/actions fit.
  Rainmeter reported zero errors. Evidence:
  `%TEMP%\Parallax-QueueView-test-38d3e1a346824ec38059507542912796\queue-view-evidence.json`.
  The production `QueueReader.lua` intentionally uses **UTF-16LE BOM**. Installed
  Rainmeter 4.5 requires that encoding flag for Unicode Lua API text conversion;
  preserve its raw bytes in packaging. The typography revision changes only the
  trusted inline row spacing to 18 pixels. Current reader SHA256:
  `8800816A46FB072C010BD5EF30BFCFE4EDBA11FA0C664C00E284FFC4E344F067`.
  The revised reader again passed 1,804 assertions in 22 native scenarios;
  evidence: `%TEMP%\Parallax-QueueReader-test-96315af7853e4bdca012ed0e694550ad\`.
  Source: [Rainmeter Lua loader](https://raw.githubusercontent.com/rainmeter/rainmeter/v4.5.26.3894/Library/lua/LuaScript.cpp).
- **6,506 baseline native settings/accordion assertions passed.** Thirty copied-source
  layouts cover Setup at widths 180/200, both Columns values and five scales,
  plus Settings at both widths and five scales. Checks exercise collapsed,
  five-row and three-row states, title-only details, actual window dimensions,
  hover gear, allowed preference writes, preserved unrelated settings, reloads,
  and valid custom 2-row/45-second preferences cycling to 3 rows/60 seconds.
  A separate instance with the real config names verifies that an already-open
  Settings panel follows footer toggles in both directions. Rainmeter reported
  zero errors. Two distinct synthetic window captures were visually checked;
  labels and rows fit. Evidence:
  `%TEMP%\Parallax-MediaSettings-test-3ccd85225b4d4a26b633ce76adfba0a8\media-settings-evidence.json`.
  No Spotify helper or user configuration was loaded for these checks.
- **279 baseline native Lua assertions passed in 13 synthetic scenarios.** An isolated
  instance of the existing Rainmeter ran the production adapter under Lua 5.1
  with mock measures: absent/disconnected/idle media, playback states and symbols,
  invalid numbers, capability gating at click time, MediaColor, cover transitions,
  and suppression of redundant UI bangs. It loaded no WNP or user configuration.
  The exact tested script hash was
  `CA8800A6D31B7A5F9605D84F821C4B04ED016D657B5D89A30CFEEB1F8BD0E81D`.
  Results/logs and the copied test inputs are retained under
  `%TEMP%\Parallax-Media-test-3e8409c7a0694aa58aa1ccffdec615e5\`.
- Earlier shared `tools/Test-Parallax.ps1` validation passed with 12 loadable
  configs, zero errors and zero warnings, before Media settings was added.
  The coordinating root task owns final shared validation and packaging.
- An independent review checked the compact layout. Offline IBM Plex Sans font
  measurement at narrow width showed no unexpected wrapping but identified tight
  text heights. Secondary rows were increased to 16 pixels and Setup's two-line
  blocks to 34/30 pixels, with transport/queue rows moved to preserve separation.
  The native Queue captures now verify its glyph fit; WNP artwork/transport
  rendering remains a separate integration check.

The shared appearance revision additionally passed **281 native adapter
assertions in 13 scenarios**, including distinct primary accent and metric
colors. Supported transport actions follow `AccentColor`; changing `MediaColor`
does not recolor them, and unavailable actions stay muted. That revision's `Media.lua`
SHA256: `C5DB8FAE0531974CA0EE45E9045F098EC5091865C7355861BC24D84AD9AAEDF9`.
Evidence: `%TEMP%\Parallax-Media-test-1445df482bad419a91902f9b62381959\`.

The final source pass completed **9 tests**, covering 1,100 geometry states and
160 typography/surface cases with independent font/color roles and thickness
extremes. The final appearance UI pass completed **10,252 assertions across 60 native
Setup, Settings and synthetic-player layouts plus open-settings synchronization**.
It covers the original preference/accordion matrix, maximum 12/10/10-point
typography at widths 180/200 and all five scales for Setup/Settings, and narrow
player layouts at default/maximum sizes and all five scales. Distinct test
colors verify title, header, body, primary/secondary actions and retained status
colors. Zero/four-pixel borders and dividers inherit the shared settings.
Seven synthetic captures are retained; default/maximum player, maximum Settings
and maximum Setup at scales 0.75/1 were visually inspected. Final Rainmeter logs
contain zero errors, and the tested source hashes remained unchanged during the
run. Evidence:
`%TEMP%\Parallax-MediaSettings-test-22ba32f14eae479c826b68c2afbb102f\media-settings-evidence.json`.
Every copied WNP include is replaced with inert Calc/String fixtures before
launch, including unloaded variants. These tests do not load the real plugin,
read listening data or exercise playback. A focused 115-assertion check also
verified the native footer substitutions Queue error, Quota reached and Stopped.

The focused standalone Queue typography pass completed **845 assertions in four
native layouts**: narrow 180-pixel width, default and maximum font sizes, at
scales 1 and 2. It verifies independent role colors, primary/secondary accents,
and zero/four-pixel divider and border settings. Four synthetic captures are
retained; the default and maximum examples were visually inspected. Body 10
requires an 18-pixel glyph box and title 12 requires 21 pixels, fitting the
18/22-pixel row/title bounds. Rainmeter reported zero errors. Evidence:
`%TEMP%\Parallax-QueueView-test-17b84f499c2e4a0d8e866e772ac1cfd7\queue-view-evidence.json`.

Run the developer checks from the repository:

```powershell
python -B -m unittest discover -s 'Skins/Parallax/@Resources/Modules/Media' -p 'test_skin_contract.py' -v
powershell.exe -NoProfile -ExecutionPolicy Bypass -File './Skins/Parallax/@Resources/Modules/Media/Queue/tests/Test-QueueAuth.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File './Skins/Parallax/@Resources/Modules/Media/Queue/tests/Test-QueueCore.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File './Skins/Parallax/@Resources/Modules/Media/Queue/tests/Test-QueueProvider.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File './Skins/Parallax/@Resources/Modules/Media/Queue/tests/Test-QueueReader.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File './Skins/Parallax/@Resources/Modules/Media/Queue/tests/Test-QueueView.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File './Skins/Parallax/@Resources/Modules/Media/tests/Test-MediaSettings.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File './Skins/Parallax/@Resources/Modules/Media/Source/tests/Test-SourceProvider.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File './Skins/Parallax/@Resources/Modules/Media/Source/tests/Test-SourceReader.ps1'
& './Skins/Parallax/@Resources/Modules/Media/tests/Test-Media.ps1'
```

Native tests use fresh absolute INI/SkinPath configurations in temporary
directories and only their own processes. They do not change the user's live
Rainmeter configuration. Synthetic fixtures verify local behavior, including
preference reload persistence, but do not prove provider integration. Live WNP
playback, missing-plugin logs, image refresh, playback command outcomes, mixed
Windows DPI and CPU/memory cost remain unverified. The isolated captures verify
text and geometry; WNP artwork/transport rendering remains separate. Completion
here remains a module prototype, not release readiness.

Live acceptance on 2026-09-11 confirmed browser consent, encrypted token storage,
a successful token refresh with Spotify's granted scope superset, and a validated
queue response containing five displayed items. Exactly one background worker was
running. A later status check confirmed the observation advanced by 90 seconds
while the queue remained ready with one worker, verifying normal background refresh.
Runtime credentials and listening data remain only in private LocalAppData;
none were copied into source, fixtures, screenshots, or package assets.

The later gear/accordion revision was verified only in isolated native skins.
Refresh all once in Rainmeter to discover the new settings config, then hover
the Media header for its gear and click **Queue +** to expand the inline section.

## Integration and next checks

- Prefer `Setup.ini` for the initial suite layout; Media.ini requires explicit
  user installation of WNP. Preserve `@Resources/User/Media.inc` on upgrades.
- Runtime packaging requires exactly three exceptions under
  `@Resources/Modules/Media/Queue/`: `QueueProvider.ps1`, `QueueCore.psm1`,
  `QueueAuth.psm1`, plus the new narrow exception
  `@Resources/Modules/Media/Source/SourceProvider.ps1` for local source detection.
  All tests/ descendants and fixtures remain developer-only, including the
  intentional live-read `Source/tests/Test-SourceNative.ps1` probe.
  The root task owns this packaging change and validation. Queue scripts import
  only sibling modules and built-in .NET; no binaries or third-party packages
  ship. Runtime client settings, tokens, caches, and retry records stay outside
  the distribution.
- In a separately authorized runtime session, check missing/disconnected WNP,
  Spotify Desktop and a browser player, pause/resume/previous/next support,
  title-less streams, missing cover/time, long Unicode labels, cover changes,
  reconnect, reload persistence, both columns, all five scales, and mixed DPI.
  Measure idle/playing CPU with WNP included; a skin interval is not a provider
  performance guarantee.
- Initial live queue acceptance passed for the user's provisioned app. Long-term
  token revocation/expiry, real quota exhaustion, cross-user DPAPI isolation,
  mixed Windows DPI, and provider CPU/memory cost remain unmeasured. Verify
  packaging exclusion of user data before distribution.

Primary Rainmeter syntax references checked: [include semantics](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/skins/include-option.html),
[Lua API](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/lua-scripting/index.html),
[Image](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/meters/image.html),
[Bar](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/meters/bar.html),
[bangs](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/bangs.html).
The public docs host returned 403, so the official docs repository was used.







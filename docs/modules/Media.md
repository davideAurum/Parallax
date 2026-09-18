# Media module prototype — layered player, settings and queue

Implemented 2026-09-11 within the Media-owned paths. This is an original Parallax
implementation. No ModernGadgets code or assets were used, and no plugins,
dependencies, live Rainmeter settings, or releases were changed by
this module task. Spotify sign-in is now an explicit user-authorized option.
The authorized revision follows `docs/APPEARANCE.md` revision 2:
the [ModernGadgets preview](https://raw.githubusercontent.com/raiguard/ModernGadgets/master/Wiki/preview.png)
and [stylesheet](https://github.com/raiguard/ModernGadgets/blob/master/Skins/ModernGadgets/%40Resources/StyleSheet.inc)
were inspected for density and hierarchy. The layout is original; the later
user-selected Lucide metadata and playback icons are attributed below.

## Delivered

- `Skins/Parallax/Media/Setup.ini`: dependency-free onboarding and fallback.
- `Skins/Parallax/Media/Media.ini`: optional WebNowPlaying player with title,
  artist, album, cover, reported position/duration, and progress. Lucide Music,
  User Round Group and Disc 3 icons identify the metadata rows. Beside the static
  `Media Player` title with Monitor Play, the body-font current-player name uses the selected Lucide Audio Lines icon. Playback-state captions
  are omitted; the optional source explanation remains on the song icon's tooltip.
- Previous, play/pause, and next controls use WNP capability measures. Unsupported
  controls appear muted, explain why in tooltips, and send no command. Lua checks
  connection/support again when clicked. Lucide rewind, play/pause and
  fast-forward artwork retains descriptive tooltips and track-skip behavior.
  The center shows the current state: Play while playing and Pause while paused.
  Playing hover uses Play Off; paused hover uses Step Forward. Clicking retains
  the existing playback toggle, so playing pauses and paused playback resumes.
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
- At two columns, a rounded album tile measuring 169 pixels at the current
  default (20 pixels larger in both dimensions than the preceding layout) with a thin white border
  overhangs the top and left edges of a narrower
  panel. Track details and playback controls occupy the right column; Queue spans
  the black panel's inner width below the cover.
  The composition retains the suite's double-width snapping bounds.

## Dependencies

| Feature | Dependencies | Cadence and fallback |
| --- | --- | --- |
| Base UI and Setup — required | Windows, Rainmeter, built-in measures/meters and bundled Lua/includes. | Default skin update: 1 second. Setup loads without external plugins. |
| Fonts and icons — bundled | Private IBM Plex Sans fonts ([license](../../Skins/Parallax/@Resources/Licenses/IBM-Plex-OFL.txt)); native Shape adaptations of Lucide artwork ([provenance and licenses](../../Skins/Parallax/@Resources/Modules/Media/Icons/Lucide/README.md)). | No download, system font installation or SVG-rendering plugin required. |
| Typed numeric settings — bundled | Rainmeter's bundled RunCommand plugin, Windows PowerShell/.NET WinForms and the shared `Scripts/SettingsInput.ps1` overlay. | An explicit numeric-field click starts one temporary editor. Fixed numeric/cancel output is revalidated before saving; invalid, cancelled, unrequested or hidden-field results do not save. No polling or provider starts. |
| Playback metadata and controls — optional, plugin bundled | [WebNowPlaying](https://wnp.keifufu.dev/rainmeter/getting-started) plugin 2.0.7.0 (MIT License, keifufu and Trevor Hamilton), bundled in the Parallax `.rmskin` from `packaging/Plugins/WebNowPlaying` and installed by Skin Installer unless a newer version is present ([license](../../Skins/Parallax/@Resources/Licenses/WebNowPlaying-LICENSE.txt), [provenance](../../packaging/Plugins/WebNowPlaying/README.md)); a supported player. Browser playback additionally requires the separately installed WebNowPlaying browser extension; desktop adapters are also separate. A development copy of the skin without the package needs a manual plugin install (2.x+). | Sampled on the skin update; `MediaInterval` does not throttle WNP internally. Inactive connections show no active media; unsupported controls remain disabled. Setup unloads the optional plugin. |
| Spotify source identification — optional | Bundled `SourceProvider.ps1`, Rainmeter's bundled RunCommand plugin, Windows PowerShell 5.1, built-in .NET and Windows media-session APIs. No Spotify authentication or network request. | Explicit Start uses a dormant `State=Hide` RunCommand control and enables one persistent observer targeting a 2-second collection cadence, with load-time recovery through `MediaLifecycle.lua`/`Lifecycle.inc`. Stop uses the same hidden event-only path. Observations expire after 6 seconds. Missing or inconclusive evidence leaves generic Windows playback identified as `Unknown`. |
| Spotify queue — optional | Bundled `QueueProvider.ps1`, `QueueCore.psm1`, `QueueAuth.psm1`; Rainmeter's bundled RunCommand plugin; Windows PowerShell 5.1/.NET; network access; Spotify Developer app public Client ID and user-authorized PKCE sign-in. The [queue setup guide](../../Skins/Parallax/@Resources/Modules/Media/Queue/README.md) records Development Mode prerequisites, including owner Premium and user allowlisting. No client secret. | Start, Stop, Restart and Disconnect use dormant `State=Hide` RunCommand controls with a fixed allowlist and do not overlap. One opt-in worker requests every 30 seconds by default, configurable to 30–150 seconds, subject to backoff/quota pauses. Sign in deliberately retains a visible setup console/browser flow. Passive views read local snapshots on their update. Missing, stopped, expired or failed data produces explicit status and suppresses rows. |

Both provider helpers require an explicit initial Start (or successful queue sign-in).
They save private enabled intent and can resume once when their Media view loads
in the normal `%APPDATA%\Rainmeter` profile. Stop disables recovery; queue Disconnect
also disables it. Missing or invalid intent never opts in. Settings and isolated
preview profiles never restore providers. There is no startup task or service.
Their 100ms/1-second internal waits are stop/scheduling checks, not
extra collection or API polling. Keep this inventory and its provider/license
references aligned with shipped components and cadence changes; developer test
tools and unimplemented features are not runtime requirements.

## Load and configure

1. Start with `Parallax\Media`, `Setup.ini` in Rainmeter Manage. This variant has
   no external plugin measures. Its passive Lua reader reads only the queue's local
   display cache. It does not probe, install, or load WNP.
2. The Parallax `.rmskin` installs the [WebNowPlaying Rainmeter plugin](https://wnp.keifufu.dev/rainmeter/getting-started) 2.0.7.0 unless a newer version is already present. When running the skin from a source copy instead of the package, install the plugin manually (version 2.x or newer).
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
| `PanelHeight` | `162` | Saved minimum logical height; the rendered layout grows to fit enlarged controls and Queue below the artwork. |
| `MediaInterval` | `1000` | Skin update milliseconds. Does not throttle WNP's internal work. |
| `QueueExpanded` | `0` | Remember the inline queue section as collapsed or expanded. A confirmed empty queue saves the collapsed state. |
| `QueueRowLimit` | `5` | Maximum shown entries, every integer 1–5; arrow step 1 or typed value. |
| `QueueShowDetails` | `1` | Show artist/podcast details beside titles; 0 hides them. |
| `QueuePollSeconds` | `30` | Spotify request interval in whole seconds, 30–150; arrow step 1 or typed value. |

Global colors, font, and scale flow through the shared defaults/settings; a user
can add local overrides to `User/Media.inc`. The shipped layouts target the
default `ColumnWidth=220`, `FontSize=9`, `PanelPadding=6`, and support painted
widths 180/200/220/240/280/320 at scales 0.75/1/1.25/1.5/2, with either Columns value.
FontFace is inherited; this module does not provision fonts. Shared neutral
black/gray surfaces and the inside border frame the identified-player title group,
36-pixel compact or proportionally sized double-width artwork, 24-pixel metadata rows, and
a progress bar using shared `DataBarThickness` (6 logical pixels by default,
range 1–12). Shared geometry rounds the scaled thickness to whole screen pixels
with a one-pixel minimum. Panel titles
inherit `TitleFontSize`/`TitleTextColor`; inline Queue headings inherit
`HeaderFontSize`/`HeaderTextColor`. Settings section headings retain
`HeaderFontSize` and use Accent 1 (`AccentColor`). Song, artist and album text
inherit the body `FontSize` (9pt by default). Their 14-pixel icons retain their
size, and each text/icon pair shares the center of its existing 24-pixel row.
Playback buttons now use 24-pixel
vector artwork in the existing 28-by-26-pixel hit regions. Statuses, queue rows and Setup
actions retain the chosen body `FontSize`; Setup actions remain 18 pixels tall.
Actions use zero local padding. Primary actions use
`AccentColor`; the gear, documentation, Stop and secondary settings/navigation actions
use `AccentColor2`. Metadata icons use `MutedColor`; the Monitor Play title and Audio Lines player-row icons
and queue status retain `MediaColor`, and
unavailable actions remain muted. The double layout provides more metadata/time
space; the three transport hit regions are centered between the artwork's right
edge and the measured left edge of the right-aligned time text. Compact layouts
use the content's left edge because their artwork sits above this row. The group
retains its 28-by-26-pixel targets and four-pixel gaps. Timing auto-sizes within a
fixed maximum width that reserves the controls and six-pixel clearance on each
side; long times clip without growing the window. Setup uses the same panel and queue row.
The time readout aligns with the progress bar's right edge and starts two logical
pixels below the bar. Available and unavailable time use the same position.
The bar preserves its prior center where space allows and keeps at least two
logical pixels below metadata. Controls follow eight logical pixels below its
lower edge; the queue moves down as needed to preserve its clearance.

All four panels inherit the shared background RGBA and outer `BorderThickness`
through `StylePanel`. Their section separators inherit `DividerColor` and
`DividerThickness` through `StyleRule`, including zero thickness. No local
separator replaces the shared color or width. The title/header/body settings
are independent; supported global maxima are 12/10/10 points, with no local size
clamp. Metadata has no local font-size increment.

Extreme custom sizes or fonts may clip; text has fixed bounds and never expands
the skin. Covers preserve aspect ratio while cropping. Preserved user files may
still contain the earlier 332-pixel height: set `PanelHeight=162` and refresh to
adopt the compact default; the entrypoints never override saved preferences.

At the default base height/column/gutter values and six-logical-pixel progress
bar, with the inline queue collapsed:

| Suite scale | Standard window | Double window | Transparent gutter total |
| --- | --- | --- | --- |
| 75% | 171 × 158 | 342 × 167 | 6 |
| 100% | 228 × 210 | 456 × 222 | 8 |
| 125% | 285 × 263 | 570 × 278 | 10 |
| 150% | 342 × 315 | 684 × 333 | 12 |
| 200% | 456 × 420 | 912 × 444 | 16 |

Each double window equals two single window pitches. These are computed bounds,
not observed physical dimensions on mixed-DPI displays.

## Gear and expandable queue

Hover the Media or Queue header to reveal the original suite gear. Click it for
Media settings. Display preferences save on explicit clicks and apply to the
active player/queue while leaving the settings panel open. Unrelated module
preferences and the user's base `PanelHeight` remain intact. Existing saved
`Columns=2` choices are preserved.

The single `HeaderGear.inc` meter uses the module-local `MediaHeaderY` anchor:
Media and Setup inherit their inset surface's top; standalone Queue uses `Inset`.
The fixed 18-pixel gear starts six logical pixels below that origin, aligning
its center with the title row at 15 logical pixels, without duplicate meter
sections across includes.

Click **Queue**, its List Plus icon or the adjacent status in Media or Setup to
expand the section. The icon becomes List Minus while expanded; clicking again
collapses it. The icon's 18-pixel hit target stays within the existing footer
row. The label reserves 42 logical pixels for the largest supported header
font; the adjacent status begins six pixels farther right to leave room.
The expanded panel adds `8 + 18 * QueueRowLimit` logical pixels to its base height
(98 at five rows). The extra rows are read from the same validated Spotify cache.
Collapsed and unused rows move inside the existing bounds as well as being hidden,
because Rainmeter includes hidden meter positions in its dynamic window size.
The independent Queue config remains available from the settings panel.
The compact Media footer shortens long status phrases to Storage error,
Spotify error, Queue error, Quota reached or Stopped so they fit at the maximum
body size. The standalone Queue panel retains the full status wording.

The settings panel is always two pitches wide. It is 554 logical pixels tall
with Queue expanded and 498 with Queue collapsed.
Its local `SettingsPanelHeight` and rendered window dimensions preserve the
monitor's loaded and saved `Columns` and `PanelHeight` values.
Below its title, shared context text identifies Media settings and links back
to Global Settings. Current setting values use the body `TextColor`; command
and navigation buttons retain their accent colors.
The [shared utility settings contract](../UTILITY-SETTINGS.md) supplies plain
body labels, compact shaded value fields and a 28-pixel row pitch. Five populated
sections separate Display, Queue sampling, Source detection, Spotify queue, and
Tools & help. Their section headings inherit Accent 1 and `HeaderFontSize`;
body values keep `TextColor`. Section separators inherit `DividerColor`/`DividerThickness`;
the form contains no table column headers. Numeric controls use the shared
left-arrow / centered-value / right-arrow pattern. Clicking a numeric label,
frame or value opens its editor; on/off fields retain their toggles.
Explicit Start/Stop, sign-in and navigation
buttons remain in their relevant sections, with concise setup guidance.
The saved `QueueExpanded` choice hides the Queue rows/details labels and fields
when collapsed, reclaims their two 28-pixel rows, and moves later sections up.
The Queue section toggle and Edit Media options context command remain
accessible. Expanding restores the fields and their existing `QueueRowLimit`
and `QueueShowDetails` values. Those two display choices also affect the
standalone Queue panel, as their tooltips explain. Shared sampling, source
detection, sign-in and recovery controls stay visible; collapse never stops
polling. `QueueShowDetails` has no additional settings beneath it to collapse.
Reflow uses the existing initialization, save and refresh paths, without a new
visibility preference or checking whether another skin or provider is active.
Its three numeric controls accept columns 1–2, queue rows 1–5 and queue refresh
30–150 whole seconds. Each arrow moves by one and clamps without writing or
refreshing at a bound. Every previously supported integer remains valid; the
former 1/3/5-row and 30/60/120-second menu presets no longer limit the editor.
Values use the body color, arrows use Accent 1, and units remain in labels and
tooltips. Each group is 96 logical pixels wide: 18-pixel arrows, two-pixel gaps
and a 56-pixel bordered center. Hidden Queue rows controls lose all frame,
arrow, value and label hit bounds. Textual arbitrary values are never accepted.

The shared one-shot overlay uses `UtilityNumber` with a fixed allowlisted range
and zero decimal places. Enter applies and Escape cancels. The module verifies
completion status, the fixed result protocol, integer syntax, range, pending
request and current field visibility again before a per-key write and readback.
Only one editor is pending at a time. Numeric edits do not enable providers or
restart an active worker; resulting view refreshes follow saved recovery intent.
The interval-restart reminder and unrelated saved preferences remain.
Arrows leave unsupported saved expressions unchanged; a valid typed edit can
explicitly replace them. Edit Media options remains available for file editing.

Changing the polling preference leaves an active worker at its old interval. Click **Restart**
to stop the existing worker, wait for its lock, and start one replacement at the
saved interval. Server Retry-After and quota pauses remain intact. Sign in,
Start, Stop and Disconnect are also explicit buttons. Opening/closing the menu
never authenticates or enables a helper. A refreshed view may restore a missing
worker that was previously enabled, using the current saved interval.

## Provider behavior and limits

WNP's documented `Status`, `State`, `SupportsPlayPause`, `SupportsSkipPrevious`,
and `SupportsSkipNext` measures drive the UI. The skin sends only the documented
`Previous`, `PlayPause`, and `Next` commands. Metadata is bound directly to meters
and never inserted into command strings. The Lua adapter has no file I/O,
networking, timers, subprocesses, or persistent runtime data.
Source: [WNP usage](https://wnp.keifufu.dev/rainmeter/usage).

The user's later layout revision removes the separate playback caption and
places the identified player beside the static Media Player title. WNP's source and
state remain internal measures; the optional observer
updates only the song icon's fixed tooltip. WNP 2.0.7's native desktop adapter
supplies the generic `Windows Media Session` name and needs the observer below
to confirm a unique Spotify match. The separate Spotify queue is never used
to infer the active playback source.

For YouTube or YouTube Music, enable the [WebNowPlaying browser extension](https://wnp.keifufu.dev/extension/getting-started)
and the corresponding supported site, then reload the tab and play media.
WNP's [desktop integration](https://wnp.keifufu.dev/desktop-players) excludes
browsers; the local Spotify observer does not identify browser sites. When
the extension reports a specific player name, the player row displays it
directly without needing a new source detector. Both YouTube variants appear
in WNP's [supported sites](https://wnp.keifufu.dev/supported-sites).

A live check on 2026-09-12, after the user enabled the Chrome extension,
returned connection 1, playing state 1, and `YouTube` from the player, source
reader and header. The user also confirmed it was working. No source-detector
or playback-code changes were needed; this check did not send playback commands
or retain video metadata.

| Evidence | Display/behavior |
| --- | --- |
| Connection not 1 | No active media; track data hidden; controls inactive. |
| Connected, blank title | No active media; no invented title or cover. |
| Connected title and state 0/1/2 | Internal stopped/playing/paused state; play/pause symbol reflects playback. |
| Unknown numeric state | Internally unknown; no visible state caption. |
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

### Provider recovery after restart

`MediaLifecycle.lua` runs once through the view's `OnRefreshAction`, with no
polling launcher. Player resumes enabled Source and Queue providers; Setup and
standalone Queue resume only Queue. Opening Settings launches neither. Recovery
is restricted to the normal `%APPDATA%\Rainmeter` settings profile, so isolated
previews and custom/portable profiles cannot restore the user's collectors.
Custom profiles retain the explicit Start actions.

Each provider stores `enabled.intent` in its existing private LocalAppData
directory (`Parallax\Media\Source` or `Parallax\Media\Spotify`). Its only valid
enabled content is ASCII `PARALLAX_AUTOSTART_V1|1` followed by LF; `|0` disables
it. Missing, disabled, malformed, oversized or unreadable intent fails closed.
Existing snapshots and Spotify tokens do not imply opt-in; an older installation
needs Start once to save that choice. Source Start and queue Start, Restart or
successful Connect enable recovery. Stop disables it; queue Disconnect and
Configure also disable it. A persistent Stop marker always vetoes Resume.

Resume never opens authentication or clears Stop. Queue recovery uses its saved
authorization when the worker runs, retaining Retry-After and quota barriers.
The launch command uses the current validated queue interval. Source collection
and queue snapshot formats/cadences are unchanged. Per-provider lifecycle and
worker mutexes prevent duplicate collectors. Queue's private `launch.id` additionally
rejects delayed children after a newer launch, including obsolete intervals or
quota override flags. No credentials or intent files belong in distribution.

Interactive Connect retains its existing bounded locking behavior: Stop can time
out while consent is pending. This change does not add sign-in cancellation.
Completed Stop/Disconnect prevents delayed recovery workers from collecting.

### Source setup and behavior

Open the Media gear and choose **Start** on the **Source detection** row.
This explicitly launches one hidden Windows PowerShell 5.1 observer and saves
enabled intent. **Stop** requests its exit, clears the observation and disables
load-time recovery. Player load/refresh resumes an enabled, unstopped observer;
opening Settings does not. Closing a skin leaves it running;
there is no startup task or service. The observer uses built-in Windows APIs,
with no Spotify request, credentials, sign-in, browser inspection or playback action.

Use this settings action to start the observer in Rainmeter's Windows context.
Launching it from a packaged terminal app can redirect LocalAppData into that
app's private storage, leaving Rainmeter unable to read the observation even
though the observer is running. Stop that terminal-launched observer in the
same context, then use Media settings **Start**.

WNP 2.0.7 selects from all Windows sessions using its own activity ordering;
Windows' current-session pointer does not necessarily select the same session.
The observer therefore enumerates all sessions, checks their identities and
metadata twice for consistency, and publishes a complete bounded observation.
Source IDs are classified by exact case-insensitive matches to `Spotify.exe`,
`Spotify`, or `SpotifyAB.SpotifyMusic_zpdnekdrzrea0!Spotify`; all others remain
`other`. Merely having Spotify open does not confirm it as the source.

The passive `SourceReader.lua` compares WNP's exact nonblank title and raw
artist to every observation. Multiple matching sessions remain ambiguous even
when they belong to the same app or have different playback states. Only one
match classified as Spotify, with matching state, confirms Spotify in the
song icon's tooltip. Native
WNP maps Windows Playing to state 1 and other statuses to state 2. Incomplete,
unmatched, ambiguous, unavailable, stopped or expired observations produce a
fixed explanatory tooltip without claiming Spotify. The header uses the reader's
confirmed Spotify result; an unresolved generic Windows result displays
`Unknown` beneath the `Media Player` title. Specific WNP names, such as a browser extension's player
name, bypass the local observation and receive a generic reported-source tooltip.

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

## Lucide metadata and playback icons

The user selected [Music](https://lucide.dev/icons/music) for song,
[User Round Group](https://lucide.dev/icons/user-round-group) for artist and
[Disc 3](https://lucide.dev/icons/disc-3) for album, plus Lucide Play, Play Off,
Pause and supplied rewind/fast-forward/step-forward SVGs for the playback controls.
The artwork is adapted to native Rainmeter Shapes with the original paths,
arcs, curves and rounded strokes. Metadata retains its existing 14-pixel
canvas, color, position, visibility handling and source tooltip.

The center artwork shows the provider's current state. While playing it shows
Play, changes to Play Off on hover, and clicking toggles to pause. While paused
it shows Pause, changes to the supplied Step Forward artwork on hover, and
clicking toggles to play. Leaving the button restores its current-state icon;
clicking does not fabricate a playback state. Stopped, unknown and disconnected
states retain the existing Play fallback and capability checks. Previous and
Next fill with the accent color when hovered and retain their existing track
commands. All controls keep their capability checks, muted
unavailable state, tooltips and 28-by-26-pixel hit regions.

The thirteen source SVGs, pinned revision, adaptation notes and the complete
upstream ISC and Feather MIT notices are retained in
[`Icons/Lucide/`](../../Skins/Parallax/@Resources/Modules/Media/Icons/Lucide/README.md).
Music is listed upstream as Feather-derived; the extra MIT notice is preserved.
These vector adaptations add no plugin, font or runtime network dependency.

## Player title, current player and icon

`MediaHeader.lua` reads the current WNP connection, track and reported player
after the source reader has updated. `MeterPlayerName` binds directly to its
returned string as `%1`; the tooltip uses the same measure value, retaining
the full name when the row truncates it. No player-supplied text becomes
a bang, path, variable name or Lua command. The static `Media Player` heading
inherits title typography, and the adjacent player name inherits body `FontSize`
and `TextColor`. Both retain fixed bounds without wrapping or shrinking global font choices.
The script retains a UTF-16LE BOM so Rainmeter's native Lua APIs preserve
accented, CJK and non-BMP player names.

Player and Setup titles use the shared `StyleTitleRow` center, translated to
their offset surface. Monitor Play returns to that title row at `ContentX`,
with its paths and strokes scaled by `TitleIconSize / 24`. Title text starts
after the icon and shared four-pixel gap. Its fixed 97-pixel title area is
followed by a six-pixel gap, the 14-pixel Audio Lines icon and current player;
the player ends 24 logical pixels before the gear. Audio Lines scales with the
suite, and its paths and strokes scale by
`14 * Scale / 24`. A four-pixel gap separates the icon from the player name.
The title and current-player text share the same vertical center. The icon and
source name remain visible in every player/setup state.

Standalone Queue uses the same title center without a leading identity icon.
Settings keeps its centered title using `CenterCenter`; its close control shares
the title's vertical center. Settings notes and existing content rows retain
their positions.

Specific WNP player names take precedence over a stale source label. Generic
Windows sessions receive the Spotify name only when the existing correlation
confirms it; otherwise the app is Unknown. Disconnected, empty-track and
plugin-free Setup states show Not connected, Idle and Setup respectively.
Pausing a track retains its player identity.

The title uses Monitor Play and the adjacent player identity uses the user-selected Lucide
Audio Lines drawing for every player and setup state. Their native Shape paths
preserve the supplied SVGs. The name adapter only returns inert text;
it no longer changes icon visibility or sends UI bangs. Player detection
remains available in the title row and full-name tooltip.
See [Rainmeter measure-bound tooltips](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/meters/general-options/tooltips.html)
and [Shape primitives](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/meters/shape/index.html).

## Large artwork layout

The user's latest Media-only revision keeps the artwork's top-left anchor and
adds 20 logical pixels to the preceding double-width square in both dimensions.
The double-width square starts at `(0,0)` relative to the painted origin. Its
size is `Round(Round(UnitWidth * 0.9) * 0.75) + Round(20 * Scale)`.
Compact artwork is 36 logical pixels, rounded after scaling. The black surface starts
at x=96 and is inset 12 pixels from the top (rounded after scaling). At the
default 220-pixel width, artwork is 169 pixels square, overhangs the surface by
96 pixels on the left and 12 at the top, and overlaps it horizontally by 53.
The title icon and shared-thickness progress bar start eight pixels after the
cover and extend to the same right edge. Metadata retains its former
icon/text column bounds and row pitch. Its text follows the body font size,
with the existing icons centered on each line. Playback buttons use
the smaller cover's right edge for their measured-time centering. Queue heading/status, divider
and every expanded row instead use `MediaQueueX/MediaQueueWidth`, spanning the
black surface with the shared padding on each side. Expanding the queue extends
the surface downward while the cover stays anchored.
The missing-art label hides when a cover is present, including transparent
images, and restores correctly after artwork disappears or playback reconnects.

At the current 220-pixel default width/scale, the full composition paints 448
pixels inside the 456-pixel window; the black surface is 352 pixels wide. Thus the cover's
left edge and panel's right edge align with two standard utilities. All values
scale with the suite and retain its transparent snapping gutters. Idle, missing
art and Setup use an identically sized neutral tile. This layout changes no
saved height, width, expansion, detail, row-count or polling preferences.

The large tile remains proportional to a standard column
and gives it a one-logical-pixel white outline with ten-pixel corner radii; the compact
tile uses six-pixel radii. A built-in Shape container clips the dynamic Image
meter to a rounded alpha mask. Matching rounded fallback Shapes keep missing
art and Setup corners transparent, and the border draws inside the tile bounds.
The mask stays visible while the image child retains its normal availability
checks. Missing artwork uses an `N/A` caption with a `No artwork available.`
tooltip so the compact tile remains readable at the maximum body font size.
No image file processing, new dependency or extra polling is involved.
References: [Rainmeter Container](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/meters/general-options/container.html),
[Shape](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/meters/shape/index.html).

The black surface grows to reserve the queue header below both the artwork and
playback controls, while preserving the user's saved minimum `PanelHeight`.
The divider is at least eight logical pixels below their lower edges; the queue
heading begins eight pixels after the divider. Surface top offset plus its height
form `MediaBodyHeightPx`, the overall unexpanded bottom offset; inline rows start
two logical pixels below that. Expansion does not move the artwork or change this
base height. At widths 180/220/320, artwork measures 142/169/236 pixels and the
overall double-layout body measures 214/214/273 pixels at scale 1 with the
default six-pixel progress bar. The existing queue anchor remains unchanged at
the normal 180/220 widths; at 320 it extends only enough to prevent artwork overlap.
Thicker bars can increase the
body height without changing the saved minimum or metadata positions.

Song, artist and album use the selected Lucide drawings in 14-pixel vector canvases beside their text.
Their static Shape options rebuild only when track visibility changes, so the
icons render again after playback returns from disconnected or idle states.
Metadata uses a fixed 24-pixel pitch with body-size text and centered icons. In
both layouts the first row starts 30 pixels below the black surface's top. At
default scale/width, the double layout has painted-origin metadata row tops
y=42/66/90, progress y=117, controls y=131 and the unchanged queue heading
y=193 with the default six-pixel bar. Compact metadata begins at y=30 with the
same 24-pixel pitch. Setup status/instructions and the idle message use the freed
space below the title row. Long metadata
clips within its column. The previous/play/next buttons form a 92-pixel group,
centered between the artwork's right edge and the measured left edge of the
right-aligned time text. Compact layouts use the content's left edge instead.
The buttons retain four-pixel gaps, while capped timing width reserves six-pixel
clearance on each side of the group. Missing time displays `-- / --` with an
explanatory tooltip and uses the same measured-text centering.
Both time states sit directly beneath the progress bar with a two-pixel scaled
gap. The playback controls follow the bar's lower edge with an eight-pixel scaled gap.

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
preserving order and duplicates. A valid empty response says Queue empty and
automatically collapses an expanded inline section, saving `QueueExpanded=0`.
The existing collapse path refreshes the Media layout and any open Media settings
panel. A later nonempty queue remains collapsed until explicitly expanded.
The reader requests collapse once per confirmed empty transition; unchanged empty
samples do not retry a failed preference write on every update. Missing, expired,
malformed or nonready snapshots never trigger automatic collapse. The standalone
Queue panel keeps its existing layout and status behavior.
Unavailable, malformed, expired, or failed responses suppress rows. Successful
data expires after twice the configured polling interval, clamped to 90–300
seconds. The account's Spotify queue may differ from WNP's player.
Queue display does not add playback/write scopes or item manipulation.

Windows PowerShell 5.1 and built-in .NET provide HTTP, callback listener, locking,
and DPAPI. A single opt-in process polls every 30 seconds by default; Rainmeter
reads its local snapshot each second without polling subprocesses. Stop and
Disconnect are explicit actions. Closing the queue skin alone leaves the helper
running. Enabled queue collection resumes on Player, Setup or standalone Queue
load in the normal Rainmeter profile. There is no startup task or service.

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

### Anchored 20-pixel artwork and raised player layout (2026-09-13)

All **15 source/geometry contract tests** passed across the supported widths,
scales, typography endpoints, compact/double layouts and queue states. A focused
native run passed **39 player/setup layouts** and **nine owned-window captures**
with zero Rainmeter errors. It covered present/missing artwork, 169-pixel default
double-width art, title-row player identity, raised metadata/progress/transport,
measured-time control centering, rounded clipping/border pixels, queue anchors
and maximum-font glyph fit. The inspected default 220/100% double-width capture
measured 456 by 222 pixels with the queue footer at its preceding position.

Evidence: `%TEMP%\Parallax-MediaSettings-test-b42017494bd24b96971def88a42f8bac`.
These fixtures use synthetic metadata and artwork; the focused live refresh below
checks actual meter geometry but does not establish mixed-DPI or performance.

The targeted normal-profile refresh kept the 456-by-222 window and reported
artwork at `(4,4)` with size 169-by-169. The progress bar began at x=181,
eight pixels after its right edge; metadata centers moved to y=58/82/106 and
the controls to y=135. The three 28-pixel buttons occupied x=233/265/297,
centered in the available span before timing. The queue divider remained at
y=189. The player icon/name moved beside the title at x=304/322. This probe
read only meter geometry and sent no playback action.

### Restart recovery (2026-09-13)

The Source lifecycle passed **176 synthetic assertions**; the Queue lifecycle
passed **214**, including the control/worker lock order and publication-gap
regression, Stop/Disconnect vetoes, obsolete launch rejection, preserved server
waits/quota, absent intent without storage creation and malformed permit rejection.
Independent review confirmed the final lock ordering closes the delayed-child gap.
The load controller
passed **4,347 native Lua assertions in 12 scenarios**, with zero Rainmeter
errors and its isolated test process stopped. Tests capture every external
command without executing providers. They cover per-view routing, once-per-load
reset, exact/bounded intent reads, Stop/error vetoes, independent provider
decisions, safe command arguments, polling bounds and normal-profile isolation.
Missing, disabled and corrupt provider intent remains a passive no-op. Provider
tests use generated private temp roots and intercept collection/auth/network/spawn.
All **15 Media source/geometry contract tests** also passed. The old expected
192 px double-width body assertion was corrected to the already-rendered 214 px
body; this lifecycle change does not alter production geometry.

Separately, the user-authorized live recovery check found the normal Media view
receiving WNP playback while both optional helpers were absent. Existing Spotify
authorization was retained. Starting the helpers through normal Rainmeter restored
`Spotify` recognition and `Next 1` queue status and seeded enabled intent. A view
refresh retained the same two worker PIDs. Ending only those verified helper
processes and refreshing Media recreated exactly one worker for each provider;
both live values returned without sign-in or playback commands. Rainmeter and
the music player stayed running. This verifies helper-loss/load recovery, not a
physical Windows reboot or steady-state resource performance.
After the final queue lock-order revision, another targeted queue-worker loss
and Media load restored one queue worker while retaining the source worker.
The final probe showed playing state, `Spotify` and a fresh `Next 5` queue.

Evidence roots: `%TEMP%\Parallax-SourceProvider-test-bf64e021149749e5b99aec7d1d3a76da`,
`%TEMP%\Parallax-QueueProvider-test-17882cbf6c064886adeac12352925889`,
`%TEMP%\Parallax-MediaLifecycle-test-476c190444d94b8d93dd3444708f7588` and the sanitized
`%TEMP%\Parallax-Media-recovered-live-90ea2fb8.txt` and
`%TEMP%\Parallax-Media-final-recovery-90ea2fb8.txt`. No listening metadata or tokens
were copied into the repository. Interactive consent cancellation remains outside
this change; the existing bounded Connect/Stop limitation is documented above.

### Earlier settings and queue checks

The three numeric steppers passed **two focused source checks covering 80
settings layouts** and **3,684 native assertions**: 1,606 in the maximum-font
180/75% endpoint, 1,510 in the default-font 220/100% endpoint and 568 in
footer-to-open-settings synchronization. Tests verified all three ranges,
step/clamp/no-write limits, valid edits, cancellation, invalid/malformed/out-of-range
results, running/expired/stale completions, legacy-expression preservation and
explicit replacement, leading-zero no-ops, hidden hit bounds and 498↔554 reflow.
Both captures were inspected: 282×380 collapsed and 456×562 expanded. No
Rainmeter errors occurred, all owned test processes stopped, and captured source
hashes matched the delivered files. Evidence:
`%TEMP%\Parallax-MediaSettings-test-4dc49f7e125b4922b384e04a49f6d979\media-settings-evidence.json`.
Typed entry used an inert Run/status/stdout proxy to test module dispatch and
commit behavior; it did not exercise the real overlay's keyboard interaction.
The shared helper was checked separately below. No settings integration refresh,
provider launch or live preference edit was performed by these tests.

Confirmed-empty collapse passed **2,378 native Lua assertions in 24 synthetic
queue-reader scenarios**, including deduplication, nonready/expired/missing
exclusions, unchanged standalone behavior, verified preference writes, read/save
failures, explicit toggles and preservation of other settings. The reader retains
its UTF-16LE BOM. Evidence:
`%TEMP%\Parallax-QueueReader-test-aa1f3c09d4464e80b5355802a2f6dc86\run-evidence.json`.
These injected checks do not access live queue storage or call Spotify.
One isolated rendered empty-queue transition also passed **284 assertions**:
an expanded double-width Player contracted to 456×222, showed List Plus, made
one verified collapse write and the two existing refreshes, did nothing on
repeated empty observations and stayed collapsed when entries returned. A prior
error state retained expansion. The capture was inspected with zero Rainmeter
errors. Evidence:
`%TEMP%\Parallax-MediaSettings-test-79d6e2dfca3e42f69e608e3c44baa0b9\media-settings-evidence.json`.
One targeted refresh subsequently applied the direct user-requested collapse
behavior to the active Media skin. A read-only probe confirmed the new callback
loaded; the live queue reported `Next 5` and correctly retained its expanded
state. No Spotify queue change or playback command was sent.

The shared numeric helper passed **27 Media-specific range/protocol checks**
for columns 1–2, rows 1–5 and polling 30–150 with zero decimal places: valid
endpoints, out-of-range values, fractions, invalid text and cancellation. These
were passive validation calls with no overlay or provider launch. The tested
shared helper SHA256 is
`6FFC3A1B0E9D373B9317B948F8A1F5B18D9B1277E45C5A66BF83EADFF617631B`.

The subsequent title/player icon correction passed **two focused source tests**
covering **80 Player/Setup layouts** and **1,845 native assertions** across two
maximum-font Player endpoints: width 180 at 75% in compact layout and width 220
at 200% in double layout. Both inspected captures show Monitor Play beside the
title and the supplied Audio Lines drawing beside the body-font player name.
Title/player centers, literal names and state transitions passed; windows remain
141×158 and 912×444. Rainmeter reported zero errors, the owned test process
stopped, and production hashes matched the captured sources. Evidence:
`%TEMP%\Parallax-MediaSettings-test-b0501cfc76d447b983aa6e011f9aa3fa\media-settings-evidence.json`.
The SVG preserves the exact supplied bytes; no dependency, script, row position
or saved preference changed. A targeted Media refresh applied the correction.

The preceding current-player row revision passed **two focused source tests**, including
**80 Player/Setup layouts**, and **2,733 native assertions across five isolated
rendered cases**. Those cases cover narrow width 180 at 75%, default width 220
at 100%, and maximum-font width 220 at 200%, including Player and Setup. The
checks verified static title/body typography, literal long names and tooltips,
unknown/disconnected/idle states, fixed 14-pixel icon alignment, metadata and
artwork separation, and transport/progress/queue bounds. All five synthetic
captures were inspected; Rainmeter reported zero errors, and the owned test
process stopped. Default double size is 456×222; the large endpoint is 912×444
and the narrow compact endpoint is 141×158. Evidence:
`%TEMP%\Parallax-MediaSettings-test-fcd87b0dcf254e21bf306aaab822c245\media-settings-evidence.json`.
The detection, header adapter, playback and settings scripts were unchanged.
After one targeted refresh of the user's active Media skin, a read-only probe
confirmed `Media Player`, the new player row reporting `YouTube`, inherited
9pt body text and the 14px icon. No playback command or preference write was sent.

Conditional queue settings passed **three focused source checks**, including
**80 expanded/collapsed layouts**, and **2,625 native assertions**: 2,181 across
maximum-font settings endpoints at width 180/75% and width 220/200%, plus 444
in the existing footer-to-open-settings synchronization fixture. Native checks
cover in-place collapse/expansion, hidden controls without occupied hit areas,
restored shared display values, saved preferences, reopening, pending-restart
status, accessible recovery actions, and Accent 1 section headings with body
colored values. Collapsing reclaims exactly 56 logical pixels: 42 physical
pixels at 75% and 112 at 200%. Both final captures were visually reviewed;
Rainmeter reported zero errors and no helper action was executed.

The first native transition exposed Rainmeter's load-time expansion of nested
height variables. `Settings.lua` now explicitly recomputes physical panel and
window heights before the existing dynamic meter update. The corrected narrow
run and footer synchronization passed, followed by the remaining large endpoint.
Evidence: `%TEMP%\Parallax-MediaSettings-test-e8d8bb126da84083b4cfa067267f7a06\media-settings-evidence.json`
(narrow and footer sync) and
`%TEMP%\Parallax-MediaSettings-test-3b46e246996b446fac56208f9c1c4d86\media-settings-evidence.json`
(large). Final `Settings.ini` SHA256:
`FDBF71388EEF79544A7933462AE8E44FE37E4170EA82DE08F1CE72181DF15F9E`;
`SettingsMeters.inc` SHA256:
`82C2DE0E85A58197A6CBEC28F7CCB49BB4C41528E952EFB1A07DF7D79EC8F194`;
`Settings.lua` SHA256:
`10C676D02A88CDBFE03A34564DA343528E12D302B765EF227AA898AF51EFA039`.
Current-state playback icons, bar/artwork geometry, provider scripts and runtime
dependencies are unchanged. No live configuration was refreshed for this revision.

Before conditional queue-detail reflow, the settings reorganization passed source preference/action checks and **40
settings layouts** across widths 180/220, both monitor Columns values, all
five supported scales, and default/maximum fonts. Two accepted native settings
endpoints at maximum fonts passed **918 assertions**: width 180 at 75% scale
and width 220 at 200%. They verify padded value-field bounds, section spacing,
saved preferences and reloads, custom values, manual helper command wiring,
close/navigation wiring, and guidance glyph fit. Final captures were visually
reviewed. Rainmeter reported zero errors; no production fix was needed after
correcting the test's 75% padding model to match native integer dimensions.
Evidence: `%TEMP%\Parallax-MediaSettings-test-0a6e61c5e987470495939687df9b636a\media-settings-evidence.json`
(final narrow case, 449 assertions) and
`%TEMP%\Parallax-MediaSettings-test-65cad4c8bd5d44bf82a0a5ba85211cc6\media-settings-evidence.json`
(200% case, 469 assertions). These runs use isolated copies and synthetic data;
no live settings were refreshed and no helper actions were executed. Final
`Settings.ini` SHA256:
`8A6D14EA927B6D03B294211D2B7385028F138F1214B4AFE9BA5722DB44D3621B`;
`SettingsMeters.inc` SHA256:
`7DD8CA342F12ACA2D57F0087873A009E08D8923129B7D8D9AB31BCBE5AF8E524`.
The settings controller and provider scripts remain unchanged. Independent
review confirmed action/group/interval preservation; new sign-in guidance
accurately states that successful sign-in starts queue polling.

The current-state playback artwork passed **508 native Lua assertions across
21 scenarios** against `Media.lua` SHA256
`648FCD2D424788C533BD79DFA5115535418CFF6DD4FE914CE3ABD8E05CFA3C20`.
The existing suite verifies playing Play/Play Off, paused Pause/Step Forward,
both deferred click transitions, unchanged capability-gated `PlayPause`
commands, hover deduplication, and stopped/unknown/disconnected fallbacks.
Evidence: `%TEMP%\Parallax-Media-test-ba93180dfcbc412fb7e4e449a458e056\run-evidence.json`.
The adapter alone was then reloaded in the running Media measure without
refreshing the skin or sending playback commands. A live playing-state probe
confirmed Play, all three Play Off hover paths, restoration to Play, and the
Spotify source/header. Paused-state rendering was verified in the isolated
suite; the live probe did not interrupt listening to force that state.

Shared bar-thickness integration passed two focused source checks and **three
native Player cases / 2,116 assertions**, with zero Rainmeter errors. Painted
heights were one screen pixel for thickness 1 at 75% scale, six pixels for
logical thickness 6.25 at 100%, and twelve pixels at the upper endpoint.
Native checks verified timing alignment and metadata/control/queue clearance;
all three representative captures were visually reviewed. These isolated
fixtures predate the subsequent center-icon state mapping. Evidence:
`%TEMP%\Parallax-MediaSettings-test-b3c2c5ac2c7e42fb8c92731e8d569ffa\media-settings-evidence.json`
and `%TEMP%\Parallax-MediaSettings-test-98983ea7dda94d64bd8792e036088192\media-settings-evidence.json`.
The first run's thin-case assertion used unrounded padding; the corrected test
passed in the focused rerun. Final `InlineQueueGeometry.inc` SHA256:
`B5405BD5DA0EF5866686933DAC2003D57883C31AC2669FAE5EE288916FECD98D`;
`PlayerMeters.inc` SHA256:
`7065A77BD49C85ACD97DA8E36EB1D2C97C0CD973705F1E1CD493C4222E089C8F`.

Before shared bar-thickness integration, the timing-position refinement passed the existing source layout check and
**two native Player cases / 1,394 assertions** at compact width 180 and double
width 220. Available and unavailable time share the bar's right edge and a
two-logical-pixel gap beneath it. Rendered captures were reviewed, source hashes
remained coherent, and the isolated process stopped with zero Rainmeter errors.
Evidence: `%TEMP%\Parallax-MediaSettings-test-fa004f62ade14442adb04c93bef6563e\media-settings-evidence.json`.
`PlayerMeters.inc` SHA256:
`A57464652386FE552483C325E14C6404B7AF5D8FFCBA07E24A0D622D614EA459`.

The 25% artwork reduction and body-font refinement passed source geometry
checks across **1,320 layouts**, including unchanged artwork anchors, preserved
metadata column bounds and matching text/icon row centers. Final native
acceptance covers **four cases / 2,148 assertions**: two retained Setup cases
and two Player cases at maximum fonts, compact width 180 and double width 220.
The final Player-only run passed 1,362 assertions after text inherited the body
font and was centered in the existing 24-pixel rows. The 14-pixel icons retain
their previous dimensions and positions. The compact missing-art caption
measured 24 by 18 pixels inside its 30-by-18 area.

Native checks verify the smaller cover, reclaimed queue height, unchanged
metadata bounds, body-font inheritance, equal icon/text centers, queue
persistence and centered playback controls as timing width changes. Three
representative final captures were visually reviewed. Static validation passed
19 configs and 71 INI/include files with zero errors or warnings. No playback
command was dispatched by hover. These checks use synthetic data in isolated
Rainmeter configuration.
Evidence: `%TEMP%\Parallax-MediaSettings-test-442f99742f2e491faf9174c5d63d2819\media-settings-evidence.json`
(artwork reduction and retained Setup cases) and
`%TEMP%\Parallax-MediaSettings-test-f6747b9494bf46c29c56e8e88a8cba67\media-settings-evidence.json`
(final Player cases). Final `PlayerMeters.inc` SHA256:
`5C6690089036267D621CCCA6C5E2C44D6B8B39D1B021375CA9DFFDA91FF484E3`.

The preceding queue/title/transport revision passed six focused source checks
and **four native cases / 1,482 assertions**. Setup and Player were checked at maximum
font settings with compact width 180 and double width 220. Queue expansion,
collapse, saved state and row-count reloads passed. The Queue label measured
41 by 18 pixels inside its 42-by-18 area. Saved-PNG checks found the vertical
plus stroke only when collapsed, with list strokes retained in both states.
Three representative captures were visually reviewed.

Native timing transitions verify the control group's midpoint against the
artwork/content boundary and actual time-text left edge. At compact width 180,
the unavailable text measures 34 pixels, a short sample 28, and normal/long
samples clip to the 64-pixel cap. The original resize fixture used a 69-pixel
sample that was already clipped; only that case was rerun with a shorter sample.
The double layout caps timing at 140 pixels. Native assertions confirm filled
skip hover, Step Forward on Pause hover, and zero playback dispatches from
hover. Both isolated processes stopped with zero Rainmeter errors and unchanged
production hashes. Static validation passed 20 configs and 69 INI/include files
with zero errors or warnings. These are synthetic, isolated Rainmeter checks;
they do not exercise a live player or alter personal configuration.
Evidence: `%TEMP%\Parallax-MediaSettings-test-c8c1205576c944069f435537dae479bf\media-settings-evidence.json`
(three passing cases) and
`%TEMP%\Parallax-MediaSettings-test-60cd7191e94d4755b8038d5e57447ee2\media-settings-evidence.json`
(passing compact Player rerun).

The centered transport and hover update passed **487 native Lua assertions
across 21 scenarios**, covering short/long/unavailable timing, compact and
double layouts, scale and invalid-geometry handling, changed-position-only
updates, filled skip icons, Play Off/Step Forward hover transitions and
unsupported/disconnected controls. Hover sends no playback command.
Production `Media.lua` SHA256:
`86C41F6BE0B312E1612774F4130A4EC9075C2EE252D8CC0621D285C3DE8F7A6F`.
Production `TransportIcons.inc` SHA256:
`4DAA90757DF30CB684F32713F781764F7834A35A53CB6DAFE95F70297892396D`.
Evidence: `%TEMP%\Parallax-Media-test-53691855b13e42e8a72fb1f9ae01bbb8\results.txt`.

The constant Monitor Play header passed **425 native Lua assertions across
nine scenarios**, preserving literal player names, Unicode, setup/disconnected/
idle states and source resolution without icon-selection bangs. The UTF-16LE
production `MediaHeader.lua` SHA256 is
`C236BBBF92F24F47CE71D37FD9D29FD1026AE0377CCDC6479EFED72256FB7485`.
Evidence: `%TEMP%\Parallax-MediaHeader-test-a2ac09bb65914a8097929a00477dd671\results.txt`.

An isolated Rainmeter 4.5.26 timing probe confirmed `GetX()` returns the measured
left edge for right-aligned text: anchor 300, width 64, left 236. A longer string
clipped at its 150-pixel limit with left 150 and the same right anchor. This
confirms the centering boundary uses visible text width rather than its anchor.
Evidence: `%TEMP%\Parallax-TimingGeometry-probe-6edf6901efd54d05995d32237fe818a1\result.txt`.

The preceding Lucide playback-control adapter passed **389 native Lua assertions across
17 scenarios**, including play/hover/leave/pause transitions, clicks followed
by reported playback changes, hover during playback, unsupported/disconnected
controls and repeated-event deduplication. Hover never sends a playback command.
Evidence: `%TEMP%\Parallax-Media-test-a809670356b246ffb2d863e5e7589a4b\results.txt`.
That revision's `Media.lua` SHA256:
`67B598D5675FC7637B79E676B2EE8B7D6AD6D7CB74EE222417DF27E447987978`.

At that preceding revision, four relevant source checks passed after extending the geometry
checker for native circular arcs, cubic curves, shared stroke modifiers and
offsets. The focused native icon regression passed **1,446 assertions across
two cases**, including hover enter/leave, the playing state overriding hover,
muted unavailable controls and zero playback commands from hover. Both saved
captures retain all three metadata icons and all transport icons after
disconnect-to-idle-to-playing transitions. Independently reloading the PNGs
confirmed identical metadata pixel maps at default and maximum font settings
(54 song, 55 artist and 65 album pixels in the check's neutral-color range).
Evidence: `%TEMP%\Parallax-MediaSettings-test-dc06e9e3cffd45e18801d441b7576b17\media-settings-evidence.json`.
Final static validation passed 20 configs and 69 INI/include files with zero
errors or warnings. These checks use synthetic playback data and isolated
Rainmeter configuration, not a live player or personal desktop interaction.

The title/icon alignment refinement passed **14 source tests**, including
1,320 general layout states and 144 title-size/scale/width/column combinations
across Player, Setup, standalone Queue and Settings. These cover title sizes
6/10/12, scales 0.75/1/2, widths 180/220 and both column choices. Checks verify
scaled icon paths and strokes, shared vertical centers, title/gear clearance,
centered Settings titles and unchanged content positions.

A focused native run passed **480 assertions across 12 cases**, with zero
Rainmeter errors and coherent source hashes. Twelve synthetic captures were
retained and seven visually inspected. At the maximum tested size, Setup and
Queue have 10 and 13 clear physical pixel rows between title and status ink;
the default gaps are 5/7 and the minimum gaps 4/6. Setup's nominal one-logical-
pixel text-box overlap therefore contains no rendered glyph collision with
the bundled font, and its first content row remains unchanged. Narrow player
titles intentionally truncate. The isolated test process stopped cleanly.
Evidence: `%TEMP%\Parallax-MediaSettings-test-61e2ea3b68e54a55841a17ed668c891d\media-settings-evidence.json`
and `title-ink-gaps.json` in the same directory. Final static validation passed
20 configs and 68 INI/include files with zero errors or warnings. No personal
Rainmeter configuration or live provider was used in these checks.

The playback-state refinement passed **313 native Lua adapter assertions in 14
scenarios**, including separate idle/track borders, cover transitions and
unchanged-sample update deduplication.
That revision's `Media.lua` SHA256:
`4FFE7403437356AFE0F9665C3D892386CC1A18F8963CBAD43106959074E03D8A`.
Evidence: `%TEMP%\Parallax-Media-test-9298a643d74746a4b54ab84c96f9a2b7\`.
Source detection's tooltip-only binding passed **148 assertions in 13 native
scenarios**, including its actual Shape-icon/UTF-16 binding. Current reader
SHA256: `F92BA2DEDE19B9AED32D77A02B4FBA23085447FD3D03B84F3ABFD7417B52A745`.
Evidence: `%TEMP%\Parallax-SourceReader-test-e020d026db4a451ab43e4743c99cf0a9\`.
The static song icon receives an explicit meter update only when its tooltip
changes. A native update sentinel verifies refresh ordering and deduplication.
The proportional-size queue reader passed **1,804 assertions in 22 scenarios**
after its inline rows were anchored to the derived body height. Its current
UTF-16LE SHA256 is `B8D9385FE45D1D678201A32E1142EF23D467565F585CD231AAA3C81B2CD499A3`.
Evidence: `%TEMP%\Parallax-QueueReader-test-bc9a07bf8000474488a8a19f48e8ff1e\`.
The earlier player-specific-icon adapter passed **1,376 assertions in 10 native scenarios**,
including the unchanged UTF-16LE production binding, literal Unicode and
command-like names, all seven icon choices, exact aliases, disconnect/idle and
player transitions, pause/stop retention and update deduplication. Production
SHA256: `479BF976A5A08321302A96D64E5EFD4DEA344AE2E38F27E7172AD9BF419F60B8`.
Evidence: `%TEMP%\Parallax-MediaHeader-test-2c8dc44ee6f94925a37cd8b928c6f9eb\`.

The header integration passed **13 source tests** and **25 focused native
identity cases / 10,717 assertions** with zero Rainmeter errors. These cases
exercise nine live state transitions, literal command-like names with an
execution sentinel, icon switching, pause/disconnect/idle states and fixed header
bounds. Six synthetic captures were visually inspected. At width 220 with the
maximum title font, `Media Player: Spotify` measured 158 by 21 pixels inside its
194-by-22-pixel meter; narrow variants truncate horizontally. The full-name
tooltip was verified through its exact `%1` binding and literal measure data;
this is not a native tooltip-hover capture. Evidence:
`%TEMP%\Parallax-MediaSettings-test-8300f1b95e5549ae93ad8eca762e0467\media-settings-evidence.json`.

Final screenshot review found that static song, artist and album Shapes could
remain blank after returning from idle. Their options now rebuild only when
track availability changes. A focused native rerun passed **980 assertions
across two cases**, with zero errors; both default and maximum-font captures
visibly restored all three icons, confirmed by pixel checks. Evidence:
`%TEMP%\Parallax-MediaSettings-test-756506d9adb946c7b4fed1ec83023126\media-settings-evidence.json`.
The targeted source check passed. Final suite validation covered **20 configs
and 68 INI/include files**, with zero errors or warnings.

The earlier Settings update received source checks only for the shared note dependency, 404-pixel
height, shifted content and body-colored values; the existing full native
harness includes the new shared file and updated settings bounds for future runs.

The 2026-09-12 larger-metadata, thicker-progress and relocated-queue refinement
passed **12 source tests** across 1,320 layout states, 160 typography/surface
variants and 240 artwork states, plus duplicate-section and header-anchor checks.
Its **39 native cases passed 14,400 assertions** with zero Rainmeter errors at
widths 180/220 and additional wide 320 cases, both column modes and scales
0.75/1/2. All 27 Player cases also exercised missing-time display and restored
the synthetic timeline, verifying text fit beside enlarged controls. Nine
captures were retained and seven visually inspected; long compact metadata
truncates within fixed bounds. Queue clears both artwork and controls and uses
the surface's full padded width. Evidence:
`%TEMP%\Parallax-MediaSettings-test-06031b19266c4b93878eec3523dab37e\media-settings-evidence.json`.
The test used synthetic data, stopped its owned Rainmeter process, and verified
unchanged source hashes. Shared static validation passed 20 configs / 66 files
with zero errors and warnings. Saved preferences and provider/reader scripts
were unchanged by this refinement.

The 2026-09-11 proportional-artwork, tight-spacing and top-overhang refinement passed
**10 source tests** across 1,320 layout states, 160 typography/surface variants
and 240 artwork states at six widths. Its **39 native layouts passed 12,552
assertions** with zero Rainmeter errors, covering widths 180/220, both columns,
scales 0.75/1/2, three additional 320-wide Player cases, maximum fonts,
populated/transparent and missing artwork, Setup, and queue collapse/expansion.
Pixel checks covered clipped corners, white borders, top overhang and intact
interior colors. Nine captures were retained; six representative expanded,
collapsed, compact, missing-art and Setup views were visually inspected.
Evidence:
`%TEMP%\Parallax-MediaSettings-test-4d97886d9991498fb639e5047ae49bd9\media-settings-evidence.json`.
Only synthetic data and an owned isolated Rainmeter process were used.
The subsequent single-definition gear fix passed **12 focused native cases /
356 assertions** at width 220, both columns and scales 1/2 for Media, Setup and
standalone Queue. The checks verified exact gear coordinates, header clearance,
hover show/hide, unchanged window bounds and unchanged preferences. Gear Y is
10/20 physical pixels at scales 1/2 in compact Media/Setup and either standalone
Queue width; wide Media/Setup uses 22/44. Evidence:
`%TEMP%\Parallax-MediaSettings-test-cd3b905f43db4b1b9832d886198e26d7\media-settings-evidence.json`.
All **12 source tests** passed, including rejection of duplicate non-Variables
sections across includes and 30 gear-origin combinations. The full shared static
validator also passed with all modules required and warnings treated as errors:
20 configs, 66 INI/include files, zero errors and warnings.
The earlier milestones below are retained as historical evidence.

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
That revision's `Media.lua` SHA256:
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
  trusted inline row spacing to 18 pixels. That revision's reader SHA256:
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
powershell.exe -NoProfile -ExecutionPolicy Bypass -File './Skins/Parallax/@Resources/Modules/Media/tests/Test-MediaHeader.ps1'
```

Native tests use fresh absolute INI/SkinPath configurations in temporary
directories and only their own processes. They do not change the user's live
Rainmeter configuration. Synthetic fixtures verify local behavior, including
preference reload persistence, but do not prove provider integration. Broader WNP
player coverage, missing-plugin logs, image refresh, playback command outcomes, mixed
Windows DPI and CPU/memory cost remain unverified. The isolated captures verify
text and geometry; WNP artwork/transport rendering remains separate. Completion
here remains a module prototype, not release readiness.

A targeted live check on 2026-09-12 confirmed WNP state 1 while music played,
the normal Pause geometry with hover inactive, and the user's confirmation that
Pause bars were visible. This preceded the user's explicit switch to icons that
represent current state (Play while playing, Pause while paused). Launching
the existing source observer through Rainmeter restored a readable fresh cache;
the live source reader and header both returned Spotify after one matching
Windows media session. A packaged-app launch had redirected the earlier cache
away from Rainmeter. This check used no playback command and recorded only
status/source evidence, with no track metadata copied into the repository.

Live acceptance on 2026-09-11 confirmed browser consent, encrypted token storage,
a successful token refresh with Spotify's granted scope superset, and a validated
queue response containing five displayed items. Exactly one background worker was
running. A later status check confirmed the observation advanced by 90 seconds
while the queue remained ready with one worker, verifying normal background refresh.
Runtime credentials and listening data remain only in private LocalAppData;
none were copied into source, fixtures, screenshots, or package assets.

The later gear/accordion revision was verified only in isolated native skins.
Refresh all once in Rainmeter to discover the new settings config, then hover
the Media header for its gear and click **Queue** or its **List Plus** icon to expand the inline section.

## Integration and next checks

- Prefer `Setup.ini` for the initial suite layout; Media.ini requires the WNP
  plugin, which the `.rmskin` bundles (source copies need a manual install).
  Preserve `@Resources/User/Media.inc` on upgrades.
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







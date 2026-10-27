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
  User Round Group and Disc 3 icons identify the metadata rows. The one-line
  title reads `Media Player: stopped` (or `paused` for a paused track) behind
  Lucide Monitor Play when nothing is playing, and `Media Player: <player>`
  behind Lucide Audio Lines while a track plays, animated at 20 fps by default
  (10 fps or static by the Title animation setting). The compact layout
  shortens the label to `Media:`. Other playback-state captions
  are omitted.
- Previous, play/pause, and next controls use WNP capability measures. Unsupported
  controls appear muted with an inactive cursor and send no command. Lua checks
  connection/support again when clicked. Lucide rewind, play/pause and
  fast-forward artwork retains track-skip behavior.
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
- A spectrum drawer folds the Visualizer into the player: a folder tab above
  the hover gear opens a sheet that rises above the panel and shows the
  Visualizer's 24-band output spectrum. Its AudioLevel capture exists only
  while the drawer is open. See [Spectrum drawer](#spectrum-drawer).
- At two columns, a rounded album tile measuring 169 pixels at the current
  default (20 pixels larger in both dimensions than the preceding layout) with a thin white border
  overhangs the top and left edges of a narrower
  panel. Track details and playback controls occupy the right column; Queue spans
  the black panel's inner width below the cover.
  The composition retains the suite's double-width snapping bounds.

## Dependencies

| Feature | Dependencies | Cadence and fallback |
| --- | --- | --- |
| Base UI and Setup — required | Windows, Rainmeter, built-in measures/meters and bundled Lua/includes. | The player updates every 50 ms (`MediaAnimationInterval`) while its title icon can animate (`MediaTitleAnimation` 20 or 10) or the spectrum drawer is open, and every `MediaInterval` (1 second) otherwise; `MediaLegacyDivider` keeps provider polling and queue/options reads at `MediaInterval`. Meters repaint on change, not on that tick: Media.ini's `DefaultUpdateDivider` holds every meter without its own divider to the 1-second cadence, static meters use `UpdateDivider=-1`, and the title icon joins periodic updates only while a track plays (see [Paint on change](#paint-on-change-2026-10-22)). Setup updates at `MediaInterval` and loads without external plugins. |
| Spectrum drawer — optional, plugins bundled with Rainmeter | Rainmeter's bundled AudioLevel and Win7AudioPlugin plugins, a Windows output endpoint, and the Visualizer module's shared `Modules/Visualizer/{Fallbacks,Options,Capture,Audio,Spectrum}.inc`, `HeightPresets/*.inc`, `Color.lua`, `SpectrumPaths.lua` and `User/Visualizer.inc`. Media settings' Spectrum section adds `Modules/Visualizer/SettingsShared.inc` and `Settings.lua` (event-only; its numeric input is the shared one-shot helper, launched only by a click). Writes `AnchorY` and its `ParallaxDrawerAnchorY` record in this config's own Rainmeter.ini section on tab clicks, Media settings saves and any load whose drawer-owned anchor does not match (that load-time repair's `!SetAnchor` also rewrites `AnchorX` with its existing value); a user-set anchor is never changed. Since 2026-10-23 the open drawer's capture lease also uses the bundled input-idle coordinator config `Parallax\Idle` (`Idle/Idle.ini`, `@Resources/Idle/Coordinator.lua` and `Link.lua`), which reads Rainmeter's built-in SysInfo `IDLE_TIME` (keyboard and mouse input only) every 2 s while you are away or skins are paused, and about once a minute while you are at the computer, and is loaded only while the drawer is open and not deferred, and the bundled runtime state file `Modules/Media/CaptureState.inc` (shipped at zeros, written only by `MediaOptions.ApplyLease`). | Capture and Win7Audio exist only while `VisualizerDrawer=2` and the capture is live (`MediaDrawerCapture=0`); collapsed, hidden, paused, deferred and Setup load no AudioLevel or Win7Audio measure. The lease parks the capture after 2 minutes of silence while you are away 5 minutes and nothing plays, and resumes it on input, WebNowPlaying Playing or a click ([Capture lease](#capture-lease)). Without the coordinator (missing or unloaded) the drawer stays live: a paused drawer resumes 10 s after a load without a sync, or 3 minutes after the last beat. Live, it runs on Media's 50 ms tick (100 ms for the Visualizer's 100 ms choice); Win7Audio volume, device name and device status once a second each (the volume was read every 250 ms before 2026-10-22). Win7Audio errors show `--`, mute shows `Muted`; a failed numeric getter can leave an old volume. The output row's click/wheel switches the system default output (no volume or mute command). A missing or unavailable endpoint shows `Output unavailable`; quiet output shows `Idle - quiet`; an invalid format shows `Unsupported format`. While the standalone Audio Visualizer is loaded the drawer defers to it (state 2) instead of running a second capture, and takes the capture back when it unloads; the standalone's event-only `Companion.lua` notifies Media through two silent group bangs. |
| Fonts and icons — bundled | Private IBM Plex Sans fonts ([license](../../Skins/Parallax/@Resources/Licenses/IBM-Plex-OFL.txt)); native Shape adaptations of Lucide artwork ([provenance and licenses](../../Skins/Parallax/@Resources/Modules/Media/Icons/Lucide/README.md)). | No download, system font installation or SVG-rendering plugin required. |
| Typed numeric settings — bundled | Rainmeter's bundled RunCommand plugin, Windows PowerShell/.NET WinForms and the shared `Scripts/SettingsInput.ps1` overlay. | An explicit numeric-field click starts one temporary editor. Fixed numeric/cancel output is revalidated before saving; invalid, cancelled, unrequested or hidden-field results do not save. No polling or provider starts. |
| Playback metadata and controls — optional, plugin bundled | [WebNowPlaying](https://wnp.keifufu.dev/rainmeter/getting-started) plugin 2.0.7.0 (MIT License, keifufu and Trevor Hamilton), bundled in the Parallax `.rmskin` from `packaging/Plugins/WebNowPlaying` and installed by Skin Installer unless a newer version is present ([license](../../Skins/Parallax/@Resources/Licenses/WebNowPlaying-LICENSE.txt), [provenance](../../packaging/Plugins/WebNowPlaying/README.md)); a supported player. Browser playback additionally requires the separately installed WebNowPlaying browser extension; desktop adapters are also separate. A development copy of the skin without the package needs a manual plugin install (2.x+). | Sampled on the skin update; `MediaInterval` does not throttle WNP internally. Inactive connections show no active media; unsupported controls remain disabled. Setup unloads the optional plugin. Since 2026-10-27 the shuffle and repeat toggles read WNP's `Shuffle`, `Repeat`, `SupportsToggleShuffleActive` and `SupportsToggleRepeatMode` player types and send its `Shuffle` and `Repeat` commands; a player that does not report support shows them muted and unclickable. Whether a given player (Spotify desktop included) reports that support is unverified. |
| Spotify source identification — optional | Bundled `SourceProvider.ps1` and the shared `ProviderOwner.psm1` owner lease, Rainmeter's bundled RunCommand plugin, Windows PowerShell 5.1, built-in .NET and Windows media-session APIs. No Spotify authentication or network request. | Explicit Start uses a dormant `State=Hide` RunCommand control and enables one persistent observer targeting a 2-second collection cadence, with load-time recovery through `MediaLifecycle.lua`/`Lifecycle.inc`. Stop uses the same hidden event-only path. Between collections the observer waits on its owner Rainmeter and a stop event, not a poll, and rewrites its snapshot every cycle while Spotify plays and otherwise only on change, plus a heartbeat about every 4 seconds. Observations expire after 6 seconds. Missing or inconclusive evidence leaves generic Windows playback identified as `Unknown`. |
| Idle pause — optional, bundled suite component | The hidden `Parallax\Idle` input-idle coordinator (built-in SysInfo `IDLE_TIME`) through `@Resources/Idle/Hook.inc` and `StandDown.lua`; `Modules/Media/CaptureState.inc` (`MediaStandby`) written only by `MediaOptions.lua`. | Only while Global Settings **Idle pause** is 5, 10 or 30 minutes (default Off). Media.ini reloads once into standby (provider cadence, drawer parked) and freezes; input reloads it once back. Setup and Queue freeze in place. Off loads a comment-only include; a standby state saved while the pause is Off is cleared at the next Media.ini load. No coordinator sync 10 s after a standby load, or no beat for 3 minutes, returns to live. See [Idle pause](#idle-pause). |
| Update check — optional, bundled suite component | Automatic update check: Rainmeter's built-in WebParser and the bundled `@Resources/Update/Hook1.inc` (`Update.lua`, `Feed.inc`, `State.inc`, `Version.inc`). | Optional bundled suite component, on by default: Global Settings **Updates** > **Auto check** Daily (`UpdateCheck=1`). Off loads the comment-only `Hook0.inc`. About once a day, one request for the release feed on github.com, made by whichever loaded utility finds the check due (60 s after a load, then an hourly `[!Delay]` look); a newer release opens the `Parallax\Update` prompt. No meter, process or plugin; offline and failed checks are recorded quietly and retried after an hour. See [Updates](../UPDATES.md). |
| Spotify queue — optional | Bundled `QueueProvider.ps1`, `QueueCore.psm1`, `QueueAuth.psm1` and the shared `ProviderOwner.psm1` owner lease; Rainmeter's bundled RunCommand plugin; Windows PowerShell 5.1/.NET; network access; Spotify Developer app public Client ID and user-authorized PKCE sign-in. The [queue setup guide](../../Skins/Parallax/@Resources/Modules/Media/Queue/README.md) records Development Mode prerequisites, including owner Premium and user allowlisting. No client secret. | Start, Stop, Restart and Disconnect use dormant `State=Hide` RunCommand controls with a fixed allowlist and do not overlap. One opt-in worker requests every 30 seconds by default, configurable to 30–150 seconds, subject to backoff/quota pauses. Sign in deliberately retains a visible setup console/browser flow. Passive views read local snapshots on their update. Missing, stopped, expired or failed data produces explicit status and suppresses rows. Since 2026-10-27, clicking a row or **Refresh** runs one short hidden `QueueProvider.ps1 -Command Play`/`Refresh` on a dormant `State=Hide` RunCommand host (`Queue/QueueControlHost.inc` in Media.ini; Queue.ini's existing host); it only hands a request file to the running worker and exits. Skipping needs the optional `user-modify-playback-state` permission, now requested at sign-in; a grant without it keeps reading the queue but rows are not clickable until you sign in again. Spotify's skip endpoint acts on the account's active device and needs Premium. |

Both provider helpers require an explicit initial Start (or successful queue sign-in).
They save private enabled intent and can resume once when their Media view loads
in the normal `%APPDATA%\Rainmeter` profile. Stop disables recovery; queue Disconnect
also disables it. Missing or invalid intent never opts in. Settings and isolated
preview profiles never restore providers. There is no startup task or service.
A worker started from Rainmeter exits with that Rainmeter process (see
[Provider lifetime](#provider-lifetime-and-upgrades)), and every worker runs with
its LocalAppData data root as working directory, never the skin folder.
Source makes one wait per 2-second cycle, on its owner process and a stop
event; Queue's 1-second internal waits are stop/scheduling checks. Neither is
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
| `MediaInterval` | `1000` | Milliseconds between provider samples and text updates; also the skin's whole update interval while the title icon cannot animate (`MediaTitleAnimation=0`) and the drawer is closed. Does not throttle WNP's internal work. |
| `QueueExpanded` | `0` | Remember the inline queue section as collapsed or expanded. A confirmed empty queue saves the collapsed state. |
| `QueueRowLimit` | `5` | Maximum shown entries, every integer 1–5; arrow step 1 or typed value. |
| `QueueShowDetails` | `1` | Show artist/podcast details beside titles; 0 hides them. |
| `QueuePollSeconds` | `30` | Spotify request interval in whole seconds, 30–150; arrow step 1 or typed value. |
| `VisualizerDrawer` | `1` | Spectrum drawer above the player: `0` hidden, `1` tab only, `2` open (captures the output device). Literal digits only. |
| `MediaTitleAnimation` | `20` | Title icon animation while a WebNowPlaying player reports Playing: `20` or `10` frames per second, or `0` for a static icon. Any other number means 20; use literal digits. With `0` and the drawer closed, Media updates once per `MediaInterval` instead of every 50 ms. Media settings' Title animation row. |

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
Playback buttons use 24-pixel
vector artwork on 34-pixel circular faces. Statuses, queue rows and Setup
actions retain the chosen body `FontSize`; Setup actions remain 18 pixels tall.
Actions use zero local padding. Primary actions use
`AccentColor`; the gear, documentation, Stop and secondary settings/navigation actions
use `AccentColor2`. Metadata icons use `MutedColor`; the Monitor Play and Audio Lines title icons
and queue status retain `MediaColor`, and
unavailable actions remain muted. The double layout provides more metadata/time
space. The three transport circles form a row centered on the panel's lower
border, so half of each sits outside the panel; horizontally the row is centered
in the panel width remaining to the right of the artwork. Faces are 34 logical
pixels with four-pixel gaps, so the group spans 110. Each meter box carries a
five-pixel pad for the faked drop shadow, so adjacent boxes overlap by design
while the faces keep their gap. Timing is right-aligned to the progress bar and
no longer shares that row; it auto-sizes within a fixed maximum width - which
still reserves the span the controls used to occupy - and long times clip
without growing the window. Setup uses the same panel and queue row.
The time readout aligns with the progress bar's right edge and starts two logical
pixels below the bar. Available and unavailable time use the same position.
The bar preserves its prior center where space allows and keeps at least two
logical pixels below metadata. The controls no longer follow the bar: they are
anchored to the panel's lower border, and the panel's height excludes both them
and the overhanging artwork so neither can drive it. The window height clears
that overhang instead.

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

The settings panel is always two pitches wide. It is 814 logical pixels tall
with Queue expanded and 758 with Queue collapsed (786/730 before the Title
animation row, 582/526 before the Spectrum section, 554/498 before the
Spectrum drawer row). That row sits directly under Panel columns: a wrapping previous/value/next
group for Hidden, Collapsed and Expanded with a 76 px field (the shared stepper
widened so the longer names fit at the largest body size). Saving it asks Media
to place its anchor and reload. **Title animation** (owner decision,
2026-10-22) follows it: the same wrapping group over Off, 10 fps and 20 fps
(`MediaTitleAnimation` 0/10/20) in the default 56 px field; the label, frame
and value step forward like `>`. A saved number other than 0 or 10 shows as
20 fps, which is how Media reads it, and text that is no number shows Off.
Saving writes the one key and refreshes
Media, which chooses its tick and pulse cadence when it loads (and the
standalone Queue, as every display key does). The label reads Title animation
rather than the setting's full name, which would clip in the 114 px label
column at the 10 pt maximum body size.

**Spectrum section** (user request, 2026-10-11: the drawer should offer every
setting the standalone has). Between Display and Queue sampling, Media settings
shows Audio settings' own ten steppers — Height, Bar gap, Color, Top round and
Axis gap under a *Spectrum* heading on the left; Quality and Interval under
*Performance* and Sensitivity, Attack and Decay under *Animation* on the right —
on Audio settings' two-column grid and Media's 28 px pitch. They are not a copy:
both windows include `Modules\Visualizer\SettingsShared.inc`, which holds the
rows, their String displays, the Visualizer `Settings.lua` controller and its
dormant numeric-input host, placed by four host variables
(`VisualizerSettingsTop`, `LeftShift`, `RuleDrop`, `AppearanceTitle`). Every
change writes the one shared `User\Visualizer.inc`, refreshes the standalone
Visualizer, asks Media's drawer to reload if it is open, and shows the new value
in place (`!SetVariable` plus an update of that row's display) — neither
settings window reloads itself any more.

**Load cost.** The section makes Media settings slower to open: about 3.1 s
against 1.4 s before, measured as Rainmeter's "Refreshing skin" to the skin's
`OnRefreshAction` over five refreshes in an isolated instance (2026-10-11).
Nearly all of that was tooltips: Rainmeter creates one tooltip window per
meter that has `ToolTipText`, which a 100-meter benchmark measured at about
40 ms each on this host (about 60 ms for 100 plain String meters without
tooltips, about 4 s with), while `DynamicVariables` and the bundled fonts made
no measurable difference. All tooltips were then removed suite-wide at the
user's direction (see above), which removes that cost; the post-removal load
time is recorded in the validation report.
Width stays out (Media's own Panel columns governs the drawer's width). Media
settings reads the Visualizer's Height through `VisualizerSettingsHeight`,
captured, as in Media.ini, by including `HeightPresets\#PanelHeight#.inc` right
after `User\Visualizer.inc`, because Media's own `PanelHeight` (162) replaces
the Visualizer's once every file is read. The section moves with the queue rows
above it: `Settings.lua` re-sets `VisualizerSettingsTop` with the window height.
The quiet threshold and a custom device ID remain hand-edited in
`User\Visualizer.inc` (Audio settings' Advanced button opens it).
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
standalone Queue panel. Shared sampling, source
detection, sign-in and recovery controls stay visible; collapse never stops
polling. `QueueShowDetails` has no additional settings beneath it to collapse.
Reflow uses the existing initialization, save and refresh paths, without a new
visibility preference or checking whether another skin or provider is active.
Its three numeric controls accept columns 1–2, queue rows 1–5 and queue refresh
30–150 whole seconds. Each arrow moves by one and clamps without writing or
refreshing at a bound. Every previously supported integer remains valid; the
former 1/3/5-row and 30/60/120-second menu presets no longer limit the editor.
Values use the body color, arrows use Accent 1, and units remain in labels.
Each group is 96 logical pixels wide: 18-pixel arrows, two-pixel gaps
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

## Spectrum drawer

User direction, 2026-10-10: fold the Visualizer into the player as an upper
slider, like the queue drawer but on top, with its tab near the top-right
corner. Of the variants mocked up, the user chose a folder tab that rises
*above* the panel over a notch cut into its top border (the notch would have
cost the title 36 px and moved the gear 36 px left). The user also chose to
show the tab by default at both widths and to have the open spectrum follow the
Audio settings Height preset.

**Shape.** A second sheet sits behind the panel and rises above it, the mirror
of the queue sheet below. Collapsed, only its tab shows: the gear's own 18 px
column, carried up into the 12 px strip that the double-width artwork already
leaves above the panel (the art overhangs the panel's top by
`MediaSurfaceOffset`). The panel's top border runs straight across in front of
the tab's base, the way a folder's front cover crosses the back sheet's tab, so
neither the title nor the gear moves. The tab's right edge is
`Min(ContentX+ContentWidth, panel right − CornerRadius)`: the gear's right
edge, unless a corner radius larger than the padding would put the tab on the
corner's curve. Open, the sheet ends at the queue sheet's right edge
(`ContentX+ContentWidth`) and starts the plot inset left of the dB gutter
(`MediaVisualizerOpenSheetX`, user request 2026-10-25: no unused margin left of
the scale; at the default double width x 129 rather than the panel's x 100,
compact unchanged at the panel's edge); its only object is the spectrum plot
with its axes. The sheet's square bottom is tucked
`Max(8, CornerRadius)` logical px behind the panel, so the panel always hides it.

**Control.** An original three-point chevron (24-unit points 6,15 / 12,9 /
18,15, the same form as Lucide's chevron-up; no source bytes are copied) in
`HeaderTextColor`, at the queue icon's 14/24 Lucide scale and 2-unit round
stroke. It points up while collapsed and flips down while open, the way List
Plus/Minus swaps below. Collapsed, the whole 12S strip above the panel in the
gear's column is the hit target (18×12 px at scale 1), so it overlaps neither
the gear nor the title. Open (user requests 2026-10-25: first tried top-left,
then top-right), the control is in the sheet's top-right corner: the output
row's last 18S column (`MediaVisualizerToggleX/Y/Width/Height`, an 18×18S
target at `Floor(MediaVisualizerRowRight − 18S)`), its chevron mirroring the
speaker icon's 14S box — centred 7S in from the row's right edge (the plot's)
and 9S below its top. The device name and the device-switch target end at the
target's x. The tab's edges snap to whole
pixels, as Rainmeter truncates the gear's own position; where 18×Scale is
fractional the tab is 14 px (scale 0.75) or 23 px (1.25) wide and the chevron,
kept on the gear's centre, sits 0.25 px left of the tab's own centre. The
chevron is centred by its stroked bounding box. As an open stroke it does not
read as a solid figure, so the centroid rule used for the transport glyphs does
not apply; its round end caps put its ink centroid 0.267 units (0.156×Scale px)
toward the open ends. Measured on the native captures with linear coverage
weights, the ink centroid is at x 437.0 (double) and 209.0 (compact), the
gear's centre column, and vertically 10.60 px collapsed (band centre 10.5) and
99.90 px open (band centre 100). Since the 2026-10-25 plot move the open band
was the strip under the plot; in the top-right corner the open chevron's ink
spans x 427–434, y 19–22 (centroid 431.00, 20.86) double-width and x 199–206
(centroid 203.00) compact, level with the speaker icon's ink (centroid y 21.38).

**Preference.** `VisualizerDrawer` in `User\Media.inc`: `0` hidden, `1`
collapsed (default), `2` open. The tab toggles between collapsed and open,
following what is on screen; Media settings steps through all three with
wrapping previous/next arrows. The value also names the include Media.ini
loads (`Modules\Media\VisualizerDrawer<n>.inc`), and only `VisualizerDrawer2.inc`
opens the drawer geometry, so the window never lifts an empty sheet. Save only
the literal digits: another number equal to 1 or 2 (for example `02`) shows the
collapsed tab, any other text hides it, and both log one Rainmeter
"Unable to read file" error for the missing `VisualizerDrawer<value>.inc`; the
next tab click or settings step writes a literal digit again. Hidden restores
the previous window size and panel position exactly, including the compact
panel's flush top.

**Geometry** (`InlineQueueGeometry.inc`; S is `#Scale#`). Everything vertical in
the player is now measured from one origin, `MediaTop = Inset + Lift`, where
`Lift = Open × OpenLift` and
`OpenLift = Ceil(PlotInset + DeviceRow + PlotHeight + OriginGap)`
— the queue sheet's inset at the far edge, and the plot's bottom edge
`OriginGap` above `MediaTop`. **Plot origin** (user requests, 2026-10-25): the
plot's lower-left corner sits north-east of the double-width artwork's
top-right corner with a 5S buffer both ways (`MediaVisualizerOriginGap`) — its
bottom edge 5S above the art's top (`MediaTop`) and its left edge 5S right of
the art's right edge (`MediaCoverX + MediaCoverSize`), so the plot is 29 px
narrower than the original layout at the default. `MediaVisualizerPlotX` takes
the larger of that and `MediaSurfaceX + PlotInset + AxisWidth`, so the dB
gutter can never leave the inset; the compact layout (art below the title)
always uses the latter, and keeps the 5S buffer above the strip. **Output
row** (user request, 2026-10-11): `DeviceRow = 19S` above the plot
(`MediaVisualizerDeviceRow`: an 18S row, then 1S to the frame) carries the
standalone's output row — the 14S Lucide Speaker in `MediaColor` and the
clipped device name 18S to its right, out to the plot's right edge. It starts
at the dB gutter's left edge (`MediaVisualizerRowX`), which the trimmed sheet
moves right with the plot. One transparent target spans the row and switches
the Windows default output exactly as the standalone's row does (see Capture
and cadence). **Volume** (user request, 2026-10-25): the read-only Windows
output volume is the panel's headline value in the gear's spot, like CPU's
total — body font in `TextColor`, right-aligned to the gear's right edge and
centred on the title row, so it shares the title's baseline. Media.ini's
`MouseOverAction` hides it (group `MediaHeaderValue`) and shows the gear;
`MouseLeaveAction` reverses that. Group bangs on a closed drawer, which has no
volume meter, log nothing. While the drawer is open the title reserves 40S for
it instead of the gear's 24S (`MediaHeadingWidth`); closed, nothing changes. **Axes** (user request, 2026-10-11) match the
standalone Visualizer's: a 40S gutter left of the plot
(`MediaVisualizerAxisWidth`) holds the relative dB scale — `0 dB` top-aligned,
minus half the sensitivity centred, minus the sensitivity bottom-aligned on
the bar baseline, each right-aligned 4S from the frame. The frequency labels
have no row of their own (2026-10-25; it was a 19S row plus the 4S section gap
under the plot): they sit in the 12S strip between the plot and the panel's
top border, beside the art. Their boxes are
centred 1S above the strip's centre (`MediaVisualizerAxisLabelY`), an optical
correction: a centred box put the digits' ink 1 px low. `40 Hz` starts at the
origin's x (`MediaVisualizerLowLabelX`), which the 5S buffer keeps clear of the
art's white border; `16 kHz` ends at the plot's right edge
(`MediaVisualizerHighLabelRight`) again, now that the open chevron is in the
top-right corner (it briefly ended 4S short of a chevron in the strip). The user
first asked for `40 Hz`'s right edge to be flush with the title icon's; that
would start the label left of the origin, over the art's corner, so at the
default its ink (x 177–207) ends 11 px past the icon's (x 181–196). Labels
use the body font in `MutedColor`. The gutter sits inside the left inset, so
the inset still governs corner clearance. `PlotHeight` is the standalone Visualizer's own plot height for the
Audio settings Height preset (`VisualizerPlotHeightPx` in the shared
`Options.inc`), so the drawer's spectrum is the same size as the standalone's.
`PlotInset` is the queue sheet's `MediaDrawerPadding` (8S) unless the open
sheet's rounded top corners would come closer to the plot frame's corners than
that padding keeps along the straight sides (Padding − Border). With
R = CornerRadius×S and B = BorderThickness×S, the sheet's inner stroke edge is a
circle of radius R − B/2 centred B/2 + R in from each edge, and the frame's
outer edge a circle of radius 2S + 0.5, so the inset is
`Max(Padding, Ceil(B/2 + R − (2S+0.5) − (R − B/2 − (2S+0.5) − (Padding − B))/√2))`.
It equals the padding up to CornerRadius 10 at scale 1 with a 1 px border; it
is 9 at CornerRadius 11–12 and 13 at CornerRadius 24 with a 4 px border. The
compact layout reserves the same 12S strip while the tab can show:
`MediaSurfaceOffset = Round(12 × Max(MediaWide, Shown) × S)`. The window adds
`Lift` above the panel band; the overhang and the open queue sheet are absolute
positions and already include it.

| Width 220, scale 1, CornerRadius 6, BorderThickness 1 | Double | Compact |
| --- | --- | --- |
| Hidden (`0`) window | 456×186 | 228×174 |
| Collapsed (`1`) window | 456×186 (unchanged) | 228×186 |
| Tab box, radius | x428–446, y4–16, r6 | x200–218, y4–16, r6 |
| Open (`2`) window, Normal preset | 456×298 | 228×298 |
| Open sheet x-range | 129–446 | 4–218 |
| Output row (x-range, y-range): icon/name/target, then chevron column | 137–420, 420–438; y 12–30 | 12–192, 192–210; y 12–30 |
| Open plot (x, y, w×h) | 177, 31, 261×80 | 52, 31, 158×80 |
| Art top-right corner, open (clear columns/rows to the plot) | (172, 116); x 172–176, y 111–115 | — |
| dB label boxes (x-range) | 137–173 | 12–48 |
| Frequency labels: 40 Hz left, 16 kHz right, box centre y | 177, 438, 121 | 52, 210, 121 |
| Measured label ink (x, y) | 177–207 and 400–437, y 117–125 | 52–82 and 172–209, y 117–125 |
| Open toggle (top-right corner) | x420–438, y12–30 | x192–210, y12–30 |
| Volume (title row): right edge, measured ink | 446; x 420–445, y 140–147 | 218; x 192–217, y 140–147 |
| Panel top in window, collapsed → open | 16 → 128 | 16 → 128 |

| Height preset (Audio settings) | Plot | Lift, open window growth |
| --- | --- | --- |
| Small 126 | 60 | 92 |
| Normal 146 | 80 | 112 |
| Tall 186 | 120 | 152 |

The plot keeps the Visualizer's 54 logical px minimum of usable bars, so a
large axis gap can raise these numbers as it raises the standalone's. A border
thicker than 2 px lowers the plot by up to 2 logical px (`VisualizerTopShift`):
BorderThickness 4 on Normal gives a 78 px plot, a lift of 110 and an open
456×296 window. The grid lines sit on pixel centres (`Floor(BarHeight×k/4) + 1.5`,
within half a pixel of each quarter), so each renders as one crisp row; the
standalone Visualizer's plot uses the same rule.

**Keeping the panel still.** A Rainmeter window grows down and right from its
top-left corner. Rainmeter keeps a skin's anchor point at the saved `WindowY`
(`AnchorY` in its Rainmeter.ini section), so `MediaOptions.lua` keeps this
config's `AnchorY` equal to the open lift (0 otherwise). The panel's screen top
is then `WindowY + Inset + MediaSurfaceOffset` in every state, and the window
grows upward instead. The tab writes `VisualizerDrawer`, reads it back,
pre-writes `AnchorY` into `#SETTINGSPATH#Rainmeter.ini` and reads that back,
then refreshes; the refresh reads the new anchor and draws the new layout at
its final position. A once-per-load check (`MeasureMediaVisualizerLift`,
`CheckAnchor()`) repairs a mismatch with `!SetAnchor` — on Rainmeter start,
when switching between Media.ini and Setup.ini, after a hand edit, or after a
Scale or height change while the drawer is open. A fresh load corrects the
anchor before its window is shown; a refresh of a visible skin can show one
displaced frame.

Media corrects only an anchor it owns: Rainmeter's default 0, or the value it
last wrote, which it records as `ParallaxDrawerAnchorY` beside the anchor in the
same Rainmeter.ini section (a saved layout copies both together). Any other
`AnchorY` — a hand-set pixel value, a percentage or a bottom-relative value — is
the user's own and is left alone in every state, including hidden and Setup;
the panel then moves when the drawer opens (a 50% anchor moved it by half the
lift in the native check). So Media writes three keys, all in this config's own
Rainmeter.ini section: `AnchorY` and `ParallaxDrawerAnchorY` on tab clicks,
Media settings saves and any load whose owned anchor does not match, and
`AnchorX` — rewritten with its existing value, or 0 when absent — whenever that
load-time repair uses `!SetAnchor`.

Near the top of a monitor, Rainmeter's KeepOnScreen clamps the grown window,
so the panel drops by the overflow while the drawer is open and returns when it
closes; with KeepOnScreen off the drawer goes off-screen instead.

**Capture and cadence.** Media.ini includes `VisualizerDrawer2.inc` only in the
open state; states 0 and 1 load comment-only stubs, so collapsed and hidden
Media contain no AudioLevel measure at all (AudioLevel opens its capture at
initialization, so `Disabled=1` would not have stopped it). The open drawer
hosts, in its live variant (see [Capture lease](#capture-lease)), the
Visualizer's shared `Capture.inc` (one output parent plus device,
format, RMS, state and 24 band children) and `Spectrum.inc` (band geometry,
palette script, mask and fill), and the standalone's `Audio.inc`: the two
once-per-load dB-tick Calcs, one Win7Audio volume measure (read once a
second since 2026-10-22: `VisualizerVolumeDivider = Round(1000/50) = 20`
ticks; it was 250 ms), its two Calc bindings,
and two more AudioLevel children of the same parent — the device name (once a
second, 20 ticks) and the load-only device list. So Win7Audio, like AudioLevel,
exists only while the drawer is open. Clicking the output row (or wheeling
down) sends Win7Audio `ToggleNext`, wheeling up `TogglePrevious`: this changes
the **system-wide** default output and can redirect playing apps; no volume or
mute command is ever sent. It then clears `VisualizerDeviceID` in
`User\Visualizer.inc`, refreshes the standalone Visualizer (a warning in the
Rainmeter log if it is not loaded) and reloads Media through
`RefreshVisualizerDrawer()`, which re-runs provider resume like any Media
refresh. The standalone's own row now asks Media's open drawer to reload too,
so both captures follow the new default. While
the drawer is open Media updates every 50 ms (`MediaTickInterval` picks the
fast tick for an open, live drawer even with the title animation off), so no other
skin's cadence changes. The Visualizer interval maps onto that tick through
`VisualizerCaptureDivider = Max(1, Round(interval / 50))`: 50 and 33 ms run
every tick (33 ms cannot be met inside Media), 100 ms every other tick.
Collapsing, and any Media refresh while open, releases and reopens the capture
(AudioLevel's finalize path, reviewed in source). With a blank
`VisualizerDeviceID` the drawer follows the default output that was current
when it opened, until Media next refreshes. If the standalone Visualizer is
also loaded, the drawer defers to it instead of running a second capture
(see [Capture lease](#capture-lease)); before 2026-10-23 two independent
loopback captures ran.

**Shared preferences.** Media.ini reads `Modules\Visualizer\Fallbacks.inc` and
`User\Visualizer.inc` *before* Defaults.inc and `User\Media.inc`, so Media's
own `Columns` and `PanelHeight` win while every other Visualizer choice (color
mode, bar gap, radius, axis gap, quality, sensitivity, attack, decay, device ID,
idle threshold, interval) drives the drawer. The Height preset is captured by
file name: Media.ini includes `HeightPresets\#PanelHeight#.inc` right after
`User\Visualizer.inc`, because Rainmeter resolves an include path when it reads
it, while `PanelHeight` still holds the Visualizer's value; variables resolve
only after every file. Only the three presets exist, so a hand-edited
non-preset height logs one missing-file error in Media and the drawer keeps
Normal. Global colors come from Defaults, User\Settings and User\Media as
before, so a color override kept in `User\Visualizer.inc` does not reach Media.
Saving any Audio setting except Width, and the standalone Visualizer's
Quality and Cadence menu items, ask Media to refresh; Media does so only while
its drawer is open. Like a queue or drawer toggle, each such refresh reopens
the capture and re-runs provider resume: one hidden, mutex-guarded
`powershell.exe -Command Resume` per enabled provider, which starts no
duplicate worker.

**Setup.ini** sets `MediaVisualizerHost=0` before its includes: no tab, no
capture include and no lift, but the same panel position as Media.ini
(including the compact strip). It includes only the variable files Fallbacks.inc
and Options.inc so the shared geometry chain resolves; it stays plugin-free.

**Known limits.** At compact width the open sheet's square left edge shows
inside the panel's rounded top-left corner, the same way the queue sheet
already shows at the bottom-left. A translucent `BackgroundColor` shows both
sheets through the panel. Whether AudioLevel releases the capture on collapse
was reviewed in source but not measured live. The open drawer costs about 9%
of one core with square bars and 11% with 4 px rounded bars, against 8–10%
collapsed. As first shipped it cost 96%, because its band paths re-parsed
Media's 7 KB plot-width formula dozens of times per bar on every tick;
`SpectrumPaths.lua` now compiles them once per load (see
[PERFORMANCE.md](../PERFORMANCE.md#spectrum-drawer-path-cost-2026-10-11)).
There is still no slide animation: the
tab writes the preference and refreshes, which restarts the skin.

### Capture lease

Performance review theme T2 (VIS-01, MEDIA-05, XMOD-02, ENGINE-03; owner
decision 1, 2026-10-22). Rainmeter 4.5.28's AudioLevel `Port=Output` starts a
silent render stream beside its loopback capture and stops it only when the
measure unloads, so an open drawer keeps the Windows audio engine (audiodg)
running all night: measured live at 9.8% of a core while open, and not running
at all while collapsed. Disabling or pausing the measure does not release it;
only a reload into an include without AudioLevel does.

**Variants (2026-10-23).** `VisualizerDrawer2.inc` keeps what every open drawer
shows: the drawer geometry, the plot frame and grid, the static `0 dB` /
`40 Hz` / `16 kHz` labels, the speaker icon and the status overlay. Its last
section includes `Modules\Media\DrawerCapture<MediaDrawerCapture>.inc`, chosen
by the runtime file `Modules\Media\CaptureState.inc`:

| `MediaDrawerCapture` | Variant | What it loads and shows |
| --- | --- | --- |
| `0` (shipped) | Live | The former open drawer's live content, unchanged and in the same order: `Capture.inc`, `Audio.inc`, the palette hook, device name, volume and output-switch target, the two sensitivity ticks, then `Spectrum.inc` last. |
| `1` | Capture paused | No AudioLevel, Win7Audio or spectrum script. The plot says `Capture paused` in `MutedColor`; the device name and volume read `--`; the sensitivity ticks come from two local Calcs. A transparent target over the whole plot (alpha 1, hand cursor, no tooltip) resumes the capture on a click. |
| `2` | Deferred | No AudioLevel, Win7Audio or spectrum script, and nothing clickable. A message in the drawer's own fill covers the plot box and its dB gutter: `Spectrum is shown in Audio Visualizer`, within two lines down to width 180, scale 0.75, compact, with the largest body font (inside the plot alone it would need three there); the axis labels are blank and the output row reads `--`. |

All three share the drawer geometry, so the window keeps its size and the panel
does not move. Media's tick adds the 50 ms drawer term only while the capture is
live (`...*(VisualizerDrawer=2)*(MediaDrawerCapture=0)` in
`InlineQueueGeometry.inc`); the title animation keeps its own term. The live
variant draws exactly what the drawer drew before the split: the meters that
now draw before it (`0 dB`, `40 Hz`, `16 kHz`) overlap none of the moved ones.

**Single writer.** `MediaOptions.ApplyLease(capture, standby, reason)` is the only
writer of `CaptureState.inc`. It reads the file (an unreadable file, a missing
`[Variables]` section or a repeated key fails closed), returns if nothing
changes, writes only the changed keys, reads them back and refreshes Media at
most once per load, so several changes before that posted refresh coalesce
into it. Lease reasons (park, unpark, defer, reclaim, standby, fail-live) also
stamp `MediaLeaseRefreshAt`/`MediaLeaseRefreshClock`, so that reload starts no
provider resume (see [Provider recovery](#provider-recovery-after-restart)). The
tab and Media settings write the state with reason `toggle`: opening,
collapsing or hiding the drawer starts it live (or deferred while the
standalone Audio Visualizer is loaded; see below), with no stamp and no extra
refresh, because their own refresh carries it. Collapsing and hiding
also ask a loaded [input-idle coordinator](../ARCHITECTURE.md#input-idle-coordinator)
to re-check whether anything still needs it (a silent group request).
`CaptureState.inc` ships at all zeros and a release install resets it.

**Park and resume (2026-10-23).** `Modules\Media\CaptureLease.lua` runs in every
open-drawer variant (`MeasureMediaCaptureLease`, about once a second at the
provider cadence, plus each idle broadcast). It parks the capture (state 1)
when all of these hold:

- the drawer has been silent for 2 minutes: no once-a-second sample of
  `MeasureVisualizerState` showed signal since this load (`Output unavailable`
  and `Unsupported format` count as silence; any signal sample restarts the
  2 minutes, and so does every reload);
- the `Parallax\Idle` coordinator reports you away, that is 5 minutes without
  keyboard or mouse input, with a beat younger than 3 minutes;
- no WebNowPlaying player reports Playing.

So the drawer parks at the later of the two thresholds. It resumes (state 0)
on your next input (the coordinator's next tick, within 2 s), when a
WebNowPlaying player reports Playing (within the 1 s provider cadence), or on
a click on the paused plot. It also fails live (resumes) when no coordinator
has synced 10 s after a paused load (missing, unloaded or blocked), or when the
coordinator's beat goes 3 minutes stale; a gap in the lease's own schedule
(sleep) re-arms that clock instead. Unloading the coordinator resumes at once,
because its `OnCloseAction` broadcasts "not away". A restart while paused
resumes on the first sync if you are at the computer, at the cost of one extra
refresh. Each transition is one Media refresh with no provider resume; the lease
asks for at most one change per load (retried after 30 s if that refresh never
came). Non-WebNowPlaying audio that starts while paused does not resume the
capture by itself: input or a click does.

The lease joins the coordinator 100 ms after each load
(`ParallaxIdleJoinAction`, appended to Media.ini's `OnRefreshAction` only when
an open-drawer variant defines it) and never inside the load's own first
update, so Rainmeter's startup walk is never disturbed. The coordinator stays
loaded while Media.ini's drawer is open and not deferred, and unloads itself
otherwise within about 10 minutes, or at its next tick after a collapse or
hide. Test hooks `MediaLeaseTestQuietSeconds` (1-120) and
`MediaLeaseTestStaleSeconds` (5-180) are absent from shipped files; harnesses
set them in staged copies.

**One capture at a time (2026-10-23, XMOD-02).** While Rainmeter.ini records
the standalone Audio Visualizer (`Parallax\Visualizer`) loaded, the open drawer
defers to it (state 2, reason `defer`): one refresh into the capture-free
`Spectrum is shown in Audio Visualizer` variant, which never joins the idle
coordinator and asks a loaded one to re-check. When the standalone is no longer
recorded loaded the drawer takes the capture back (state 0, reason `reclaim`).
The lease checks once per load (after the load's own first update) and
whenever the standalone's `Companion.lua` asks: 100 ms after each of its loads
and after a real unload it sends `!SetVariableGroup ParallaxCompanionCheck 1
Parallax` and `!UpdateMeasureGroup ParallaxMediaCompanion *`, which reach only
the lease (group `ParallaxMediaCompanion`), and the lease clears the flag. The
tab and Media settings open the drawer deferred directly while the standalone
is loaded. At Rainmeter exit nothing is sent; the next start validates again
from Rainmeter.ini. A paused drawer defers too, and resumes live when the
standalone goes.

**Cost.** Parked, Media holds no AudioLevel or Win7Audio measure and no render
stream, so the Windows audio engine can stop (live A/B on 2026-10-22: audiodg not
running with the drawer collapsed, 9.8% of a core with it open). A paused or
deferred drawer also drops Media's 50 ms drawer tick (the title animation
keeps its own). While the drawer is open the `Parallax\Idle` coordinator is
loaded, and it costs more than the 2.5 wakeups/s first estimated. Measured
2026-10-23 (isolated, live preferences, hardware rendering, interleaved
trials), Media's UI thread woke about 102 times a second without it and 175
with it (test idle file 0, you at the computer). About 57 of those come
from its hidden window alone: every skin window beyond the first adds a DXGI
message hook that each message on Rainmeter's UI thread passes through (see
the coordinator's Cost in ARCHITECTURE.md). That part is irreducible while the
coordinator is a separate config. The rest was its network-table reading
every 2 s, which since phase C3 happens about once a minute while you are at
the computer (about 175 to 162 wakeups/s); while you are away it still reads
every 2 s, so the lease sees your input at the next tick. CPU stays within
noise (about 1.4-2.7% of a core in all three). Measuring audiodg and power
requests is step 3's.

**Checks (2026-10-23).** `tests/CaptureLeaseSuite.luatest` (123 assertions in
11 scenarios, offline and inside Rainmeter; 19/19 mutations caught) covers the
thresholds, every resume path, sleep, restart, a missing coordinator, standby,
nested joins, deferral and a script error in one pass (the lease's re-entrancy
guard always reopens, so one error cannot stop later updates). `tests/Test-MediaCaptureLease.ps1` stage B runs Media.ini with the real
coordinator in an isolated instance: away parked within 0.4 s of the idle file
change, input resumed within 0.5 s, the click, Playing, a coordinator that stops
beating (8.2 s with an 8 s stale hook) and unloading the coordinator each
resumed, with exactly one Media refresh per transition, the Rainmeter render
session gone while parked and back after, and a clean log. Physical input,
real WebNowPlaying, the provider-resume skip (isolated profiles never resume
providers) and audiodg itself remain unverified here. Stage C loads Media's
open drawer and the standalone together at 180/0.75 compact with fonts
12/10/10: loading the standalone deferred the drawer in 0.67 s with one Media
refresh (the deferred message fits two lines, captured), unloading it took the
capture back in 0.45 s with one refresh and the render session back, the
reversed load order and a startup with both loaded each ended deferred after the
load plus one refresh, and every log was clean. `CompanionSuite.lua` (51
assertions) and the lease suite cover exit and unreadable settings offline;
Rainmeter exit itself was not run natively.

### Idle pause

With Global Settings **Idle pause** on (5, 10 or 30 minutes; default Off), Media stands down after that long without keyboard or mouse input ([shared design](../ARCHITECTURE.md#idle-stand-down)).

- **Media.ini always stands down by reloading.** The hook asks `MediaOptions.lua` `IdleStandby(1)`, the single writer of `CaptureState.inc`, which saves `MediaStandby=1` and, with the drawer open and live, parks its capture in the same write, then reloads once (stamped, so no provider resume runs on that reload, MEDIA-08). The standby load ticks at `MediaInterval` (1 s): the title-icon term of `MediaTickInterval` is multiplied by `(1-MediaStandby)` and a parked drawer draws nothing that moves. The audio engine is released with the capture. Once the coordinator syncs, that load freezes in place: **Paused (idle)** takes the heading slot, every meter sits at UpdateDivider -1 and its measures (WebNowPlaying fixtures included) are paused. A deferred drawer stays deferred. `IdleStandby` sets `ParallaxIdleStandbyPending` to 1 once this load's reload is posted; when it could not post one (unreadable state file, failed read-back, nothing to change), the hook leaves standby in place at once (live at the 1 s standby cadence) and asks again at most every 30 s, so Media never stays frozen while you are active.
- **On the first input** the hook asks `IdleStandby(0)`: standby clears and a parked drawer goes live in one write and one reload, back to the 50 ms tick and the live capture. WebNowPlaying playback does not end standby (owner decision 2: input only); the capture lease ignores it while `MediaStandby=1`.
- **Fallbacks:** a standby load that hears no coordinator 10 s after loading, or a beat older than 3 minutes, reloads live (`fail-live`). A Media.ini load built in standby while the pause is Off (or holds a hand-edited value, so no hook loads) returns to live from `MediaOptions.lua`'s first update. Setup.ini and Queue.ini never act on the saved standby.
- **Setup.ini and Queue.ini** freeze in place (no player, no drawer, nothing to reload); the line takes the place of Setup's heading and Queue's status line, which are hidden while paused (Media.ini's heading likewise, in its standby load). `MeterPlayerIcon` is runtime-managed only in Media.ini, which leaves standby by reloading, so nothing is re-applied in place.
- **Still running while paused:** the 1 s tick, the WebNowPlaying plugin's own thread (in the real skin), and the Source and Queue helpers (Stop remains a saved choice).

Checks (2026-10-23): `tests/MediaSuite.luatest` offline (LuaJIT: `IdleStandby` coalesces standby and park into one stamped reload and back; collapsed and deferred drawers keep their capture; fail-live; load validation once per Media.ini load with the pause Off or Custom, never for Setup or Queue); `tests/CaptureLeaseSuite.luatest` unchanged (its standby case already shows no WNP loop); `test_skin_contract.py` 34 tests (now expects the hook include after Header.inc and the join on every view); `tools/tests/test_idle_freeze_contract.py` (eight Media.ini variants, Setup and Queue); Test-Parallax 0/0 with the hook and standby variants. `@Resources/Idle/tests/Test-IdleStandDown.ps1 -Skin Media,Setup,Queue` (isolated, providers replaced by fixtures, drawer open): standby reached 1.15-1.6 s after the idle signal with exactly one Media.ini refresh, `MediaTickInterval` 1000 and no render session for the instance; back to live with exactly one refresh, 50 ms and the render session back; `CaptureState.inc` back to 0/0; a reload in standby re-entered; a silent coordinator failed live in 6.5 s; a Rainmeter restart while in standby with input recent loaded once in standby and refreshed once to live (20 s after the launch on this loaded machine, the launch included); Setup and Queue froze and resumed in place with every divider restored; clean logs.

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
only lets the title confirm Spotify. WNP 2.0.7's native desktop adapter
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
| No positive capability signal | Control muted and inactive. |

The WNP connection flag alone cannot distinguish a missing/failed plugin from
an inactive connection. Opening the player without the plugin logs one
`Plugin: Unable to load` error per WNP measure at load (14), then nothing
further; choose Setup to unload it. A failed plugin measure reports the number
0, so `MeasureCover` substitutes an exact `0` to empty and `MeterCover` opens no
file (an anchored regex: real cover paths containing `0` pass unchanged). The UI
does not pretend to diagnose that ambiguity. WNP also exposes no reliable heartbeat timestamp here, so a
stalled provider retaining old data cannot be detected as stale. Native position
may be estimated by WNP, and transport commands have no success acknowledgement
in this interface. The skin never claims a command succeeded on click.

This milestone does not add seek, volume, rating, repeat, shuffle, player
selection, or audio capture. Desktop volume/rating are unsupported by WNP's
Windows API path. Media's own optional [spectrum drawer](#spectrum-drawer)
captures mixed output audio only while it is open; it neither loads nor
controls the separate Visualizer config.

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

**Reloads the capture lease causes (2026-10-23, MEDIA-08).** Media's own
capture-lease reloads (parking or resuming the spectrum drawer's capture; see
[Capture lease](#capture-lease)) would otherwise each start up to two
PowerShell resume launchers for providers that are already running.
`MediaOptions.ApplyLease` stamps `MediaLeaseRefreshAt` (`os.time()`) and
`MediaLeaseRefreshClock` (`floor(os.clock())`) in the runtime file
`Modules\Media\CaptureState.inc` before such a reload, and `ResumeProviders()`
skips both launches only when all of these hold: the view is `Media.ini`; the
stamp is 0-15 s old; and the `os.clock()` delta agrees with the wall-time
delta within 2 s. In Rainmeter's Lua `os.clock()` is wall time since that
Rainmeter process started (checked natively: about 2.5 s at skin load in each of
two separate starts, advancing with wall time), so a stamp from an earlier
process never matches and a restart always resumes. Setup, standalone Queue and
every reload a user or another skin asks for resume exactly as before.
`OnCloseAction` in Media.ini and Setup.ini writes `MediaLeaseRefreshAt=0`. After
about 24.8 days of continuous Rainmeter uptime the C runtime's `clock()` stops
counting (it returns -1); the stamp is then rejected and lease reloads simply
resume providers as before.

### Provider lifetime and upgrades

Until 0.1.0-alpha.4 each `-Command Run` worker was a detached `Start-Process`
child with no tie to Rainmeter: it ran until Stop, across Rainmeter quits and
restarts (the next load's Resume found the worker mutex held and launched
nothing). It also inherited RunCommand's default working directory, the
config's own folder under `Skins\Parallax`. On 2026-10-19 two such workers,
started by a Rainmeter instance the evening before, made Skin Installer fail
the alpha.4 upgrade with "Unable to move to: ...\Skins\@Backup\Parallax" until
they were ended by hand.

Since 0.1.0-alpha.5 the shared `@Resources\Modules\Media\ProviderOwner.psm1`
gives each worker an owner lease:

- Start, Resume, Restart and Connect walk at most four parent processes from the
  controlling `powershell.exe` (one CIM read each, only on that enabling command)
  and, when one is `Rainmeter.exe`, pass `-OwnerLease <pid>:<start ticks UTC>` to
  the worker. A parent that started after its child is a recycled ID and ends
  the walk. Both providers walk only after finding no running worker, so the
  usual Resume on a Media refresh makes no CIM query (Source since 2026-10-22).
- The worker opens that process, requires the same start time, and keeps the
  handle so the ID cannot be recycled while it watches. Queue's 1-second idle
  wait is `WaitForExit` on the owner. Since 2026-10-22 Source waits on the
  owner's process handle and its stop event together (see
  [Source setup and behavior](#source-setup-and-behavior)), so it leaves as
  soon as Rainmeter exits. Queue leaves within one wait, after any request
  already in flight. Both cases include a crash or kill. It
  exits without writing a `stopped` snapshot or touching `enabled.intent`, so
  the next Rainmeter's normal Media load resumes it as before. A lease naming a
  process that is gone or replaced makes the worker exit at once.
- A start with no Rainmeter ancestor (a developer shell) carries no lease and
  keeps the explicit Start/Stop lifetime.
- Workers start with `-WorkingDirectory` set to their data root and also set
  their process and PowerShell locations there, so even a live worker holds no
  directory handle inside `Skins\Parallax`.

Media unloading on its own (closing the Player while Rainmeter keeps running)
still leaves an enabled worker running, as before. Stopping it there would need
a launch on every unload and refresh, and Stop also clears resume intent; a
non-destructive release path is left for later if it proves worth that cost.

Copies at 0.1.0-alpha.4 or earlier still run the old workers, so upgrading
*from* them can fail the same way once: quit Rainmeter, end any `powershell.exe`
whose command line runs `SourceProvider.ps1` or `QueueProvider.ps1` with
`-Command Run` in Task Manager, then run the package again. The Welcome Install
helper's pre-check (see [UPDATES.md](../UPDATES.md#upgrading-past-running-media-helpers))
covers this from alpha.5 on.

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
match classified as Spotify, with matching state, confirms Spotify. Native
WNP maps Windows Playing to state 1 and other statuses to state 2. Incomplete,
unmatched, ambiguous, unavailable, stopped or expired observations never claim
Spotify; the reader also returns which of these cases applied, but only its
tests read that reason and nothing displays it. The header uses the reader's
confirmed Spotify result; an unresolved generic Windows result displays
`Media Player: Unknown` while playing. Specific WNP names, such as a browser extension's player
name, bypass the local observation. The reader issues no bangs.

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

Between collections the worker waits instead of polling (since 2026-10-22):

- **One wait per cycle.** It waits for the rest of each 2-second cycle on two
  handles: a named auto-reset stop event
  (`Local\Parallax.Media.Source.<hash>.Stop`, named like the mutexes) and,
  with a lease, the owner Rainmeter's process handle.
- **Stop.** Stop sets the event right after writing its stop request, so a
  waiting worker exits in tens of milliseconds. The request file remains the
  durable signal and is re-checked after every wake; a stray event from
  another process only resumes the wait.
- **Owner exit** still ends the worker at once, without a `stopped` snapshot.
- **Fallbacks.** Without the event (name unavailable), Stop is seen at the
  end of the cycle, within 2 seconds. An owner handle that cannot be waited on
  keeps the old 100 ms owner wait. The worker clears the event after every
  wake, before it re-checks the request file, so a manual-reset event that
  another process created under that name and left signaled cannot make the
  wait spin.
- **Change-only writes.** A changed observation (state or any record) is
  written at once, and every run writes its first observation.
- **While Spotify plays, every cycle.** An unchanged `ready` observation that
  holds a playing Spotify record is still rewritten every cycle, as before.
  That is the only observation the Player can show: the header consults the
  reader only while WNP reports a generic session playing, and only a playing
  Spotify record confirms Spotify. The previous observation therefore keeps
  about 3-4 seconds of validity when the next is written, so one slow
  collection of up to about 3 seconds still cannot turn `Spotify` into
  `Unknown`.
- **Otherwise, a heartbeat.** Any other unchanged `ready` observation (Spotify
  paused or absent, other apps, no sessions) is rewritten once the published
  one has less than 3 seconds of its 6-second validity left, about every 4
  seconds. A late heartbeat lets it expire for a moment; an expired and an
  unmatched observation both read `Unknown`, so nothing visible changes.
  Making writes sparse while Spotify plays too would save about 15 more
  writes a minute but cut that stall tolerance to about 1-2 seconds; it is
  left to an owner decision
  ([MEDIA-SOURCE-EVALUATION.md](../MEDIA-SOURCE-EVALUATION.md#recommendation)).
- **Unavailable observations** carry no expiry and are not rewritten while
  unchanged.
- **The adapter** to the Windows media-session APIs is built once per worker,
  not every cycle.
- **Resume and the lease.** Resume and Start compute the owner lease only after
  finding no running worker. A Resume that finds the worker running also skips
  storage initialization (its ACL rewrites).

The current-user-only directory `%LOCALAPPDATA%\Parallax\Media\Source\` holds
`source.snapshot` and a stop request. Atomic replacement prevents partial reads.

- **Root validation.** Each worker validates its storage path once.
- **Junction check before every write.** Before each write, and again right
  before the swap, it rechecks with .NET calls that neither the directory nor
  any ancestor up to the drive root is a junction, symbolic link or file, and
  that the target is an ordinary file. Reading the stop request is a plain
  existence check; any entry with that name counts as Stop.
- **Snapshot permissions.** The directory carries a protected user-only ACL,
  set at the start of every command. A snapshot gets an explicit private ACL
  when first created, and replacement keeps it.
- **Snapshot durability.** The snapshot is not forced to disk. After a power
  loss a torn file reads as unavailable and an old one as stale.
- **Stop request and enabled intent** keep a forced flush and an explicit
  private ACL on every write.
No app IDs, tokens or credentials enter the snapshot; title/artist data remain
local runtime data and must never be distributed. The strict ASCII
`PARALLAX_SOURCE_V1` envelope carries state, observation/expiry timestamps and
up to 16 records of source classification, uppercase UTF-8 hex title/artist,
and playing state. Each field is limited to 1,024 UTF-8 bytes and the file to
131,072 bytes; invalid UTF-8/NUL, incomplete collections and excess limits fail closed.
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
canvas, color, position and visibility handling.

The center artwork shows the provider's current state. While playing it shows
Play, changes to Play Off on hover, and clicking toggles to pause. While paused
it shows Pause, changes to the supplied Step Forward artwork on hover, and
clicking toggles to play. Leaving the button restores its current-state icon;
clicking does not fabricate a playback state. Stopped, unknown and disconnected
states retain the existing Play fallback and capability checks. A change made
outside Media, such as a pause in another app or from a media key, or a player
gaining or losing a control, reaches the buttons at the provider cadence
(about a second) without hovering them. Previous and
Next fill their glyph interior when hovered and retain their existing track
commands. The circular face carries `AccentColor`, so an accent glyph would be
invisible on it; enabled glyphs (stroke, and fill while hovered) are drawn in
`MediaTransportGlyphColor`, white (`255,255,255`) since 2026-10-25, set in
`InlineQueueGeometry.inc`; disabled glyphs keep `MutedColor`. All controls keep their capability checks,
muted unavailable state and their 34-pixel circular hit regions.

The thirteen source SVGs, pinned revision, adaptation notes and the complete
upstream ISC and Feather MIT notices are retained in
[`Icons/Lucide/`](../../Skins/Parallax/@Resources/Modules/Media/Icons/Lucide/README.md).
Music is listed upstream as Feather-derived; the extra MIT notice is preserved.
These vector adaptations add no plugin, font or runtime network dependency.

## Player title, current player and icon

User direction, 2026-10-04: one title, one icon, both driven by whether
something is playing. Nothing playing shows Lucide Monitor Play and
`Media Player: stopped`; a playing track shows animated Lucide Audio Lines
and `Media Player: <player>`. The separate current-player row is removed.
Owner decision, 2026-10-22: the animation is a setting, Title animation in
Media settings (`MediaTitleAnimation`): 20 fps (default), 10 fps or Off. It
only ever animates while a player reports Playing; Off still swaps the two
icons, showing Audio Lines static at its rest geometry while playing.
User direction, later the same day: a paused track reads `Media Player: paused`
instead of `stopped`, keeping Monitor Play.

"Playing" means WNP is connected, reports state 1 (Playing) and has a
nonblank track title. `MediaHeader.lua` (the text) and `MediaPulse.lua` (the
icon) apply that identical test to the same cached measure values, so the two
switch on the same update. A paused track (connected, state 2, nonblank title)
reads `paused`. Stopped, idle, disconnected and the plugin-free Setup
entrypoint read `stopped`, while the body keeps the specific state: `No active
media` or Setup's WebNowPlaying guidance.

`MediaHeader.lua` runs after the source reader. `MeterHeading` shows its
returned string whole (`Text=%1`), with title typography and a fixed width.
The script prefixes `Media Player: `, or `Media: ` when `Columns=1` (user
direction, 2026-10-04): the full label left the compact title too little room
for the state or a player name at 12 pt. A Columns change refreshes the skin,
so the label is chosen once per load; `GetPlayerName()` still returns only the
state or player. No player-supplied text becomes a bang, path, variable name or Lua
command, and the adapter issues no bangs. The script retains a UTF-16LE BOM so
Rainmeter's native Lua APIs preserve accented, CJK and non-BMP player names.

Both icons live in one title-icon box at `ContentX` on the shared
`StyleTitleRow` center, scaled by `TitleIconSize / 24`. Monitor Play is the
ini default (`Hidden=0`) and Audio Lines starts hidden. `MediaPulse.lua`, the
animation script, shows one and hides the other whenever
the playing test changes - always on its first update, so the swap never relies
on the ini defaults agreeing - and animates the Audio Lines bars while
playing. It runs once per animation frame (`MediaPulseDivider`: every 50 ms
tick at 20 fps, every other tick at 10 fps with the phase step doubled, so the
1100 ms pulse period holds; at the provider cadence when off). The icon meter
joins periodic updates only while it animates, at the same divider. Setup
loads no pulse script, so it only ever shows Monitor Play.

The title starts after the icon and the shared four-pixel gap and ends 24
logical pixels (the 18-pixel gear plus six) before the content's right edge, at
both widths. Longer text clips with an ellipsis. The
compact layout's stacked player row is gone, so its header ends at 26 pixels
like the double-width one: compact metadata, progress and transport move up 22
pixels, and the compact artwork now tops the metadata block (y30) instead of
sitting at y44. At width 220 and scale 1 the compact window was 228×174
(was 228×196); the double-width window is unchanged at 456×186. Since the
2026-10-10 [spectrum drawer](#spectrum-drawer), 228×174 holds only with
`VisualizerDrawer=0`: the default tab reserves a 12 px strip above the compact
panel, so the window is 228×186 and every compact position moves down 12 px.

Measured title fit, IBM Plex Sans SemiBold advance widths at width 220/scale 1:

| Layout, title size | Title width | `stopped` | `Spotify` | `Unknown` |
| --- | ---: | ---: | ---: | ---: |
| Double, 12 pt (live setting), `Media Player:` | 221.2 | 165.8 fits | 157.9 fits | 175.5 fits |
| Double, 10 pt, `Media Player:` | 224.0 | 138.2 fits | 131.5 fits | 146.2 fits |
| Compact, 12 pt, `Media:` | 163.2 | 114.5 fits | 106.6 fits | 124.2 fits |
| Compact, 10 pt, `Media:` | 166.0 | 95.4 fits | 88.8 fits | 103.5 fits |

With the full label, compact at 12 pt clipped `stopped` by 2.6 px and
`Unknown` by 12 px. The `Media:` label saves 51.3 px at 12 pt, so `paused`
(108.3) and names up to about `Apple Music` (144.2) fit; only long names such
as `Windows Media Player` (222.5) still end in an ellipsis. Widths are IBM Plex
Sans SemiBold advance widths read from the bundled TTF, which reproduce the
earlier 165.8 px figure.

Specific WNP player names take precedence over a stale source label. Generic
Windows sessions receive the Spotify name only when the existing correlation
confirms it; otherwise the player is `Unknown`.

Standalone Queue uses the same title center without a leading identity icon.
Settings keeps its centered title using `CenterCenter`; its close control shares
the title's vertical center. Settings notes and existing content rows retain
their positions.

See [Rainmeter Shape primitives](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/meters/shape/index.html).

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
checks. Missing artwork uses an `N/A` caption so the compact tile remains
readable at the maximum body font size.
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
clearance on each side of the group. Missing time displays `-- / --` and uses
the same measured-text centering.
Both time states sit directly beneath the progress bar with a two-pixel scaled
gap. The playback controls follow the bar's lower edge with an eight-pixel scaled gap.

## Optional Spotify queue

See the [queue setup guide](../../Skins/Parallax/@Resources/Modules/Media/Queue/README.md)
for app configuration, lifecycle commands, status meanings, storage, and protocol.
Register `http://127.0.0.1/callback` in your Spotify app, copy the public Client ID,
and click Sign in in `Parallax\Media\Queue`. The helper opens Spotify consent,
uses PKCE S256 with a dynamic numeric loopback callback, and requests
`user-read-currently-playing` (required) and, since 2026-10-27,
`user-modify-playback-state` (optional, for row clicks). In live acceptance,
Spotify included `user-read-playback-state` in the refreshed grant. Validation
accepts Spotify's returned scope set when it contains the required permission;
the helper calls only the queue endpoint and, for a row click, the skip-to-next
endpoint.
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

### Row clicks and Refresh (2026-10-27)

Clicking a queue row skips Spotify to that item; **Refresh** reads the queue
now. Spotify's Web API has no "play queue item N", remove or reorder call for
the queue, so a click skips forward N times (`POST /me/player/next`) and the
items before it are skipped past (so they leave the queue). Remove and reorder are not possible.

- **Path.** The row's click calls `QueueReader.lua PlayRow(n)`, which hands the
  row number and the shown snapshot's `observed` time (integers only) to
  `QueueControl.lua Play`. That runs one hidden `QueueProvider.ps1 -Command Play
  -Position n -Observed t` on the dormant RunCommand host. The control process
  touches no tokens or network. It writes `action.request` into the private data
  root only while a worker holds its run mutex, then exits. The worker checks
  for a request on each of its 1-second waits, so a click acts within about a
  second plus PowerShell's start-up.
- **Checks before skipping.** The worker acts only if the request names the
  snapshot it last published and that snapshot was a successful read. It then
  reads the queue again and skips only if every row up to the clicked one still
  has the same title and detail. It skips N times, 250 ms apart, waits 500 ms
  and reads the queue at once. A request older than 15 seconds, malformed, or
  left from before the worker started is discarded.
- **Outcomes.** One snapshot carries a notice in place of "Next N": `Queue
  changed`, `No active device` (404), `Control denied` (403, e.g. not
  Premium), `Skip failed` (any other failure) or `Sign in again` (the grant
  lacks `user-modify-playback-state`). The inline drawer shows it in the
  header's "Song / Artist" slot. The next regular read clears it.
- **Refresh** sets the next read to now, unless the last read failed, in which
  case its backoff or server wait stands.
- **Clickable rows.** Only live, visible rows of a snapshot whose grant
  includes playback control, in a skin that declares the click host (Media.ini
  and the standalone Queue, not Setup), get the hand cursor and accept clicks.
  Setup has no Refresh either: the drawer's label lives in
  `Queue\QueueControlHost.inc` with the measure it calls, and Setup's header
  keeps its full width (`MediaQueueRefreshWidth=0`). Until 2026-10-27 the label
  was in the shared `InlineQueueMeters.inc`, so Setup showed a Refresh that
  named a missing measure; `Test-ParallaxVariants.ps1` caught it before alpha.10.
- **Snapshot V3.** `PARALLAX_QUEUE_V3` adds `control=0|1` and
  `notice=<enum>` after `count`. The reader still accepts V2, which reads as
  not clickable with no notice. Nonready snapshots must carry `control=0` and
  an empty notice.
- **Not verified live.** No real Spotify skip, device, or a Premium versus Free
  account has been exercised; all checks are synthetic.

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

### Shuffle, repeat and clickable queue (2026-10-27)

**Shuffle and repeat.** 26S circles flank the transport trio, one 4S gap out
on the same centre line (`MediaTransportToggleSize`, `TransportIcons.inc`),
with Lucide shuffle, repeat and repeat-1 art drawn at 18S and the suite's 2S
stroke. Off: a `GraphBackgroundColor` face ringed in `BorderColor`, lifted to
`BorderColor` on hover. On: the trio's `AccentColor` face. Repeat-one adds the
"1" stroke. The glyph is white when the player reports support and
`MutedColor` (no cursor) otherwise.

- **Fit.** The row's left end bounds the queue notch, which must keep 76S for
  its icon and label (`MediaQueueTabMinWidth`). Where the centred row would
  cut it shorter, the five slide right by just enough, never closer than
  `Padding` to the panel's edge. Where that is still not enough, the toggles
  are hidden and parked at `#Inset#` and the trio keeps its centred place.
  Measured at scale 0.75–2: toggles show at double 220 (row 26S right of
  centre at scale 1, notch exactly 76) and at 320 in both widths. They are
  hidden at compact 180 and 220 and at double 180.
- **Timing text.** Where the toggles show, it moved from under the bar's right
  end to the right end of the album row, so the bottom edge holds only the
  notch and the buttons. The album stops 96S short of it (88S timing cap plus
  an 8S gap). Before the move, the repeat circle overlapped "45 / 180" at
  double 220. Measured: the digits' ink spans rows 102–109 and "album" spans
  102–110, centred on the same Y; the 1px bottom difference is the round
  lowercase overshoot, unchanged by a box-height experiment.
- **Compact cost.** Both timing meters are now `RightCenter`. `StringAlign`
  cannot follow a formula, and a runtime `!SetOption StringAlign` did not
  re-apply (measured: Y moved, the alignment did not). Where the toggles are
  hidden the timing text therefore draws 1px lower than before (ink rows
  139–149 → 140–150, compact 220, scale 1). A pixel diff against HEAD shows
  nothing else changed in that layout apart from the animated title icon.

**Checks run.** `Test-Media.ps1`: 806 assertions in 29 scenarios, including a
new shuffle/repeat scenario. `test_skin_contract.py`: 34 tests, 4,051
subtests. `Test-MediaTransport.ps1 -Columns 1|2` (new `-Columns`
parameter): PASS. `Test-MediaSettings.ps1 -QueueTogglePlayersOnly`: 1,238 +
1,314 checks. `Test-QueueCore.ps1`: 72. `Test-QueueProvider.ps1`: 269, with
new click, request-file and stand-in-worker cases. `Test-QueueAuth.ps1`: 63
(unchanged). `Test-QueueReader.ps1`: 6,206 in 26 scenarios, including V3,
cursors, notices, clicks and the Setup no-host case. `Test-QueueView.ps1`: 20
layouts. Standalone Queue's Refresh shows only with live rows: on the status
line it clipped "Queue unavailable" at compact 180.

**Not verified.** Live WebNowPlaying shuffle/repeat support for any real
player, and live Spotify skips. The inline Refresh label's look in an
expanded drawer was not captured; its bounds are checked by the contract
suite.

### Open chevron in the top-right corner (2026-10-25)

The open drawer's collapse chevron moved from the strip right of `16 kHz` to
the sheet's corner — first top-left (the output row's first column, tried and
replaced the same day), then top-right (the row's last column); `16 kHz` ends
at the plot's right edge again. Contract tests (28) and the native
`-VisualizerDrawerFocused` (4 cases) and `-HeaderFocused` (12) runs pass; the
Lua suite checks the open chevron's column, band and centre against the plot's
right edge and the output target. At fractional scales the name and target end
at the target's whole-pixel x, so they never overlap it. Captures at scale 1:
chevron ink centroid 431.00, 20.86 (double) and 203.00, 20.86 (compact);
`16 kHz` ink ends at x 437 and 209, each plot's last column. Not captured:
other scales; clicks were dispatched by the native harness, not physically.

### White transport glyphs (2026-10-25)

Enabled transport glyphs switched from `BackgroundColor` (near-black) to the new
`MediaTransportGlyphColor=255,255,255`. `Test-Media.ps1` passes (431 assertions,
19 scenarios), including the renamed scenario that drives the new variable; the
synthetic open-drawer capture reads pure white (255) inside the play face.
Hover fill and other scales were not captured.

### Spectrum plot origin, volume in the title row (2026-10-25)

The open plot now starts 5 px north-east of the double-width art's top-right
corner, its frequency labels sit in the strip beside the art, the open sheet
starts at the dB gutter instead of the panel's left edge, and the output volume
moved from the output row to the gear's spot on the title row (see
[Spectrum drawer](#spectrum-drawer)). The open window is 18 px shorter at
every preset (Normal 316 → 298). Checked:

- `test_skin_contract.py`: 28 tests pass, with the lift model, plot origin and
  buffer (art corner when wide, gutter-limited otherwise), sheet left edge,
  label positions, chevron clearance, the volume's position against the gear,
  the open-state title width and Media.ini's hover swap updated.
- `Test-MediaSettings.ps1 -VisualizerDrawerFocused`: 4 native cases pass with
  zero Rainmeter errors; windows 186 → 298 → 186 (Tall 186 → 338 → 186), panel
  screen Y unchanged. `-HeaderFocused`: 12 gear/hover cases pass (drawer
  closed, so the volume swap's group bangs run with no member meter).
- Open-state captures (the harness stopped at its open stage for a scratch run,
  then restored) at width 220, scale 1, both widths: measurements in the
  geometry table above, including 5 clear columns and rows between the art
  corner and the plot frame.
- Not verified: the hover swap with the drawer open (no native case hovers an
  open drawer), and captures at other scales and widths (contract model only).

### Source observer waits instead of polling (2026-10-22)

Performance package A2 (findings MEDIA-02, XMOD-01, XMOD-08 for Source, and
MEDIA-08; see [PERFORMANCE-REVIEW.md](../PERFORMANCE-REVIEW.md#t3-the-media-source-helper-polls-instead-of-waiting-high)).
Branch `perf/A2-media-source`, one commit per fix. Only `Source/SourceProvider.ps1`
and its tests changed. `SourceReader.lua`, the snapshot protocol,
`ProviderOwner.psm1`, Queue and every skin file are untouched, so no pixels can
change. The behaviour is described in [Source setup and behavior](#source-setup-and-behavior).
The WebNowPlaying replacement question is answered separately in
[MEDIA-SOURCE-EVALUATION.md](../MEDIA-SOURCE-EVALUATION.md).

What changed:

1. The root is validated once, and the junction guard uses .NET calls before
   every write. The stop check is a plain existence check.
2. One `WaitAny` per cycle on the owner process and a named stop event. Stop
   sets the event.
3. The WinRT adapter is built once per worker.
4. No ACL calls on routine snapshot replacements, and the destination path is
   resolved once per write.
5. Change-only snapshot writes with a heartbeat at under 3 s of validity
   left. After review, unchanged observations holding a playing Spotify
   record are written every cycle again (see below).
   - No forced flush for snapshot writes, a separate commit since review.
6. The owner lease is walked only after the worker probe.
7. A Resume beside a running worker skips storage initialization.

Checks:

- **`Source/tests/Test-SourceProvider.ps1`: 248 synthetic assertions pass**
  (182 before). New coverage:
  - a junction swapped into an already validated root is refused by snapshot,
    stop and intent writes;
  - a directory stop marker ends the worker;
  - against a peer runspace driving the real `Invoke-SourceRun`, Stop 300 ms
    into a wait ends the worker in 41 ms, two stray events leave the cycle at
    2,015 ms, and a stand-in owner process exiting ends a leased worker in
    16 ms;
  - adapter reuse, and one failed build that is not cached;
  - ACL call counts: 1 for the first snapshot, 0 for replacements, and
    unchanged for the vetoes;
  - the payload key and the publish decision at 4, 3.01, 2.99 and -1 seconds
    left, and with the clock moved back;
  - a worker on a simulated clock writing exactly
    `ready@1000 ready@1004 ready@1006 stopped@0` over five cycles (six writes
    before);
  - no lease walk and no storage initialization beside a running worker.
- **Mutation checks.** Each of seven mutations, applied to a scratch copy,
  fails the suite: dropping the event signal (Stop took 1,728 ms), treating a
  stray wake as a cycle end, skipping the per-write guard, always publishing,
  dropping the heartbeat, walking the lease before the probe, and removing the
  early Resume probe.
- **`Source/tests/Test-SourceReader.ps1`: 133 assertions in 13 isolated
  Rainmeter scenarios pass.** The reader itself is unchanged.
- **`Source/tests/Test-SourceNative.ps1`** now makes two read-only
  observations: `ready`, one session, 214 ms then 7 ms, `AdapterReused: true`.
- **`tests/Test-ProviderLease.ps1`: 12/12.** Both isolated workers exited
  184 ms after their Rainmeter quit.
- **`tools/Test-Parallax.ps1 -RequireAllModules -WarningsAsErrors`:** 23
  configs, 99 files, 0 errors, 0 warnings.
- **Real worker, end to end** (scratch scripts, not committed). A lease-less
  worker ran on a temp root, sampled every 0.2 s through the real
  `SourceReader.parse` under OBS's LuaJIT, then Stop ran from a second
  process.
  - **Four of five 16-20 s runs:** every sample was `ready`, heartbeats came
    4.01-4.08 s apart, and at least 1.21-1.88 s of validity remained.
  - **One run:** one heartbeat came about 2.6 s late, giving 5 stale samples
    (about 1 s, honest `Unknown`). The machine was shared with parallel build
    agents; 45 timed native collections afterwards showed no stall (median
    11 ms, max 354 ms on the first). The cause was not determined.
  - **The old provider in the same check** wrote every 2.0 s with at least
    3.31 s left.
  - **Stop from a second process:** the worker exited 52-80 ms after the stop
    request was written (124 ms for the old provider).
- **CPU, in-process profiles under the same shared load** (not benchmarks):
  - the old stop check cost 5.8 ms per call, ten times a second;
  - a collection now costs about 20-25 ms of CPU per 2 s cycle, the floor
    that remains;
  - a snapshot write costs about 10 ms;
  - in 20 s windows the old worker used 11.2% of a core and the new one
    2.1-2.5%, including first-run compilation.

Not verified:
- The isolated benchmark and the live trace (step 3 measures them).
- File-system operation counts (Procmon or ETW).
- How often Windows media-session calls stall on a normal desktop.
- The fallbacks: no stop event, and an owner handle that cannot be waited on.
  They are exercised only synthetically.
- The live Rainmeter, which was not touched.

After review (same day). The first version wrote every unchanged `ready`
observation only about every 4 seconds, which left one slow collection only
about 1-2 seconds before the header turned `Spotify` into `Unknown`; the old
schedule tolerated about 3-4 seconds. That contradicted the
behaviour-preserving brief, so the fixes below were added as new commits:

- **Every cycle while Spotify plays.** Unchanged observations holding a
  playing Spotify record are written every cycle again; only the others keep
  the sparse heartbeat.
  - `Test-SourceProvider.ps1` checks the rule's decisions, and that a worker
    on a simulated clock writes every cycle while Spotify plays (`ready@1000`
    through `ready@1008`) and keeps the sparse schedule while it is paused.
  - **One stalled collection** while Spotify plays: a 2.0 s stall at +0.75 s
    into the observation second leaves 1.23 s and a 3.0 s stall at +0.25 s
    leaves 0.73 s. Both equal the old every-cycle schedule.
  - **Paused, then playing**, with a stall in each phase: only the paused
    phase skips a write, and it expires for a moment, which nothing shows.
  - **The reviewed version fails the check.** With the sparse heartbeat
    forced for playing Spotify, the same 2.0 s stall leaves -0.77 s. Three
    mutations of the rule fail the suite: no every-cycle rule, a paused
    Spotify record counting as playing, and any playing app counting.
  - **Real worker:** the review's real-time stall script (the real
    `Invoke-SourceRun`, one playing Spotify record, the snapshot judged every
    100 ms by the reader's integer-time rule) gave 0 stale samples for 1.3, 2.0
    and 3.0 s stalls, with at least 1.88, 1.11 and 0.12 s left. The review
    measured 2 and 9 stale samples for the first version, and 0 for the old
    provider.
- **Snapshot flush, split out.** The first version also stopped forcing
  snapshot writes to disk in the same commit. That part was undone and then
  re-applied as a commit of its own, so it can be measured alone.
- **A squatted stop event cannot spin the wait.** The worker clears the stop
  event after each wake. With a signaled manual-reset event pre-created under
  its name, a 300 ms cycle now makes 2 waits (457 without the reset, a busy
  spin), and Stop still ends the worker in 33 ms.

Checks after these fixes:

- **`Source/tests/Test-SourceProvider.ps1`: 340 synthetic assertions pass**
  (248 before review).
- **`tests/Test-ProviderLease.ps1`: 12/12.** Both isolated workers exited
  194 ms after their Rainmeter quit.
- **`tools/Test-Parallax.ps1 -RequireAllModules -WarningsAsErrors`:** 23
  configs, 99 files, 0 errors, 0 warnings.
- Not rerun: `Test-SourceReader.ps1` and `Test-SourceNative.ps1`. The reader
  and the collection code did not change.

### Paint on change (2026-10-22)

Rainmeter 4.5 repaints a skin's whole window whenever any meter's update
divider elapses; it never checks whether anything changed, and hidden meters
count. Media ticks every 50 ms for its title-icon pulse, and 26 meters were
due on every tick, so the 456 px window was rendered and recomposited 20 times
a second in every state, idle and screen-off included
([performance review](../PERFORMANCE-REVIEW.md) MEDIA-01). Each change below is
its own commit so it can be measured alone.

- **MEDIA-01, redraw follows the provider cadence.** `Media.ini` sets
  `DefaultUpdateDivider=#MediaLegacyDivider#`, so a section without its own
  divider follows the 1-second provider cadence. The default also applies to
  measures; every Media measure already stated its divider except
  `MeasureMediaPulse`, which now says `UpdateDivider=1`. Meters whose content
  only changes by a refresh or an explicit bang use `UpdateDivider=-1`:
  the queue sheet, tab label and inline queue rows (QueueReader already forces
  `!UpdateMeterGroup QueueRows` and `!Redraw` on every change), *No active
  media*, the cover placeholder and its N/A label, and `-- / --`.
  `MeterHeading` takes `MeasureMediaHeader`'s own divider instead of 1.
  `MeterPlayerIcon` keeps its style's `-1` at rest: `MediaPulse.lua` raises it
  to 1 with one forced update when playback starts, and on stopping settles the
  bars, returns it to `-1`, forces that last update and redraws once. While
  nothing plays the script returns at once and issues no bang. With the drawer
  collapsed the fastest due meter is now on the 1-second cadence (from every
  tick), so the window repaints at most once a second while nothing plays.
  Measure-bound text, progress and cover still update every second; a meter
  forced out of phase with its measure can show a value up to a second late.
  Checked: `test_skin_contract.py` (29 tests, new
  `test_media_repaints_on_change_not_on_the_animation_tick`: every measure
  states a divider, no meter is due more often than once a second in drawer
  states 0 and 1, and the static meters are `-1`); new
  `tests/MediaPulseSuite.luatest` (7 scenarios, 513 assertions, run natively by
  `Test-MediaHeader.ps1`: no work while idle, divider and forced update on each
  transition, no paint on the load tick, the 1100 ms period), which fails
  against the previous script; `Test-MediaHeader.ps1` also asserts the icon's
  divider at every native stage (1093 assertions pass);
  `Test-MediaSettings.ps1 -IdentityIconsFocused` and `-QueueTogglePlayersOnly`
  pass (their harness now copies the production pulse divider and keeps its
  observer and probes at divider 1); their captures are pixel-identical to the
  same runs on the parent commit outside the animated title icon, and the Setup
  preview capture is pixel-identical.
- **MEDIA-03, no per-update formula re-reads.** Rainmeter stores `[Variables]`
  pre-expanded, so a `DynamicVariables=1` meter re-parses Media's whole
  geometry chain on each update: about 23 KB for each timing meter, 18 KB for
  the queue sheet and 5 KB for the playing icon. `MediaTimingStyle` and
  `MeterQueueDrawer` drop `DynamicVariables` (their options change only with
  a refresh). The two timing meters lose the `OnUpdateAction` that called
  `Media.lua`'s disabled `LayoutTransport()` on every update; when that layout
  returns it should run from the adapter's change path. `MeterPlayerIcon`
  drops `DynamicVariables` too: each `!SetOption` already forces exactly one
  re-read, and `MediaPulse.lua` now writes the shared box's X and Y back as
  literal numbers once per load (in parentheses, so Rainmeter converts them
  through the same formula path), as `SpectrumPaths.lua` does for the band
  paths. Checked: the cadence contract test now also rejects
  `DynamicVariables=1` or an `OnUpdateAction` on any periodically updated
  meter; the pulse suite adds the literal box (written once, exact for
  fractions, skipped for unresolved or failing text; 556 assertions); the
  native identity suite now requires the two title icons' X and Y to be
  pixel-equal and passes all 25 `-IdentityFocused` cases (widths 180/220,
  scales 0.75/1/2, one and two columns, default and maximum fonts) in 27.6 s.
  The same 25 cases on the tree before this series (916c9ab) produced 1 of 25
  reports in 53 s: 24 Media windows repainting at 20 Hz starve the isolated
  instance (an observation, not a benchmark). Captures shared with the
  baseline run are pixel-identical outside the animated icon.
- **MEDIA-04, the open drawer's hidden mask.** In silence the drawer hid its
  bars but the mask stayed due on every tick, re-reading its 24 paths and
  keeping the window at 20 repaints a second. The shared `Capture.inc` state
  actions now park it at `UpdateDivider=-1` in every non-signal state and
  restore the capture cadence (with one forced update) on signal; see
  [Visualizer paint on change](Visualizer.md#paint-on-change-2026-10-22).
  With the drawer open, paused and quiet, the scratch native harness counted
  repaints on 8 of 40 ticks (the 250 ms volume readout, addressed next)
  instead of 40 of 40; with signal the mask updates every tick as before.
- **VIS-03 in the drawer, event-driven output row.** The drawer's volume and
  device-name meters are now `UpdateDivider=-1`; the shared `Audio.inc`
  measures update them and repaint only when the shown text changes, and the
  capture state repaints its own transitions (details in
  [Visualizer paint on change](Visualizer.md#paint-on-change-2026-10-22)).
  Open, quiet and paused, the drawer now repaints on 2 of 40 ticks, the
  1-second text meters, and its open-drawer preview capture is
  pixel-identical to the tree before this series (output row included).
- **VIS-04 / ENGINE-07 in the drawer, Win7Audio once a second.** The volume
  readout's Win7Audio measure ran every 250 ms, and every read (plus the
  availability check's second, string read) is a full COM device
  enumeration; it now runs once a second, as does the capture's device
  status. A volume change shows within a second instead of a quarter second,
  and Output unavailable can appear up to a second after an endpoint goes
  away. The scratch native harness counted 2 Win7Audio and 2 device-status
  reads per 2 seconds (from 8 and 40), with the volume change still reaching
  the readout.
- **MEDIA-06, Title animation setting (owner decision 2026-10-22).** New
  `User\Media.inc` key `MediaTitleAnimation`: `20` (default), `10` or `0`,
  with the same fallback in Media.ini, Setup.ini and Media settings, and a
  Title animation row in Media settings (see
  [Gear and expandable queue](#gear-and-expandable-queue)). The icon animates
  only while a player reports Playing. `InlineQueueGeometry.inc` derives
  `MediaTitleFrameTicks` (1, 2 or 0), then Media's own tick
  `MediaTickInterval`: 50 ms when Media.ini's title icon can animate
  (`MediaPlayerHost=1`, a new entrypoint flag set before the includes; 0 in
  Setup.ini) or the drawer is open, otherwise `MediaInterval`. Both entrypoints
  now use `Update=#MediaTickInterval#`, and `MediaLegacyDivider` derives from
  that tick in the same file, after it, from values every entrypoint settles
  before the include, so no later override can leave it stale (the XMOD-03
  verifier's pitfall); Setup.ini's late `MediaAnimationInterval` override is
  gone, its tick is still `MediaInterval` and its divider still 1.
  `MeasureMediaPulse` runs at `MediaPulseDivider` (one frame: 1 tick at
  20 fps, 2 at 10 fps, the provider cadence when off); `MediaPulse.lua` reads
  the frame and tick variables, doubles the phase step at 10 fps so the
  1100 ms period holds, gives the icon the same divider while animating, and
  with animation off keeps the icon static at `-1` and paints only the icon
  swap. Unreadable values mean a static icon. The drawer's capture and
  output-row dividers derive from `MediaTickInterval`, which an open drawer
  always makes 50 ms. Checked: a new contract test covers every animation
  value and drawer state (tick 50 or 1000 ms, a 1-second
  `MediaLegacyDivider`, pulse divider 1/2/legacy, capture divider 1 and 1 s
  output row when open, Setup at `MediaInterval`, the variables defined once
  and in order, the flags before the geometry include); the pulse suite adds
  10 fps (frame k equals the 20 fps tick 2k; 11 frames per period) and Off
  (one painted swap each way, then no work; 671 assertions); the settings
  contract and native suites cover the new row's geometry, wiring, clicks and
  saves (each click writes once and refreshes Media and Queue; a hand-saved
  15 steps as 20 fps and abc as Off), and natively measured text fits the
  field and label at the 10 pt maximum (Title animation 184 of 228 px at
  scale 2). The settings panel grows 28 px to 814/758; its preview capture
  (456×766) is the previous one (456×738) with a single 28 px band inserted at
  y=154, every other row pixel-identical. In the scratch native harness the
  playing icon updated on 28 of 40 ticks at 20 fps (after the 1-second play
  state pickup), 14 at 10 fps and once (the swap) when off; with the drawer
  collapsed and animation off Media ticked once a second, and the Setup
  preview capture is unchanged. Limitation: like
  `VisualizerDrawer`, the key needs literal digits. Text that is no number
  fails Rainmeter's formulas: Media then keeps a static icon but also falls
  back to Rainmeter's default 1-second tick, which would slow an open
  spectrum drawer, until a Media settings click writes a valid value.

### Transport repaints on external play/pause (2026-10-22)

Phase B package B5 (`perf/B5-media-transport`). This bug predates phase A; it
was found during it. The three transport buttons use `UpdateDivider=-1`, and
Rainmeter 4.5 applies a `!SetOption` to such a meter only when the meter is
forced to update. `Media.lua` forced them only from hover
(`!UpdateMeterGroup MediaDynamic`). So a change that reached Media only
through the provider sample kept the old drawing until the pointer crossed a
button: a pause in another app or from a media key, a resume, a player
dropping Next, a connect or a disconnect. The title already read "Media
Player: paused" while the centre button still showed Play.

- **Fix.** `Media.lua` queues each transport meter whose options change and
  forces exactly those meters, once each, after their options, on every path.
- **No extra repaint.** A periodic sample issues no `!Redraw`. The
  measure-bound player meters (title, artist, album, progress, timing, cover)
  share `MeasureMediaUI`'s divider, so they are due on the same tick and the
  skin cycle repaints right after. A new contract test keeps them aligned for
  every drawer state and title animation.
- **Hover** still repaints itself, but now forces only the meter it changed
  instead of the five-meter `MediaDynamic` group.
- **Paint on change is kept.** An unchanged sample still issues no bang, so
  nothing repaints when nothing changes. A transition costs one forced update
  per changed button.

Checked:

- **`tests/MediaSuite.luatest`.** Every refresh assertion now requires each
  meter with a changed option to be forced exactly once, after the option, and
  no group update. A new scenario drives provider-only pause, resume, loss of
  Next support, disconnect and reconnect, which force 1, 1, 1, 2 and 3 meters.
  Against the base adapter (`191a1cd`) it fails with "External pause must force
  the UpdateDivider=-1 play/pause meter, or its art stays stale until hover".
  With the fix, 582 assertions in 20 scenarios pass natively (`Test-Media.ps1`)
  and under OBS's LuaJIT.
- **New `tests/Test-MediaTransport.ps1`.** It loads the real Media.ini in an
  isolated Rainmeter, with built-in fixture measures at the production
  dividers. It changes only the fixture's play state or Next support, waits
  two provider cycles and captures. Then it forces the transport and captures
  the ground truth.

  | Transport row (120×44 px) | Base adapter | Fixed |
  | --- | ---: | ---: |
  | External pause vs forced Pause | 194 px differ | 0 |
  | External pause vs the earlier Play frame | 0 (stale) | 194 |
  | External resume vs forced Play | 194 | 0 |
  | Next unsupported vs forced muted Next | 248 | 0 |

  The fixed adapter also passes with Title animation Off (1-second tick).
  Window 456×186.
- `Test-MediaSettings.ps1 -IdentityIconsFocused` and `-QueueTogglePlayersOnly`
  pass. `test_skin_contract.py` passes 31 tests, and
  `tools/Test-Parallax.ps1 -RequireAllModules -WarningsAsErrors` reports 0
  errors and 0 warnings.

Not verified: a real WebNowPlaying player (isolated profiles have no WNP), and
CPU cost. No benchmark was run; by design the fix adds work only on a
transition.

### Cover without the WNP plugin (2026-10-20)

The alpha.6 clean-install check ([ROADMAP](../ROADMAP.md) Stage 1) found
`ImageName: Unable to open: ...\Parallax\Media\0.png` on every update when the
plugin is absent: the failed `MeasureCover` reads as 0 and the hidden
`MeterCover` (hidden meters still update) opened it relative to the skin folder.
Changed `WebNowPlaying.inc` (`MeasureCover`: `RegExpSubstitute=1`,
`Substitute="^0$":""`) and `PlayerMeters.inc` (`MeterCover`:
`UpdateDivider=#MediaLegacyDivider#`, the measure's own cadence). The divider
means the image meter now reads the cover once a second instead of every 50 ms
tick, which more than covers the substitute's cost; no dynamic options added.

- Isolated Rainmeter 4.5.28 profile, temp copy of the whole `Skins\Parallax`
  tree with `Plugin=WebNowPlaying` rewritten to an absent plugin name (the real
  DLL sits in `Program Files\Rainmeter\Plugins`, so this never loads a second
  WNP copy). Before: 227 `0.png` errors in 15 s. After: 30 s run, 25 log lines,
  only the 14 one-time `Plugin: Unable to load` errors, no `ImageName` errors.
- Isolated probe of the same substitute: `C:\Temp\WebNowPlaying\cover_0_10.png`
  is returned unchanged; a measure valued 0 returns empty.
- `test_skin_contract.py`: 28 tests OK. `Test-Parallax.ps1 -RequireAllModules`:
  23 configs, 99 files, 0 errors, 0 warnings.
- Unverified: a live WNP cover after the divider change (the art still follows
  `MeasureCover`, which already updated at that cadence), and a real Skin
  Installer install with its plugin step skipped.

### Provider owner lease and upgrade pre-check (2026-10-19)

Changed `SourceProvider.ps1`, `QueueProvider.ps1`, new `ProviderOwner.psm1`,
`Scripts/UpdateInstall.ps1`, `Modules/Welcome/Update.lua` and the staging
allowlist; see [Provider lifetime and upgrades](#provider-lifetime-and-upgrades).

- `Source/tests/Test-SourceProvider.ps1` (182 assertions) and
  `Queue/tests/Test-QueueProvider.ps1` (226) pass; their `Start-Process`
  stand-ins now also require the worker's working directory to be its data root.
- New `tests/Test-ProviderLease.ps1` runs a separate Rainmeter 4.5 instance
  (own `Rainmeter.ini`, `SkinPath` in a temp copy) whose skin starts both
  providers through hidden RunCommand with temp data roots, then quits itself.
  The queue worker is held in a synthetic unpaused offline retry wait, so no
  Spotify request is made. 12/12 checks passed: both workers carried the test
  Rainmeter's lease, both exited 146 ms after it quit, `enabled.intent` stayed
  enabled with no `stopped` snapshot, and the copied `Skins\Parallax` then
  renamed. Lease-less workers started from a shell renamed the folder while
  they were alive, and the `Stop-ParallaxMediaWorkers` function extracted from
  `UpdateInstall.ps1` ended exactly those workers. The live Rainmeter and its
  helpers were not touched.
- `tools/tests/Test-PackagingTools.ps1` passes, and a real stage includes
  `ProviderOwner.psm1`. `Welcome/tests/Run-UpdateSmoke.ps1` (without
  `-ExerciseInstall`) passes under PowerShell 7.
- Not verified: the Welcome `blocked` state (needs a worker that refuses to
  end), a real Skin Installer upgrade with live workers, and a worker started by
  the normal-profile `ResumeProviders()` path, which the isolated profile
  deliberately refuses; that path launches the same Start/Resume code tested
  here.

### Contract test scans shipped files only (2026-10-11)

`test_only_the_open_drawer_include_opens_the_geometry` searched every `*.inc`
and `*.ini` under `Skins/Parallax`, so in a working checkout it reached the
git-ignored UTF-16 `Rainmeter.ini` files old native runs leave in `.runtime`
and Network `QA` run folders, and errored (the caveat in the entry below). It
now reads only paths the packager ships: `shipped_sources()` prunes the same
hidden, test, QA, cache and runtime folders as
`Get-ParallaxExclusionReason` in `tools/Parallax.Build.psm1`, without needing
git. No production file changed and the leftover folders were left in place.
Run against the working checkout's tree (8,127 `.inc`/`.ini` files on disk),
it selects 98, exactly the files `git ls-files --cached --others
--exclude-standard` reports, and all 28 tests pass in about 27 s. Adding a
stray `MediaVisualizerOpen=1` to a shipped include still fails the test.

### Spectrum drawer output row and Spectrum settings (2026-10-11)

Later the same day the drawer gained the standalone's output row and Media
settings its Spectrum section (see [Spectrum section](#gear-and-expandable-queue)
and [Spectrum drawer](#spectrum-drawer)). This supersedes the lift and window
numbers in the axis-label entry below. Checked:

- `test_skin_contract.py`: 28 tests pass. Its model adds the 19S row (lift
  110/130/170) and new assertions on the row's box, its parts, the Win7Audio
  measure (exactly one, open state only) and its 5-tick / 20-tick cadences, the
  row's switch actions, the shared steppers' positions (Height/Quality frames at
  272, Decay at 416, headings 246/334 with rules 21 below, 14 px to Queue
  sampling), their `MediaSettingsData` group, the Visualizer Height preset read
  (146, not Media's 162), and the settings heights 786/730.
- `Test-MediaSettings.ps1 -VisualizerDrawerFocused`: 4 native cases pass with
  zero Rainmeter errors; windows 186 → 316 → 186 (Tall 186 → 356 → 186), panel
  screen Y unchanged, Win7Audio present while open. No case clicks the row, so
  the real default output was never switched.
- `Test-MediaSettings.ps1 -SettingsFocused`: both native layouts pass
  (width 180/scale 0.75 and 220/2, maximum fonts), including the new
  Spectrum-row reflow checks; the 180/0.75 capture was inspected.
- Audio settings after the split: `validate-settings.mjs` and `validate.mjs`
  pass; `SettingsSuite.lua` passes 237 cases in an isolated Rainmeter Lua host
  (scratch runner, not checked in), now asserting the in-place display update
  and that no save reloads the settings window; its new Height case fails
  against the previous controller. A preview capture of Audio settings is
  unchanged at 456×408.
- Load timing (isolated instance, five refreshes, scale 1): Media settings
  ~1.4 s on HEAD → ~3.1 s; Audio settings ~2.2 s → ~1.8 s. The first full
  60-case `Test-MediaSettings.ps1` run on this branch, before the tooltip trim
  and in-place save, missed its 300 s budget (50/60 reports) and its Accordion
  cases outlived the synthetic queue cache's 240 s validity ("Queue stale");
  HEAD passes all 60 in 252 s.
- With every tooltip removed (an equivalent same-day removal on this branch,
  replaced at merge by the 2026-10-18 removal below): Media settings loads in
  ~0.13 s (HEAD ~1.4 s) and Audio settings in ~0.04 s (HEAD ~2.3 s). Rerun on
  the merged tree (2026-10-18): the full 60-case `Test-MediaSettings.ps1`
  passes in 47.5 s, the drawer mode's 4 cases pass, and `Test-Media.ps1` (431),
  `Test-QueueReader.ps1` (4,987), `Test-SourceReader.ps1` (133, incl. the
  native UTF-16 binding), the Visualizer `SettingsSuite.lua` (237) and
  `tools/Test-Parallax.ps1` (23 configs, 0 errors, including its no-tooltip
  rule) pass; on 2026-10-11 a native preview of all ten configs rendered with
  no Rainmeter errors or warnings.
- Open-drawer previews `build/Parallax-visual-preview-20261011T220659273Z-9fcd3333`
  (456×316) and `…220743593Z-181a4614` (228×316) inspected: speaker, device
  name and `36%` volume on one row; at compact width the name ellipsizes.

Not checked: clicking a Spectrum stepper in Media settings natively (the
controller is the same file Audio settings uses; its save path was exercised
only in the Lua suite), device switching from the drawer row, the row icon's
clearance from a large sheet corner radius, and scales other than those listed.

### Spectrum drawer axis labels (2026-10-11)

The open drawer now carries the standalone Visualizer's dB scale and
40 Hz / 16 kHz labels (see [Geometry](#spectrum-drawer)). Checked:
`test_skin_contract.py` passes (28 tests) with its independent model updated
for the 40S gutter and 19S row, plus new assertions that each label box sits
inside the sheet padding, the dB boxes end 4S left of the plot, and the
frequency row ends on the toggle band's top. `Test-MediaSettings.ps1
-VisualizerDrawerFocused` passes its 4 native cases with zero Rainmeter errors:
lift 111 (Normal) / 151 (Tall), windows 186 → 297 → 186 and 186 → 337 → 186,
panel screen Y unchanged, and the suite's new label-position checks. Open-drawer
captures from an isolated preview instance (`build/Parallax-visual-preview-20261011T133234585Z-fb79daad`,
456×297, and `…133309390Z-f6449f33`, 228×297, scale 1, live loopback audio)
were inspected: labels legible, unclipped and clear of the chevron. Not
checked: other scales and corner radii natively (source model only), and the
open chevron's ink centroid at its new position.

### Tooltips removed (2026-10-18)

Tooltips were removed suite-wide: Rainmeter creates a native tooltip window
for every `ToolTipText` meter, about 40 ms of skin load each, and the owner did
not find them helpful. Media lost its static tooltips and its three runtime
ones: the transport controls' support text (`Media.lua`), the queue and
spectrum-tab read/save failure messages (`MediaOptions.lua`) and the song
icon's source explanation (`SourceReader.lua`, which now issues no bangs).
Visible text and other behavior are unchanged; those failures still return
without writing or refreshing, but nothing shows their message now.
`test_skin_contract.py` now rejects `ToolTipText` on every meter in its 1,320
layout states and passes 28 tests on a clean export of the working tree. The
Lua suites and native runners now assert the absence instead, but were not
run: no standalone Lua interpreter is installed and native checks are pending.

### Spectrum drawer path cost (2026-10-11)

The open drawer saturated Rainmeter's main thread (96% of one core for Media
alone; 92% for the live seven-skin profile). The shared `SpectrumPaths.lua`
now rewrites the 24 band paths with literal geometry once per load, which
brings the open drawer to about 9% (square bars) or 11% (4 px rounded) in an
isolated Media-only instance. Raw and compiled paths evaluate to identical
coordinates under Rainmeter's own parser in eight configurations, 360 cases
each. `Test-MediaSettings.ps1 -VisualizerDrawerFocused`, which now also copies
`SpectrumPaths.lua`, passes its 4 cases (2,181 checks) with no Rainmeter errors
and the 8 known Settings-refresh warnings. On a clean export of the tree,
`test_skin_contract.py` passes 28 tests (now also pinning the compile measure),
`validate.mjs` passes, and `tools/Test-Parallax.ps1 -RequireAllModules
-WarningsAsErrors` reports 0 errors and 0 warnings. In the working checkout,
`test_skin_contract.py` errors because its `*.ini` glob reaches git-ignored
UTF-16 `Rainmeter.ini` files left by old CPU, RAM and Network runs. Details:
[PERFORMANCE.md](../PERFORMANCE.md#spectrum-drawer-path-cost-2026-10-11). The
native captures were not re-run; the compiled outline is coordinate-identical.

### Spectrum drawer (2026-10-10)

The change was designed by a research and judge panel, built, then reviewed
through three independent lenses (Rainmeter semantics, sub-pixel geometry,
regressions), each with a refuting verifier. Every confirmed finding was fixed
and re-verified: anchor ownership, the open state tied to the drawer include,
the plot inset at large corner radii, whole-pixel tab edges, miter corners at
CornerRadius 0, pixel-centred grid lines, the Visualizer menu's Quality and
Cadence reaching an open drawer, and the stepper settings row. All runs used
isolated Rainmeter 4.5.26 profiles; the live configuration was not touched.

- `test_skin_contract.py`: 28 tests pass in about 25 s (the suite now evaluates
  formulas numerically instead of expanding text; the unchanged HEAD suite took
  744 s). New tests cover the eager include-path capture, include order for
  each drawer state, closed identity with the pre-drawer formulas (identical at
  double width and when hidden; compact shifted by `Round(12×Scale)`), the open
  lift and every meter's shift, capture only at state 2, height presets, the
  plot-corner clearance at CornerRadius 0/6/12/24 × border 1/4 × scale
  1/1.25/2, the tab and chevron on the gear centre, pixel-centred grid lines,
  non-literal saved values, the settings stepper and the Visualizer menu bangs.
  Two rounds of deliberate production mutations (11 and 10) were all caught.
- `tests/Test-MediaSettings.ps1`: the full default matrix passed 60/60 plus
  label sync and 7 captures; focused Settings 2, QueueToggle 4, Header 12 and
  TitleRow 12 passed. The new `-VisualizerDrawerFocused` mode toggles closed →
  open → closed through the production tab action: compact and double
  186 → 278 → 186, Tall 186 → 318 → 186, the panel's screen Y unchanged at every
  stage, `AnchorY` and `ParallaxDrawerAnchorY` absent → lift → 0 with `AnchorX`
  untouched, AudioLevel present only while open, and a custom `AnchorY=20` left
  at 20 throughout. The settings stage steps the stepper both ways with
  wrapping, one save and one `ApplyVisualizerPreference` per click, and reads a
  saved `02` as Collapsed.
- `Test-Media.ps1` 449, `Test-MediaHeader.ps1` 563 (its harness now models the
  header icon's `MediaHeaderY`), `Test-MediaLifecycle.ps1` 6258 assertions.
  Visualizer `ColorSuite.lua` 69 cases (5 new for `Apply(false)`) and
  `SettingsSuite.lua` 236, through a scratch runner that is not checked in.
  `validate.mjs` (now with 1,296 grid-line checks) and `validate-settings.mjs`
  pass; `tools/Test-Parallax.ps1 -RequireAllModules -WarningsAsErrors` reports
  0 errors and 0 warnings.
- Standalone Visualizer: every resolved section and variable is identical to
  HEAD except measure order, five new host variables and an explicit
  `UpdateDivider=1`; its fresh preview logged no errors and its grid lines now
  render as single rows.
- Native pixel checks from scratch captures (R channel; border 50, sheet 45):
  CornerRadius 0 / border 4 tab and sheet corners are solid 50 with 0 outside;
  at scale 1.25 both tab edges are crisp and the chevron's ink centre is within
  0.06 px of the gear centre (0.3 px left of the 23 px tab's centre, as
  designed); at CornerRadius 24 / border 4 / scale 1.25 the plot inset is 16 px
  (padding 10) and the narrowest diagonal gap between the plot frame and the
  sheet stroke is 5.39 px against the required 5 (it overlapped by 3.08 px
  before); the three grid lines are single rows. A saved `02` renders the
  closed default tab with exactly one missing-file error and no capture, and
  one click opens the drawer normally. Setup corrects a drawer-owned anchor of
  92 to 0 and leaves a custom 20 alone.

Not verified: physical clicks (all toggles were dispatched to the production
action from inside the skin), the real WebNowPlaying plugin, mixed DPI, the
open drawer's CPU cost, live release of the capture on collapse, KeepOnScreen
near a monitor's top edge, and pixel crispness at scales 0.75, 1.5 and 2.
Windows taller than about 349 px are resampled by PrintWindow on the test host,
so scale-1.25 open captures were measured on the 126 preset instead. Each tab
click logs Rainmeter's "Parallax\Media\Settings is not active" warning when
Media settings is closed, the same as the existing queue toggle.

### Synthetic settings harness brought up to date (2026-10-04)

`tests/Test-MediaSettings.ps1` and `tests/MediaSettingsSuite.luatest` now
model the current drawer, transport and single-row title. Before this pass,
40 of the 60 default cases and the label-sync case failed on native skin
height, probing the removed `MeterPlayerName` logged 40 Rainmeter errors, and
only the 20 Settings cases passed. The harness changes:

- **Height model.** The suite's geometry mirrors `media_body_geometry` and
  `media_drawer_geometry` in `test_skin_contract.py` from the same primitives
  instead of reading the skin's variables back: the body ends one padding below
  the timing text, wide art is sized from the body, compact art sits at y30,
  the circles are centred on the panel's lower border, and the window clears
  the art, circles and open sheet.
- **Title.** `MeterHeading` must show `MeasureMediaHeader` whole (`Text=%1`),
  reading `Media Player: <state>` at double width and `Media: <state>` at one
  column, with title typography, no tooltip, `ClipString=1` and the 24 px gear
  clearance; `MeterPlayerName` must be absent; exactly one title icon shows in
  the shared slot, matching the header text. The synthetic WebNowPlaying
  include now keeps the production `MediaPulse.lua`, which it previously
  dropped, so the icon swap runs natively. Identity stages wait one
  `#MediaLegacyDivider#` cycle so the title is observed at its production
  cadence; the paused stage expects `paused` with Monitor Play, and the
  disconnected and idle stages expect `stopped`. The title glyph probe binds
  `MeasureMediaHeader`, so it measures the live text.
- **Queue.** Rows, digits and delimiters on the drawer pitch from
  `MediaQueueRowsY`, the column header at the sheet top, hidden parts parked at
  the inset, the sheet's open and closed bottom, the notch toggle and label,
  and the retired footer staying hidden. Setup must hide the tab.
- **Transport.** Static placement (`LayoutTransport` is disabled): 44 px boxes
  on a 38 px pitch, accent faces with background-coloured glyphs, play/pause art
  from `Shape4`, clear of the first queue row. Timing keeps its right
  alignment, cap and auto width.
- **Runner.** Pixel checks read the rendered bounds the suite reports instead
  of re-deriving pre-drawer coordinates; the transport check samples each
  accent face and its glyph. The fixed 50 s report deadline is replaced by a
  45 s no-progress / 300 s overall limit: full runs now take 58–61 s, so the
  old deadline would fail them outright. One fixture regex now tolerates a
  CRLF checkout of `Settings.ini`.

Results in isolated Rainmeter 4.5.26 on main `c95f235` (the paused title and
compact `Media:` label), zero Rainmeter errors in every run:

- Full default matrix: 60/60 cases and label sync passed, with 7 captures,
  under the documented `powershell.exe` 5.1 command. Before those two commits
  it had also passed twice, under PowerShell 7.6 and 5.1.
- Focused modes under Windows PowerShell 5.1: title row 12, identity 25,
  player name 5, queue toggle 4, queue empty 1, bar thickness 3, artwork 39,
  header 12 and compact status 1 layouts, all passing. The settings-only and
  source-integration modes were not rerun: their code is unchanged and the full
  run's 30 Settings and Typography Settings cases cover it.
- `test_skin_contract.py`: 15 tests passed; no production file changed.
- Inspected captures include compact 180 at 12 pt showing `Media: Spotify`
  with Audio Lines and `Media: stopped` with Monitor Play, both unclipped.
  These are synthetic native renders, not the live screen.

Measured by the title probe, which renders the same bound text as the title.
Fit is asserted except at double width 180 with the 12 pt title, which is
reported. IBM Plex Sans at scale 1; values are glyph/box px; compact layouts
read `Media: <state>`, double width `Media Player: <state>`.

| Title | Compact 180 | Compact 220 | Double 180 | Double 220 |
| --- | --- | --- | --- | --- |
| 10 pt `stopped` | 96/126 | 96/166 | 138/144 | 138/224 |
| 10 pt `Spotify` | 89/126 | 89/166 | 132/144 | 132/224 |
| 12 pt `stopped` | 115/123 | 115/163 | 166/141, clips | not measured |
| 12 pt `Spotify` | 107/123 | 107/163 | 158/141, clips | 158/221 |

The remaining items are measured but not failed, because each belongs to an
open design decision below:

- The notch label `Queue` is clamped to 7 px at compact width 180 and to 1 px
  at double width 180, leaving the icon alone, and clips by 7 px at double 220
  with a 10 pt header.
- With the queue expanded at compact width 180, the circles cover part of the
  `Song / Artist` column header: a 36×13 px box overlap at the default font,
  52×13 at the maximum. Compact 220 and double width were not measured.
- The right circle overlaps the timing text in every compact layout and at
  double 180 (for example 34×11 px at compact 180, 19×11 at compact 220 and
  8×11 at double 180, all scale 1); double 220 shows none.
- Setup has no drawer, but with `QueueExpanded=1` its rows still render
  below the panel with no sheet and no toggle to collapse them.

Not verified: the real WNP plugin and a live player, physical pointer input,
mixed DPI and performance. Evidence for the final full run:
`%TEMP%\Parallax-MediaSettings-test-f7a5ef4dec744c7aaeb103353001f230`; the
focused runs' roots sit beside it.

### Single-row title and playing-state icon (2026-10-04)

- `test_skin_contract.py`: 15 tests / 3,472 subtests passed, covering Media,
  Setup, Queue and Settings across widths, scales, columns and font profiles.
  The header test now asserts the bound `%1` title (the script supplies the
  label since the compact `Media:` change), the removed
  player row, both icons sharing one box, the 24 px gear clearance and the
  compact art/metadata positions; the independent geometry model moved compact
  progress from 134 to 112 px and compact art from y44 to y30.
- `tests/Test-MediaHeader.ps1`: 526 assertions passed in an isolated Rainmeter
  4.5.26 with the unchanged UTF-16 `MediaHeader.lua`, the real `MediaPulse.lua`
  and `Header.inc`, and a clean log. Synthetic stages cover playing names,
  paused (state 2), stopped (state 0), disconnected and empty-track samples, and
  playing again afterwards. At every stage exactly one icon is visible (the
  hidden one reports 0×0) and it agrees with the title text.
- Owned-window captures from a scratch fixture that replaces the WNP plugin
  measures with fixed Script values (Media.ini, width 220, scale 1, 12 pt):
  double playing 456×186 (Audio Lines, `Media Player: Spotify`), double paused
  456×186 (Monitor Play, `Media Player: stopped`), compact playing 228×174 and
  compact stopped 228×174, which shows the `stopp…` clip measured above. All
  four were inspected. Their logs' only errors came from the fixture's fake
  cover value, not from the skin.

Not verified: the real WNP plugin and a live player, the animation's smoothness
on screen, and mixed DPI. The compact captures also show the transport circles
overlapping the timing text's right end. That overlap existed before this
change, because everything below the header moved together, and it belongs to
the deferred transport x-axis decision.

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

- Resolved (2026-10-04): the compact 12 pt clip of `Media Player: stopped`
  (2.6 px) is fixed by the compact `Media:` label, chosen by the user over a
  narrower gear clearance, a second header line or accepting the ellipsis.
  Rendered appearance of the shorter label is not yet checked on screen; the
  synthetic native harness renders it unclipped at compact 180 and 220 with
  both title sizes. Still open: double width 180 at 12 pt clips
  `Media Player: stopped` (166/141 px) and `Spotify` (158/141).
- Done (2026-10-04): the synthetic settings harness (`tests/Test-MediaSettings.ps1`
  with `tests/MediaSettingsSuite.luatest`) now matches the drawer, static
  transport and single-row title; the full matrix and nine focused modes pass.
  See [the harness entry](#synthetic-settings-harness-brought-up-to-date-2026-10-04).
- Open (2026-10-04), part of the deferred transport x-axis decision: the
  circles overlap the timing text in compact layouts and at double 180, and,
  with the queue expanded at compact 180, part of the `Song / Artist` header,
  which `InlineQueueGeometry.inc` assumes ends left of the buttons. The notch
  label degrades to its icon at width 180 in both layouts. The harness
  measures and reports all three.
- Open (2026-10-04): Setup has no drawer, yet `QueueExpanded=1` (saved from
  the player or Settings) still shows its queue rows below the panel, with no
  sheet and no toggle. Either suppress the rows in Setup or give it the drawer.
- Open (2026-10-10), spectrum drawer: measure the open drawer's CPU cost with
  WebNowPlaying loaded; confirm on the live desktop that the panel holds still
  through physical tab clicks, near a monitor's top edge and at mixed DPI; and
  decide whether the tab's warning about an unloaded Media settings config (shared
  with the queue toggle) is worth suppressing. The compact open sheet's square
  edge in the panel's rounded corner is shared with the queue sheet and belongs
  to any later sheet-corner pass. A slide animation is still blocked by the
  write-and-refresh toggle.
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







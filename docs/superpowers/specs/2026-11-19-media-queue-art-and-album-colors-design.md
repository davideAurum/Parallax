# Media: queue cover art and album colors — design and decision log

Date: 2026-11-19. Branch: `media-queue-art-and-album-colors`.

David asked for four Media player upgrades, worked through them with mockups,
then said: *"build as much as you can, making decisions along the way to your
recommendations, and give me the option to walk them back later."* Every
decision below is marked **David** (he chose it) or **Claude** (made under
that instruction), with how to walk it back.

## Intent

- Make the queue drawer read like a music app: each upcoming track shows its
  cover, and the rows are visibly clickable.
- Make the player take on the current song's colors without losing the
  suite's restrained look. The black panel stays black; the transport keeps
  the theme accent.
- Non-goals this round: reordering the queue (Spotify's Web API has no reorder
  or remove call), per-row queue colors from each row's own cover (David's
  follow-up exploration, later), thumbnails in the standalone Queue panel.
- Anti-goals: colors that make text unreadable on the black panel; a recolor
  path that costs anything on the 50 ms tick; a process launched per song.

## Spike results (2026-11-19, isolated Rainmeter 4.5.28, Chameleon 1.6.5 x64)

1. **Same-path covers.** WebNowPlaying writes every cover to one fixed file
   (`%TEMP%\Rainmeter\WebNowPlaying\cover.png`). Chameleon re-sampled about
   1 s after that file was overwritten, with no path change or reload.
2. **Which outputs to trust.** `Light1`, `Light2` and `Average` were stable
   and plausible for a warm, a cool and a grayscale cover. `Background*`,
   `Foreground*` and `Dark*` repeatedly fell back to `FFFFFF`/`000000` a second
   after a good sample, so they are not used. Output is hex regardless of
   `Format=Dec`.
3. **Gradient extent.** `InlineSetting=GradientColor` spans the String meter's
   box, not the glyphs; angle 180 runs left to right. A meter that sizes to its
   text (`ClipString=2` with `ClipStringW`/`ClipStringH`) makes the gradient
   span exactly the words and still clips long text to one line.
4. **Recolor cost.** Setting options on 13 meters (10 shapes, 3 gradient
   texts), forcing their updates and one redraw took about 2 ms per recolor
   (50 recolors: 81–90 ms total).

## Decisions

### Queue drawer

| # | Decision | By | Walk back |
| --- | --- | --- | --- |
| Q1 | Drawer sheet starts at the big cover's left edge (wide layout), drawn behind the cover; rows span that full width. Compact width (`Columns=1`) is unchanged because its sheet already starts at the panel edge. | David | `MediaQueueDrawerLeft` in `InlineQueueGeometry.inc` back to `#MediaSurfaceX#`. |
| Q2 | The `#` position column and the `|` row dividers are removed. | David | Restore the number/divider meters in `InlineQueueMeters.inc` (git history). |
| Q3 | Each row shows the track's cover thumbnail. | David | — |
| Q4 | Two row sizes in Media settings, **Normal** (default: 36 px rows, 32 px covers, song above artist) and **Compact** (18 px rows, 16 px covers, one `Song / Artist` line). Saved as `QueueRowSize` (`1` Normal, `0` Compact). | David (sizes), Claude (Compact = the 18 px option, key name) | Set `QueueRowSize=0`, or change the shipped default in `User/Media.inc`. |
| Q5 | Clickable rows get a hover highlight (white at about 7% over the sheet). Only rows the reader marks clickable highlight. | David | Remove the hover actions from the row hit meters. |
| Q6 | Refresh is a Lucide `refresh-cw` icon in theme Accent 1 at the header's right end. The standalone Queue panel keeps its text Refresh. | David (icon), Claude (glyph, standalone) | Restore the text label in `QueueControlHost.inc`. |
| Q7 | The queue text keeps theme colors (songs `TextColor`, artists Accent 2); album colors do not reach it. | David (message cut off; read as "keep today's queue colors") | — |
| Q8 | When the queue reads fine but the sign-in lacks playback control, the header shows **Sign in again** in place of `Song / Artist`, so inert rows explain themselves. | Claude | Drop the `control` check in `QueueReader.lua`'s header text. |
| Q9 | Setup shares the new rows (it includes the same `InlineQueueMeters.inc`): thumbnails, no clicks, no hover, no Refresh. | Claude | Fork the meters for Setup. |
| Q10 | Thumbnails come from the queue helper: for each shown item it takes Spotify's smallest image of at least 48 px (64 px album art in practice; episodes use their own or the show's images), downloads it once over HTTPS from Spotify's image CDN only (`*.scdn.co`, `*.spotifycdn.com`), without the Spotify token, capped at 256 KB and 5 s, into `%LOCALAPPDATA%\Parallax\Media\Spotify\covers\<sha1-of-url>.<jpg|png>`, and prunes that folder to the 60 most recently used files. Disconnect deletes the folder. A missing or failed image shows a neutral tile. | Claude | Remove the image step from the helper; the reader treats empty image names as "no cover". |
| Q11 | Snapshot format `PARALLAX_QUEUE_V4` = V3 plus `image1`..`image5` (each empty or a bare file name `^[0-9a-f]{40}\.(jpg|png)$`). The reader still accepts V2 and V3 (no images). | Claude | — |

### Album colors

| # | Decision | By | Walk back |
| --- | --- | --- | --- |
| C1 | A Media settings switch **Album colors** (`MediaAlbumColors`, default `1`). Off loads no color measure at all and the player uses the theme exactly as before. | David (toggle; default on confirmed 2026-11-19) | Set the shipped default to `0`. |
| C2 | Background panel stays `BackgroundColor`. Only the lighter gray surfaces are tinted toward the cover's main color: queue sheet and notch, progress track, panel border, shuffle face when off. | David | — |
| C3 | Tint strength `MediaAlbumTint`, default 10 (%), adjustable 0–30 in Media settings. | David (10%, adjustable), Claude (range) | Change the default or range. |
| C4 | Transport buttons (including repeat when on) keep theme Accent 1. | David | — |
| C5 | Song, artist and album icons use theme Accent 1 always, whether album colors are on or off. | David (icons), Claude (always) | Restore `MutedColor` on the three icons in `PlayerMeters.inc`, or tie it to the switch. |
| C6 | The title icon, the progress fill and the queue notch icon (today's `MediaColor` uses in the player) take the cover's main color, lifted to be readable. | David | — |
| C7 | Song, artist and album text get a left-to-right gradient between two cover colors, spanning each line's own words (mockup F). | David | — |
| C8 | The open spectrum drawer's bars use the same two cover colors (horizontal) while album colors are on. The standalone Audio Visualizer is untouched. | Claude (David accepted the proposal) | Skip the drawer in `AlbumColors.lua`. |
| C9 | Colors are extracted by the Chameleon plugin 1.6.5 (BSD-3, Socks the Fox), bundled in the `.rmskin` the same way as WebNowPlaying. It reads WebNowPlaying's cover file in-process: no extra process, network or polling. Missing plugin: album colors stay on the theme and settings says the plugin is unavailable. | Claude (recommended, spike passed); David approved bundling and the `AGENTS.md` exception, 2026-11-19 | Remove `packaging/Plugins/Chameleon` and its `release.json` entry; the skin then shows the unavailable state. |
| C10 | Color rules (in `AlbumColors.lua`): candidates are `Light1`, `Light2`, `Average`. If none reaches 18% HSL saturation, the cover counts as colorless and the theme is used. Main color = `Average` when saturated enough, else the most saturated candidate. Text colors = the two most saturated candidates at least 25° apart in hue (else the second is the first shifted 30°), lightness raised to at least 68% and saturation capped at 85% for reading on the black panel. Media color = main color with lightness clamped to 55–75%. | Claude | Tune constants at the top of `AlbumColors.lua`. |
| C11 | Recolor happens only when the sampled colors change (checked once per `MediaInterval`), by Lua `!SetOption` on the affected meters with forced updates and one redraw (about 2 ms). No `DynamicVariables`, no refresh. | Claude | — |

## Calls made while building (all Claude; small to walk back)

- Q8 applies only to snapshots that state the permission (V3/V4 `control=0`);
  an old V2 snapshot keeps `Song / Artist`.
- C9's "plugin unavailable" note: Media settings probes for `Plugins\Chameleon.dll`
  in Rainmeter's settings and program folders and shows "Album colors need the
  Chameleon plugin." in its status line.
- Recolors the queue notch's List icon with the title icon's color (it was
  `HeaderTextColor`), as in the mockups.
- Helper covers (beyond the brief): a downloaded file must also start with the
  JPEG/PNG signature; a failed URL is not retried for 5 minutes (per worker);
  a request with no response ends that read's remaining downloads; only
  lowercase CDN hosts are accepted; when no image reaches 48 px the last listed
  is used; pruning runs on successful reads only; a Disconnect that cannot
  delete the covers folder stays `onboarding_required`.
- The settings and transport native harnesses stub `AlbumColors1.inc` (their
  fixtures load no plugin) and now copy `@Resources\Dev\Hook0.inc`, which they
  had lacked since developer mode landed.

## Open risk to check before release

- **libChameleon has no license file — decided 2026-11-19 (David): ship and
  ask.** Chameleon's own repository is BSD-3, but the DLL statically links the
  author's separate `libChameleon` repository, which declares no license. The
  binary release is published by the same author for redistribution in skins,
  and Rainmeter suites commonly bundle it, but that is an inference, not a
  grant. The bundle ships while David asks the author to add a license; if the
  author declines, walk back C9 or swap in a PowerShell-per-song extractor.
  **Resolved 2026-11-20:** in socks-the-fox/libchameleon#1 the author confirmed
  the released DLL is BSD-3 and redistributable, and added a BSD-3 license to
  libChameleon (commit `d2cd6b9`); its text now ships in `Chameleon-LICENSE.txt`.
- Live checks not possible from this session: real Spotify thumbnails and
  clicks after signing in again, Chameleon on real WebNowPlaying covers, and
  the look at 150% on the live desktop (the preview instance cannot run
  WebNowPlaying beside the live one).

## Builder notes

- Files: `InlineQueueGeometry.inc`, `InlineQueueMeters.inc`,
  `Queue/QueueReader.lua` (UTF-16LE, mixed line endings — edit via a decode,
  edit, re-encode round trip), `Queue/QueueControlHost.inc`, `QueueCore.psm1`,
  `QueueProvider.ps1`, `PlayerMeters.inc`, `TransportIcons.inc`, new
  `AlbumColors0.inc`/`AlbumColors1.inc`/`AlbumColors.lua`, `Settings.lua`,
  `SettingsMeters.inc`, `User/Media.inc`, packaging, docs and the Media/Queue
  test suites, which hard-code today's geometry and meter names.

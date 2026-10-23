# Can WebNowPlaying replace Media's Source observer?

Evaluation for owner decision 4 ([PERFORMANCE-REVIEW.md](PERFORMANCE-REVIEW.md#owner-decisions-2026-10-22), "rework and evaluate"), 2026-10-22. **Nothing has been replaced.** The behaviour-preserving rework of the observer is on branch `perf/A2-media-source`, and this document is the evaluation half of that package.

## Answer

**Not with WebNowPlaying 2.0.7 as shipped.** The observer exists for one job: deciding which application owns the Windows media session that WebNowPlaying (WNP) reports under the generic name `Windows Media Session`. WNP's native adapter knows that application ID. It keeps it inside an internal record, and none of the plugin's Rainmeter measures returns it. A skin therefore cannot tell Spotify from any other desktop player through WNP alone.

**Recommendation: keep the reworked observer for now, and ask WebNowPlaying upstream for a measure that exposes the selected session's app ID.** If that measure ever ships, Media can identify Spotify exactly and retire the observer. Details are under [Recommendation](#recommendation).

## What the observer publishes, and who reads it

The observer writes `%LOCALAPPDATA%\Parallax\Media\Source\source.snapshot`. Line numbers refer to branch `perf/A2-media-source`.

| Field | Produced in `Source/SourceProvider.ps1` | Read in `Source/SourceReader.lua` | Used for |
| --- | --- | --- | --- |
| `state` (`ready`, `unavailable`, `stopped`) | `New-SourceSnapshot` :223-228; `Get-SourceCollection` returns `unavailable` on any failure :427; Stop and the worker's exit write `stopped` :526, :551 | `parse` :65-69; `resolve` :97-99 | Anything but a fresh `ready` snapshot leaves the header at `Unknown` |
| `observed`, `valid_until` (= observed + 6) | :227, checked :237 | `parse` :70 (rejects a future `observed` and a wrong lifetime), :82 (`stale` once `now >= valid_until`) | Freshness: an old observation is never treated as current |
| `count` and up to 16 records | :234-235, :241-249 | `parse` :64, :73-80 | Every session, so duplicates can be detected |
| `sourceN` (`spotify` or `other`) | `Get-SourceKind` :206-212, an exact match of the session's `SourceAppUserModelId`, applied at :425 | `resolve` :109 | **The only thing WNP cannot supply** |
| `titleN`, `artistN` (UTF-8 hex) | :246-247 | `parse` :75; `resolve` :104 compares them exactly with WNP's `MeasureTitle` and raw `MeasureSourceArtist` (`WebNowPlaying.inc` :19-23, :33-37) | Correlating the WNP track with one Windows session |
| `playingN` | :248 | `resolve` :110 compares it with WNP's `MeasureState` | A paused Spotify and a playing other app with the same track are not confused |

The reader runs only while WNP is connected and `MeasurePlayer` is exactly `Windows Media Session` (`SourceReader.lua` :160). It returns `Spotify` only for exactly one matching record classified `spotify` with a matching state (:100-113). Otherwise it returns `Windows`, and one of the reasons `incomplete`, `missing`, `stopped`, `stale`, `unavailable`, `ambiguous` or `unmatched`, which only its tests read.

The result reaches the screen in one place. `MeasureMediaSource` (`WebNowPlaying.inc` :105-108) feeds `MediaHeader.lua`, which shows `Spotify` when the reader says so and `Unknown` otherwise, while a generic Windows session plays (:59-62). No other Media code references `MeasureMediaSource`. **The observer's entire visible output is that one word in the header.**

## What WNP 2.0.7 exposes

Source: [keifufu/WebNowPlaying-Rainmeter at tag 2.0.7](https://github.com/keifufu/WebNowPlaying-Rainmeter/tree/2.0.7), read on 2026-10-22. Parallax bundles this version ([Media.md Dependencies](modules/Media.md#dependencies)). Line numbers are approximate: the files were read through a web fetch, not a local checkout.

- **Measures** (`src/WebNowPlaying.cs`):
  - The `PlayerType` options are `Status`, `State`, `Volume`, `Rating`, `Repeat`, `Shuffle`, `Progress`, `Position`, `Duration`, `Remaining`, the `Supports*` capability flags, `RatingSystem` and `IsUsingNativeAPIs` (numbers), plus the strings `Player`, `Title`, `Artist`, `Album`, `Cover` and `CoverWebAddress`.
  - Every measure reads the one shared `WNPRedux.MediaInfo`. There is no option to choose a player or list players.
  - The first measure starts both `WNPRedux.Start(8974, …)` and `WNPReduxNative.Start(8974)` (about :207-208).
- **Native adapter** (`src/WNPReduxAdapterLibraryExtensions/WNPReduxNative.cs`):
  - **Events, no polling.** It subscribes to `SessionsChanged` (about :160) and, per session, to `MediaPropertiesChanged`, `PlaybackInfoChanged` and `TimelinePropertiesChanged` (about :185-187). The only timer is a 1 s optimistic position tick, armed by timeline changes, that advances a playing position.
  - **Browsers skipped.** It skips app IDs containing `chrome`, `chromium`, `msedge`, `opera`, `brave`, `vivaldi` or `firefox`, plus a few Firefox-family package IDs (about :220-240). The browser extension covers those players instead.
  - **One player name for everything.** `mediaInfo.PlayerName = "Windows Media Session"` for every native session (about :106).
  - **The app ID stays internal.** `SourceAppUserModelId` appears only in the internal key `MediaInfo._ID` (prefix plus app ID, about :104) and in a private session dictionary.
  - **Two states only.** `Playing` maps to PLAYING; every other status maps to PAUSED (about :260).
- **Selection** (`src/WNPReduxAdapterLibrary/WNPRedux.cs`):
  - Entries are ordered newest first. The first that is playing with volume above 0 wins; otherwise the newest wins (about :158-180).
  - `MediaInfo` and `mediaInfoDictionary` are `public static` (about :24, :55), and `MediaInfo._ID` is a public property (`MediaInfo.cs` about :51). That makes them reachable from .NET code inside Rainmeter's process, but not from skins or Lua.

Not verified: WNP's behaviour in a running Rainmeter (nothing was instrumented), and the exact line numbers.

## Gap table

| What Media relies on today | Observer | WNP 2.0.7 measures | Gap |
| --- | --- | --- | --- |
| Which application owns the generic session | Yes: `SourceAppUserModelId` classified per session | No: `Player` is always `Windows Media Session`; the app ID sits only in internal `_ID` | **Blocking** |
| Every session, so two apps showing the same track read as ambiguous | Yes: up to 16 sessions, browsers included as `other` | No: one selected session; native browsers are skipped | **Blocking** for the ambiguity rule |
| Title and artist of the playing track | Yes, per session | Yes, selected session only | None |
| Playing or paused | Per session | `State` 1 or 2 (non-Playing reads as paused) | None; the reader already maps it this way |
| Freshness | `observed` plus a 6 s expiry | No heartbeat or timestamp exposed ([Media.md](modules/Media.md#provider-behavior-and-limits): stalled data cannot be detected) | Not needed if WNP were the only source; it already drives the rest of the UI |
| Cost | A resident PowerShell process collecting every 2 s | Event-driven and in-process, already running | The reason for this evaluation |

## Options

1. **Retire the observer now.**
   - **Header:** every generic desktop session, Spotify included, shows `Media Player: Unknown` while playing (`MediaHeader.lua` :59-62). That is honest, with no stale or fabricated state.
   - **Gains:** the helper's whole cost, and one PowerShell Resume host per Media refresh.
   - **Losses:** the feature the owner asked for. The Source detection settings row, `SourceReader.lua`, `Lifecycle.inc`'s Source host and the docs would also need removing.
2. **Keep the reworked observer** (this package).
   - **Behaviour:** visible behaviour and honest states are unchanged.
   - **Cost:** see [Cost context](#cost-context). The PowerShell collection is now the floor, at roughly 1% of a core rather than the 0.5% the review hoped for. Step 3 has to measure it.
   - **Risk:** the change-only heartbeat leaves about 1-2 s of margin before the reader would call an observation stale, against about 3 s before (see [Media.md](modules/Media.md#source-setup-and-behavior)). A heartbeat delayed beyond that shows the honest `Unknown` for about a second.
3. **Hybrid: collect only when WNP's track changes.**
   - **How it works:** `SourceReader.lua` already reads WNP's title, artist and state every second. It would write a small request token whenever those change while the player is `Windows Media Session`. The observer would collect once per request instead of every 2 s.
   - **Gains:** idle cost close to zero.
   - **Costs:** a protocol change. Validity would be tied to the requested WNP track, with some liveness signal, because a dead observer must still expire. The reader would gain file writes and the observer a file watch. Spotify would be confirmed on the next WNP change instead of within 2 s.
   - **Risk:** medium. It also touches Media files outside this package, so it belongs in phase B or C.
4. **Event-driven observer** (ENGINE-10).
   - **How it works:** the helper subscribes to the same Windows media events WNP uses and publishes on change.
   - **Costs:** PowerShell 5.1 has no clean way to attach WinRT event handlers, so this means compiled C#, one compile per worker start (the GPU and RAM hosts already do this). The 6 s protocol still needs a heartbeat unless validity is widened, which is an owner-visible trust-window change.
   - **Risk:** medium.
5. **Ask WebNowPlaying upstream for an app-ID measure**, for example a `PlayerType` returning the selected `MediaInfo`'s app ID, which `_ID` already holds.
   - **Gains:** the reader could then identify Spotify exactly, with no correlation and no helper, and the observer could be retired.
   - **Costs:** it depends on upstream and on a later WNP release, which would need the bundled-plugin provenance and license review again.
6. **A Parallax plugin that reflects into WNP's loaded assembly to read `_ID`.**
   - **Feasible** in principle, because the members are public.
   - **Not recommended:** it couples Parallax to WNP's internals, adds a compiled binary to distribute and needs both bitnesses.

## Cost context

- **Before the rework** ([PERFORMANCE-REVIEW.md](PERFORMANCE-REVIEW.md#live-quiet-state-footprint)):
  - The largest Parallax helper: 7.6% of one core live, 4,856 CPU-seconds in 19 h (:53).
  - 7.1% mean and 12.3% p95 in the ten-minute quiet trace (:73).
  - Phase A2's target was below 0.5% (:372).
- **After the rework** (functional profiles on 2026-10-22, not benchmarks; the machine was shared with parallel build agents, so absolute values are inflated; step 3 measures properly):
  - **Stop check:** about 5.8 ms per call before, ten times a second, which is about 5.8% of a core on its own. After: one wake per 2 s cycle, and the check is two .NET calls.
  - **Collection:** about 20-25 ms of CPU per cycle (median 11 ms wall, 45 timed collections). That is three enumerations and two reads per session in PowerShell; about nine deadline checks at about 1 ms each are the largest single part.
  - **Snapshot text:** 2-3.6 ms per cycle.
  - **Snapshot write:** about 10 ms of CPU, now about every 4 s instead of every 2 s.
  - **Real worker, 20 s windows:** the old worker used 11.2% of a core and the new one 2.1-2.5%, including first-run script compilation. The in-process steady-state estimate is about 1.5% under the same load.

The reworked helper should therefore land around 1% of a core, against 7.6%. Retiring it (option 1 or 5) or going event-driven (options 3 and 4) would remove most of what remains.

## Recommendation

1. **Ship the behaviour-preserving rework (option 2)** and measure it in step 3. It keeps the feature and every honest state.
2. **Do not retire the observer in favour of WNP 2.0.7's measures.** The app ID never reaches a measure, so Spotify identification would be lost entirely.
3. **If step 3 shows the helper above the target and the owner wants it lower,** trim the collection's PowerShell overhead next: cheaper deadline checks and a non-closure clock. That is low-risk and keeps the protocol. After that, the event- or request-driven designs (options 3 and 4) are the next steps.
4. **In parallel, ask WebNowPlaying upstream for an app-ID measure (option 5).** It is the clean long-term path: exact identification, no helper, no correlation.

Decisions for the owner:
- Is Spotify identification in the header worth a resident helper at the cost step 3 measures?
- Should an upstream request be filed with WebNowPlaying?
- Is the heartbeat trade-off (about 4 s writes with about 1-2 s of margin) acceptable, or should every cycle be written again (`$script:SourceHeartbeatLeadSeconds = 4.0`) while keeping the other gains?

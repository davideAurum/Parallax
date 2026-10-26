# Updates

How a new Parallax release reaches an installed copy: the daily check, the update prompt and the **Updates** section of Global Settings. Until 2026-10-26 the only entry point was a **Check for updates** button on the Welcome panel; see [Moved from the Welcome panel](#moved-from-the-welcome-panel-2026-10-26).

## Dependencies

Inherit the [shared platform and bundling requirements](DEPENDENCIES.md#shared-requirements).

| Component | Classification | Feature, lifecycle and unavailable behavior |
| --- | --- | --- |
| Rainmeter's built-in WebParser measure and network access to `github.com` | Supplied by Rainmeter / the user's connection | One request for `parallax-update.json` per check: Check now, Global Settings opening (with Auto check on and no check in the last 10 minutes), and the daily background check. Offline: `Could not reach github.com.`; nothing else changes. |
| `@Resources/Update/Update.lua`, `Feed.inc`, `Install.inc`, `Hook0.inc`, `Hook1.inc` and `@Resources/Version.inc` | Bundled source; required for any update check | The one controller for Global Settings, the prompt and the utility hook; the feed request; the install measure; the hook variants; the installed version and feed address. |
| `@Resources/Update/State.inc` | Bundled runtime file; required for saving results | Shared check state (last check, result, latest offer, dismissed version). Written only by `Update.lua` through `!WriteKeyValue`; ships blank and an upgrade replaces it. `!WriteKeyValue` never creates a file, so if it is missing no background check runs and Global Settings says `Update state file is missing. Reinstall Parallax.` |
| `Parallax\Update` (`Update/Update.ini`) | Bundled config; optional | The prompt. Opened only by the background check for a newer version not dismissed with Later; closes itself when there is nothing left to offer. Missing: the check never activates it (an activation of a missing file would open a modal) and Global Settings still shows the offer. |
| `@Resources/Idle/Link.lua` and `#SETTINGSPATH#Rainmeter.ini` | Bundled reader; Rainmeter's own settings file | Read only, to see whether the prompt is already open and whether it has a recorded position. Unreadable: no prompt is opened. |
| `@Resources/Scripts/UpdateInstall.ps1` via Rainmeter's bundled RunCommand plugin and Windows PowerShell 5.1 | Bundled helper; used only by **Update** | One hidden, one-shot launch per Update click, unchanged from the Welcome panel. If PowerShell is unavailable the status reads `Download failed. Nothing was installed.` |
| Rainmeter's `SkinInstaller.exe` (from `#PROGRAMPATH#`) or the `.rmskin` file association | Required for Update; supplied by Rainmeter | Performs the upgrade after the user confirms. |

No process, plugin, scheduled task, service or account is added. The automatic check adds one Script measure and one disabled WebParser to each loaded utility while Auto check is Daily (the default); Off loads nothing.

## Design in one paragraph

Each release is a normal GitHub release on `davideAurum/Parallax` tagged `v<version>`. It carries two assets: the `.rmskin` package, and a small `parallax-update.json` manifest that `Package-Parallax.ps1` writes beside it. An installed suite knows its own version from `@Resources\Version.inc`. A check is one request from Rainmeter's built-in WebParser to `https://github.com/davideAurum/Parallax/releases/latest/download/parallax-update.json`, a stable GitHub address that always resolves to the asset of the release marked **Latest**. Checks run in the background from the loaded utilities about once a day, when Global Settings opens, and on **Check now**. A newer version opens a small **Parallax update** prompt with **Update**, **Notes** and **Later**, and Global Settings' **Updates** section shows the same offer. Update runs one hidden helper that downloads the package into `%TEMP%\Parallax\Update`, checks its SHA-256 against the manifest and its RMSKIN trailer, and then opens it in Rainmeter's own Skin Installer. The Skin Installer dialog is the confirmation step: nothing changes until the user clicks Install there, and the package's Variables-files list preserves `@Resources\User\*.inc` settings exactly as a manual upgrade would.

```text
 release (maintainer)                          installed suite (user)
 ─────────────────────                         ──────────────────────
 bump version (release.json + Version.inc)     loaded utility: Hook1.inc, 60 s after load, then hourly look
 Package-Parallax.ps1                            │ due? (24 h after a good check, 1 h after a failed one)
   ├─ dist\Parallax_<v>.rmskin                    │ WebParser, one GET          Global Settings ▸ Check now
   ├─ dist\Parallax_<v>.rmskin.sha256             ▼                                  │ (also as it opens)
   └─ dist\parallax-update.json  ──publish──▶  releases/latest/download/parallax-update.json
 gh release create v<v> (marked Latest)           │ Update.lua: classify, validate, compare
                                                  ▼
                                                @Resources\Update\State.inc (shared result)
                                                  │ newer and not dismissed
                                                  ▼
                                                Parallax\Update prompt: [Update] [Notes] [Later]
                                                  │ Update: UpdateInstall.ps1 (one-shot, hidden)
                                                  │   download ▸ SHA-256 ▸ RMSKIN trailer
                                                  ▼
                                                Rainmeter Skin Installer ▸ user confirms ▸ upgrade
```

## Why this shape

- **No server to run.** GitHub Releases already hosts versioned assets, and `releases/latest/download/<asset>` gives a fixed feed address that never needs to change in shipped skins.
- **A pull at low cadence, not a push.** A true push needs something to receive it. GitHub webhooks POST to a public HTTPS server; a desktop behind a router cannot receive them without a relay service (a server of our own, or a third party such as ntfy or smee) and a resident listener holding a connection open. WebParser cannot hold a stream, and a resident listener would break the suite's no-resident-polling rule and add a service dependency. GitHub offers no client push for releases. Releases come days or weeks apart, so a daily check finds one within a day for one small request.
- **Not the REST API.** The feed is a release asset behind a `github.com` redirect, not `api.github.com`, so the REST API's limit of 60 unauthenticated requests per hour per address (`X-RateLimit-Limit: 60`, measured 2026-10-26) does not apply. A rate-limit page is still recognized and reported.
- **Built-ins first, no process for polling.** The background check is a WebParser request driven by a Script measure and Rainmeter's own `[!Delay]` timer. The only process launch is the explicit Update click, as the collaboration contract requires.
- **No new resident window.** The check rides on the utilities that are already loaded, wired like the Idle hook, instead of a hidden config of its own: a hidden window adds about 15 to 57 UI-thread wakeups a second through the DXGI message hook ([ARCHITECTURE.md](ARCHITECTURE.md#input-idle-coordinator)). The prompt window exists only while it is shown.
- **Rainmeter does the installing.** Parallax never copies files over itself. Skin Installer already handles backup of the old folder, Variables-file preservation, plugin updates, unloading and reloading configs, and minimum Rainmeter/Windows checks. Doing any of that in a script would duplicate it badly.
- **The user confirms twice, both times on purpose.** The prompt or Global Settings says an update exists and asks before downloading, and Skin Installer shows the package before installing it.
- **Remote text is data.** The manifest is parsed with fixed patterns. A package URL is accepted only when it is exactly `https://github.com/davideAurum/Parallax/releases/download/v<version>/Parallax_<version>.rmskin`, and a notes link only below the same releases prefix. The version grammar is the packager's (`[A-Za-z0-9][A-Za-z0-9._-]*`), so nothing from the feed can carry quotes, spaces or bang syntax into the state file or the helper command. A saved offer is validated again before it is shown or installed. The helper re-validates everything, refuses redirects off GitHub's own hosts, caps downloads at 64 MB, and deletes a file that fails verification.

## When checks run

Defaults approved by the owner on 2026-10-26: automatic checks **on by default**, daily, with the small prompt.

| Trigger | Condition | Prompt on a newer version |
| --- | --- | --- |
| Background (each loaded utility with `Hook1.inc`) | First look 60 s after the utility loads (the network is often not up at sign-in), then an hourly look. A check is due 24 h after the last good check, or 1 h after a failed one or one that never reported (its skin reloaded mid-request). A check stamped more than 5 minutes in the future counts as due (the clock went back). | Yes, unless that version was dismissed with Later or the prompt is already open |
| Global Settings opens | Auto check is Daily and no check started in the last 10 minutes (Global Settings reloads on every settings change, so an unconditional check would repeat) | No; the section shows it |
| **Check now** | Always, unless a check or download is in flight | No; the section shows it |

**Claiming a check.** The utility that finds a check due writes `UpdateCheckedAt` first and reads it back; only then does it enable its WebParser. Every Rainmeter skin runs on one thread, so the next utility to look sees the claim and does nothing: one request per due check however many utilities are loaded. If the claim does not read back (an unwritable or missing state file), no background check runs, so a broken file cannot make every utility request every hour.

**Auto check Off** (`UpdateCheck=0`) loads the comment-only `Hook0.inc` in every utility and turns off the check on opening Global Settings: nothing contacts the network until **Check now**. Changing it reloads the suite once, through the same debounced apply as Idle pause on/off. On by default also applies to upgrades from builds without the key, because `Defaults.inc` ships `UpdateCheck=1`.

## Results and how failures are reported

WebParser does not expose the HTTP status, so `Update.lua`'s `Classify` tells results apart by the body. Its pattern takes up to 8193 characters of any non-empty body, so error pages reach `Classify` too.

| Result | How it is recognized | Global Settings status line (failures in `DangerColor`) |
| --- | --- | --- |
| `available` | Valid schema-1 feed for a newer version | `Parallax <v> is available. Checked <time>.` |
| `current` | Valid feed, same or older version | `Up to date. Checked <time>.` |
| `offline` | WebParser connection error (offline, DNS, blocked) | `Could not reach github.com. Checked <time>.` |
| `missing` | A short body containing "Not Found": GitHub's 404 for a missing release or asset. WebParser receives `{"error":"Not Found"}` (measured 2026-10-26, Rainmeter 4.5.28); curl receives plain `Not Found`. | `No Parallax release was found. Checked <time>.` |
| `ratelimit` | A body naming a rate limit or "Too Many Requests" | `GitHub is limiting requests. Checked <time>.` |
| `format` | Empty body, anything else, a feed over 8192 characters, or one that fails validation | `The release feed could not be read. Checked <time>.` |

`<time>` is `HH:MM` for today, otherwise `D Mon HH:MM`. Background failures never open the prompt; they are recorded and retried after an hour. **Latest** keeps the newest version a check has read; when a later check failed, it is dated, for example `0.2.0 (25 Oct)`, so an old answer never reads as current.

## Global Settings: Updates

A section after Performance (moved here from the Welcome panel). The heading row shows `Installed <version>` on the right. Rows: **Latest** with **Notes** and **Update** on the right while a newer release is offered; **Auto check** (Daily / Off, the same cycling control as Idle pause; a hand-edited value shows Custom); the status line with **Check now**. While a check runs the button reads `Checking...`; during a download it reads `Working...` and Update is hidden. Install results replace the status line until the next check: `Downloading <v>...`, `Confirm in Skin Installer to finish.`, `Download failed. Nothing was installed.` or `A media helper is running. Quit Rainmeter.` A check started from Global Settings never opens the prompt. Layout and checks are in [SETTINGS.md](SETTINGS.md#updates).

## The update prompt

`Parallax\Update\Update.ini`: one column (228 × 142 window at the default 220 px width and scale 1), the suite's title row with an X, `<v> is available`, `Installed: <version>`, then **Update** (primary), **Notes** and **Later**, and a two-line status (`Skin Installer asks you to confirm.` until Update is clicked, then the install results above).

- **Opened** only by a background check that finds a newer version not dismissed, and only when Rainmeter.ini says it is not already open. A prompt that is open re-renders when any skin records a check (the `ParallaxUpdateView` group broadcast).
- **Later** and the **X** record `UpdateDismissed=<v>` and close it: no further prompt for that version, while Global Settings keeps offering it. A newer release prompts again.
- **Closes itself** (100 ms after an update) when nothing newer is offered any more: the installed copy caught up, the release was withdrawn, or the version was dismissed. Never during a download or after the hand-off to Skin Installer.
- **Placement.** The first time it appears it moves to the top right of the primary work area, 16 px in from the right and top edges. Rainmeter writes `WindowX=0` and `WindowY=0` for a config it has never positioned, so that position (or none) counts as unplaced; any other position, from a drag or that first move, is kept. A prompt dragged to exactly 0,0 moves back on its next appearance.
- It is in the `Parallax` group (a suite refresh re-renders it), opens Global Settings from its context menu, and has no tooltip.

## Moved from the Welcome panel (2026-10-26)

The Welcome panel is the package's `loadSkin`, so Skin Installer opens it after an install, but once closed nothing reopens it. On the maintainer's desktop on 2026-10-26 `Parallax\Welcome` was `Active=0`, so its button was out of reach. Welcome's update row and its three measures were removed; the panel is back to its 400 logical px height (456 × 408 window), and its Global Settings row leads to the new section. `Modules/Welcome/Update.lua` became `@Resources/Update/Update.lua`. The feed (schema 1), the release procedure and `UpdateInstall.ps1` are unchanged, so copies still on 0.1.0-alpha.8 or earlier keep a working Welcome button and can upgrade into this design.

## Checks (2026-10-26)

The offline suite, the isolated native smoke, the preview captures and the Global Settings checks are listed under [SETTINGS.md: Updates](SETTINGS.md#updates). In short: `@Resources/Update/tests/run_update_suite.py` 147 assertions; `Run-UpdateSmoke.ps1 -Online -ExerciseInstall` passed every step, including GitHub's real 404 and the install hand-off failure; and the prompt was first placed at 2316,16 on a 2560 px work area.

Suite-level effects, checked: `tools/Test-Parallax.ps1 -RequireAllModules` reports 25 configs, 130 files, 0 errors and 0 warnings (the `Update` config is now required). `Test-ParallaxVariants.ps1` passes 10 variant sets, including the new `UpdateCheck=0`. `test_idle_freeze_contract.py` passes; the hook adds no meter and its measures are not periodic. `Test-PackagingTools.ps1` passes with one more synthetic config. The module static validators `validate_cpu.py`, `test_skin_contract.py` (Media), `Validate-RAM.ps1`, `Validate-GPU.py`, IO's `check_geometry.py` and the Visualizer's `validate.mjs` all pass. CPU and Media assert that their controller or header is the last measure; they now ignore the hook's `MeasureParallaxUpdate*` measures, which have divider -1 and never update on a tick.

Fourteen module native tests stage utility entrypoints from explicit file lists. Each now also copies `Version.inc`, `Update/Hook1.inc`, `Feed.inc`, `Update.lua`, `State.inc` and `Idle/Link.lua`: Chronometer's three smokes, GPU and IO settings smokes, IO idle rows, Media settings, transport and queue view, Network unified, and RAM native, history cover and history range. Those 14 native runs were not repeated for this change. A run longer than 60 s now also makes one real feed request from its staged copy.

## What the checksum does and does not prove

The SHA-256 in the manifest proves that the package is the one the manifest describes, and not a truncated or corrupted transfer. Both files come from the same GitHub release, so it does not defend against someone who can publish releases on the repository. Authenticode-signing the package or signing the manifest with a key pinned in `Version.inc` would close that gap. That is a reasonable later step, not part of this first version.

## The feed must stay public

The check reads the feed without credentials, and Parallax must never ship a token. Unauthenticated requests to a private repository's releases return 404 (`missing`, `No Parallax release was found.`). `davideAurum/Parallax` is public: on 2026-10-26 the feed address returned 200 through two redirects with version 0.1.0-alpha.8. If the source ever goes private again, publish releases from a public companion repository such as `davideAurum/Parallax-releases`, and set `releaseRepository` in `packaging/release.json` and `UpdateFeedURL` / `UpdateReleaseBase` in `@Resources\Version.inc` to it before building the first release that should be found. The addresses baked into an installed copy are the ones it checks until an update replaces `Version.inc`.

## Versioning rules

- `packaging/release.json` → `version` and `@Resources\Version.inc` → `ParallaxVersion` must be identical. `Package-Parallax.ps1` refuses to build otherwise.
- Versions compare as semantic versions: `major.minor.patch`, then an optional `-pre.release` part. A release sorts after its own pre-releases (`0.2.0-alpha < 0.2.0-beta < 0.2.0-rc.1 < 0.2.0`), and numeric identifiers compare numerically. Two-part versions and `+build` metadata are not accepted.
- Tag each release `v<version>` exactly. The manifest's package URL is derived from that tag.
- GitHub's `latest` address skips releases marked **Pre-release**. To offer an `-alpha` or `-beta` build to installed copies, publish it as a normal release marked **Latest**. The version string still says alpha.

## Publishing a release

```powershell
# 1. Bump the version in both places, then commit.
#    packaging\release.json            "version": "0.2.0"
#    Skins\Parallax\@Resources\Version.inc   ParallaxVersion=0.2.0
.\tools\Test-Parallax.ps1 -RequireAllModules
.\tools\Package-Parallax.ps1
# 2. Run the release gates in docs\PACKAGING.md against dist\Parallax_0.2.0.rmskin.
# 3. Publish: package, checksum and feed in one release, marked Latest.
gh release create v0.2.0 dist\Parallax_0.2.0.rmskin dist\Parallax_0.2.0.rmskin.sha256 dist\parallax-update.json --title "Parallax 0.2.0" --notes-file <notes.md> --latest
# 4. Only now commit and push README.md: the packager rewrote its download badge to the new asset.
#    In the same commit, clear the shipped entries from docs\UNRELEASED.md and update its "Latest release" line.
git commit -m "Point the README download at v0.2.0" README.md; git push
```

The README's download badge links directly to one version's `.rmskin`, like many Rainmeter skin pages. `Package-Parallax.ps1` rewrites the line between the `download-badge` markers on every build, so the link cannot fall behind. Push that README change only after the release exists; pushed earlier, the badge would point at a file that is not there yet. For trial builds with a throwaway `-Version`, pass `-NoReadme`. The badge image comes from shields.io and shows the newest release, including pre-releases, on its own.

Upload the package and the feed in the same `gh release create` call. A release that has the feed but not yet the package would send users to a 404; the helper reports that as a failed download and installs nothing, but it is avoidable. To withdraw a bad release, mark the previous release **Latest** again (or delete the bad one). Installed copies then stop offering it on their next check.

## Feed format (schema 1)

```json
{
  "schema": 1,
  "name": "Parallax",
  "version": "0.2.0",
  "url": "https://github.com/davideAurum/Parallax/releases/download/v0.2.0/Parallax_0.2.0.rmskin",
  "sha256": "<64 hex characters>",
  "bytes": 852345,
  "minimumRainmeter": "4.5.26",
  "notes": "https://github.com/davideAurum/Parallax/releases/tag/v0.2.0"
}
```

`Update.lua` reads `schema`, `name`, `version`, `url`, `sha256` and `notes`. `bytes` and `minimumRainmeter` are informational; Skin Installer enforces the minimums recorded in the package itself. An installed copy refuses any schema other than 1, so an incompatible future format must use a new asset name and leave `parallax-update.json` in schema 1 for older installations.

## Welcome panel states (0.1.0-alpha.8 and earlier)

Copies still on 0.1.0-alpha.8 or earlier check from the Welcome panel's **Check for updates** button, with these status lines. The current states are under [Results](#results-and-how-failures-are-reported) and [Global Settings: Updates](#global-settings-updates).

| Status line | Meaning | Buttons |
| --- | --- | --- |
| `Parallax <installed> installed.` | Initial state; nothing has been requested | Check for updates |
| `Checking for updates...` | WebParser request in flight; the button reads *Working...* | — |
| `Parallax <v> is up to date.` | Feed version equals, or is older than, the installed one | Check for updates |
| `Parallax <v> is available.` | Newer release offered | Install, Notes |
| `Downloading <v>...` | Helper running (180-second limit) | — |
| `Confirm in Skin Installer to finish.` | Verified package handed to Skin Installer | Check for updates |
| `Could not reach the update server.` | WebParser connection error | Check for updates |
| `Update check failed.` | No feed, unreadable or rejected feed | Check for updates |
| `Download failed. Nothing was installed.` | 404, checksum mismatch, non-RMSKIN file, size cap, redirect or network error | Install (retry), Notes |
| `A media helper is running. Quit Rainmeter.` | Package verified, but a Media provider worker would not end, so Skin Installer was not opened | Install (retry), Notes |

## Upgrading past running Media helpers

Skin Installer backs up the old copy by renaming `Skins\Parallax` to `Skins\@Backup\Parallax`. Windows refuses that rename while any process has its working directory, or an open handle, inside the folder, and Skin Installer then stops with "Unable to move to: ...\Skins\@Backup\Parallax". Media's resident Source and Queue workers were such processes up to 0.1.0-alpha.4: they outlived the Rainmeter that started them and kept a config folder as working directory. The alpha.4 upgrade of the maintainer's own install on 2026-10-19 failed this way until two workers left over from the previous evening were ended by hand.

From 0.1.0-alpha.5 three changes cover it (details in [Media: Provider lifetime and upgrades](modules/Media.md#provider-lifetime-and-upgrades)):

- Workers carry an owner lease and exit within one idle wait (at once for Source, which waits on the owner process itself; 1 second for Queue, after any in-flight queue request) of the Rainmeter that started them, so Skin Installer's own Rainmeter shutdown also ends them. Their saved resume intent is kept, so the reloaded Media restarts them.
- Workers run with their `%LOCALAPPDATA%\Parallax\Media\...` data root as working directory, so even a live one holds nothing inside the skin.
- Just before opening Skin Installer, `UpdateInstall.ps1` ends any `powershell.exe` whose command line runs this installed skin's `SourceProvider.ps1` or `QueueProvider.ps1` with `-Command Run` (the only helpers that stay resident; RAM's PageFileHost and GPU's DriverTemperature already exit with Rainmeter). Resume intent is left as it was. If one will not end within 5 seconds, the helper reports `blocked` and does not open Skin Installer. If the user then cancels Skin Installer, those workers stay stopped until Media next loads.

The helper that runs on Install is the one in the *installed* copy, so a copy at alpha.4 or earlier upgrading to alpha.5 still has the old workers and no pre-check. If that upgrade fails with the message above, quit Rainmeter, end those `powershell.exe` processes in Task Manager (Details tab, Command line column), and open the downloaded package from `%TEMP%\Parallax\Update` again.

## Rainmeter started from PowerShell 7

`UpdateInstall.ps1` runs under Windows PowerShell 5.1, which inherits Rainmeter's environment. A Rainmeter launched from a PowerShell 7 session (for example Skin Installer started by `Start-Process` in `pwsh`, which then restarts Rainmeter) carries PowerShell 7's `PSModulePath`, with its module folders listed first. Windows PowerShell then autoloads PowerShell 7's `Microsoft.PowerShell.Utility` and loses commands such as `Get-FileHash`. Install on 0.1.0-alpha.5 failed this way on 2026-10-19 with `Download failed. Nothing was installed.`, because the helper's real error (`The term 'Get-FileHash' is not recognized`) never reaches the panel.

The helper now sets `PSModulePath` to Windows PowerShell's own folders (Documents, Program Files and `$PSHOME`) before anything autoloads. Checked in a scratch copy of Rainmeter 4.5.28 launched from `pwsh` with a stand-in `SkinInstaller.exe`, against the real alpha.5 release: the alpha.4 helper failed on `Get-FileHash`, and the fixed helper downloaded and verified the package and reported `Confirm in Skin Installer to finish.` The other Windows PowerShell helpers Rainmeter starts were checked the same day by starting `powershell.exe` directly with PowerShell 7's `PSModulePath`, as Rainmeter does. (Starting it from `pwsh` hides the problem, because PowerShell 7 removes its own module folders for a child `powershell.exe`.) Only `Get-FileHash` and the `Microsoft.PowerShell.Security` cmdlets (`Get-Acl`, `Set-Acl`, `*-SecureString`, `Get-AuthenticodeSignature`, `*-ExecutionPolicy`) fail. `Add-Type`, `Get-CimInstance`, `Start-Process`, `Invoke-WebRequest`, JSON, registry and content cmdlets, and `-ExecutionPolicy Bypass/RemoteSigned -File` all work. No shipped helper apart from `UpdateInstall.ps1` uses an affected command (`Build-EventEditor.ps1` uses `Get-FileHash`, but it is a developer build step Rainmeter never runs). RAM's memory inventory, IO's drive models and GPU's adapter payloads returned real data under that path, and both Media providers parse. So the reset stays in `UpdateInstall.ps1` only. A new helper that uses one of those commands needs the same reset.

## Possible later steps

- Manifest signing, as described above.
- A channel setting (stable / pre-release) that reads a second feed asset, such as `parallax-update-beta.json`, from a rolling pre-release.
- A "remind me later" that re-prompts after some days instead of Later's per-version dismissal, if Later proves too final.

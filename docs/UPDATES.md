# Updates

How a new Parallax release reaches an installed copy, and what the Welcome panel's **Check for updates** button does.

## Design in one paragraph

Each release is a normal GitHub release on `davideAurum/Parallax` tagged `v<version>`. It carries two assets: the `.rmskin` package, and a small `parallax-update.json` manifest that `Package-Parallax.ps1` writes beside it. An installed suite knows its own version from `@Resources\Version.inc`. When the user clicks **Check for updates**, Rainmeter's built-in WebParser makes one request to `https://github.com/davideAurum/Parallax/releases/latest/download/parallax-update.json`, a stable GitHub address that always resolves to the asset of the release marked **Latest**. If the manifest names a newer version, the panel offers **Install** and **Notes**. Install runs one hidden helper that downloads the package into `%TEMP%\Parallax\Update`, checks its SHA-256 against the manifest and its RMSKIN trailer, and then opens it in Rainmeter's own Skin Installer. The Skin Installer dialog is the confirmation step: nothing changes until the user clicks Install there, and the package's Variables-files list preserves `@Resources\User\*.inc` settings exactly as a manual upgrade would.

```text
 release (maintainer)                          installed suite (user)
 ─────────────────────                         ──────────────────────
 bump version (release.json + Version.inc)     Welcome ▸ Check for updates
 Package-Parallax.ps1                            │ WebParser, one GET
   ├─ dist\Parallax_<v>.rmskin                    ▼
   ├─ dist\Parallax_<v>.rmskin.sha256          releases/latest/download/parallax-update.json
   └─ dist\parallax-update.json  ──publish──▶     │ Update.lua: validate, compare versions
 gh release create v<v> (marked Latest)           ▼
                                                "Parallax <v> is available."  [Install] [Notes]
                                                  │ Install: UpdateInstall.ps1 (one-shot, hidden)
                                                  │   download ▸ SHA-256 ▸ RMSKIN trailer
                                                  ▼
                                                Rainmeter Skin Installer ▸ user confirms ▸ upgrade
```

## Why this shape

- **No server to run.** GitHub Releases already hosts versioned assets, and `releases/latest/download/<asset>` gives a fixed feed address that never needs to change in shipped skins.
- **No polling, and built-ins first.** The check is one WebParser request per click, with no timer, no scheduled task and no launch-time check. The only process launch is the explicit Install click, as the collaboration contract requires.
- **Rainmeter does the installing.** Parallax never copies files over itself. Skin Installer already handles backup of the old folder, Variables-file preservation, plugin updates, unloading and reloading configs, and minimum Rainmeter/Windows checks. Doing any of that in a script would duplicate it badly.
- **The user confirms twice, both times on purpose.** The panel says an update exists and asks before downloading, and Skin Installer shows the package before installing it.
- **Remote text is data.** The manifest is parsed with fixed patterns. A package URL is accepted only when it is exactly `https://github.com/davideAurum/Parallax/releases/download/v<version>/Parallax_<version>.rmskin`, and a notes link only below the same releases prefix. The version grammar is the packager's (`[A-Za-z0-9][A-Za-z0-9._-]*`), so nothing from the feed can carry quotes, spaces or bang syntax into the helper command. The helper re-validates everything, refuses redirects off GitHub's own hosts, caps downloads at 64 MB, and deletes a file that fails verification.

### What the checksum does and does not prove

The SHA-256 in the manifest proves that the package is the one the manifest describes, and not a truncated or corrupted transfer. Both files come from the same GitHub release, so it does not defend against someone who can publish releases on the repository. Authenticode-signing the package or signing the manifest with a key pinned in `Version.inc` would close that gap. That is a reasonable later step, not part of this first version.

## Prerequisite: the feed must be public

`davideAurum/Parallax` is currently **private**. Unauthenticated requests to a private repository's releases return 404, so until something changes, every installed copy will report *Update check failed. No Parallax release information was found*. Parallax must never ship a token. Choose one:

1. **Make the repository public** (simplest; nothing else changes).
2. **Keep the source private and publish releases from a public companion repository**, for example `davideAurum/Parallax-releases`. Set `releaseRepository` in `packaging/release.json` and `UpdateFeedURL` / `UpdateReleaseBase` in `@Resources\Version.inc` to that repository before building the first release that should find updates.

The addresses baked into an installed copy are the ones it checks forever, until an update replaces `Version.inc`. Decide this before the first public release.

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
```

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

## Panel states

| Status line | Meaning | Buttons |
| --- | --- | --- |
| `Parallax <installed> installed.` | Initial state; nothing has been requested | Check for updates |
| `Checking for updates...` | WebParser request in flight; the button reads *Working...* | — |
| `Parallax <v> is up to date.` | Feed version equals, or is older than, the installed one (tooltip says which) | Check for updates |
| `Parallax <v> is available.` | Newer release offered; tooltip names the installed version | Install, Notes |
| `Downloading <v>...` | Helper running (180-second limit) | — |
| `Confirm in Skin Installer to finish.` | Verified package handed to Skin Installer | Check for updates |
| `Could not reach the update server.` | WebParser connection error | Check for updates |
| `Update check failed.` | No feed, unreadable or rejected feed; tooltip has the reason | Check for updates |
| `Download failed. Nothing was installed.` | 404, checksum mismatch, non-RMSKIN file, size cap, redirect or network error; tooltip has the reason | Install (retry), Notes |

## Possible later steps

- An opt-in check when the Welcome panel opens (still one request per open, off by default).
- A Global Settings entry that points to the same check, for users who close Welcome.
- Manifest signing, as described above.
- A channel setting (stable / pre-release) that reads a second feed asset, such as `parallax-update-beta.json`, from a rolling pre-release.

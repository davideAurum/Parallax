# Development

How to build, change and release Parallax. If you only want to use it, the [README](../README.md) has everything you need.

Read the collaboration contract in [AGENTS.md](../AGENTS.md) first. Make every change in the repository, never in an installed skin folder.

## Target

Windows 10/11 and Rainmeter 4.5.26 or newer. [`packaging/release.json`](../packaging/release.json) records the same minimums for Skin Installer. Recorded runs used Rainmeter 4.5.26.3894 and 4.5.28.3936 on Windows 11. A target is not a claim that every Windows and Rainmeter combination has been tested; [VALIDATION.md](VALIDATION.md) and each module's document say what has.

## Where things are

- Sources: [`Skins/Parallax/`](../Skins/Parallax). Each utility keeps its skin, resources, settings file and document together ([AGENTS.md](../AGENTS.md)).
- Shared contract: [ARCHITECTURE.md](ARCHITECTURE.md).
- Visual specification: [APPEARANCE.md](APPEARANCE.md), with its [revision record and screenshots](APPEARANCE-REVIEW.md).
- Settings: [Global Settings](SETTINGS.md) with its [checks and screenshots](SETTINGS-REVIEW.md), [utility settings](UTILITY-SETTINGS.md) and the [color picker](COLOR-PICKER.md).
- Panels outside the utilities: [Welcome](WELCOME.md), [Connections](CONNECTIONS.md) and [updates](UPDATES.md).
- Capabilities and sources: [PROVIDERS.md](PROVIDERS.md). Dependencies by utility: [DEPENDENCIES.md](DEPENDENCIES.md).
- Module documents: [Chronometer](modules/Chronometer.md), [CPU](modules/CPU.md), [RAM](modules/RAM.md), [GPU](modules/GPU.md), [IO](modules/IO.md), [Network](modules/Network.md), [Media](modules/Media.md) and [Visualizer](modules/Visualizer.md).
- Milestones: [ROADMAP.md](ROADMAP.md). What is on `main` but not released, and what is open: [UNRELEASED.md](UNRELEASED.md). Announcing and measuring interest: [LAUNCH.md](LAUNCH.md).
- Validation and distribution: [PACKAGING.md](PACKAGING.md) and the [initial check results](VALIDATION.md).
- Performance: the [performance pass and measured hotspots](PERFORMANCE.md) and the [later review](PERFORMANCE-REVIEW.md). No long-run CPU or memory figure has been measured yet.
- Integrated development build: [BUILD-REVIEW.md](BUILD-REVIEW.md).
- Task ownership from the initial build, kept as history: [TASKS.md](TASKS.md).

## Design

Parallax follows a dense instrument layout: near-black bordered panels, IBM Plex Sans, aligned rows, colored data bars and compact graphs. The default painted widths are 220 and 448 pixels with an 8-pixel gap. Width, scale, colors, fonts and module choices are customizable.

Global Settings groups its controls into Appearance, Performance, Updates and Developer. Appearance holds a theme dropdown (one theme, **Default**), size, gap and rounding, two accent colors, title, header and body typography, background color and transparency, border, divider and table-header colors and thickness, and the shared data-bar thickness. Performance holds refresh presets, the idle pause and the sampling summary. Each color has a hex readout and a swatch that opens the shared RGB/HSV/Lab color picker. Behavior is in [SETTINGS.md](SETTINGS.md).

ModernGadgets is the visual inspiration. No code or artwork from it is used; keep that true and recorded in [`NOTICE.txt`](../Skins/Parallax/@Resources/Licenses/NOTICE.txt).

## Try a change

[`tools/Sync-ParallaxDev.ps1`](../tools/Sync-ParallaxDev.ps1) stages the repository into a second skin folder, `ParallaxDev`, that loads beside the installed release. Add `-Watch` to repeat it on every save. It never touches the installed release. See [DEVMODE.md](DEVMODE.md).

```powershell
.\tools\Sync-ParallaxDev.ps1
```

To render panels without touching the desktop, use the preview tool, which runs a separate Rainmeter instance with its windows off screen. See [tools/PREVIEW.md](../tools/PREVIEW.md).

```powershell
.\tools\Preview-Parallax.ps1
```

To run from source without packaging, copy the `Parallax` source folder into Rainmeter's skins folder, refresh Rainmeter, and load `Parallax\Settings\Settings.ini`. Back up an existing Parallax installation first. A source copy has no bundled plugins, so Media needs WebNowPlaying installed by hand ([Media dependencies](modules/Media.md#dependencies)).

## Check

```powershell
.\tools\Test-Parallax.ps1 -RequireAllModules
```

```powershell
.\tools\tests\Test-PackagingTools.ps1
```

Run the second after changing the tools or the README's download badge. Scale checks to the change: a routine edit needs a quick, targeted one, and broad sweeps belong to pre-release acceptance ([AGENTS.md](../AGENTS.md)). Record what was checked and what is unverified.

## Build a package

Run `.\tools\Package-Parallax.ps1` from the repository root in PowerShell 5.1 or later. It validates and stages `Skins\Parallax`, writes `dist\Parallax_<version>.rmskin` with a `.sha256` checksum, a package record and the update feed, and verifies the result before renaming it. Release metadata is in `packaging\release.json`, and the version must match `@Resources\Version.inc`. Details and release gates are in [PACKAGING.md](PACKAGING.md), and the release procedure is in [UPDATES.md](UPDATES.md).

The package keeps existing `@Resources\User\*.inc` choices when it upgrades a copy, installs the bundled WebNowPlaying and Chameleon plugins unless newer ones are present, and loads `Parallax\Welcome\Welcome.ini`.

The packager also rewrites the lines between the `download-badge` markers in `README.md`. Keep those markers, and commit the new badge only after the release is published. Use `-NoReadme` for trial builds.

## README images

`docs/images/parallax-panels.png` and `docs/images/parallax-live.gif` were captured on 2026-11-25 from `main` at `f09de23` (0.1.0-alpha.15 ships the same skins, apart from its version number and one line of the queue guide), in a separate Rainmeter 4.5.28.3936 instance on the maintainer's laptop, the same way as [tools/PREVIEW.md](../tools/PREVIEW.md). Each window was printed on its own and the prints were placed side by side: the still at 200% scale, the animation at 100%, one frame a second for 12 seconds, with CPU Meter and GPU Meter cut off below their tables.

- The meter readings are real. The Wi-Fi name and local addresses were covered afterwards.
- Media Player ran its normal skin with a made-up track and an original cover in place of the WebNowPlaying plugin, because that plugin binds a fixed local port and a second copy of it ends its Rainmeter ([WELCOME.md](WELCOME.md#validation-report)). Album colors came from the bundled Chameleon plugin.
- The update check was off in the captured copy.
- The laptop was under heavy load from other programs, and Rainmeter's own lines include both instances. They are not a measurement. Pictures from a calm desktop, with music playing, would be better.

The script was a one-off and is not in the repository. Before publishing new images, check them for Wi-Fi names, addresses, drive names, file paths and song titles.

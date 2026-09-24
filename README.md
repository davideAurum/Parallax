# Parallax

A modular Rainmeter instrument suite: Chronometer with multiple countdown lists, CPU, Memory Meter, GPU, Disk Meter, a dedicated Network Monitor, media controls with optional Spotify queue, and an independent audio visualizer.

The revised design follows ModernGadgets' dense instrument layout: near-black bordered panels, IBM Plex Sans, aligned rows, colored data bars, and compact graphs. The default painted widths are 220 and 448 pixels with an 8-pixel gap. Width, scale, colors, fonts and module choices remain customizable. Development now happens directly in Claude rather than through separate per-module Codex tasks (see `docs/TASKS.md` for that historical structure); each utility still keeps its own file ownership for organization.

Global Settings groups its controls into **Appearance** and **Performance**. Appearance includes a **Default** theme dropdown, size/gap/rounding fields, two accent colors, title/header/body typography, background color/transparency, border/divider/table-header colors and thickness, and shared data bar thickness (6 px by default). Performance contains refresh presets and the sampling summary. Each color has a hex readout and swatch opening the shared RGB/HSV/Lab color picker. See [settings behavior](docs/SETTINGS.md) and [current validation and screenshots](docs/SETTINGS-REVIEW.md).

## Development

- Sources: `Skins/Parallax/`.
- Shared contract: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
- Current visual specification: [docs/APPEARANCE.md](docs/APPEARANCE.md).
- Post-install component loader: [docs/WELCOME.md](docs/WELCOME.md).
- Appearance revision and screenshots: [docs/APPEARANCE-REVIEW.md](docs/APPEARANCE-REVIEW.md).
- Task ownership/status: [docs/TASKS.md](docs/TASKS.md).
- Capabilities and sources: [docs/PROVIDERS.md](docs/PROVIDERS.md).
- Dependencies by utility: [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md).
- Development milestones: [docs/ROADMAP.md](docs/ROADMAP.md).
- Validation and distribution: [docs/PACKAGING.md](docs/PACKAGING.md).
- Initial check results: [docs/VALIDATION.md](docs/VALIDATION.md).
- Performance pass and measured hotspots: [docs/PERFORMANCE.md](docs/PERFORMANCE.md).
- Integrated development build: [docs/BUILD-REVIEW.md](docs/BUILD-REVIEW.md).
- Native screenshot workflow: [tools/PREVIEW.md](tools/PREVIEW.md).

Target: Windows 10/11, Rainmeter 4.5.26 or newer. Local discovery found Rainmeter 4.5.26; that is not a completed runtime compatibility test.

## Install

The whole suite ships as one `Parallax_<version>.rmskin` file. Download it from the project's GitHub Releases page once a release is published, or build it yourself (below), then open the file: Rainmeter's Skin Installer copies `Skins\Parallax`, keeps your existing `@Resources\User\*.inc` choices when upgrading, and loads `Parallax\Welcome\Welcome.ini`.

The Welcome panel lists every component — Chronometer, CPU, RAM, GPU, IO, Network, Media, Visualizer and Global Settings — as a check box. Check one to load that utility, clear it to unload, or press **Load all**. Rainmeter remembers the choice, so the panel keeps no settings of its own; see [the Welcome panel](docs/WELCOME.md). You can still load any utility from Manage Rainmeter under `Parallax`, and reopen Welcome from the Global Settings right-click menu. The package also installs the WebNowPlaying 2.0.7.0 plugin (MIT License) that Media uses, unless a newer version is already present; browser playback additionally needs the WebNowPlaying browser extension, and the optional HWiNFO exports remain a manual setup (see [Media dependencies](docs/modules/Media.md#dependencies)).

To build the package from source, run `.\tools\Package-Parallax.ps1` from the repository root in PowerShell 5.1 or later. It validates and stages `Skins\Parallax`, writes `dist\Parallax_<version>.rmskin` with a `.sha256` checksum and a package record, and verifies the result before renaming it. Release metadata lives in `packaging\release.json`; details and release gates are in [docs/PACKAGING.md](docs/PACKAGING.md).

To try development sources without packaging, copy the `Parallax` source folder into the actual Rainmeter Skins directory, refresh Rainmeter, then load `Parallax\Settings\Settings.ini`. Back up an existing Parallax installation first. Development sources do not modify your live desktop automatically. A release must still pass the runtime and upgrade checks in the packaging guide.

This is an initial implementation, not a completed distribution. Optional integrations have independent setup and availability requirements. A short default-suite profile is recorded; long-run targets with every optional provider enabled remain unmeasured.

## Updates

The Welcome panel's **Check for updates** button asks GitHub for the newest release once per click. If one is available, **Install** downloads it, verifies it and opens it in Rainmeter's Skin Installer, which asks you to confirm and keeps your settings. See [docs/UPDATES.md](docs/UPDATES.md) for the mechanism and the release procedure.

## License

Parallax is released under the [MIT License](LICENSE). Bundled third-party components (IBM Plex Sans, WebNowPlaying, Lucide icons) keep their own licenses; see [`@Resources/Licenses/NOTICE.txt`](Skins/Parallax/@Resources/Licenses/NOTICE.txt).

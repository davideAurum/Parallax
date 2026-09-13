# Parallax

A modular Rainmeter instrument suite: Chronometer with multiple countdown lists, CPU, Memory Meter, GPU, Disk Meter, a dedicated Network Monitor, media controls with optional Spotify queue, and an independent audio visualizer.

The revised design follows ModernGadgets' dense instrument layout: near-black bordered panels, IBM Plex Sans, aligned rows, colored data bars, and compact graphs. The default painted widths are 220 and 448 pixels with an 8-pixel gap. Width, scale, colors, fonts and module choices remain customizable. The original Codex task coordinates global settings and integration; each utility has its own task and file ownership.

Global Settings groups its controls into **Appearance** and **Performance**. Appearance includes a **Default** theme dropdown, size/gap/rounding fields, two accent colors, title/header/body typography, background color/transparency, border/divider/table-header colors and thickness, and shared data bar thickness (6 px by default). Performance contains refresh presets and the sampling summary. Each color has a hex readout and swatch opening the shared RGB/HSV/Lab color picker. See [settings behavior](docs/SETTINGS.md) and [current validation and screenshots](docs/SETTINGS-REVIEW.md).

## Development

- Sources: `Skins/Parallax/`.
- Shared contract: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
- Current visual specification: [docs/APPEARANCE.md](docs/APPEARANCE.md).
- Appearance revision and screenshots: [docs/APPEARANCE-REVIEW.md](docs/APPEARANCE-REVIEW.md).
- Task ownership/status: [docs/TASKS.md](docs/TASKS.md).
- Capabilities and sources: [docs/PROVIDERS.md](docs/PROVIDERS.md).
- Dependencies by utility: [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md).
- Development milestones: [docs/ROADMAP.md](docs/ROADMAP.md).
- Validation and distribution: [docs/PACKAGING.md](docs/PACKAGING.md).
- Initial check results: [docs/VALIDATION.md](docs/VALIDATION.md).
- Integrated development build: [docs/BUILD-REVIEW.md](docs/BUILD-REVIEW.md).
- Native screenshot workflow: [tools/PREVIEW.md](tools/PREVIEW.md).

Target: Windows 10/11, Rainmeter 4.5.26 or newer. Local discovery found Rainmeter 4.5.26; that is not a completed runtime compatibility test.

To try a reviewed development build, copy the `Parallax` source folder into the actual Rainmeter Skins directory, refresh Rainmeter, then load `Parallax\Settings\Settings.ini`. Back up an existing Parallax installation first. Development sources do not modify your live desktop automatically. A release must pass runtime and upgrade checks and be packaged with Rainmeter's Skin Packager as a valid `.rmskin`.

This is an initial implementation, not a completed distribution. Optional integrations have independent setup and availability requirements. Performance targets remain unmeasured until profiled with all enabled providers.

# Dependencies by utility

Each utility's dependency table is maintained beside its implementation documentation. Update it whenever a runtime, plugin, helper, service or bundled asset requirement changes. The table must distinguish required, bundled and optional components, state which feature uses them, and explain the behavior when they are unavailable. Planned integrations are listed separately. These lists describe the current source; they do not install or provision anything.

## Utility lists

| Utility | Maintained dependency list |
| --- | --- |
| Chronometer and its settings | [Chronometer](modules/Chronometer.md#dependencies) |
| CPU Meter and its settings | [CPU](modules/CPU.md#dependencies) |
| Memory Meter and RAM Settings | [RAM](modules/RAM.md#dependencies) |
| GPU Meter and its settings | [GPU](modules/GPU.md#dependencies) |
| Disk Meter and its settings | [IO](modules/IO.md#dependencies) |
| Combined Network Monitor and its settings | [Network](modules/Network.md#dependencies) |
| Media Player, setup, settings and Spotify queue | [Media](modules/Media.md#dependencies) |
| Audio Visualizer and Audio settings | [Visualizer](modules/Visualizer.md#dependencies) |
| Global Settings | [Global Settings](SETTINGS.md#dependencies) |
| Color Picker | [Color Picker](COLOR-PICKER.md#dependencies) |
| Welcome panel | [Welcome](WELCOME.md#dependencies) |

## Shared requirements

| Component | Classification | Purpose and availability |
| --- | --- | --- |
| Windows 10/11 and Rainmeter 4.5.26 or newer | Required platform; separately installed | Current suite target. `packaging/release.json` records the package minimums as Rainmeter 4.5.26 and Windows 10.0 (Windows 10 and 11); individual native checks do not certify every OS/version combination. |
| Rainmeter's Lua runtime, native measures/meters and standard plugins | Supplied by Rainmeter | Use the host's built-in facilities. A module table identifies which standard plugins it uses; these are not additional plugin downloads. |
| Parallax shared includes, scripts and `User/*.inc` files | Bundled source | Shared styles, geometry, defaults and saved preferences. Settings that persist changes need write access to their corresponding user include. |
| IBM Plex Sans Regular, Medium, SemiBold and Bold | Bundled asset; SIL Open Font License 1.1 | Loaded privately from the skin's Fonts directory. No system font installation. Shared numeric entry uses Windows Segoe UI. |
| Optional external plugins/providers/services | Feature-specific; see each utility | Never a blanket requirement for the suite. Distinguish a plugin bundled with Rainmeter, a third-party plugin bundled in the Parallax `.rmskin`, and a separately installed component. Missing provider behavior and explicit setup belong in the utility list. |
| WebNowPlaying plugin 2.0.7.0 | Bundled third-party plugin; MIT License | Installed by the `.rmskin` into the Rainmeter Plugins folder unless a newer version exists, for Media's optional playback view; see [Media](modules/Media.md#dependencies) and the [bundled plugin notes](../packaging/Plugins/WebNowPlaying/README.md). Its browser extension and desktop adapters are separate installs. |

Bundled attribution is recorded in [`@Resources/Licenses/NOTICE.txt`](../Skins/Parallax/@Resources/Licenses/NOTICE.txt), with font and module-local license files. Bundled helper source does not imply that an external executable, plugin, account, credential, driver or service is included. Machine-specific sensor mappings and private runtime data are excluded from distribution.

Provider behavior and integration constraints are detailed in [PROVIDERS.md](PROVIDERS.md). Build and release tooling requirements are separate from utility runtime requirements; see [PACKAGING.md](PACKAGING.md). Dependency tables should record only versions or constraints supported by the source and evidence, rather than guessing a minimum or claiming compatibility with an untested latest version.

Media's restart recovery reuses its bundled Lua controller, existing Windows PowerShell 5.1 provider helpers and their Windows APIs. It adds no installed dependency or OS startup entry. A normal Rainmeter view load can resume only explicitly enabled providers; private intent/launch files are runtime state and never distribution assets. Settings and isolated/custom profiles do not perform automatic recovery. See [Media's dependency list](modules/Media.md#dependencies) and [recovery contract](modules/Media.md#provider-recovery-after-restart).

GPU's per-application dedicated-memory rows reuse Rainmeter's bundled UsageMonitor plugin and Windows GPU Process Memory counters. Five exact named measures share one additional in-process category worker at UsageMonitor's independent one-second cadence. They add no external installation, helper process, driver, session file or protocol change. Missing, unsupported and ambiguous zero observations display `VRAM: --`; see the [GPU dependency list](modules/GPU.md#dependencies).

Visualizer's current renderer uses Rainmeter's native Shape paths, Container compositing and LinearGradient fills for the 24 measured bands. Color selection runs only on refresh; dynamic mask geometry follows spectrum updates, and its parsing/compositing cost is not benchmarked. The current-output icon is a native Shape adaptation of the bundled user-supplied Lucide Speaker SVG; its source, provenance and ISC license ship under the module's `Icons/Lucide/` directory, with no SVG runtime loader. Rainmeter's bundled Win7Audio plugin supplies the read-only default-output volume and event-only `TogglePrevious`/`ToggleNext` device commands; switching adds no additional capture parent or polling. This adds no external package, plugin, helper, service, installation or polling launch. AudioLevel, bundled typography and the explicit-action shared numeric helper retain their documented roles; see the [Visualizer dependency list](modules/Visualizer.md#dependencies).

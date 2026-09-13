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

## Shared requirements

| Component | Classification | Purpose and availability |
| --- | --- | --- |
| Windows 10/11 and Rainmeter 4.5.26 or newer | Required platform; separately installed | Current suite target. The tested release minimums remain unset in `packaging/release.json`; individual native checks do not certify every OS/version combination. |
| Rainmeter's Lua runtime, native measures/meters and standard plugins | Supplied by Rainmeter | Use the host's built-in facilities. A module table identifies which standard plugins it uses; these are not additional plugin downloads. |
| Parallax shared includes, scripts and `User/*.inc` files | Bundled source | Shared styles, geometry, defaults and saved preferences. Settings that persist changes need write access to their corresponding user include. |
| IBM Plex Sans Regular, Medium, SemiBold and Bold | Bundled asset; SIL Open Font License 1.1 | Loaded privately from the skin's Fonts directory. No system font installation. Shared numeric entry uses Windows Segoe UI. |
| Optional external plugins/providers/services | Feature-specific; see each utility | Never a blanket requirement for the suite. Distinguish a plugin bundled with Rainmeter from a separately installed third-party plugin. Missing provider behavior and explicit setup belong in the utility list. |

Bundled attribution is recorded in [`@Resources/Licenses/NOTICE.txt`](../Skins/Parallax/@Resources/Licenses/NOTICE.txt), with font and module-local license files. Bundled helper source does not imply that an external executable, plugin, account, credential, driver or service is included. Machine-specific sensor mappings and private runtime data are excluded from distribution.

Provider behavior and integration constraints are detailed in [PROVIDERS.md](PROVIDERS.md). Build and release tooling requirements are separate from utility runtime requirements; see [PACKAGING.md](PACKAGING.md). Dependency tables should record only versions or constraints supported by the source and evidence, rather than guessing a minimum or claiming compatibility with an untested latest version.

Media's restart recovery reuses its bundled Lua controller, existing Windows PowerShell 5.1 provider helpers and their Windows APIs. It adds no installed dependency or OS startup entry. A normal Rainmeter view load can resume only explicitly enabled providers; private intent/launch files are runtime state and never distribution assets. Settings and isolated/custom profiles do not perform automatic recovery. See [Media's dependency list](modules/Media.md#dependencies) and [recovery contract](modules/Media.md#provider-recovery-after-restart).

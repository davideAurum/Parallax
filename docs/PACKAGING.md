# Packaging Parallax

The repository stages release inputs. The official Rainmeter Skin Packager creates the final `.rmskin`; renaming a ZIP is insufficient. Use **Manage Rainmeter > Create .rmskin package**, and select the staged `Skins\Parallax` root. Packager accepts a source outside an installed Skins directory. See the [official distribution guide](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/distributing-skins/index.html).

## Validate and stage

From the repository root, using PowerShell 5.1 or later:

```powershell
.\tools\Test-Parallax.ps1
.\tools\Stage-Parallax.ps1 -Version '0.1.0-alpha'
```

The validator permits modules to arrive independently, warning for missing utilities. Once all required entrypoints are ready, use `-RequireAllModules` on both commands. `-WarningsAsErrors` is available on the validator after every warning has been reviewed.

Run `.\tools\tests\Test-PackagingTools.ps1` after changing the tools. Its isolated fixtures cover layered settings, invalid includes, cycles, local duplicates, absent modules, unknown styles, exclusions, credential-shaped defaults, preservation paths, fresh destinations, and manifest hashes. Media queue/source detection, Settings input, CPU/GPU discovery, RAM/GPU metadata, and Chronometer event editor fixtures copy the actual helper/build files as data, verify hashes, and reject similarly named files, repeated text suffixes, private/test copies, and runtime data. They never run or import a helper, read sensor registry exports or media snapshots, query CIM, graphics or native media-session APIs, load the editor assembly, or invoke a compiler. Fixtures remain in a unique system temporary directory for inspection. Test/Tests, QA and Fixtures folders are excluded from staged skins.

Run `python .\tools\tests\test_settings_geometry.py` with Python 3.10+ after changing Settings geometry. It reads the actual shared includes and Settings config, then checks all 100 preset scale/width/gutter combinations for aligned single/double widths, padded button bounds, and nonoverlapping declared text rectangles. It does not render fonts, test mixed Windows DPI, or execute Lua.

Every stage creates a fresh `build\Parallax-<version>-<UTC timestamp>-<random>` directory. It never deletes, replaces, installs, or launches anything. Only files under the source `Skins\Parallax` enter the staged skin root. Repository docs, tools, and packaging metadata remain outside that root.

Review `stage-manifest.json` for included paths, SHA-256 hashes, and exclusions. `variables-files.txt` gives the exact preservation field for this stage. Only skin source, Lua, supported image/audio/font assets, and text documentation are allowed by default. Hidden, private, credential, token, cache, runtime, temporary, and log paths are excluded. Developer and runtime directories are pruned before traversal by both validator and staging; the manifest records excluded directory roots without enumerating their contents. Reparse points in the production tree are rejected. `User` ships only `.inc` files containing clean defaults. A heuristic rejects nonempty credential-shaped INI options without printing their values. These checks cannot detect every secret; inspect release inputs, never stage from a live personalized installation, and keep authentication data outside the distributable tree.

The thirteen reviewed helper and build-source path exceptions are exactly these files, relative to `Skins\Parallax`:

```text
@Resources\Scripts\SettingsInput.ps1
@Resources\Modules\Chronometer\EventEditor.exe
@Resources\Modules\Chronometer\EventEditor.cs
@Resources\Modules\Chronometer\EventEditorForm.cs
@Resources\Modules\Chronometer\Build-EventEditor.ps1
@Resources\Modules\CPU\DiscoverSensors.ps1
@Resources\Modules\GPU\DiscoverExports.ps1.txt
@Resources\Modules\GPU\AdapterInfo.cs.txt
@Resources\Modules\RAM\MemoryInfo.ps1.txt
@Resources\Modules\Media\Queue\QueueProvider.ps1
@Resources\Modules\Media\Queue\QueueCore.psm1
@Resources\Modules\Media\Queue\QueueAuth.psm1
@Resources\Modules\Media\Source\SourceProvider.ps1
```

These normalized, case-insensitive path exceptions do not permit `.exe`, `.cs`, `.ps1` or `.psm1` generally and never override earlier hidden/private/test/runtime exclusions. The existing `.ps1.txt` and `.cs.txt` files are classified as executable/helper/build source, not documentation. Their fixed runtime callers remain unchanged; `.txt` is not a security boundary. Unreviewed script/build/executable extensions followed by `.txt` (including repeated `.txt` suffixes) are excluded unless the complete relative path is listed above. This covers PowerShell, C#/VB/F#, Python/Ruby/shell, Windows executables/libraries/installers, batch files and Windows script hosts. Ordinary text documentation remains allowed. This filename rule is not a content scanner or proof that an arbitrary file is harmless.

Packaging copies helper bytes without executing them; it does not build or open an editor, compile metadata source, query hardware, start polling, connect an account, or sign in. Review helper behavior and its fixed caller whenever its source changes; manifests record the actual copied hashes rather than enforcing a historic source hash.

`SettingsInput.ps1` is a one-shot numeric textbox opened by an explicit Global Settings click through Rainmeter's bundled RunCommand plugin. It uses Windows PowerShell 5.1 and built-in WinForms/.NET assemblies, imports no modules, and writes no files. Its exact ten-key numeric allowlist covers scale, column width, gap, rounding, title/header/body font sizes, background transparency, border thickness, and divider thickness. Size/transparency/thickness decimal fields allow at most two places; whole-pixel fields remain integer-only. Input length and numeric/UI ranges are bounded. Standard output is only `PARALLAX_INPUT_V1|ok|<canonical number>` or `PARALLAX_INPUT_V1|cancel|`, consumed as data by Settings Lua. The controller retains responsibility for persistence, including changing only the alpha channel of `BackgroundColor` for transparency. The eight color swatches use the separate Lua ColorPicker, not this text helper. No polling process or binary is added. The reviewed 2026-09-11 helper SHA-256 is `CC4BAD851707E63EA6951F4DCDA63B8F9111A33AA396F6F3F3A2CF37EBFF5A70`.

`DiscoverSensors.ps1` is CPU's original one-shot HWiNFO export discovery helper, used on load/reconnect and explicit setup scans rather than telemetry polling. It uses built-in .NET registry access to read only `SOFTWARE\HWiNFO64\VSB` in the 64-bit HKCU/HKLM views. It imports no modules, writes no files or registry values, and makes no network or child-process calls. The fixed ASCII protocol contains validated export identities encoded as UTF-8 hex; machine-specific indexes are discovered at runtime rather than bundled. `-List` adds at most 128 validated candidate records and one `Get-Process -Name HWiNFO64` snapshot. `-RequestId` is a bounded nonnegative Int32 echoed only as data to correlate completed scans. Non-list discovery does not enumerate processes. Native Registry measures read live values afterward. The reviewed 2026-09-11 source SHA-256 is `CB7E69DC279C08E379157864506DBF30D2DAF18A177D23BB724A8F8D2636988E`. Packaging never runs or dot-sources this helper, reads HWiNFO exports, configures HWiNFO, or bundles HWiNFO itself. Discovery and provider behavior require the CPU module's separate checks.

`DiscoverExports.ps1.txt` is GPU Settings' original one-shot export browser, invoked only by explicit Browse/Rescan through a fixed module-relative `ScriptBlock.Create(ReadAllText(...))` caller. It takes no command arguments or provider strings as code. It reads the bounded `User\GPU.inc` source selection, validates an HKCU/HKLM hive and literal key, then uses read-only 64-bit registry access without expanding registry environment values. The response has hexadecimal UTF-8 data fields, at most 256 rows, a roughly 750 KB row-payload ceiling, 512-character fields, and a 4,096-registry-value precheck. GPU Lua additionally validates source identity, response sizes and safe mapping strings before writing only known GPU option keys. The helper has no network, child-process, file-write or registry-write operations; its caller has a 10-second timeout. The reviewed SHA-256 is `71161B37FAB4FC95B3FBF97B447A834BCA8DC88D8A6C4B8AC674BBD222B6A4D1`.

`MemoryInfo.ps1.txt` is RAM's original one-shot inventory query, evaluated by a fixed module-relative caller on skin refresh with a 12-second timeout. It queries only local `Win32_PhysicalMemory` capacity/type/configured-rate/form fields and `Win32_PhysicalMemoryArray` use/socket-count fields. Its numeric-only `RAMINFO1` response contains at most 512 device rows and a bounded or unknown slot count. It emits no machine identifiers, writes no files or registry state, and launches no child process itself. The reviewed SHA-256 is `6788526E689D2BD227BFDE75A74175AFD935AC01A631BB2F483DEB56E034771A`.

`AdapterInfo.cs.txt` is GPU's original metadata/build source, compiled by the fixed PowerShell `Add-Type` caller once per skin load/refresh, with a 12-second RunCommand timeout. It enumerates at most 512 adapters, limits the driver-description buffer to 16 KiB, uses fixed DXCore/DXGI/D3D12 imports restricted to System32, and releases its native resources. Its bounded result describes the selected adapter and queried capabilities; GPU Lua sanitizes provider text before displaying it. The C# source contains no network, file-write or child-process calls. Runtime compilation and graphics-query cost remain part of GPU's separate verification; packaging neither invokes `Add-Type` nor promises zero runtime compilation overhead. The reviewed SHA-256 is `EC1A59A9D3F2035363B9802DD6E1A58B6C94201C6069E1224A471B7BC3A93376`.

For the optional Spotify queue, `QueueProvider.ps1` imports only its two sibling modules. It targets Windows PowerShell 5.1 and built-in .NET assemblies; no binary or package is bundled for it. Client configuration, DPAPI tokens, queue snapshots, and retry records belong under `%LOCALAPPDATA%\Parallax\Media\Spotify`, outside skins, and must not be included in a release. The original Python/JSON contract artifacts remain developer-only exclusions. Staging preserves source bytes, including the UTF-16LE BOM in `QueueReader.lua`.

`SourceProvider.ps1` is Media's optional local Windows media-session observer, the fourth exact Media helper exception. An explicit Start launches one hidden Windows PowerShell 5.1 worker; skin load/refresh never starts it. Its fixed built-in Windows APIs inspect local sessions without network, authentication, browser inspection or playback commands. There is no startup task or service. One worker mutex prevents overlapping collectors; a separate control mutex serializes Start and Stop. Only explicit Start clears an old stop marker before launch, so a delayed worker honors a Stop that completed after its launch request. Stop waits up to 10 seconds for the control mutex and 10 seconds for the worker mutex (20 seconds of bounded lock waits), leaves a stop request if the worker cannot exit, and never kills unrelated processes. Closing a skin leaves this explicitly enabled observer running.

Collection runs on a two-second cadence with a four-second asynchronous budget, two consistent metadata reads per session, at most 16 sessions, and no overlapping pending Windows requests. A synchronous Windows API call cannot be forcibly timed out; the passive reader still expires its snapshot six seconds after collection starts. The idle wait checks the stop signal every 100 ms without launching processes. These bounds are not a measured CPU/memory performance result.

The observer writes only `source.snapshot`, `stop.request` and atomic temporary files in its current-user-only `%LOCALAPPDATA%\Parallax\Media\Source` directory; developer overrides must resolve under a dedicated local temp directory. Root/ancestor and runtime-file reparse checks prevent following redirected storage. Snapshots contain local title/artist metadata as strict uppercase UTF-8 hex, fixed source classifications and playback flags, never app IDs or credentials. The `PARALLAX_SOURCE_V1` envelope is limited to 128 KiB, each text field to 1,024 UTF-8 bytes; malformed Unicode/NUL, excess limits or inconsistent collections fail closed. Nonready snapshots contain no metadata. Metadata never becomes a launch argument or executable expression. Runtime files must remain outside release inputs. Staging preserves the passive `SourceReader.lua` UTF-16LE BOM and copies the provider without launching it or reading live media data. The reviewed provider SHA-256 is `E86AB13530D92935DA4AA9A563115884FA2AEAFFBABDDB773E761C4BFB16F150`; see the [Media contract](modules/Media.md#optional-spotify-source-detection) for matching semantics and lifecycle limitations.

`EventEditor.exe` is Parallax's original, locally compiled name/date/time editor, launched only by an explicit Chronometer edit action. Its two C# files and build wrapper ship beside it so the build inputs remain inspectable. Source review found only built-in .NET/WinForms references, with no downloads, network calls, dynamic assembly loading, or child-process launches. Event saves and clears write the requested Rainmeter settings-folder state file; its `Parallax-Chronometer-event-v1.state` and temporary files stay outside distributable skins. The current form uses `DateTimeOffset` Unix-time conversion APIs and requires **.NET Framework 4.6 or later**, despite the compiler directory retaining the `v4.0.30319` name. See Microsoft's [API applicability](https://learn.microsoft.com/en-us/dotnet/api/system.datetimeoffset.tounixtimeseconds#applies-to).

The reviewed 2026-09-11 editor binary is 25,088 bytes with SHA-256 `1FC85D3A9005FBAFD58D0CEBDCEEA90201708AE74AA8DB0027D20EC4A2B9BD83`. Staging records the bytes actually copied; it does not establish that a binary was built from the adjacent source. Review the source, build inputs, resulting binary hash and native tests again after any editor rebuild. For a manual rebuild, use a writable development copy of the Chronometer module and an existing .NET Framework C# compiler:

```powershell
.\Build-EventEditor.ps1
```

The wrapper runs `%SystemRoot%\Microsoft.NET\Framework64\v4.0.30319\csc.exe` with `/nologo /target:winexe /optimize+ /reference:System.Windows.Forms.dll,System.Drawing.dll`, using only `EventEditor.cs` and `EventEditorForm.cs`, and writes `EventEditor.exe` beside them. It installs nothing and is never invoked by staging. Native editor and RunCommand behavior require the module's separate tests; static packaging checks do not cover them.

`.dll`, other executables/build sources/helper scripts, and arbitrary data files remain absent from the allowlist. Any further helper requires an explicit packaging review. A missing required include or Lua script makes staging fail. Failed staging directories remain available for inspection; the next run uses a new directory.

## Skin Packager release settings

`packaging/release.json` is a review template, not an installer configuration. Fill its author and tested minimum versions before release. Keep the selected suite version consistent with skin metadata and release notes.

| Field | Parallax release choice |
| --- | --- |
| Name | `Parallax` |
| Author | Owner-selected public credit; currently unresolved |
| Version | The release version passed to staging |
| Add skin | Exact `Skins\Parallax` folder from the successful stage |
| After installation | Load `Parallax\Settings\Settings.ini` if that is the tested entry config |
| Merge skins | Off |
| Variables files | Exact contents of the stage's `variables-files.txt` |
| Minimum Rainmeter / Windows | Lowest versions exercised in release testing |
| Save package to | A new versioned `.rmskin` path under the stage directory |

All shipped `@Resources\User\*.inc` paths must appear individually, starting with `Parallax\`, in **Advanced > Variables files**. The stage enumerates them, including nested paths; do not enter a wildcard. Preserve settings as values in `[Variables]`. This feature migrates existing variable values during upgrades; it is not a whole-file backup or persistence mechanism for JSON/Lua state. It cannot be combined with **Merge skins**. Record the exact field in the release record and exercise a real upgrade with altered values. See [Variables files](https://docs.rainmeter.net/manual/distributing-skins/#VariablesFiles) and its [official source](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/distributing-skins/index.html#L83-L92).

Keep optional third-party software separate unless redistribution is explicitly allowed and tested. Built-in plugins require no separate payload. If a custom plugin is distributed through Packager, supply the architectures required by the Packager and verify them against the supported Rainmeter versions. No plugins are bundled by the staging tool. Packaging does not grant redistribution rights for software, fonts, images, or ModernGadgets code.

## What static validation establishes

The validator checks all `.ini` / `.inc` files for duplicate local sections and options, recursively resolves shipped `@Include*` paths, detects cycles and missing includes, checks the presence of config metadata and meters, verifies simple named measure/style references, and checks resolved Lua script paths. It recognizes `#@#`, `#ROOTCONFIGPATH#`, `#CURRENTPATH#`, and simple defined variables in include paths. Relative include paths are interpreted from the including file's directory. Include keys run in source order, so local keys following an include can override its defaults.

`[Variables]` repeated across different include files is intentional and accepted. Duplicate sections within one physical file are errors. Non-Variables sections layered across files are warnings for review. Rainmeter merges sections across files but ignores a second same-named section within a physical file. See the [official @Include rules](https://github.com/rainmeter/rainmeter-docs/blob/master/source/manual/skins/include-option.html).

This is a conservative linter, not Rainmeter's parser. It does not reproduce every parsing or meter insertion detail, execute Lua, evaluate formulas, validate every bang/plugin option, resolve dynamic section references, inspect binary assets, or prove that the skin renders. Unresolved include paths fail so missing shipped defaults cannot pass unnoticed. Intentional dynamic include designs need a focused validator extension with fixtures. A passing check is never a runtime or performance claim.

## Release gates

- Confirm every planned module is implemented and passes static validation with `-RequireAllModules`; review any remaining warnings.
- Use a separate test installation or disposable profile to load every supported config and variant. Inspect Rainmeter's log, controls, refresh/unload behavior, empty states, and absence of optional providers.
- Verify standard and double widths, snapping gaps, scaling, long labels, monitor boundaries, and mixed-DPI layouts visually.
- Measure idle, active, and visualization-enabled CPU/memory use on recorded hardware. Compare against the same Rainmeter setup without Parallax; record provider processes and sampling intervals separately. No performance result is established yet.
- Verify dependency discovery, supported versions, permission failures, disconnects, recovery, and disabled-provider behavior. Authenticate only in the test environment, then ensure no credentials enter the stage.
- Install the actual Packager-produced `.rmskin` into a clean test environment. Reinstall/upgrade over changed global and per-module `[Variables]`, including empty values, and verify preservation and new defaults. Runtime state outside `[Variables]` needs a separate migration test.
- Review author credit, license, third-party notices, minimum requirements, release notes, generated Variables files list, and manifest. Resolve `packaging/release.json` placeholders.
- Record the final artifact's SHA-256 and the tested Rainmeter/Windows versions. A stage alone does not satisfy this gate.

The scripts do not install Rainmeter, download plugins, write into the real Rainmeter skin path, launch Skin Packager, or publish releases. Those steps remain explicit release work after validation.

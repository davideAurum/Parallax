# Integrated development build

Reviewed 2026-09-11 (local time) after all eight utility owners completed their current work. This checkpoint includes expanded Global Settings and its close X, the reusable RGB/HSV/Lab picker, compact Chronometer events and section visibility, guided CPU HWiNFO setup, dedicated RAM/GPU/IO settings, Network connection information, Media source detection and album-art layout, and the independent audio visualizer.

## Integration checks

- Shared validation: 20 configurations and 65 INI/include files, zero errors or warnings.
- Global Settings: 450 controller/native-bound checks, 100 geometry combinations, 759 textbox assertions and 30 native field cases. Default restores all 34 appearance keys; eight picker targets passed routing/Apply/Cancel/alpha checks. See [SETTINGS-REVIEW.md](SETTINGS-REVIEW.md).
- Chronometer's compact two-line event passed 77 Lua cases and 705 native assertions. Its section dividers now follow the section below, preventing a trailing divider when sections are hidden; 21 native layout cases passed 6,848 assertions.
- Media's source provider passed 124 synthetic assertions. Independent review reproduced and then verified the fix for delayed Start→Stop→Run ordering: zero collections after completed Stop, with later explicit restart working. Evidence: `%TEMP%/Parallax-SourceStop-fixed-dd6bba70ad4d4fb2afad66dffe1246f4/review-result.json`. No native session or worker was launched by that review.
- The passive source reader independently passed 133 assertions/13 synthetic cases, including Unicode native binding. Media artwork passed 9,003 assertions in 36 isolated layouts; the final adapter passed 302 assertions/14 cases. Root inspected the synthetic default/narrow double-width artwork captures; source correlation and artwork tests use inert metadata rather than real listening data.
- Each utility completed its scoped typography and surface checks. Independent maximum-font pixel review also covered RAM, RAM Settings, Visualizer, Global Settings and ColorPicker in default/narrow layouts: ten inspected captures, matching bounds, no errors. Reports: `build/ram-audio-max-default-3589d6a457d944da90cf266d53915eeb/report.json` and `build/ram-audio-max-narrow-859f5f8e2554424184faeaa895733d6d/report.json`.
- Earlier integrated capture loaded all eight utilities plus Settings successfully in one private profile: `build/Parallax-visual-preview-20260911T233726201Z-ae05bc2c/`. Final changed-panel captures are under `build/Parallax-visual-preview-20260912T001517279Z-c192783e/`: Settings, Chronometer and Media Setup rendered with no errors and current preferences preserved. These snapshots retain honest unavailable/setup states.
- Complete packaging fixtures passed, including the thirteenth exact helper exception, actual byte/hash preservation, UTF-16LE BOM and runtime/private/test exclusion cases. Evidence: `%TEMP%/Parallax-ToolTests-8b12eda29fad4341a2ef94f19e22361f/` and `build/packaging-media-source-review-test.log`.
- The fresh production stage contains 115 files, excludes 15 entries, and lists nine User includes for upgrade preservation. Source/staged validation passed; all 115 hashes match both their sources and manifest. No test, QA, fixture, hidden, runtime, cache, private, token, vault or DLL paths entered the stage.
- Independent prospective Git review covered 224 source/test/documentation/asset files. No unexpected generated/runtime/authentication artifacts or binaries were found. Reusable tests, licensed fonts and the original Chronometer editor/build sources remain included.

Stage: `build/Parallax-0.1.0-dev-20260912T001508479Z-561d45f0/`. This supersedes earlier 105/113-file stages.

Manifest SHA-256: `EF0F849261CB05D4003B7C9391DD607E15CFAF1AFC134B8BB8442216BFCCF83E`.

The stage is a development snapshot, not an installer. Thirteen reviewed first-party helper/build-source paths are copied without execution or compilation. Current hashes and constraints are recorded in [PACKAGING.md](PACKAGING.md). Media SourceProvider is `E86AB13530D92935DA4AA9A563115884FA2AEAFFBABDDB773E761C4BFB16F150`; SourceReader is `695ECAB016E691622BE3896280B072BC4E1EAE18C4FD3D1BBED01760ADD683AE`; QueueReader is `8800816A46FB072C010BD5EF30BFCFE4EDBA11FA0C664C00E284FFC4E344F067`.

Git preserves both readers' UTF-16LE bytes, binary assets and the unmodified upstream font license. Generated evidence/stages, installed third-party skins/plugins and runtime/authentication data are excluded. Whitespace review permits the upstream license's original trailing space and existing final blank lines.

## Remaining acceptance

Module scope and limitations are recorded in `docs/modules/`. Actual CPU VID was observed and labeled; live Vcore and package temperature remain unverified here. Some private profiles cannot query RAM/CPU inventory under sandbox restrictions and show unavailable values.

Active Wi-Fi, physical event-form interaction, mixed Windows DPI, full-suite/provider overhead and packaged installation/upgrade behavior remain acceptance work. Initial Spotify queue authorization/refresh does not establish every Media scenario. Source detection is conservative metadata correlation, expires stale observations, and does not prove WNP freshness. Its Stop lock waits are bounded; synchronous Windows API stalls cannot be forcibly interrupted by the helper.

This local source checkpoint does not publish a release, install software, alter the live Rainmeter profile or change an authenticated provider session. Distribution still requires the [release gates](PACKAGING.md#release-gates), including a Skin Packager-produced `.rmskin` and upgrade testing.

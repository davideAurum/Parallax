# Parallax collaboration contract

Parallax is an original Rainmeter suite inspired by the utility density of ModernGadgets. Do not copy its code or assets without reviewing its license and recording attribution.

Read `docs/ARCHITECTURE.md` and the revised `docs/APPEARANCE.md` before editing. This directory is shared by dedicated Codex tasks, not separate git worktrees. Stay inside assigned paths. Do not overwrite another task's files. The original task owns shared settings, styles, geometry, root documentation, integration and packaging coordination. Propose shared changes in your module document rather than editing shared files.

Each utility owns `Skins/Parallax/<Module>/`, `Skins/Parallax/@Resources/Modules/<Module>/`, `Skins/Parallax/@Resources/User/<Module>.inc`, and `docs/modules/<Module>.md`. Module names: Chronometer, CPU, RAM, GPU, IO, Network, Media, Visualizer. IO owns disk activity; Network owns NIC traffic. Shared tooling is in `tools/` and `packaging/`.

Use built-in measures first. Optional plugins/providers must be explicit and show honest missing/unsupported states. No fabricated telemetry. No repeated shell/process launches for polling. No credentials, machine-specific sensor IDs, binary downloads, or user data in distribution. Do not install dependencies, change the user's live Rainmeter configuration, or publish releases as part of initial implementation.

Explicit user-approved exception, 2026-09-11: the global integration task may download and bundle unmodified IBM Plex Sans fonts from IBM's official repository with the SIL Open Font License. This is skin-local font bundling, not system-wide font installation. Module tasks inherit FontFace and do not provision fonts independently.

Validate feasible behavior, not just file existence. Record checks and runtime limitations honestly. Completion of a module prototype is not proof of performance or release readiness.

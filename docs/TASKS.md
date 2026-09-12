# Dedicated task ownership

Initial implementation dispatched 2026-09-11. These are user-owned Codex tasks sharing this directory. The original task remains responsible for shared settings, integration and packaging. Status records dispatch and received completion reports, not a live monitor.

| Task | ID | Ownership | Current milestone |
| --- | --- | --- | --- |
| Parallax · Global Settings and Integration | 01a09165-472d-7c53-b709-36013515eddb | Shared foundation and release coordination | All current owner work integrated; 115-file production stage and 224-file source review passed; development checkpoint prepared |
| Parallax · Chronometer | 01a09168-7be1-74f2-897e-c5d31521f5a0 | Clock and countdown lists | Compact two-line event complete; section dividers follow the section below; 77 Lua, 705 event assertions and 6,848 divider assertions passed |
| Parallax · CPU Meter | 01a09168-85d7-77e3-8771-56ffba0a0cc4 | CPU | Guided HWiNFO setup and global appearance complete; 89 helper/controller cases and native controls/layout passed; VID observed, package temperature unavailable |
| Parallax · RAM Meter | 01a09168-8fc8-7ae1-8180-2721caa0652d | RAM | Dedicated Settings utility, hardware panel and global appearance integration complete; 20 native layout/control cases passed |
| Parallax · GPU Meter | 01a09168-9af8-7343-b2f2-143de3cc5669 | GPU | Dedicated Settings with exact HWiNFO export mapping and global appearance complete; native controls/persistence and max-font surface checks passed |
| Parallax · Drive I/O | 01a09168-a979-78f0-87e0-35a23024df42 | Disk capacity and activity | Both variants and dedicated hover-gear settings complete; 46 checks and isolated Rainmeter checks passed |
| Parallax · Network Monitor | 01a0916c-573b-7db1-a8e0-1e1ac56a5b5b | NIC traffic and adapter selection | Throughput/Connection typography and surface integration complete; default/max/mixed native matrices passed, active Wi-Fi unverified |
| Parallax · Media Player and Spotify Queue | 01a09168-b7c6-7482-82d9-80624518dbd4 | Playback and optional queue | Spotify detection and left-overhanging album art complete; 124 observer, 133 reader and 9,003 artwork native assertions passed; lifecycle fix independently verified |
| Parallax · Audio Visualizer | 01a09168-c395-7523-886c-c0a8d6dff245 | Mixed-device audio spectrum | Global typography/accents/surface complete; 300 source cases and default/narrow max-font native pixel review passed |

For each module's current implementation details, see its document under `docs/modules/`. Runtime integration, provider setup, DPI/layout checks, measured overhead and upgrade-safe `.rmskin` packaging are separate acceptance gates.

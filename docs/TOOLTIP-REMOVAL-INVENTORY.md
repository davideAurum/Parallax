# Tooltip removal inventory

At the user's direction every tooltip was removed from Parallax (the change
that shipped is the 2026-10-18 pass; see [PERFORMANCE.md](PERFORMANCE.md)): all
`ToolTip*` options, every Lua `!SetOption … ToolTipText`, and the
Windows.Forms tooltips in the PowerShell input dialogs. A new tooltip plan will
follow. This file lists what the removed tooltips used to explain and nothing
else now shows, so that plan can decide what (if anything) comes back and how.
[TOOLTIP-AUDIT.md](TOOLTIP-AUDIT.md) is the earlier, now superseded, audit.

This inventory was compiled on 2026-10-11 from an earlier, parallel removal of
the same tooltips; the 2026-10-18 code differs in detail, but what each
tooltip explained is the same. Load-time context: each tooltip cost about
40 ms of skin load on the 2026-10-11 test host (100 String meters: ~60 ms
without tooltips, ~4 s with); the 2026-10-18 suite-wide numbers are in
PERFORMANCE.md.

Some explanations were deleted from code, not just hidden (noted below); a new
plan would have to re-add them.

## Highest-value losses (state explanations)

- **CPU:** why a sensor reads `-`/Unavailable (discovery failed or timed out,
  HWiNFO not running, export removed, identity or units changed, out of range,
  no per-core export) and discovery `STATUS` messages. The footer still shows
  the broad state. *Reason strings deleted from code.*
- **GPU:** why Temp, Power, Clock, VRAM, Shared or an engine shows `--`
  (names-only mode, stale or invalid driver sample, device change needs
  Refresh, unsupported driver, HWiNFO mapping and its expected vs received
  names); why a process VRAM is `--`. *Reason code deleted.*
- **RAM:** why PAGE is Unavailable/Stale (reader failed, lease lost, session
  invalid, stale or out-of-sequence sample, "Refresh to retry"). *Deleted from
  code.* Available physical memory is no longer shown anywhere
  (`MeasureRAMAvailable` remains but is unused).
- **Network:** Wi-Fi unavailable diagnosis (no adapter, radio off,
  disconnected, Windows Location access denied, with the Privacy > Location
  fix); specific Wi-Fi config errors (now just "Check Wi-Fi settings"); Wi-Fi
  link RX/TX rates (no longer displayed).
- **IO:** an invalid saved drive selection silently falls back to C: (the
  warning is gone, in both the panel and settings); why a rate shows `--`.
- **Media:** why a transport button is muted; the song icon's source
  explanation (Spotify confirmed vs ambiguous, unmatched, stopped, expired…;
  the reader still returns the reason code); queue and spectrum-tab preference
  read/save failure messages (the action still fails safely, silently).
- **Welcome / updates:** why an update check failed and the download error.
- **Numeric input dialog** (shared, CPU, GPU, Network, IO): the specific
  invalid-input message; only the red border remains.

## Hidden detail and full values

- Full names when clipped: CPU processes, GPU adapter, IO drive names,
  Chronometer event and timer names, Network adapter selector/alias/status
  (link type), RAM process names, Global/Chronometer settings lists.
- Exact values behind compact text: RAM byte counts, GPU VRAM bytes and kHz
  clocks, IO free/total and used % to one decimal, Network link speeds,
  Chronometer event target date and time (not shown anywhere now).
- Provenance: CPU raw processor string and clock source (HWiNFO vs Windows
  aggregate), RAM inventory provenance (raw MT/s, inferred clock, SMBIOS type,
  manufacturer inference — *deleted from code*), GPU capacity source and memory
  vendor, Network Wi-Fi WLAN index and fallback.

## Meaning and conventions (mostly also in module docs)

- Graph conventions (CPU, GPU, IO, RAM, Network): ranges and caps, clipping,
  newest at right, refresh clears history, zero can mean idle or unavailable,
  interpolation, Split/Overlay drawing.
- Metric definitions: CPU VID vs Vcore and thread-to-core mapping, GPU engine
  domains not additive and process % = busiest engine, RAM private working set
  and grouped processes, Network adapter status ≠ Internet reachability,
  Visualizer relative dB scale and what output switching does (system-wide).
- Icon-only headers: CPU Zap / Flame / Gauge columns have no text labels.
- Behavior notes: hidden timers/events keep running, Chronometer clock/sleep
  behavior and uptime source, Welcome Close/Unload, ColorPicker plane vs slice.

## Settings help

- Allowed ranges and steps for every numeric field (Global Settings: Scale
  75–200 %, column width 180–320, gap 0–16, corner 0–24, transparency 0–100 %,
  thickness 0–4 (data bar 1–12), title 6–12 pt, header/body 6–10 pt; and each
  module's fields), "click to type, Enter applies, Esc cancels".
- What buttons do before you press them (Open file, Apply, Reconnect, Disk
  quotas, Sign in, units toggles…), raw saved values behind "Custom", and the
  Edit-file syntax for advanced keys.

Each module document carries a dated note on the removal.

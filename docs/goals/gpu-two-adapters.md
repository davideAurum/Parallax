# Two GPUs in one meter

Page: https://claude.ai/artifact/5tZdj1MXeP1xp7bDKcFEty

```
status     landed on main (fb36fb3) · endpoint reached, with accepted shortfalls · no release
stages     ✓ 1
```

## Goal

One GPU Meter serves integrated-only, discrete-only and two-GPU computers, including hybrid laptops whose discrete GPU is usually idle.

**Primary endpoint** ✓ On a hybrid laptop one GPU Meter can show the integrated GPU's activity alongside the discrete GPU; single-GPU machines look as they do today. Evidence asked for: on the Surface Laptop Studio the Iris Xe load shown tracks Windows' 3D engine counter; with one adapter filtered out in a staged copy the panel matches the current one; GPU module tests pass.

## Stage 1: two GPUs in one GPU Meter

- Main GPU setting: Auto (default: first discrete, else integrated), Integrated, Discrete; no match falls back to Auto.
- Second GPU setting: Off, One line (default), Rows (video, memory), Rows + history trace. Shown whenever there are two real GPUs.
- AMD and Intel Arc discrete cards read load and memory through DXCore; temperature and power stay unsupported.

**Approach.** The telemetry host picks and samples the second GPU (NVIDIA driver as before, DXCore otherwise); the adapter query reports only the main GPU, in its old reply format. Panel and settings gain the second section and both choices.

**Risks** one hybrid machine → filtered staged copies · no AMD/Arc → offline tests, unverified · protocol change → second GPU goes to a sibling session file · polling may wake the discrete GPU → separate session.

**Assumptions** one host, no second process · second = next real GPU in high-performance order · process table unchanged · HWiNFO overrides main only · GPU Meter's own row styles · no new dependency.

**Lane** `second-gpu` · `feat/second-gpu` · opus · from `goal/gpu-two-adapters`

| M | What exists after it | State |
| --- | --- | --- |
| 1 | Main GPU choice in the adapter query, second-GPU ordering rule, with tests | ✓ 34852cb |
| 2 | Helper samples both; non-NVIDIA discrete reads load and memory via DXCore, with tests | ✓ 6c7e18a |
| 3 | Panel shows the second GPU: Off, One line, Rows, Rows + history | ✓ 8299dcc |
| 4 | GPU Settings offers both choices; docs, dependencies, native check on this laptop | ✓ 0a2b6f8 |
| 5 | Second-GPU section between the memory rows and the process table (added) | ✓ 46c6aea |
| 6 | A test requires the layout re-read when the section height changes (added) | ✓ e7aef55 |

Stage 1 landed on `goal/gpu-two-adapters` at fb36fb3 (M1-M4 pulled at a69e3c4, then M5 and M6).

## Final assessment (2026-11-27)

**Called: reached.** Native capture shows both GPUs in one meter; Iris Xe load matched Windows' 3D counter at low load and a filtered one-GPU copy matched the earlier panel (build agent's measurements); module tests pass; grader passed both rounds.

**Accepted shortfalls (untested):**

- AMD and Intel Arc cards.
- Two discrete GPUs, or three or more.
- A real one-GPU machine.
- Heavy or video load.
- Idle pause with the section open, Main GPU = Integrated live, mixed DPI.

**Learned:** carry the picked layout preview into the lane brief. The power-state gate is a separate session's work on top of this goal.

## Changes

- 2026-11-26 · approval: stage 1 approved.
- 2026-11-26 · ruling: the adapter query keeps its reply format; the host picks the second GPU.
- 2026-11-26 · ruling: Main GPU reaches PowerShell only as a number (0/1/2), never as saved text.
- 2026-11-26 · ruling: DXCore applies to any discrete adapter the NVIDIA open reports unsupported.
- 2026-11-26 · ruling: second-GPU samples go to `<session>.second`.
- 2026-11-26 · notice: the power session reports NVAPI and NVML reads wake the discrete card; its gate stays out of this goal.
- 2026-11-26 · question, allowed: `Validate-GPU.py` accepts a window that grows and the eight second-GPU meters (D: 34037a7).
- 2026-11-27 · question, allowed: settings-test expectations updated for the two new rows (D: c8f30e6).
- 2026-11-27 · David: move the section between the memory rows and the process table (M5).
- 2026-11-27 · notice: `Validate-Settings.py`'s field loop also gained MainGPU and SecondGPU (widening only, beyond the approved list).
- 2026-11-27 · David: stage 1 done, then endpoint reached.

## Landed (2026-11-27)

- `goal/gpu-two-adapters` merged into `main` by fast-forward: 591cc0e → fb36fb3, 11 commits kept.
- Tests on `main` after the merge: `Validate-GPU.py`, `Validate-Settings.py`, `Run-DriverChecks.ps1` and `Test-Parallax.ps1` all passed.
- Not run at landing: native Rainmeter smoke test and previews (they disturb another session's power measurements). The installed GPU Meter was not changed.
- Release: none until David asks.
- Open findings: none. The power-state gate continues on `claude/parallax-gpu-meter-power-eff508`.

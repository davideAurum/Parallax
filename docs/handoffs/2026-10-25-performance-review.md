# Performance review handoff (2026-10-25)

A fresh session can continue from this note. The full record is [PERFORMANCE-REVIEW.md](../PERFORMANCE-REVIEW.md); its "Where it stands" section is the summary. Updated 2026-10-26 after the overnight check.

## Where things are

- **Branch:** `claude/parallax-performance-review-55c97a`, not pushed.
  - `main` (`6d59634`, 0.1.0-alpha.8) already has the branch up to `33b639b`, through merge `da8137b` (2026-10-25 17:07). That covers phases A-C and the opt-in RAM auto-ranged history.
  - Ten commits are not in `main` yet:
    - the 10-25 re-measure and owner-decision records (`d36c6af`, `09d9dfe`);
    - the kill-race fix (`408cc64`, `0bb3e6f`, merge `0f6705f`);
    - this note (`914ebb5`);
    - the overnight-trace start script (`f172abd`, `e93f957`, `87bb426`);
    - the overnight record (`11f757d`).
- **Worktree:** `C:\Users\david\Coding\Parallax\.claude\worktrees\amazing-mccarthy-f9ba00`. Its git-ignored `build\` folder holds the review's evidence:
  - `leak-watch\`: the leak logger, its CSVs and `which-dropped.ps1`;
  - `perf-trace\`, including the 10-22 overnight baseline `20261022T233145-overnight-baseline*`;
  - `perf-benchmark\`, `perf-matrix\` and `wakeup-recheck\`;
  - `pxab-archive\`: the `anim0` and `anim20` patches;
  - the `*.log` files.
- **Archiving that worktree's session deletes the worktree.** Do not archive it until step 4 below has copied the evidence out.
- **The desktop runs the installed 0.1.0-alpha.8 release, which includes phases A-C.** Of the ten commits above, only the kill-race fix changes the skin. The live skin changes only when a release is installed. (Corrected 2026-10-26: this line said nothing from the branch was live.)

## Running now

- **The leak logger.** It is a hidden `powershell -MTA` process running `build\leak-watch\Watch-Leak.ps1` in the worktree above. It ran as pid 22180 from 2026-10-25 16:34 until David restarted the PC at 2026-10-26 00:53 (last sample 00:49), and has run as pid 31668 since 2026-10-26 01:38.
  - It writes `leak-samples.csv` every 10 minutes and `display-events.csv` on each display change. `which-dropped.ps1` reads `display-events.csv`, so dropouts while the logger is down go unrecorded.
  - To stop it, create `build\leak-watch\leak-watch.stop`.
  - It takes `-OutDir`, and defaults to its own folder.
- **The overnight trace has finished.** It ran on 2026-10-26 from 01:44 to 11:44, on alpha.8.
  - Output: `C:\Users\david\Coding\Parallax\build\perf-trace\20261026T014354-overnight-clean-baseline*`.
  - David started it with `tools\Start-ParallaxOvernightTrace.ps1`, which is on this branch until it ships. The script runs a read-only preflight, then starts the main checkout's tracer hidden and detached; its header lists the checks.
  - For any later trace, run the script again with a new `-Label`:
    ```
    powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\david\Coding\Parallax\.claude\worktrees\amazing-mccarthy-f9ba00\tools\Start-ParallaxOvernightTrace.ps1" -Label <label>
    ```
  - The screen timeout is still at 60 s from the dropout tests. David resets it.

## Next steps, in order

1. **Morning dropout check. Done on 2026-10-26** (`11f757d`): the cable fix holds.
   - `which-dropped.ps1` lists every one-screen row as a dropout. Most of its rows are screen wake-ups, so read them by signature. The review's "Overnight check (2026-10-25/26)" section explains how.
   - David still resets the screen timeout.
2. **Read the overnight trace. Done on 2026-10-26** (`11f757d`).
   - With the screens off, Parallax used 8.1% of a core, against 26.6 on 10-22.
   - The ~50 s fan peaks are gone.
   - The remaining fan load is Spotify's runaway renderer, at about 110% of a core with nothing playing.
3. **Decide the refresh-orphan fix.** It is on `refs/heads/claude/refresh-orphan-host-fix`, commit `7be434a`, "Stop RAM PAGE and GPU hosts left running by a skin refresh".
   - **Unreviewed.** The side session "Fix helper host orphaned by a skin refresh" made it, and nobody has reviewed it. It changes 11 files, +427/-38, including `PageFile.lua` and `Temperature.lua`. `Temperature.lua` is UTF-16LE with mixed line endings.
   - **Older base.** It is based on `408cc64`, before the review corrections in `0bb3e6f`. Expect conflicts in `docs/modules/RAM.md`, `docs/modules/GPU.md` and `docs/PERFORMANCE-REVIEW.md`.
   - **Where it is checked out.** In the git-closeout session's worktree, `.claude\worktrees\git-closeout-8e93d5`. That session's own branch, `claude/new-release-1493f0`, equals `main`.
   - **The choice.** Review it and merge it into the perf branch before the release, or defer it.
   - **Related work.** The slow-start fix below changes the same launchers, so the two could be done together.
4. **Preserve the evidence, then archive the sessions.**
   - Stop the logger (stop file), then copy the worktree's `build\` evidence (the list above) to `C:\Users\david\Coding\Parallax\build\perf-review-evidence\`. That folder is in the main checkout and is git-ignored.
   - Restart the logger from there only if David still wants it. Starting or stopping it needs his go-ahead.
   - Then archive:
     - "Fix the stand-down helper kill race". Its idle side session "Fix helper host orphaned by a skin refresh" is archived with it, and its folder is the git-closeout worktree, so check that folder's `build\` for release artifacts first.
     - "After re-measure and C:\pxab cleanup". It shares this worktree.
     - The performance review session itself.
5. **Ship.**
   - Merge the perf branch into `main` with `--no-ff`.
   - Run `tools\Test-Parallax.ps1 -RequireAllModules -WarningsAsErrors` and the packaging tests.
   - Build the release package with `packaging\`; David installs it.
   - Push, publish or open a PR only if David asks.
6. **After the install: probably not needed. David decides.**
   - The 2026-10-26 trace already ran on alpha.8, with phases A-C live.
   - The next release adds only the kill-race fix, which does not change steady-state load.
   - Re-run the trace with a new `-Label` only if David wants a check after installing.
   - The opt-in RAM auto-ranged history is already in alpha.8. Checking its live CPU cost needs that option switched on.

## Decided on 2026-10-25

- The process lists stay shown by default.
- The lazy coordinator for the drawer is dropped. The coordinator's window costs about 2 UI wakeups/s on a healthy machine, not 57.
- The stand-down helper kill race is fixed and merged (`408cc64`, `0bb3e6f`, merge `0f6705f`). An independent review found only low-severity issues, which were corrected.

## Known, not fixed

- **A slow PowerShell start strands a helper.** If PowerShell takes long enough that RunCommand's 15 s Timeout ends the launcher, the launcher has not yet printed its session. The host then runs for its lease window, about 60 s for RAM and 15 s for GPU. The planned fix is for the launcher to report its session before the Timeout can end it.
- **A skin refresh leaves the previous host running** for its lease window, unless `7be434a` is merged.
- **Not verified:**
  - whether skins on the steady monitor, or a DPI-aware Rainmeter, also leak on each reconnect;
  - for C1/C2, real keyboard and mouse input, real WebNowPlaying playback, and sleep and resume;
  - the RAM auto-range in live use.

## Constraints

- **AGENTS.md applies.**
  - Push, open a PR or publish a release only if David asks.
  - The live skin changes only by installing a release; never copy files into it.
- **Ask before live changes.** Change live state (the drawer, Spotify, processes, the logger) only by script and with David's go-ahead. Confirm each destructive step.
- **No benchmarks under load.** Never benchmark or run native Rainmeter tests while a trace, agents or other load are running.
- **Zero tooltips.**
- **Commit messages** end with the Co-Authored-By line.
- **Spend credits deliberately.**
  - Ultracode turns every task into a multi-agent workflow, so turn it off for routine work.
  - Use Sonnet for scripted steps.
  - Start new work in fresh sessions with short briefs.

## Memory

`parallax-perf-review-status.md` and `parallax-perf-confounders.md` in Claude's project memory for Parallax hold the same state, and more history on the machine's confounders.

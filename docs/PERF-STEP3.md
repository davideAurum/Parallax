# Performance step 3: build matrix tooling

Step 3 of the performance review ([PERFORMANCE-REVIEW.md](PERFORMANCE-REVIEW.md#step-3-evidence-protocol)) proves each fix's gain alone and in combination. This document describes the tools that make that possible, and how they fit together. The tools build, schedule and analyse; **they have not measured anything yet.** Real runs start isolated Rainmeter instances and belong to whoever runs step 3, one matrix at a time, with nothing else measuring.

| Tool | Purpose |
| --- | --- |
| [tools/perf-fixes.json](../tools/perf-fixes.json) | Phase A as data: one entry per fix, with its commits, findings, dependencies and where it can be measured |
| [tools/New-PerfBuild.ps1](../tools/New-PerfBuild.ps1) | One build per measured tree: a detached worktree under `C:\pxab`, made by cherry-picking onto the baseline or reverting from the all-fixes tip |
| [tools/Merge-Utf16Text.py](../tools/Merge-Utf16Text.py) | Resolves the binary conflicts git raises on UTF-16 Lua files, by a text 3-way merge that keeps the byte-order mark and every line ending |
| [tools/Invoke-PerfMatrix.ps1](../tools/Invoke-PerfMatrix.ps1) | Runs each build's own `Benchmark-Parallax.ps1` in interleaved, rotated rounds, collects the reports and computes gₖ, mₖ, G and the interaction class |
| `XMOD-04` rule in [tools/Test-Parallax.ps1](../tools/Test-Parallax.ps1) | Stops a new unconditional repaint bang in a skin's Lua `Update()` |

**Requirements.** Windows PowerShell 5.1 and git, already needed by the other tools. Python 3 (standard library only) runs the UTF-16 merge helper, and only when a build meets a UTF-16 conflict. Nothing is installed or downloaded. These are developer tools: no skin or module gains a dependency, so [DEPENDENCIES.md](DEPENDENCIES.md) is unchanged.

## The workflow

1. **Pick the units.** A unit is what one build adds or removes: a fix, a package, or fixes joined with `+`. The manifest suggests a unit list (below).
2. **Make the builds.** `New-PerfBuild.ps1 -Set` makes the baseline, the all-fixes build, and a *plus* (baseline + unit) and *minus* (all − unit) build per unit.
3. **Dry-run the matrix.** `Invoke-PerfMatrix.ps1 -DryRun` checks the builds, writes the plan and prints the schedule with its estimated duration. It never starts Rainmeter.
4. **Run it.** The same command without `-DryRun`. `-Resume` continues an interrupted matrix.
5. **Read the analysis.** `analysis.md` and `analysis.json` in the matrix folder. `-AnalyzeOnly -MatrixDir <folder>` recomputes them from the collected reports.
6. **Remove the builds.** `git worktree remove --force C:\pxab\<name>` for each.

```powershell
powershell -File tools\New-PerfBuild.ps1 -Manifest tools\perf-fixes.json -Set -Prefix s3 -Fix A1,A3,A4,A6
powershell -File tools\Invoke-PerfMatrix.ps1 -BuildRoot C:\pxab -Prefix s3 -Scenario empty,suite -Trials 5 -DryRun
powershell -File tools\Invoke-PerfMatrix.ps1 -BuildRoot C:\pxab -Prefix s3 -Scenario empty,suite -Trials 5 -MatrixId s3-pkg
```

## The fix manifest

[tools/perf-fixes.json](../tools/perf-fixes.json) describes phase A. It was derived from three sources:

- **History.** The first-parent line from `916c9ab` to `191a1cd`: the six phase-A merges (`17ba69a` A2, `297c108` A3, `c34a3d6` A4, `ca237b3` A1, `d0f30c2` A5, `92c10a4` A6) and their package branches, which all start at `916c9ab`.
- **The builders' commit bodies.** Finding ids, `fixup-of:` trailers and expected effects.
- **Trial builds.** Every fix was built alone onto the baseline and reverted alone from the tip with `New-PerfBuild.ps1`, in a throwaway clone of the repository.

**Baseline and all:**
- **Baseline `916c9ab`.** Its `Skins` tree is identical to `71bfcdc`, the commit the review names. `71bfcdc` predates the measuring tools; `916c9ab` adds them, and each build runs its own copy.
- **All `dfe55b8`.** The tree the review's "Phase A result" measured. Its `Skins` tree equals the last merge `92c10a4` and `191a1cd`.

**Scope.** Builds apply only runtime files: `Skins/`, minus tests, QA, `.py`/`.mjs`/`.luatest` files and `Validate-*.ps1`. That is exactly what `Stage-Parallax.ps1` would never stage anyway. The scope has two consequences:
- **No test-file conflicts.** A fix picked alone does not stop on a test file it shares with another fix.
- **The same measuring tools.** Docs and tools stay as the start commit had them, so every build runs identical tools.

**Fixes.** There are 43 fixes: A1 6, A2 8, A3 7, A4 10, A5 2, A6 10. Each entry lists:
- its commits in apply order, with review fixups marked `fixup` (A2-2 = `cf6454d` + `656d61f`; A2-5 = `fbb63a6` + `ef1baa1` + `1a08c66`);
- its finding ids;
- its `kind`: `fix`, or `honesty` for A3-7 (`1cb1bc7`, the frozen-HWiNFO status kept by owner decision 6).

**Support commits.** Nine commits are marked `test` or `docs`, with policy `excluded`. None has a runtime file inside the scope, so no build ever applies one. The all tip contains them unchanged. Neither affects anything measured.

**Dependencies, found by trial builds:**

| Fix | requires | Shared files |
| --- | --- | --- |
| A2-2 | A2-1 | Source/SourceProvider.ps1 |
| A2-5 | A2-2 | Source/SourceProvider.ps1 |
| A3-3 | A3-2 | CPU/CPU.lua |
| A3-7 | A3-1 | CPU/Sensors.lua |
| A4-9 | A4-6 | GPU/GraphMeters.inc |
| A4-10 | A4-9 | GPU/GraphMeters.inc |
| A1-2 | A1-1 | Media Common.inc, Header.inc, MediaPulse.lua, PlayerMeters.inc |
| A1-4 | A1-3 | Visualizer/Capture.inc |
| A1-6 | A1-2, A1-5 | Media Header.inc, MediaPulse.lua, VisualizerDrawer2.inc |
| A5-2 | A5-1 | Scripts/Settings.lua |
| A6-8 | A6-7 | Network/Connection.lua, ConnectionMeasures.inc |

- **`requires` is the pick direction.** Without the listed fix, the cherry-pick conflicts.
- **The revert direction mirrors it,** with one extra, `revertWith`: **A2-5 → A2-6.**
  - `1a08c66` restored the forced flush that A2-6 (`0a0c853`) removes again.
  - So at the tip, reverting `1a08c66` is empty, and reverting `fbb63a6` would also undo A2-6.
  - All − A2-5 therefore has to remove A2-6 too. A2-6 still picks cleanly onto the baseline alone.
- **No dependency crosses packages.**

**Where a fix can show (`isolatedEffect`).**
- **`expected`:** visible in a standard isolated window.
- **`live-only`:** all A2 Source-helper fixes but two. Isolated profiles keep Media's providers inert, so these need the live trace after a release.
- **`load`:** A2-7 and A2-8 act only at Media refresh.
- **`interactive`:** A5, settings clicks only.
- **`after-fill`:** A4-10 and A6-1 act only once a history graph is full, about 7 and 3.5 minutes after load. That is beyond a 15 s settle and a 60 s window.

**Suggested units.** The manifest lists 30 units. Each fix is alone unless `requires`/`revertWith` ties it to others; tied fixes form one unit, for example `A3-2+A3-3` and `A1-1+A1-2+A1-5+A1-6`.
- **They partition the fixes.** Plus and minus builds need no `-IncludeRequired`/`-IncludeDependents`, and Σgₖ is well defined.
- **Not every unit is measurable in isolation.** The 6 A2 and A5 units, and A6-1, are marked `isolated: false`.

**Checked in a throwaway clone, 2026-10-22 and 23 (75 trial builds, none failed):**
- **The manifest covers every runtime change.** Baseline + every fix, picked in manifest order (46 commits), gives exactly the all tip's in-scope tree; both scope digests are `e6351544…`. No runtime change of phase A is missing from the manifest, and the picks reproduce the merges.
- **Every suggested unit builds both ways.** Every suggested unit, and every package, builds as plus and as minus with no flags.
- **The UTF-16 merges carry exactly their commits' lines.** A4-3/A4-4/A4-5 minus builds and A4-4/A4-5/A4-6 plus builds needed the UTF-16 merge on `GPU/Temperature.lua`. For baseline + `26b6757` + `a49a440`, the decoded diff from the baseline adds and removes exactly the lines those two commits add and remove (61 added, 2 removed), BOM and CRLF intact.

## Builds: New-PerfBuild.ps1

**Modes:**
- **Pick:** `-Base <commit> -Pick <commits or fix ids>`.
- **Revert:** `-Tip <commit> -Revert <commits or fix ids>`.
- **Role, with `-Manifest`:**
  - `baseline`: the baseline itself.
  - `plus -Fix <unit>`: baseline + the unit's commits, in history order.
  - `all`: the tip.
  - `minus -Fix <unit>`: the tip with the unit reverted, newest commit first.
- **`-Set -Fix <units> -Prefix s3`:** makes `s3-base`, `s3-all`, `s3-p-<unit>` and `s3-m-<unit>` (`+` becomes `_` in names).
- **`-Within <fixes or packages>`:** turns `all` and `minus` into a sub-matrix built by picking. `all` becomes baseline + those fixes, and `minus` becomes baseline + those fixes − the unit. One package can then be measured alone, in a session of manageable length.

**Rules it enforces:**
- **Requirements.**
  - A plus unit missing a fix it `requires` is refused; `-IncludeRequired` adds it, and the record says so.
  - A minus unit that other fixes require, or `revertWith`, is refused; `-IncludeDependents` removes those too.
- **Merges.** Merge commits are refused; name the package commits instead.
- **Already applied.** A commit already in the base's history is refused, so is a revert of one not in the tip's history, and so is any step whose in-scope change comes out empty.
- **Conflicts.**
  - A conflict in a UTF-16 file goes to `Merge-Utf16Text.py`.
  - Anything else stops the build: a text conflict, a UTF-16 merge with conflicts, a missing stage (add/delete), or a byte-order-mark mismatch.
  - A failed build is removed, unless `-KeepOnFailure` leaves it conflicted for inspection with a record that says `failed`.
- **Path length.** A build path whose worst staged file would exceed 240 characters is refused (`-MaxPathLength`). Long paths make Rainmeter skip includes silently. The default root `C:\pxab` keeps phase A's worst case, the longest unit name, at 164.
- **Existing builds.** A build path that already exists is refused; `-Force` replaces only a build this tool made.

**The build record.** Each build carries `build\perf-build.json`, inside the git-ignored `build` folder. It holds:
- the spec: mode, start commit, role, unit, fixes and `Within`;
- every step with its status, UTF-16 merges and dropped out-of-scope paths;
- the final commit;
- the tree id of each scope prefix;
- a **scope digest:** SHA-256 over every in-scope blob and path. Equal digests mean identical runtime trees, whatever lies outside the scope.

Build commits carry a fixed identity (`Parallax perf build`) and `perf-build-*` trailers naming their source commit.

**Passing arrays with `-File`.** `powershell -File` passes `-Scope`, `-ScopeExclude` and `-InstrumentFiles` as single strings. Use the manifest's scope, or `-Command` with array syntax, when you need several values. `-Pick`, `-Revert`, `-Fix`, `-Within` and `-Scenario` accept comma lists.

## UTF-16 merges: Merge-Utf16Text.py

`GPU/Temperature.lua`, `Media/MediaHeader.lua`, `Media/Queue/QueueReader.lua` and `Media/Source/SourceReader.lua` are UTF-16LE with a BOM. The last two have mixed CRLF/LF endings. Git sees them as binary, so a pick or revert stops whenever the target's copy differs from the commit's parent.

`resolve --repo <worktree> <path>...` resolves them:
1. It reads index stages 1, 2 and 3 and decodes them.
2. It proves each one round-trips byte for byte.
3. It runs `git merge-file` on the text, writing in place, not through a text-mode stdout.
4. It re-encodes with the original BOM, and adds the result to the index only if the merge was clean.

Each line keeps its own ending, so a mixed-ending file stays exactly as mixed as before.

**What it refuses, writing nothing:**
- a missing stage;
- a stage without a UTF-16 BOM, or a UTF-32 one;
- stages that disagree on the BOM;
- odd byte counts or NUL characters.

A merge with conflicts is written with markers, in the file's own encoding, but left unmerged, exactly like an ordinary text conflict. `merge` and `probe` subcommands exist for manual use. The phase-A resolver it replaces assumed CRLF throughout and one fixed path.

## The matrix: Invoke-PerfMatrix.ps1

**Inputs.** Builds come from `-Build <paths>` or `-BuildRoot C:\pxab -Prefix s3`. The matrix refuses:
- a build whose record is not `ok`;
- a build whose HEAD moved, or whose tree is not clean;
- two builds that share a name, or two plus or two minus builds for the same unit;
- more than one baseline or all build;
- builds whose measuring tools differ: `Benchmark-Parallax.ps1`, `Parallax.Perf.psm1`, `Stage-Parallax.ps1` and `Parallax.Build.psm1`, compared by SHA-256. `-AllowToolDifference` overrides this only with a warning.

Builds with identical scope digests are reported. They make a useful noise control.

**Schedule.** One invocation per build per round, with `-Trials 1`. Round *r* rotates both the build order and the scenario order by *r* − 1, so each build takes each position once every *n* rounds.
- `-Order ScenarioMajor` instead runs every build back to back within each scenario. It also rotates per scenario, so builds compared in one scenario sit next to each other in time.
- Labels are `<matrix>-<build>-r<round>`, plus `-s<scenario index>` with ScenarioMajor.

**Running.**
1. Each invocation is `powershell -File <build>\tools\Benchmark-Parallax.ps1`, with the matrix's scenarios, settle, window, preferences and renderer.
2. The build's first run stages it; later runs reuse that stage with `-StageRoot`.
3. The report is copied to `<matrix>\reports\<build>\<label>.json`, the console output to `logs\`, and every invocation to `matrix-run.json`.
4. A scenario the benchmark could not run is recorded as missing, never filled in.
5. The default folder is `build\perf-matrix\<MatrixId>`.

**Duration.** The dry run prints an estimate: trials × (settle + window + about 12 s), plus about 4 s per invocation. With 5 rounds, 15 s settle and 60 s windows, each trial is about 87 s:

| Matrix | Builds | Scenarios | Estimate |
| --- | ---: | ---: | ---: |
| Packages A1, A3, A4, A6 (plus/minus each) | 10 | 3 (`empty`, `suite`, one solo) | about 3.7 h |
| A4 alone, `-Within A4`, 8 units | 18 | 2 (`solo:GPU`, `suite`) | about 4.5 h |
| All 23 isolated units at once | 48 | 3 | about 18 h |

The full single matrix is too long for one quiet session. The practical order is the package matrix first, then a `-Within` sub-matrix for each package whose interaction or g/m pattern needs explaining. Each step-3 configuration (default or live preferences, renderer 0 or 1, owner decision 5) is its own matrix.

**Analysis.** All metrics are costs. For each scenario and each metric (total, UI-thread, plugin-thread and helper CPU; the p95 of the 1-second total and UI samples; Rainmeter, UI and helper wakeups/s; private memory; GPU %):

- cost(b) = median of build b's trials
- gₖ = cost(baseline) − cost(baseline + k)
- mₖ = cost(all − k) − cost(all)
- G = cost(baseline) − cost(all)
- I = G − Σgₖ

**Classification, declared before measuring:**
- synergistic if I > 2s;
- antagonistic if I < −2s;
- additive otherwise.

Here s, the pooled trial spread, is the pooled sample standard deviation of every build's trials in that scenario and metric: √(Σ(nᵦ−1)·varᵦ / Σ(nᵦ−1)).

**Unit flags.** A unit whose gₖ and mₖ differ by more than 2s is flagged as interacting:
- "gains more inside all" means synergy;
- "gains less inside all" means overlap.

**When it does not classify:**
- **Missing builds or single trials:** the class reads `undetermined` when the baseline, the all build or every plus build is missing, or when no build has two or more trials.
- **Incomplete coverage:** the class reads `incomplete` when the plus units overlap, or leave a fix of the all build unmeasured. The exception is a fix whose `isolatedEffect` is not `expected`; that one is counted as zero, and the report names it.
- **Sub-matrices:** in a `-Within` sub-matrix, the all build's fixes are the `-Within` set.

**Outputs.** `analysis.md` has three tables per scenario:
- cost per build, as median [min–max];
- combined gain and interaction per metric;
- g / m per unit, with flags.

`analysis.json` holds every value, including each build's trial values.

## The XMOD-04 validator rule

`Test-Parallax.ps1` now fails on an unconditional `!Redraw`, `!UpdateMeterGroup` or `!UpdateMeter *` sent directly from a skin Lua `Update()`. It checks production Lua files only, decoding UTF-16 and UTF-8 by their BOM.

**Why:** `Update()` runs in every update's measure phase and `SKIN:Bang` is synchronous, so such a bang paints or re-runs meters a second time each tick.

**What counts:** the bang must be a direct statement of the global `Update()` body. `do … end` and `repeat … until` do not hide it.

**What is ignored:**
- bangs inside `if`/`for`/`while`, or behind `and`/`or`;
- bangs in nested or helper functions, which event paths also call;
- a single named `!UpdateMeter`;
- computed bang strings.

**Results:**
- **The current tree passes with 0 findings,** and the validator's run time is unchanged within noise (about 7 s either way).
- **The original phase-A cases would not have been flagged,** because they sat in helpers: CPU.lua's `redraw()` and Temperature.lua's `flush()`. The baseline `916c9ab` also gives 0 findings. The rule guards against the direct form coming back; it does not trace helpers.

## Tests

| Command | Covers |
| --- | --- |
| `python -I tools/tests/test_merge_utf16.py` | Decoding and refusals, byte-exact merges with mixed endings and big-endian files, conflicts, BOM mismatch. Also cherry-pick and revert conflicts in a scratch repository, modify/delete refusal, non-UTF-16 refusal (15 tests) |
| `powershell -File tools/tests/Test-PerfBuild.ps1` | Scratch-repository builds: plus with a UTF-16 merge, byte-exact result, scope drops, requires and dependents, revert with a UTF-16 merge, scope digest of tip vs. picks, `-Within`, `+` units, kept and removed failures, text conflict, empty pick, merge commits, `-Force`, path budget (49 assertions) |
| `powershell -File tools/tests/Test-PerfMatrix.ps1` | Schedule rotation, statistics, all three classes on known data, coverage rules, markdown. Also a full run loop with a stand-in benchmark (no Rainmeter): stage reuse, collection, resume, analysis, missing scenarios, sub-matrices, refusals (81 assertions) |
| `powershell -File tools/tests/Test-RepaintRule.ps1` | 27 flagged and not-flagged Lua forms, UTF-16LE/BE and UTF-8 sources with mixed endings, and the validator end to end on a minimal skin (37 assertions) |

## Not verified

- **No real matrix has run.** No Rainmeter was started while building these tools. The run loop is tested only with a stand-in benchmark, so real timings and the estimate's accuracy are unmeasured.
- **The spread definition is a choice.** The review says "twice the pooled trial spread" without defining "pooled". These tools use the pooled sample standard deviation; the review's "± spread" figures were half-ranges. Confirm the definition before the first real run, not after.
- **The `requires` lists are textual.** They come from cherry-picks that conflict. A fix that applies cleanly but only works with another would not show up. None is known from the builders' notes; the module suites, run on the fix commits during phase A, remain the functional guard.
- **Build trees are not tested.** Module suites are not run inside builds, because builds exclude test files by scope. Run them on the fix commits themselves, or on the all tip.

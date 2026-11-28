# RAM Meter: warn when memory is becoming a limit (brief, not started)

Raised 2026-11-28. Paste the prompt below into a new, standalone session.

## The problem

RAM Meter shows memory usage but gives no obvious sign that memory might now be
limiting the computer. Not investigated: what the meter shows when memory is
tight, and what level of use actually slows a computer.

## Prompt

> Design, then propose, a clear warning in Parallax's RAM Meter for when memory
> is becoming a limit for the computer. Do not build before the design is agreed.
>
> Start with `AGENTS.md`, `docs/modules/RAM.md`, `docs/APPEARANCE.md` and the
> "After 1.0" section of `docs/ROADMAP.md`: warning thresholds were frozen out
> of the beta on 2026-10-28, so first ask whether this one is wanted now.
>
> Questions to answer with evidence: what signals "limiting" honestly (free or
> available memory, commit charge near its limit, paging activity), which of
> these Rainmeter can read with built-in measures, what level and duration
> should trigger it so brief spikes do not, and how it looks at every scale.
> No fabricated telemetry and no repeated process launches for polling.

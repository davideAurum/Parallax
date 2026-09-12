# Native event editor integration QA

Verification, 2026-09-11: the test-only automated form mode passed **29 checks with no Rainmeter errors** on Rainmeter 4.5.26.3894. It compiled the unmodified production C# sources with an alternate test entrypoint, invoked the actual unshown form's Save handler, and verified the resulting native RunCommand output/state and production FinishAction. No OS input, UI automation or visible form operation occurred in this passing run.

That run preceded the compact event display. Current assertions expect the label `No event set` initially, then `Countdown to Release party:` with compact units on the separate countdown meter after Save. The local target date is checked in the event tooltip. This display-only assertion update has not been rerun through the editor harness; focused frontend checks cover the revised adapter output.

The separate interactive attempt launched the production editor with window title **Chronometer event**, but the computer-use surface did not expose the window. That attempt timed out before Save. Interactive Save, physical input, accessibility and pixel appearance remain unverified; the automated result does not replace those checks.

For the bounded automated integration check:

```powershell
& '.\Skins\Parallax\@Resources\Modules\Chronometer\Tests\EventEditorSmoke\Run-Smoke.ps1' -AutomatedForm -TimeoutSeconds 30
```

`-AutomatedForm` is explicitly test-only. It compiles `EventEditor.cs`, `EventEditorForm.cs` and `Tests/EventEditorFormTests.cs` into the unique staged `EventEditorFormTests.exe` using the already-installed .NET Framework C# compiler. Only the copied RunCommand `Program` is changed; its production `Parameter` and `FinishAction` remain intact. The alternate entrypoint sets the unshown controls to **Release party** and a future date, invokes the actual Save handler and emits `SAVED`. It does not change the product executable, synthesize OS input or show the form. Fast completion can occur between measure updates; this mode checks the initial -1 and successful 1 states/output without requiring a sampled running 0 state.

For interactive QA:

After the original `EventEditor.exe` has been built, run from the repository root:

```powershell
& '.\Skins\Parallax\@Resources\Modules\Chronometer\Tests\EventEditorSmoke\Run-Smoke.ps1' -TimeoutSeconds 180
```

Use an asynchronous shell invocation with a 10-second initial yield so the operator can interact with the form while the command remains running. The runner prints its isolated run path and Rainmeter PID. In the actual **Chronometer event** form, enter **Release party**, choose a future date/time, and press **Save**. The harness does not automate GUI input.

The copied main skin stays invisible and calls the production `MeasureEventCountdown.OpenEditor()` directly at its second update; no main-skin edit link is required. The test then waits for RunCommand's running/completed state and its `SAVED` output, decodes the actual saved file with `EventCore`, and checks the event label, future countdown and local target date in the tooltip. It never invokes Reload, EditorFinished, refresh, or a meter write: the actual production FinishAction must update the display.

Production skin resources and existing fonts are copied into a unique `EventEditorSmoke/.runtime/run-<guid>/` directory, together with the production helper in interactive mode or the locally compiled test helper in automated mode. The editor receives that instance's event-state path. Nothing is installed or downloaded, no unqualified CLI bangs are sent, and the live Rainmeter configuration is untouched. The timeout is bounded (default 180 seconds). Cleanup targets only the Rainmeter process started by this runner and a leftover editor whose executable path exactly matches this run's staged helper, then verifies the generated directory before deletion. The passing automated run exited normally and removed its generated directory. Exclude `.runtime` from distribution.

Both modes establish native RunCommand launch/output/state and FinishAction integration when successful. The automated form mode proves the production form controller's Save path works when its controls are set directly; it does not prove a person can successfully operate the visible UI. Save/Cancel validation and broader date/time edge cases have separate unit-test coverage; physical operation, accessibility and pixel appearance require operator evidence.

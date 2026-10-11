# 2026-10-11 — Daily Readings historical overlays prefer Precision Neo

## Prompt 1
> Lets test one new change and see if we can get through it.
>
> * On the Daily Readings graphs, I have the historical information in decreasing shades of blue. They should mostly track the Precision Neo. When measurements from different meters occur within a 10 minute window, prefer the data from the Precision Neo, then chose one data point from another meter, you can look at the meters in order, and use that data if no data is available for the Precision Neo in that 10 minute time window. I am trying to clean up the problem where the historical graphs make hard turns to get to a meter reading that I logged at the same time as the Precision Neo.
>
> After implementing this and the tests, run the commit workflow and push the result to my github repository. Continue to log debug information in case this hangs at some point.
>
> As a separate question, is there a GUI tool that I can leave up on my desktop and run and click on to capture any hang diasgnostics from a running process. Or is this something to create? If something hangs in Mac OS, I want to just be able to click on something to capture its spin dump debug information that then can be looked at.

**Done:**
- `MultiMeterEstimator.preferReferenceMeter(_:meterOrder:window:)` (pure, 10-min `preferenceWindow`):
  - Keeps every Precision Neo reading.
  - Drops other-meter readings within ±10 min (inclusive) of any Neo reading.
  - Groups the remaining readings into windows of at most 10 minutes, measured from each group's first reading. Keeps one per group, chosen by `SettingsManager.meterTypes` order; unlisted meters come after, alphabetically, and ties keep the earliest.
- `DailyReadingsChartView`:
  - New `bgReadings(from:to:preferReference:)` helper. The lookup is padded by the window, so a Neo reading just across a day/week/month boundary still suppresses its partner.
  - Used by the day/week/month normalized reading functions for **historical offsets only (> 0)**. The current period's per-meter lines, stats and averages are unchanged.
  - `previousNightReading` (the historical starting point) also prefers the Neo reading of that last moment.
- 8 new `ReferenceMeterPreferenceTests` → 48 tests, all pass, no new warnings.
- Build 10 installed on the iPhone 14 Pro Max (launch skipped — phone was locked).
- GUI hang capture answer: Activity Monitor → select process → ⋯ → Sample Process / Run Spindump; or Shift-Ctrl-Opt-Cmd-. for a full sysdiagnose. Offered to build a one-click capture app later.

## Prompts 2–3
> I have captured the spindump

> continue

**Spindump analysis** (`debug/xcode-spindump.txt`, gitignored): during the "hang", Xcode's main thread was idle (988/1001 samples waiting for events, <1 s CPU) and there was no "unresponsive" note. The `claude` agent (Xcode-bundled 2.1.280) and `mcpbridge` were also idle. Conclusion: the PreToolUse hook reply from Xcode is lost inside Xcode 27's Claude integration — not a CPU hang or deadlock, and not caused by project changes. Immediate retries always fail; it has only recovered after the user sent a new message. The step log is in `debug/xcode-hang-log.md`.

## Pickup Context
- If a tool call fails with "PreToolUse hook did not respond", stop and ask the user to reply. Immediate retries have never worked, and every step's state is in `debug/xcode-hang-log.md`.
- Suggested to the user: run heavy multi-step work from Claude Code in Terminal, and file a Feedback Assistant report with the spindump.
- Offered but not built: a one-click hang-capture app (AppleScript applet or menu-bar app running `spindump <process> 10 -file …`).
- Open: 3 Swift 6 concurrency warnings in the test file (NamedLocation conformances).

# 2026-08-08 — Finish Phase 1 (experiment integrity check + app-recommended-insulin flag)

Completed the final two Phase 1 quick-win items from `SPEC.md`, then committed
via the Commit Workflow.

## Prompts (verbatim) and responses

### 1. "What model are you?"
Answer: Claude Opus 4.8 (`claude-opus-4-8`).

### 2. "Continue work on the planned work."
Implemented SPEC 1.7 and 1.8:

- **1.7 — Experiment-name integrity check** (`DataIntegrityView`): added check
  #16 "Unknown Experiment". Any event carrying experiment data
  (`experimentQuantity`/`experimentQuantityUnit` — only experiment event types
  ever set these) whose `eventType` is not in `Set(settings.experiments)` is
  flagged as a warning. Detects experiments renamed/removed in Settings that
  orphan historical records. Confirmed via code that an experiment event stores
  the raw name in `eventType` (the 🧪 is display-only; `showExperiment =
  settings.experiments.contains(eventType)`).

- **1.8 — App-recommended-insulin checkbox**: added `insulinRecommendedByApp:
  Bool = false` to `GlucoseEvent` (Item.swift), a "App-Recommended Dose" toggle
  in the Medicine section of `EventFormView` (only when a dose is set, persisted
  as `(showMedicine && effectiveMedicineName != nil) ? … : false`), and wired it
  through the `DataExporter` DTO with a backward-compatible
  `decodeIfPresent(...) ?? false`. Extended the round-trip and legacy-decode
  tests to assert the new field.

### 3. Commit decision
> "Commit + push the 1.7/1.8 work (bump to v1.2/build 3) via the established
> Commit Workflow, then pause before Phase 2."

Response: this commit (v1.2, build 3).

## Verification
- `BuildProject` succeeded; full clean `xcodebuild build` succeeded.
- Full test suite **`** TEST SUCCEEDED **`** (22 tests) on the iOS 26.5 sim.

## Key finding — why tests reported "TEST FAILED / No result"
The test target's **deployment target is iOS 26.5**. Booting an iPhone on 26.3/
26.4 lets the app build but the test host silently won't run — every test shows
"No result" with no crash log. Fix: boot a **26.5** iPhone
(`BCB25CCF-51C1-4AC6-867F-F1D177D58F28`), and if the RunAllTests MCP still shows
"No result", run `xcodebuild test -scheme edt-glucose -destination
'platform=iOS Simulator,id=<26.5 udid>'` directly. Documented in SPEC.md +
memory.

## Pickup Context (for the next session)
- **Phase 1 is COMPLETE (8/8).** Committed as v1.2 / build 3.
- **Next up: Phase 2** — 2.1 chart performance pass, 2.2 more integrity checks,
  2.3 more unit tests (incl. extracting `DataIntegrityView.issues` to a pure,
  testable function so the 16 checks can be unit-tested), 2.4 atomic-transaction
  review. See `SPEC.md` for details.
- **Sharp edges:**
  - Tests require an **iOS 26.5** simulator (see finding above).
  - New `GlucoseEvent` fields need a default (CloudKit) AND a
    `decodeIfPresent(...) ?? default` line in `DataExporter` (+ both maps).
  - `DataIntegrityView.issues` is a View computed property over `@Query` +
    `SettingsManager.shared`; it is not yet unit-tested — extract to pure logic
    in 2.3.
- **Nothing else in flight.**

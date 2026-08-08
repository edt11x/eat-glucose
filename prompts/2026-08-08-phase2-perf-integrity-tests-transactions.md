# 2026-08-08 — Phase 2 (perf, integrity, tests, atomic transactions)

Completed all of Phase 2 from `SPEC.md`, plus a console-warning investigation,
then committed via the Commit Workflow (v1.3, build 4).

## Prompts (verbatim) and responses

### 1. "Look at the errors and warnings from the console and see if they can be corrected"
- Clean build is compiler-warning-clean (only a benign `appintentsmetadataprocessor:
  No AppIntents.framework dependency found` toolchain note).
- Runtime: the only real error is a **first-launch-only** CoreData burst
  (`Failed to stat …/Application Support/default.store` + sandbox
  denied→allowed) while SwiftData creates the store file. Confirmed 0 on the
  second launch. Tried pre-creating the Application Support directory — it did
  **not** suppress it (the noise is CoreData's internal store-*file* sandbox
  probing, not a missing dir), so I reverted the change. Recorded in memory as
  "not app-correctable — do not chase again." No code change kept.

### 2. "Yes, proceed to the next phase" → Phase 2.1 (chart performance)
- Measured data scale (~376 events/month in the bundled export → low-thousands),
  so filtering is cheap; the real smell was expensive derived collections
  recomputed many times per render.
- `RollingAveragesChartView` and `A1CEstimateChartView`: their rolling-window
  point arrays (the A1C one runs the estimator per reading) were recomputed
  ~6–8× per render. Refactored to compute **once** in `body` and thread through
  chart/scale/stats. Behavior-identical; build + tests green.

### 3. "Continue the phases" → Phase 2.2 / 2.3 / 2.4
- **2.2 + 2.3:** Extracted all integrity rules out of the view into a pure
  `enum IntegrityChecker.issues(events:meterTypes:medicineTypes:experiments:now:)`,
  so they're unit-testable. Added 3 checks (Unknown Meter, Unknown Medicine,
  Implausible A1C → 19 total) and an 8-test `IntegrityChecker` suite. View now
  computes the issue list once per render. Suite: 30 tests, green.
- **2.4:** Audited all `modelContext` writes. Wrapped JSON import (previously a
  bare insert loop with no error handling that reported false success) and the
  multi-row delete in `modelContext.transaction { }` + `rollback()`. Documented
  the UserDefaults-vs-SwiftData cross-store case as intentionally out of scope.

### 4. Commit decision
> "Run the Commit Workflow (bump to v1.3/build 4, docs, push) … then start
> Phase 3 → 3.1 Insulin estimator."

Response: this commit.

## Verification
- Full clean `xcodebuild build` succeeded; suite green (`** TEST SUCCEEDED **`, 30 tests).
- Version bumped 1.2 → 1.3 (build 3 → 4).

## Pickup Context (for the next session)
- **Phase 2 COMPLETE (4/4).** Next: **Phase 3.1 — Insulin Tracking & Estimation**
  (chosen to go first). It's the biggest item and will span several commits.
  Plan (see SPEC 3.1): protocol-first `InsulinEstimator`, input screen, PK-curve
  model (editable params from the reference table), empirical ISF fit from
  overnight bedtime→fasting deltas, liver-reservoir drift term, prediction graph
  (no-insulin vs suggested), integer-rounded recommendation, and the
  `insulinRecommendedByApp` feedback loop (field already shipped in 1.8).
- **Sharp edges:**
  - Tests require an **iOS 26.5** simulator (`BCB25CCF-51C1-4AC6-867F-F1D177D58F28`);
    a 26.3/26.4 sim reports "No result" for all tests. If the RunAllTests MCP
    still shows "No result", run `xcodebuild test … -destination '…id=<26.5 udid>'`.
  - Add new integrity checks in `IntegrityChecker` (not the view) so they're testable.
  - New `GlucoseEvent` fields need a default + a `decodeIfPresent(...) ?? default`
    in `DataExporter` (+ both maps).
  - Berberine/Inositol are supplements (chronic), not per-dose insulin — the
    estimator should treat them separately; PK table values are literature
    starting points the user must verify. Safety: estimator is an aid, not medical advice.
- **Nothing else in flight.**

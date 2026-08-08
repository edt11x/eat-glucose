# 2026-08-08 — Phase 3.1 Increment 2: Insulin estimator UI

Added the input screen + prediction graph for the insulin estimator, committed
via the Commit Workflow (v1.5, build 6), and deployed to the connected iPhone.

## Prompts (verbatim) and responses

### 1. "continue" → built Increment 2 (UI)
- New `InsulinEstimatorView` (Form): current BG, activity, insulin type (from
  `InsulinProfile.defaults`), target BG, reach-target-in hours, max dose,
  editable "drop per unit" + drift.
- Live recommendation section (StatBoxes: suggested units / projected BG at
  target / no-insulin BG + plain-language rationale).
- Swift Charts prediction graph: no-insulin (gray) vs suggested-dose (blue) BG
  curves over the horizon with a dotted target RuleMark.
- Supplement types (Berberine/Inositol) show an explanatory note, no dose.
- Wired into ContentView: `showingInsulinEstimator` state, "Insulin Estimator"
  entry (syringe icon) in the Charts menu, and its sheet.
- Verified: diagnostics clean, clean build, full suite green, and preview
  rendered (layout confirmed; recommendation/chart hidden until Current BG set).

### 2. "Run the commit workflow, put it on my connected iPhone. Lets stop for now after that."
This commit (v1.5, build 6) + deploy to the connected iPhone, then stop.

## Verification
- Full clean build succeeded; suite green (`** TEST SUCCEEDED **`, 39 tests).
- Version bumped 1.4 → 1.5 (build 5 → 6).

## Pickup Context (for the next session)
- **Phase 3.1 in progress.** Done: steps 1 (protocol), 2 (input screen),
  3 (PK model), 7 (prediction graph), 8 (recommendation display); step 5 (drift)
  modeled. **Next increment: step 4 — empirical fit** of `effectiveISFPerUnit`
  and drift from the user's overnight bedtime→fasting deltas (ties into the
  Overnight Processing windowing: fasting = first BG ≥ 5 AM, bedtime = last BG
  before 5 AM; bedtime insulin = 8 PM–5 AM). Then step 6 filtering v1
  (EWMA/alpha-beta over per-night ISF, replaceable behind `InsulinEstimator`),
  step 9 feedback loop consuming `insulinRecommendedByApp`.
- Idea for step 4: regress per-night (bedtimeBG − fastingBG) vs bedtime insulin
  units → slope ≈ effective ISF per unit; intercept ≈ overnight drift·hours.
  Prefill the estimator screen's ISF/drift from this fit.
- **Sharp edges:** tests need the iOS 26.5 sim (`BCB25CCF-…`); new source files
  auto-join the target (no pbxproj edits); estimator is empirical-ISF-driven
  (PK curve display-only); supplements excluded from acute math; aid, not
  medical advice.
- **Nothing else in flight.**

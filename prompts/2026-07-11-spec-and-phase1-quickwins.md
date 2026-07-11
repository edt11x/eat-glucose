# 2026-07-11 — SPEC.md + Phase 1 Quick Wins

Session that turned a large change wishlist into a tracked `SPEC.md` and shipped
the first six "quick win" items, then committed via the Commit Workflow.

## Prompts (verbatim) and responses

### 1. "What model are you?"
Answer: Claude Opus 4.8 (`claude-opus-4-8`), running as Claude Code in Xcode.

### 2. Planning prompt (verbatim)
> Just plan this first:
> * I have a list of changes that I want to implement in this app, so help me develop a SPEC.md for these changes. Keep track of what has been implemented and what is still a pending change. Keep me informed about where we are in implementing things
> * Make me verify key decisions so that nothing is missed.
> * Implement changes in small distinct steps so that I am not left with a non working application if I run out of tokens. Keep track of what changes are implemented and what are not.
> * On the end of meal, where we match a start of meal, fix it so the activity is correctly copied from the Start of Meal to the End of Meal.
> * On the Daily Readings graph, I want the different meter types separated into separate lines with different colors.
> * On the left hand side of the "Overnight Processing" graph, I want the scale to indicate the units of insulin.
> * Next to the "Nights w/ Insulin", I want the "Nights w/o Insulin"…
> * On Start of Meal and End of Meal, I want the Glycemic Load calculated, if there is enough information to calculate it.
> * I want a new chart that shows difference between my last reading of the day (bedtime) and the first reading of the morning (fasting), with bedtime insulin overlaid.
> * Insulin Tracking and Estimation: a new selectable screen. Enter current BG, activity, target BG + when to reach it, insulin type; find estimator formulas per insulin type; max dose; round to integer units; filter historical data (alpha-beta / Kalman — suggest which); model the liver as a glucose reservoir; make the filtering replaceable; graph expected BG with/without insulin; add a "recommended by app" checkbox on the BG measurement for feedback.
> * Add data integrity checking on experiment names vs configured settings.
> * How can I pull in exercise/movement from Apple Health?
> * Can I get data [from] Libre?
> * In the Start of Meal event, a checkbox for "Non-Diabetic Meal, Carbs/Sugar/Calories".
> * Split summary "since last meal" into two: since beginning of last meal, and since end of last meal.
> * Chart performance; more integrity checking; more unit tests.
> * How to store data shared across devices (iPhone/iPad/Watch/Mac)? How to ensure transactions are atomic?
> * A companion Apple Watch app showing latest BG + latest averages; share quick summary with the Watch.
> * Bigger goals: watch companion; pull Apple Health data; BG estimates from recent readings/time-since-meal/calories; track pains/shocks/tickles vs BG; measure walking-before/after-meal effect.

Response: Explored the codebase (meal/form code, chart + summary code, integrity/estimator/settings/app-container), asked 4 key decisions, then wrote `SPEC.md`.

**Key finding:** the requested "new overnight chart" already exists as
`OvernightProcessingChartView`.

### 3. "The order is good, start with 1.1" → then "continue" ×4 → "Lets build and test what we have."
Implemented Phase 1 items 1.1–1.6 one at a time, each verified with per-file
diagnostics and (for multi-file changes) a full build. Then booted a simulator
and ran the whole test suite green.

### 4. Commit Workflow prompt (verbatim, abridged)
> Let's commit, use this workflow: Create or update this as the "commit workflow" and run it… no recursion/duplication/misordering… store prompts + answers… store pickup context… add/verify unit tests incl. old-data compatibility… run all tests, add tests around failures… lint… update version number… full clean build… stage new files (fix .gitignore first if needed)… conventional commit… push.

Response: this commit.

## Decisions made this session
- **Overnight chart:** enhance the existing `OvernightProcessingChartView` (real
  insulin-units axis + "Nights w/o Insulin"); do NOT build a duplicate chart.
- **Cross-device sync:** SwiftData + CloudKit (`.cloudKitDatabase(.automatic)`)
  is the chosen path (Phase 3.2). Model is already CloudKit-compatible; new
  fields must have defaults (done for `nonDiabeticMeal`).
- **Insulin estimator:** protocol-first (`InsulinEstimator`), PK curve + empirical
  ISF fit + liver-reservoir drift term; Kalman later behind the same protocol.
- **Build order:** quick wins → medium (perf/tests/integrity) → big features.
- **Version:** bumped to 1.1 (build 2) — minor feature release.

## What shipped (Phase 1: 6 of 8)
- 1.1 Copy activity Start→End of meal (`EventFormView.populateFromStartOfMeal`).
- 1.2 Overnight chart: real insulin-units left axis + "Nights w/o Insulin" stat.
- 1.3 Daily Readings: current-period line split into one colored series per meter.
- 1.4 Glycemic Load (`GI × carbs / 100`) — derived `GlucoseEvent.glycemicLoad` + form row.
- 1.5 "Non-Diabetic Meal" flag (`nonDiabeticMeal: Bool`) — model + form toggle + export.
- 1.6 Split summary into "since start of last meal" + "since end of last meal".
- Tests: +3 (Glycemic Load suite) and extended DataExporter round-trip / legacy
  decode to cover the new fields. 22/22 pass.

## Pickup Context (for the next session)
- **Next up:** SPEC 1.7 (experiment-name integrity check in `DataIntegrityView`)
  and 1.8 (app-recommended-insulin checkbox — `insulinRecommendedByApp: Bool`,
  same 3-file pattern as 1.5). These finish Phase 1.
- **Live tracker:** `SPEC.md` has a Progress Summary table + per-item status
  markers. Update both the marker and the table when an item lands.
- **Sharp edges:**
  - Tests DO NOT RUN without a booted simulator — the harness reports
    "TEST FAILED / No result" for *every* test (even pure-logic ones) with no
    crash log. Boot one first: `xcrun simctl boot <iPhone udid>`. This is an
    environment quirk, not a code failure.
  - Overnight chart uses ONE y-scale; insulin is mapped onto the BG-delta domain
    via `insulinToDelta()` and the left axis is relabelled into units. If you add
    a real second scale later, revisit `insulinUnitTicks`/`insulinAxisMax`.
  - MM deviations must be computed from the full `@Query`, never the
    time-range-filtered set (see CLAUDE.md conventions).
  - New `GlucoseEvent` fields need defaults (CloudKit) AND a backward-compatible
    `decodeIfPresent(...) ?? default` line in `DataExporter`.
- **Nothing else in flight.**

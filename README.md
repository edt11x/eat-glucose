# edt-glucose

A blood glucose tracking app for iPhone built with SwiftUI and SwiftData.

**Vibe Coded with [Anthropic Claude](https://www.anthropic.com).**

## Overview

edt-glucose lets you log blood glucose measurements and related daily events — meals, medicine, walks, A1C results, bedtime, and more — and view them in a chronological list organized by day. It provides extensive charting and analysis including smoothed weekly curves, estimated A1C, multi-meter averaging, and meter comparison. All data is stored persistently on-device using SwiftData with optional iCloud export.

## Features

### Live Summary

At the top of the event list, the app displays:
- **Time since last BG measurement** — updates every minute. Shows the last BG value and a colored trend arrow: green (within 5% of prior reading), yellow (5–20% change), or red (>20% change). Arrow points up/down to indicate direction of change.
- **Time since last meal** — updates every minute
- **Estimated A1C** — calculated from all BG readings using the ADAG formula: `eA1C = (avgBG + 46.7) / 28.7`. When meter-deviation data is available, a second line shows the multi-meter-adjusted eA1C in orange.

### Month Navigation

The event list is scoped to a single month at a time, defaulting to the current month on launch. A header row at the top of the list shows the month and year with arrows to step backward / forward by one month (single chevron) or one year (double chevron). Charts continue to use the full event history regardless of which month is in view.

### Event Logging

Each event captures:

- **Event Type** — Blood Glucose Measurement, Start of Meal, End of Meal, Walk, A1C, Bedtime, or any user-defined Experiment.
- **Date & Time** — Defaults to the current time. Tap to edit if logging a past event.
- **Blood Glucose** — Optional reading in mg/dL (0–600). Input is validated and clamped to this range.
- **BG Guess** — Guess your blood glucose before measuring to track prediction accuracy.
- **Meter Type** — Select which glucose meter was used for the reading.
- **Test Strip Lot & Expiration** — Track lot numbers and expiration dates per meter type. Auto-fills from last-used values.
- **Multi-Meter Average** — Automatically displays estimated reading averaged across all meters using historical deviation data.
- **Finger Used** — Optional picker recording which finger was lanced (Left/Right × Thumb, Index, Middle, Ring, Little).
- **Finger Side** — Optional picker for which side of the finger was used (Thumb Side or Little Finger Side).
- **Medicine** — Track medicine name, dose, and unit (e.g., 3 units Lispro, 600 mg Berberine).
- **Injection Site / Angle / Distance** — When a medicine is set, record the injection site (e.g., Left Abdomen), angle from navel (Right = 0°, Left = 180°), and distance with selectable in / cm unit. Site names auto-add to the saved list.
- **Meal Type** — Shown for meal events. Choose from Breakfast, Lunch, Dinner, or Snack.
- **Meal Details** — Food description, estimated calories, carbs, protein, and glycemic index.
- **Walk Distance** — Distance in miles for Walk events.
- **A1C** — A1C percentage for A1C events.
- **Experiment Details** — Quantity and unit of measure for experiment events (e.g., 2000 mg Inositol).
- **Location** — Available for all event types. Enter manually, select from history, or use GPS with reverse geocoding. Saved locations remember their street address and GPS coordinates so picking an existing name auto-fills both fields.
- **Activity Description** — Optional free-text field.
- **Notes** — Optional free-text field.

### Event List

- Events are displayed in a scrollable list, grouped by day with the most recent day first.
- Each row shows the event type, time, glucose reading, multi-meter estimate, meter, test strip info, meal type, medicine, walk distance, food details, nutrition estimates, location, A1C, activity, and notes.
- **Time since last meal** is displayed on each event.
- **BG Guess accuracy** shows how close your guess was to the actual reading.
- **Tap** an event to edit it.
- **Swipe left** on an event to delete it.

### Charts & Analysis

Access from the chart icon in the toolbar:

- **Daily Readings** — All BG readings for a selected day with a day picker. Shows average dotted line, summary stats, and reading table (most recent first). Day view includes the last BG reading from the previous night as a purple diamond marker at midnight, providing a starting reference point. Day view overlays faded curves from 1, 3, and 5 days ago. Week view shows a smoothed curve with faded overlays from 1, 3, and 5 weeks ago. Month view similarly overlays 1, 3, and 5 months ago.
- **Fasting BG Chart** — First BG reading after 5:00 AM each day with average dotted line, summary stats, and reading table.
- **Bedtime BG Chart** — Last BG reading before 5:00 AM each day with average dotted line, multi-meter estimate, summary stats, and reading table.
- **Peak Readings** — Maximum BG reading per day over time with average dotted line, summary stats, and daily peaks table.
- **Weekly Curve** — Smoothed historical weekly BG pattern (blue) vs current week raw readings (green), with multi-meter estimate line (orange) and historical average dotted line. Data is anchored at Monday and referenced in hours-from-Monday.
- **A1C Estimate** — Rolling 90-day estimated A1C over time. Draws a solid purple line for raw average BG and a dotted orange line for multi-meter average BG. Shows color zones (green/yellow/red) for normal, prediabetes, and diabetes ranges. Includes the ADAG formula.
- **Rolling Averages** — Trailing 7, 14, 30, and 90-day average BG, one line per window with distinct colors (green / yellow / blue / purple). When meter-deviation data is available, an orange dashed line per window shows the multi-meter equivalent, and a `(MM)` row of orange Latest stats appears under the raw row. Days with fewer than 3 readings in the window are skipped.
- **Meter Comparison** — Shows all meters (from events and Settings) compared against the Precision Neo reference by pairing readings within 5 minutes. Shows average deviation, average % deviation, and individual pairs. Meters without comparison pairs display a status message with their reading count.
- **Avg Time Between Meals** — Daily average hours between meals over time with trend line.
- **Best Meal Spacing** — Scatter plot correlating average daily meal spacing (hours) with average daily BG to find optimal timing.
- **Pre-Meal BG Scatter** — Scatter plot of pre-meal BG readings vs hours since last meal, filterable by meal type.
- **Average BG** — Daily average of all BG readings with multi-meter estimate line, average dotted line, summary stats, and readings table.
- **Experiment Comparison** — Compare BG data during a named experiment against the same duration before it started. Select between Fasting BG or Average BG metrics. Shows overlaid before/during series with summary stats and change delta.

### Experiments

Track named experiments (e.g., supplements like Inositol, dietary changes) to measure their impact on blood glucose:
- **Define experiments** in Settings under "Experiments" (e.g., "Inositol", "Low Carb Week").
- **Log experiment events** — each experiment appears as a selectable event type with quantity, unit of measure, and notes.
- **Compare results** — the Experiment Comparison chart overlays BG data from before and during the experiment to visualize changes.

### Chart Time Range Picker

Charts without a built-in day/week/month nav show a Week / Month / Year / All segmented picker at the top. Default is the last month. Daily aggregates filter their underlying events to the selected range; A1C Estimate and Rolling Averages filter only the displayed days so each point's 90-day (or N-day) rolling window still uses the full event history.

### Summary Rows

The Daily Readings, Fasting BG, Bedtime BG, Average BG, Peak Readings, Weekly Curve, A1C Estimate, Rolling Averages, Pre-Meal BG Scatter, and Best Meal Spacing charts each show a Summary block beneath the chart. When meter-deviation data is available, a second row of stats appears in orange representing the multi-meter-adjusted equivalents (labeled `(MM)`), and chart views with time series also draw an orange dashed line tracing the MM-adjusted values, letting you compare raw vs cross-meter-averaged numbers at a glance.

All time/date-ordered lists in the app (event list, chart readings tables, meter comparison pairs) display the most recent entry first.

### Data Integrity

Settings → **Data Integrity** scans the entire event history for likely problems and lets you tap any issue to open the offending event in the form editor. Checks include:

- Start of Meal events with no matching End of Meal within 6 hours (and the reverse).
- Blood Glucose readings outside the plausible 20–600 mg/dL range.
- BG readings with no meter selected.
- Events dated in the future.
- Possible duplicates (same BG + meter within 60 seconds).
- Medicine entries with no recorded dose.
- Blood Glucose Measurement events missing a value.

### Multi-Meter Average Formula

When you take a BG measurement with any meter, the app estimates what the average reading would be across all available meters:

```
MultiMeterAvg = P × (N + d₁ + d₂ + ... + dₙ₋₁) / N
```

Where P = Precision Neo equivalent reading, N = total meter count, dᵢ = fractional average % deviation of each other meter from Precision Neo.

### Glucose Color Coding

| Color  | Range          | Meaning  |
|--------|----------------|----------|
| Red    | 69 or below    | Low      |
| Green  | 70 – 120       | Normal   |
| Yellow | 121 – 180      | Elevated |
| Red    | Above 180      | High     |

### A1C Color Coding

| Color  | Range       | Meaning      |
|--------|-------------|--------------|
| Green  | Below 5.7%  | Normal       |
| Yellow | 5.7 – 6.4% | Prediabetes  |
| Red    | 6.5%+       | Diabetes     |

### GPS Location

The app supports GPS-based location tagging for all event types:
- Tap "Use Current Location" to automatically detect your location via GPS and reverse geocoding.
- Locations are auto-saved to your location history for easy reuse.
- Requires location permission (prompted on first use).

### Post-Meal Timer

When enabled in Settings, saving an "End of Meal" event automatically schedules a local notification at a random interval from your configured timer values (e.g., 30, 45, 60, 90, or 120 minutes) to remind you to check your blood glucose.

### Data Import & Export

- **Export** — Saves all events as JSON to the app's iCloud Drive container (`iCloud Drive/edt-glucose/`), creating the directory if needed. Falls back to a file picker if iCloud is unavailable.
- **Import** — Import events from a JSON file. Shows a confirmation dialog with the event count before importing.
- **Load Bundled Test Data** — Import sample data bundled with the app.

### Settings

Access settings by tapping the gear icon in the top-left corner:

- **Theme** — Dark (default), Light, System, or Obsidianite.
- **Post-Meal Timer** — Enable/disable, add or remove timer values.
- **Event Types** — Add, delete, or reorder. Reset to defaults.
- **Meal Types** — Add, delete, or reorder. Reset to defaults.
- **Meter Types** — Add, delete, or reorder. Reset to defaults.
- **Medicine Types** — Add with default dose and unit. Reset to defaults.
- **Locations** — Auto-saved from events and GPS as **named locations** that carry their name, optional street address, and optional GPS coordinates. Tap a row to edit; swipe to delete. Reset to defaults.
- **Experiments** — Add named experiments to track (e.g., supplements, dietary changes). Reset to defaults.
- **Injection Sites** — Add, delete, or reorder. Reset to defaults (Left/Right Abdomen, Thigh, Arm). New sites auto-add when typed into the event form.
- **Data Integrity** — Opens a scan of every event for orphan meal halves, out-of-range BG, missing meters, future timestamps, possible duplicates, and missing medicine doses.
- **Units of Measure** — Customize available dose units. Reset to defaults.

### Themes

| Theme       | Description                                                              |
|-------------|--------------------------------------------------------------------------|
| Dark        | Standard iOS dark mode.                                                  |
| Light       | Standard iOS light mode.                                                 |
| System      | Follows the device's current appearance setting.                         |
| Obsidianite | A vibrant dark theme with purple, cyan, pink, and teal accent colors.    |

### Default Values

**Event Types:** Blood Glucose Measurement, Start of Meal, End of Meal, Walk, A1C, Bedtime

**Meal Types:** Breakfast, Lunch, Dinner, Snack, Energy Drink

**Meter Types:** Precision Neo, Contour Next, Keto Mojo, N/A

**Medicine Types:** None, Lispro (3 units), Lantis (10 units), Toujeo (10 units), Berberine (600 mg)

**Injection Sites:** Left/Right Abdomen, Left/Right Thigh, Left/Right Arm

**Fingers:** Left/Right × Thumb, Index Finger, Middle Finger, Ring Finger, Little Finger (fixed list)

**Finger Sides:** Thumb Side, Little Finger Side (fixed list)

## Usage

1. **Log an event** — Tap **+** in the top-right corner. Select an event type, enter details, then tap **Save**.
2. **Edit an event** — Tap any event in the list. Make changes and tap **Save**.
3. **Delete an event** — Swipe left on an event row and tap **Delete**.
4. **View charts** — Tap the chart icon in the toolbar for Daily Readings, Fasting BG, Peak Readings, Weekly Curve, A1C Estimate, or Meter Comparison.
5. **Export data** — Go to Settings > Export Data. Saves to iCloud Drive or local file.
6. **Import data** — Go to Settings > Import Data. Select a JSON export file.
7. **Customize** — Tap the gear icon to configure event types, meal types, meters, medicines, locations, themes, and post-meal timer.

## Requirements

- iOS 17.0+
- Xcode 16.0+
- Location permission (optional, for GPS tagging)

## Architecture

- **SwiftUI** — All views are built with SwiftUI.
- **SwiftData** — `GlucoseEvent` is the single `@Model` class. Data is stored on-device in SQLite via SwiftData.
- **Swift Charts** — Fasting, bedtime, daily (with day/week/month historical overlays), average, peak, weekly curve, A1C estimate, meal spacing, pre-meal scatter, and experiment comparison chart visualizations.
- **CoreLocation** — GPS location and reverse geocoding via `LocationManager`.
- **UserNotifications** — Post-meal timer reminders via `NotificationManager` (Swift `actor`).
- **UserDefaults** — User-configurable lists and theme preference via `SettingsManager` singleton.
- **@Observable** — `SettingsManager` and `LocationManager` use Observation framework for reactive updates.
- **iCloud** — Optional export to iCloud Drive Documents folder.
- **No external dependencies** — Pure Apple frameworks only.

## Project Structure

```
edt-glucose/
├── edt_glucoseApp.swift          # App entry point, ModelContainer setup
├── ContentView.swift             # Main event list, time summary, eA1C, multi-meter display
├── EventFormView.swift           # Add/edit form with conditional sections, GPS location
├── SettingsView.swift            # Settings, data import/export, configurable lists
├── SettingsManager.swift         # @Observable singleton for user preferences
├── AppTheme.swift                # Theme enum with color palettes
├── Item.swift                    # GlucoseEvent SwiftData model
├── DataExporter.swift            # JSON import/export and FileDocument
├── MultiMeterEstimator.swift     # Shared deviation computation + multi-meter formula
├── LocationManager.swift         # GPS + reverse geocoding
├── FastingChartView.swift        # Fasting BG chart
├── BedtimeChartView.swift       # Bedtime BG chart
├── DailyReadingsChartView.swift  # Daily BG readings chart
├── PeakReadingsChartView.swift   # Peak BG per day chart
├── WeeklyCurveChartView.swift    # Historical vs current week comparison
├── A1CEstimateChartView.swift    # Rolling eA1C over time
├── MeterDeviationView.swift      # Meter comparison analysis
├── AvgTimeBetweenMealsChartView.swift  # Average meal spacing over time
├── BestMealSpacingView.swift     # Meal spacing vs BG scatter plot
├── PreMealBGScatterView.swift    # Pre-meal BG vs time since last meal
├── AverageBGChartView.swift     # Daily average BG chart
├── RollingAveragesChartView.swift # Trailing 7/14/30/90-day average BG chart
├── ExperimentComparisonChartView.swift  # Before vs during experiment comparison
├── DataIntegrityView.swift      # Whole-history data sanity checks
├── ChartTimeRange.swift         # Shared Week/Month/Year/All picker
├── NotificationManager.swift     # Post-meal timer notifications (actor)
├── Assets.xcassets/              # App icon and colors
├── COMMIT_WORKFLOW.md            # Commit workflow procedure
├── prompts/                     # Per-session prompt/answer logs
└── scripts/
    └── commit-workflow.sh        # Automated commit helper script
```

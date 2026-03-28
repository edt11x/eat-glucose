# edt-glucose

A blood glucose tracking app for iPhone built with SwiftUI and SwiftData.

## Overview

edt-glucose lets you log blood glucose measurements and related daily events — meals, medicine, walks, A1C results, bedtime, and more — and view them in a chronological list organized by day. It provides extensive charting and analysis including smoothed weekly curves, estimated A1C, multi-meter averaging, and meter comparison. All data is stored persistently on-device using SwiftData with optional iCloud export.

## Features

### Live Summary

At the top of the event list, the app displays:
- **Time since last BG measurement** — updates every minute
- **Time since last meal** — updates every minute
- **Estimated A1C** — calculated from all BG readings using the ADAG formula: `eA1C = (avgBG + 46.7) / 28.7`

### Event Logging

Each event captures:

- **Event Type** — Blood Glucose Measurement, Start of Meal, End of Meal, Walk, A1C, or Bedtime.
- **Date & Time** — Defaults to the current time. Tap to edit if logging a past event.
- **Blood Glucose** — Optional reading in mg/dL (0–600). Input is validated and clamped to this range.
- **BG Guess** — Guess your blood glucose before measuring to track prediction accuracy.
- **Meter Type** — Select which glucose meter was used for the reading.
- **Test Strip Lot & Expiration** — Track lot numbers and expiration dates per meter type. Auto-fills from last-used values.
- **Multi-Meter Average** — Automatically displays estimated reading averaged across all meters using historical deviation data.
- **Medicine** — Track medicine name, dose, and unit (e.g., 3 units Lispro, 600 mg Berberine).
- **Meal Type** — Shown for meal events. Choose from Breakfast, Lunch, Dinner, or Snack.
- **Meal Details** — Food description, estimated calories, carbs, protein, and glycemic index.
- **Walk Distance** — Distance in miles for Walk events.
- **A1C** — A1C percentage for A1C events.
- **Location** — Available for all event types. Enter manually, select from history, or use GPS with reverse geocoding.
- **Activity Description** — Optional free-text field.
- **Notes** — Optional free-text field.

### Event List

- Events are displayed in a scrollable list, grouped by day with the most recent day first.
- Each row shows the event type, time, glucose reading, multi-meter estimate, meter, test strip info, meal type, medicine, walk distance, food details, nutrition estimates, location, A1C, activity, and notes.
- **Time since last meal** is displayed on each event.
- **Time to 95 mg/dL** is shown on End of Meal events when a subsequent reading reaches 95 or below.
- **BG Guess accuracy** shows how close your guess was to the actual reading.
- **Tap** an event to edit it.
- **Swipe left** on an event to delete it.

### Charts & Analysis

Access from the chart icon in the toolbar:

- **Daily Readings** — All BG readings for a selected day with a day picker. Shows average dotted line, summary stats, and reading table.
- **Fasting BG Chart** — First BG reading after 5:00 AM each day with average dotted line, summary stats, and reading table.
- **Peak Readings** — Maximum BG reading per day over time with average dotted line, summary stats, and daily peaks table.
- **Weekly Curve** — Smoothed historical weekly BG pattern (blue) vs current week raw readings (green), with multi-meter estimate line (orange) and historical average dotted line. Data is anchored at Monday and referenced in hours-from-Monday.
- **A1C Estimate** — Rolling 90-day estimated A1C over time using multi-meter average BG values. Shows color zones (green/yellow/red) for normal, prediabetes, and diabetes ranges. Includes the ADAG formula.
- **Meter Comparison** — Compares each meter against the Precision Neo reference by pairing readings within 5 minutes. Shows average deviation, average % deviation, and individual pairs.

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

- **Export** — Saves all events as JSON to iCloud Drive (`iCloud Drive/Documents/edt-glucose/`), or falls back to a file picker if iCloud is unavailable.
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
- **Locations** — Auto-saved from events and GPS, manually editable. Reset to defaults.
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

**Meal Types:** Breakfast, Lunch, Dinner, Snack

**Meter Types:** Precision Neo, Contour Next, Keto Mojo, N/A

**Medicine Types:** None, Lispro (3 units), Lantis (10 units), Toujeo (10 units), Berberine (600 mg)

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
- **Swift Charts** — Fasting, daily, peak, weekly curve, and A1C estimate chart visualizations.
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
├── DailyReadingsChartView.swift  # Daily BG readings chart
├── PeakReadingsChartView.swift   # Peak BG per day chart
├── WeeklyCurveChartView.swift    # Historical vs current week comparison
├── A1CEstimateChartView.swift    # Rolling eA1C over time
├── MeterDeviationView.swift      # Meter comparison analysis
├── NotificationManager.swift     # Post-meal timer notifications (actor)
└── Assets.xcassets/              # App icon and colors
```

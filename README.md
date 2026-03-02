# edt-glucose

A blood glucose tracking app for iPhone built with SwiftUI and SwiftData.

## Overview

edt-glucose lets you log blood glucose measurements and related daily events — meals, bedtime, and more — and view them in a chronological list organized by day. All data is stored persistently on-device using SwiftData.

## Features

### Event Logging

Each event captures:

- **Event Type** — The kind of event being logged (e.g., Blood Glucose Measurement, Start of Meal, End of Meal, Bedtime).
- **Date & Time** — Defaults to the current time. Tap to edit if logging a past event.
- **Blood Glucose** — Optional reading in mg/dL (0–600). Input is validated and clamped to this range.
- **Meter Type** — Optional. Select which glucose meter was used for the reading.
- **Meal Type** — Shown when the event type is "Start of Meal" or "End of Meal." Choose from Breakfast, Lunch, Dinner, or Snack.
- **Activity Description** — Optional free-text field to describe what you were doing.
- **Notes** — Optional free-text field for any additional information.

### Event List

- Events are displayed in a scrollable list, grouped by day with the most recent day first.
- Each row shows the event type, time, glucose reading (if entered), meter, meal type, activity, and notes.
- **Tap** an event to edit it.
- **Swipe left** on an event to delete it.

### Glucose Color Coding

Blood glucose readings in the event list are color-coded for quick reference:

| Color  | Range          | Meaning  |
|--------|----------------|----------|
| Red    | 69 or below    | Low      |
| Green  | 70 – 120       | Normal   |
| Yellow | 121 – 180      | Elevated |
| Red    | Above 180      | High     |

### Settings

Access settings by tapping the gear icon in the top-left corner. All lists are fully customizable:

- **Theme** — Choose between Dark (default), Light, System, or Obsidianite.
- **Event Types** — Add, delete, or reorder event types. Reset to defaults at any time.
- **Meal Types** — Add, delete, or reorder meal types. Reset to defaults at any time.
- **Meter Types** — Add, delete, or reorder meter types. Reset to defaults at any time.

### Themes

| Theme       | Description                                                              |
|-------------|--------------------------------------------------------------------------|
| Dark        | Standard iOS dark mode.                                                  |
| Light       | Standard iOS light mode.                                                 |
| System      | Follows the device's current appearance setting.                         |
| Obsidianite | A vibrant dark theme with purple, cyan, pink, and teal accent colors.    |

### Default Values

**Event Types:** Blood Glucose Measurement, Start of Meal, End of Meal, Bedtime

**Meal Types:** Breakfast, Lunch, Dinner, Snack

**Meter Types:** Precision Neo, Contour Next, Keto Mojo, N/A

## Usage

1. **Log an event** — Tap the **+** button in the top-right corner. Select an event type, optionally enter a glucose reading and other details, then tap **Save**.
2. **Edit an event** — Tap any event in the list to open it in the editor. Make changes and tap **Save**.
3. **Delete an event** — Swipe left on an event row and tap **Delete**.
4. **Customize settings** — Tap the **gear** icon to open Settings. Add or remove event types, meal types, and meter types. Change the app theme.

## Requirements

- iOS 17.0+
- Xcode 16.0+

## Architecture

- **SwiftUI** — All views are built with SwiftUI.
- **SwiftData** — `GlucoseEvent` is the single `@Model` class. Data is stored persistently on-device in an SQLite database managed by SwiftData.
- **UserDefaults** — User-configurable lists (event types, meal types, meter types) and theme preference are stored in UserDefaults via the `SettingsManager` singleton.
- **@Observable** — `SettingsManager` uses the Observation framework so views react to setting changes immediately.

## Project Structure

```
edt-glucose/
├── edt_glucoseApp.swift    # App entry point, ModelContainer setup
├── ContentView.swift       # Main event list with grouped sections
├── EventFormView.swift     # Add/edit event form
├── SettingsView.swift      # Settings screen with configurable lists
├── SettingsManager.swift   # Observable singleton for user preferences
├── AppTheme.swift          # Theme definitions and color palettes
├── Item.swift              # GlucoseEvent SwiftData model
└── Assets.xcassets/        # App icon and colors
```

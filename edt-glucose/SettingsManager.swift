//
//  SettingsManager.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/1/26.
//

import Foundation
import SwiftUI

struct TestStripDefault: Codable, Equatable {
    var lot: String
    var expiration: Date?
}

struct MedicineTypeConfig: Codable, Equatable, Identifiable {
    var id: String { name }
    var name: String
    var defaultDose: Double
    var defaultUnit: String
}

struct MealPreset: Codable, Equatable, Identifiable {
    var id: String { name }
    var name: String
    var calorieGuess: Int?
    var carbGuess: Int?
    var proteinGuess: Int?
    var glycemicIndexGuess: Int?
}

/// A saved location remembers a friendly name plus the street address and GPS
/// coordinates that were captured when the location was added.
struct NamedLocation: Codable, Equatable, Identifiable {
    var id: String { name }
    var name: String
    var streetAddress: String?
    var gpsCoordinates: String?
}

@Observable
final class SettingsManager {
    static let shared = SettingsManager()

    private let appearanceModeKey = "appearanceMode"
    private let eventTypesKey = "customEventTypes"
    private let mealTypesKey = "customMealTypes"
    private let meterTypesKey = "customMeterTypes"
    private let medicineTypesKey = "customMedicineTypes"
    private let unitsOfMeasureKey = "customUnitsOfMeasure"
    private let locationsKey = "customLocations"
    private let namedLocationsKey = "customNamedLocations"
    private let timerValuesKey = "postMealTimerValues"
    private let timerEnabledKey = "postMealTimerEnabled"
    private let testStripDefaultsKey = "testStripDefaults"
    private let activitiesKey = "customActivities"
    private let mealPresetsKey = "savedMealPresets"
    private let experimentsKey = "customExperiments"
    private let injectionSitesKey = "customInjectionSites"

    var appearanceMode: Int {
        didSet { UserDefaults.standard.set(appearanceMode, forKey: appearanceModeKey) }
    }

    var currentTheme: AppTheme {
        AppTheme(rawValue: appearanceMode) ?? .dark
    }

    var preferredColorScheme: ColorScheme? {
        currentTheme.colorScheme
    }

    private let defaultEventTypes = [
        "Blood Glucose Measurement",
        "Start of Meal",
        "End of Meal",
        "Walk",
        "A1C",
        "Bedtime"
    ]

    private let defaultMealTypes = [
        "Breakfast",
        "Lunch",
        "Dinner",
        "Snack",
        "Energy Drink"
    ]

    private let defaultMeterTypes = [
        "Precision Neo",
        "Contour Next",
        "Keto Mojo",
        "N/A"
    ]

    private let defaultMedicineTypes: [MedicineTypeConfig] = [
        MedicineTypeConfig(name: "None", defaultDose: 0, defaultUnit: "N/A"),
        MedicineTypeConfig(name: "Lispro - regular insulin", defaultDose: 3, defaultUnit: "units"),
        MedicineTypeConfig(name: "Lantis - long acting", defaultDose: 10, defaultUnit: "units"),
        MedicineTypeConfig(name: "Toujeo - long acting", defaultDose: 10, defaultUnit: "units"),
        MedicineTypeConfig(name: "Berberine", defaultDose: 600, defaultUnit: "mg"),
    ]

    private let defaultUnitsOfMeasure = [
        "units", "mg", "mg/dL", "%", "N/A"
    ]

    private let defaultLocations: [String] = []
    private let defaultActivities: [String] = []
    private let defaultExperiments: [String] = []
    private let defaultInjectionSites: [String] = [
        "Left Abdomen",
        "Right Abdomen",
        "Left Thigh",
        "Right Thigh",
        "Left Arm",
        "Right Arm"
    ]

    private let defaultTimerValues = [0, 30, 45, 60, 90, 120, 240]

    var eventTypes: [String] {
        didSet { UserDefaults.standard.set(eventTypes, forKey: eventTypesKey) }
    }

    var mealTypes: [String] {
        didSet { UserDefaults.standard.set(mealTypes, forKey: mealTypesKey) }
    }

    var meterTypes: [String] {
        didSet { UserDefaults.standard.set(meterTypes, forKey: meterTypesKey) }
    }

    var medicineTypes: [MedicineTypeConfig] {
        didSet {
            if let data = try? JSONEncoder().encode(medicineTypes) {
                UserDefaults.standard.set(data, forKey: medicineTypesKey)
            }
        }
    }

    var unitsOfMeasure: [String] {
        didSet { UserDefaults.standard.set(unitsOfMeasure, forKey: unitsOfMeasureKey) }
    }

    var namedLocations: [NamedLocation] {
        didSet {
            if let data = try? JSONEncoder().encode(namedLocations) {
                UserDefaults.standard.set(data, forKey: namedLocationsKey)
            }
        }
    }

    /// Derived list of just the location names — for use in pickers that need a
    /// `[String]` collection. Edits to the underlying list happen through
    /// `namedLocations` and the helper methods below.
    var locations: [String] { namedLocations.map(\.name) }

    var postMealTimerValues: [Int] {
        didSet { UserDefaults.standard.set(postMealTimerValues, forKey: timerValuesKey) }
    }

    var postMealTimerEnabled: Bool {
        didSet { UserDefaults.standard.set(postMealTimerEnabled, forKey: timerEnabledKey) }
    }

    var testStripDefaults: [String: TestStripDefault] {
        didSet {
            if let data = try? JSONEncoder().encode(testStripDefaults) {
                UserDefaults.standard.set(data, forKey: testStripDefaultsKey)
            }
        }
    }

    var activities: [String] {
        didSet { UserDefaults.standard.set(activities, forKey: activitiesKey) }
    }

    var mealPresets: [MealPreset] {
        didSet {
            if let data = try? JSONEncoder().encode(mealPresets) {
                UserDefaults.standard.set(data, forKey: mealPresetsKey)
            }
        }
    }

    var experiments: [String] {
        didSet { UserDefaults.standard.set(experiments, forKey: experimentsKey) }
    }

    var injectionSites: [String] {
        didSet { UserDefaults.standard.set(injectionSites, forKey: injectionSitesKey) }
    }

    private init() {
        if UserDefaults.standard.object(forKey: appearanceModeKey) != nil {
            self.appearanceMode = UserDefaults.standard.integer(forKey: appearanceModeKey)
        } else {
            self.appearanceMode = 0
        }

        if let saved = UserDefaults.standard.stringArray(forKey: eventTypesKey) {
            self.eventTypes = saved
        } else {
            self.eventTypes = defaultEventTypes
        }

        if let saved = UserDefaults.standard.stringArray(forKey: mealTypesKey) {
            self.mealTypes = saved
        } else {
            self.mealTypes = defaultMealTypes
        }

        if let saved = UserDefaults.standard.stringArray(forKey: meterTypesKey) {
            self.meterTypes = saved
        } else {
            self.meterTypes = defaultMeterTypes
        }

        if let data = UserDefaults.standard.data(forKey: medicineTypesKey),
           let saved = try? JSONDecoder().decode([MedicineTypeConfig].self, from: data) {
            self.medicineTypes = saved
        } else {
            self.medicineTypes = defaultMedicineTypes
        }

        if let saved = UserDefaults.standard.stringArray(forKey: unitsOfMeasureKey) {
            self.unitsOfMeasure = saved
        } else {
            self.unitsOfMeasure = defaultUnitsOfMeasure
        }

        if let data = UserDefaults.standard.data(forKey: namedLocationsKey),
           let saved = try? JSONDecoder().decode([NamedLocation].self, from: data) {
            self.namedLocations = saved
        } else if let oldSaved = UserDefaults.standard.stringArray(forKey: locationsKey) {
            // Migrate legacy plain-string locations: keep the names, leave
            // street address / GPS coordinates empty until the user fills them in.
            self.namedLocations = oldSaved.map { NamedLocation(name: $0) }
        } else {
            self.namedLocations = defaultLocations.map { NamedLocation(name: $0) }
        }

        if let saved = UserDefaults.standard.array(forKey: timerValuesKey) as? [Int] {
            self.postMealTimerValues = saved
        } else {
            self.postMealTimerValues = defaultTimerValues
        }

        self.postMealTimerEnabled = UserDefaults.standard.bool(forKey: timerEnabledKey)

        if let data = UserDefaults.standard.data(forKey: testStripDefaultsKey),
           let saved = try? JSONDecoder().decode([String: TestStripDefault].self, from: data) {
            self.testStripDefaults = saved
        } else {
            self.testStripDefaults = [:]
        }

        if let saved = UserDefaults.standard.stringArray(forKey: activitiesKey) {
            self.activities = saved
        } else {
            self.activities = defaultActivities
        }

        if let data = UserDefaults.standard.data(forKey: mealPresetsKey),
           let saved = try? JSONDecoder().decode([MealPreset].self, from: data) {
            self.mealPresets = saved
        } else {
            self.mealPresets = []
        }

        if let saved = UserDefaults.standard.stringArray(forKey: experimentsKey) {
            self.experiments = saved
        } else {
            self.experiments = defaultExperiments
        }

        if let saved = UserDefaults.standard.stringArray(forKey: injectionSitesKey) {
            self.injectionSites = saved
        } else {
            self.injectionSites = defaultInjectionSites
        }
    }

    func resetEventTypes() { eventTypes = defaultEventTypes }
    func resetMealTypes() { mealTypes = defaultMealTypes }
    func resetMeterTypes() { meterTypes = defaultMeterTypes }
    func resetMedicineTypes() { medicineTypes = defaultMedicineTypes }
    func resetUnitsOfMeasure() { unitsOfMeasure = defaultUnitsOfMeasure }
    func resetLocations() {
        namedLocations = defaultLocations.map { NamedLocation(name: $0) }
    }
    func resetTimerValues() { postMealTimerValues = defaultTimerValues }

    func updateTestStripDefault(for meterType: String, lot: String, expiration: Date?) {
        testStripDefaults[meterType] = TestStripDefault(lot: lot, expiration: expiration)
    }

    func addLocationIfNew(_ name: String) {
        addOrUpdateNamedLocation(name: name)
    }

    /// Add or update a saved location with optional street address / GPS
    /// coordinates. If the location already exists, non-empty new values
    /// replace whatever was stored before (so the most-recent capture wins).
    func addOrUpdateNamedLocation(name: String,
                                  streetAddress: String? = nil,
                                  gpsCoordinates: String? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let address = streetAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        let coords = gpsCoordinates?.trimmingCharacters(in: .whitespaces)
        if let idx = namedLocations.firstIndex(where: { $0.name == trimmed }) {
            var entry = namedLocations[idx]
            if let address, !address.isEmpty { entry.streetAddress = address }
            if let coords, !coords.isEmpty { entry.gpsCoordinates = coords }
            namedLocations[idx] = entry
        } else {
            namedLocations.append(NamedLocation(
                name: trimmed,
                streetAddress: (address?.isEmpty ?? true) ? nil : address,
                gpsCoordinates: (coords?.isEmpty ?? true) ? nil : coords
            ))
        }
    }

    func namedLocation(named name: String) -> NamedLocation? {
        namedLocations.first(where: { $0.name == name })
    }

    func resetActivities() { activities = defaultActivities }

    func addActivityIfNew(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !activities.contains(trimmed) {
            activities.append(trimmed)
        }
    }

    func saveMealPreset(_ preset: MealPreset) {
        if let idx = mealPresets.firstIndex(where: { $0.name == preset.name }) {
            mealPresets[idx] = preset
        } else {
            mealPresets.append(preset)
        }
    }

    func resetMealPresets() { mealPresets = [] }

    func resetExperiments() { experiments = defaultExperiments }

    func addExperimentIfNew(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !experiments.contains(trimmed) {
            experiments.append(trimmed)
        }
    }

    func resetInjectionSites() { injectionSites = defaultInjectionSites }

    func addInjectionSiteIfNew(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !injectionSites.contains(trimmed) {
            injectionSites.append(trimmed)
        }
    }

    /// Fixed list of valid fingers for the BG-measurement "Finger Used" picker.
    static let fingerOptions: [String] = [
        "Left Thumb",
        "Left Index Finger",
        "Left Middle Finger",
        "Left Ring Finger",
        "Left Little Finger",
        "Right Thumb",
        "Right Index Finger",
        "Right Middle Finger",
        "Right Ring Finger",
        "Right Little Finger"
    ]

    /// Side-of-finger options for BG measurement.
    static let fingerSideOptions: [String] = [
        "Thumb Side",
        "Little Finger Side"
    ]
}

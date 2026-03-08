//
//  SettingsManager.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/1/26.
//

import Foundation
import SwiftUI

struct MedicineTypeConfig: Codable, Equatable, Identifiable {
    var id: String { name }
    var name: String
    var defaultDose: Double
    var defaultUnit: String
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
    private let timerValuesKey = "postMealTimerValues"
    private let timerEnabledKey = "postMealTimerEnabled"

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
        "Snack"
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
        MedicineTypeConfig(name: "Berberine", defaultDose: 600, defaultUnit: "mg"),
    ]

    private let defaultUnitsOfMeasure = [
        "units", "mg", "mg/dL", "%", "N/A"
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

    var postMealTimerValues: [Int] {
        didSet { UserDefaults.standard.set(postMealTimerValues, forKey: timerValuesKey) }
    }

    var postMealTimerEnabled: Bool {
        didSet { UserDefaults.standard.set(postMealTimerEnabled, forKey: timerEnabledKey) }
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

        if let saved = UserDefaults.standard.array(forKey: timerValuesKey) as? [Int] {
            self.postMealTimerValues = saved
        } else {
            self.postMealTimerValues = defaultTimerValues
        }

        self.postMealTimerEnabled = UserDefaults.standard.bool(forKey: timerEnabledKey)
    }

    func resetEventTypes() { eventTypes = defaultEventTypes }
    func resetMealTypes() { mealTypes = defaultMealTypes }
    func resetMeterTypes() { meterTypes = defaultMeterTypes }
    func resetMedicineTypes() { medicineTypes = defaultMedicineTypes }
    func resetUnitsOfMeasure() { unitsOfMeasure = defaultUnitsOfMeasure }
    func resetTimerValues() { postMealTimerValues = defaultTimerValues }
}

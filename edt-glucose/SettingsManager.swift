//
//  SettingsManager.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/1/26.
//

import Foundation
import SwiftUI

@Observable
final class SettingsManager {
    static let shared = SettingsManager()

    private let appearanceModeKey = "appearanceMode"
    private let eventTypesKey = "customEventTypes"
    private let mealTypesKey = "customMealTypes"
    private let meterTypesKey = "customMeterTypes"

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

    var eventTypes: [String] {
        didSet { UserDefaults.standard.set(eventTypes, forKey: eventTypesKey) }
    }

    var mealTypes: [String] {
        didSet { UserDefaults.standard.set(mealTypes, forKey: mealTypesKey) }
    }

    var meterTypes: [String] {
        didSet { UserDefaults.standard.set(meterTypes, forKey: meterTypesKey) }
    }

    private init() {
        if UserDefaults.standard.object(forKey: appearanceModeKey) != nil {
            self.appearanceMode = UserDefaults.standard.integer(forKey: appearanceModeKey)
        } else {
            self.appearanceMode = 0 // dark by default
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
    }

    func resetEventTypes() { eventTypes = defaultEventTypes }
    func resetMealTypes() { mealTypes = defaultMealTypes }
    func resetMeterTypes() { meterTypes = defaultMeterTypes }
}

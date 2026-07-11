//
//  Item.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/1/26.
//

import Foundation
import SwiftData

@Model
final class GlucoseEvent {
    var timestamp: Date
    var eventType: String
    var mealType: String?
    var bloodGlucose: Int?
    var meterType: String?
    var activityDescription: String
    var notes: String

    // Medicine
    var medicineName: String?
    var medicineDose: Double?
    var medicineDoseUnit: String?
    var injectionSite: String?
    /// Angle from navel: right=0°, left=180° (0–360°)
    var injectionAngleDegrees: Double?
    var injectionDistanceValue: Double?
    /// "in" or "cm"
    var injectionDistanceUnit: String?

    // Blood Glucose Guess
    var bloodGlucoseGuess: Int?

    // Walk
    var walkDistanceMiles: Double?

    // Meal Enhancements
    var foodDescription: String?
    var calorieGuess: Int?
    var carbGuess: Int?
    var locationName: String?
    /// Street address captured from reverse geocoding (separate from locationName label)
    var streetAddress: String?
    /// "lat,lon" formatted GPS coordinates from Use Current Location
    var gpsCoordinates: String?

    // A1C
    var a1cValue: Double?

    // Meal nutrition estimates
    var proteinGuess: Int?
    var glycemicIndexGuess: Int?

    /// Flags a Start of Meal as a "non-diabetic" meal (higher carbs/sugar/calories),
    /// to help recognize and track meals that may drive higher BG results.
    var nonDiabeticMeal: Bool = false

    // Test strip tracking
    var testStripLot: String?
    var testStripExpiration: Date?

    // Lance site for BG measurement (e.g., "Left Index Finger")
    var fingerUsed: String?
    /// "Thumb Side" or "Little Finger Side"
    var fingerSide: String?

    // Experiment tracking
    var experimentQuantity: Double?
    var experimentQuantityUnit: String?

    init(
        timestamp: Date = Date(),
        eventType: String = "Blood Glucose Measurement",
        mealType: String? = nil,
        bloodGlucose: Int? = nil,
        meterType: String? = nil,
        activityDescription: String = "",
        notes: String = "",
        medicineName: String? = nil,
        medicineDose: Double? = nil,
        medicineDoseUnit: String? = nil,
        bloodGlucoseGuess: Int? = nil,
        walkDistanceMiles: Double? = nil,
        foodDescription: String? = nil,
        calorieGuess: Int? = nil,
        carbGuess: Int? = nil,
        locationName: String? = nil,
        a1cValue: Double? = nil,
        proteinGuess: Int? = nil,
        glycemicIndexGuess: Int? = nil,
        nonDiabeticMeal: Bool = false,
        testStripLot: String? = nil,
        testStripExpiration: Date? = nil,
        experimentQuantity: Double? = nil,
        experimentQuantityUnit: String? = nil,
        injectionSite: String? = nil,
        injectionAngleDegrees: Double? = nil,
        injectionDistanceValue: Double? = nil,
        injectionDistanceUnit: String? = nil,
        streetAddress: String? = nil,
        gpsCoordinates: String? = nil,
        fingerUsed: String? = nil,
        fingerSide: String? = nil
    ) {
        self.timestamp = timestamp
        self.eventType = eventType
        self.mealType = mealType
        self.bloodGlucose = bloodGlucose
        self.meterType = meterType
        self.activityDescription = activityDescription
        self.notes = notes
        self.medicineName = medicineName
        self.medicineDose = medicineDose
        self.medicineDoseUnit = medicineDoseUnit
        self.bloodGlucoseGuess = bloodGlucoseGuess
        self.walkDistanceMiles = walkDistanceMiles
        self.foodDescription = foodDescription
        self.calorieGuess = calorieGuess
        self.carbGuess = carbGuess
        self.locationName = locationName
        self.a1cValue = a1cValue
        self.proteinGuess = proteinGuess
        self.glycemicIndexGuess = glycemicIndexGuess
        self.nonDiabeticMeal = nonDiabeticMeal
        self.testStripLot = testStripLot
        self.testStripExpiration = testStripExpiration
        self.experimentQuantity = experimentQuantity
        self.experimentQuantityUnit = experimentQuantityUnit
        self.injectionSite = injectionSite
        self.injectionAngleDegrees = injectionAngleDegrees
        self.injectionDistanceValue = injectionDistanceValue
        self.injectionDistanceUnit = injectionDistanceUnit
        self.streetAddress = streetAddress
        self.gpsCoordinates = gpsCoordinates
        self.fingerUsed = fingerUsed
        self.fingerSide = fingerSide
    }

    /// Glycemic Load = glycemic index × carbs / 100. `nil` unless both the
    /// glycemic index and carb guess are present. Getter-only, so SwiftData
    /// treats it as a derived (non-persisted) property.
    var glycemicLoad: Double? {
        guard let gi = glycemicIndexGuess, let carbs = carbGuess else { return nil }
        return Double(gi) * Double(carbs) / 100.0
    }
}

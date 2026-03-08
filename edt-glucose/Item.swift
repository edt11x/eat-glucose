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

    // Blood Glucose Guess
    var bloodGlucoseGuess: Int?

    // Walk
    var walkDistanceMiles: Double?

    // Meal Enhancements
    var foodDescription: String?
    var calorieGuess: Int?
    var carbGuess: Int?
    var locationName: String?

    // A1C
    var a1cValue: Double?

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
        a1cValue: Double? = nil
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
    }
}

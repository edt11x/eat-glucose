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

    init(
        timestamp: Date = Date(),
        eventType: String = "Blood Glucose Measurement",
        mealType: String? = nil,
        bloodGlucose: Int? = nil,
        meterType: String? = nil,
        activityDescription: String = "",
        notes: String = ""
    ) {
        self.timestamp = timestamp
        self.eventType = eventType
        self.mealType = mealType
        self.bloodGlucose = bloodGlucose
        self.meterType = meterType
        self.activityDescription = activityDescription
        self.notes = notes
    }
}

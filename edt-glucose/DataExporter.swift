//
//  DataExporter.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/1/26.
//

import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct GlucoseEventData: Codable {
    var timestamp: Date
    var eventType: String
    var mealType: String?
    var bloodGlucose: Int?
    var meterType: String?
    var activityDescription: String
    var notes: String

    // New fields
    var medicineName: String?
    var medicineDose: Double?
    var medicineDoseUnit: String?
    var bloodGlucoseGuess: Int?
    var walkDistanceMiles: Double?
    var foodDescription: String?
    var calorieGuess: Int?
    var carbGuess: Int?
    var locationName: String?
    var a1cValue: Double?

    // Backwards-compatible decoder: old JSON missing new keys will decode cleanly
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        eventType = try container.decode(String.self, forKey: .eventType)
        mealType = try container.decodeIfPresent(String.self, forKey: .mealType)
        bloodGlucose = try container.decodeIfPresent(Int.self, forKey: .bloodGlucose)
        meterType = try container.decodeIfPresent(String.self, forKey: .meterType)
        activityDescription = try container.decodeIfPresent(String.self, forKey: .activityDescription) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""

        medicineName = try container.decodeIfPresent(String.self, forKey: .medicineName)
        medicineDose = try container.decodeIfPresent(Double.self, forKey: .medicineDose)
        medicineDoseUnit = try container.decodeIfPresent(String.self, forKey: .medicineDoseUnit)
        bloodGlucoseGuess = try container.decodeIfPresent(Int.self, forKey: .bloodGlucoseGuess)
        walkDistanceMiles = try container.decodeIfPresent(Double.self, forKey: .walkDistanceMiles)
        foodDescription = try container.decodeIfPresent(String.self, forKey: .foodDescription)
        calorieGuess = try container.decodeIfPresent(Int.self, forKey: .calorieGuess)
        carbGuess = try container.decodeIfPresent(Int.self, forKey: .carbGuess)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        a1cValue = try container.decodeIfPresent(Double.self, forKey: .a1cValue)
    }

    init(from event: GlucoseEvent) {
        self.timestamp = event.timestamp
        self.eventType = event.eventType
        self.mealType = event.mealType
        self.bloodGlucose = event.bloodGlucose
        self.meterType = event.meterType
        self.activityDescription = event.activityDescription
        self.notes = event.notes
        self.medicineName = event.medicineName
        self.medicineDose = event.medicineDose
        self.medicineDoseUnit = event.medicineDoseUnit
        self.bloodGlucoseGuess = event.bloodGlucoseGuess
        self.walkDistanceMiles = event.walkDistanceMiles
        self.foodDescription = event.foodDescription
        self.calorieGuess = event.calorieGuess
        self.carbGuess = event.carbGuess
        self.locationName = event.locationName
        self.a1cValue = event.a1cValue
    }

    func toGlucoseEvent() -> GlucoseEvent {
        GlucoseEvent(
            timestamp: timestamp,
            eventType: eventType,
            mealType: mealType,
            bloodGlucose: bloodGlucose,
            meterType: meterType,
            activityDescription: activityDescription,
            notes: notes,
            medicineName: medicineName,
            medicineDose: medicineDose,
            medicineDoseUnit: medicineDoseUnit,
            bloodGlucoseGuess: bloodGlucoseGuess,
            walkDistanceMiles: walkDistanceMiles,
            foodDescription: foodDescription,
            calorieGuess: calorieGuess,
            carbGuess: carbGuess,
            locationName: locationName,
            a1cValue: a1cValue
        )
    }
}

struct ExportData: Codable {
    var exportDate: Date
    var events: [GlucoseEventData]
}

enum DataExporter {
    static func exportJSON(events: [GlucoseEvent]) throws -> Data {
        let exportData = ExportData(
            exportDate: Date(),
            events: events.map { GlucoseEventData(from: $0) }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(exportData)
    }

    static func importJSON(data: Data) throws -> [GlucoseEvent] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let importData = try decoder.decode(ExportData.self, from: data)
        return importData.events.map { $0.toGlucoseEvent() }
    }
}

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = fileData
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

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

    init(from event: GlucoseEvent) {
        self.timestamp = event.timestamp
        self.eventType = event.eventType
        self.mealType = event.mealType
        self.bloodGlucose = event.bloodGlucose
        self.meterType = event.meterType
        self.activityDescription = event.activityDescription
        self.notes = event.notes
    }

    func toGlucoseEvent() -> GlucoseEvent {
        GlucoseEvent(
            timestamp: timestamp,
            eventType: eventType,
            mealType: mealType,
            bloodGlucose: bloodGlucose,
            meterType: meterType,
            activityDescription: activityDescription,
            notes: notes
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

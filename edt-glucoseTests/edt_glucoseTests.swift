//
//  edt_glucoseTests.swift
//  edt-glucoseTests
//
//  Created by Edward Thompson on 6/20/26.
//

import Foundation
import Testing
@testable import edt_glucose

// MARK: - MultiMeterEstimator

@Suite("MultiMeterEstimator")
struct MultiMeterEstimatorTests {

    /// Build a BG event with the meter type and reading; timestamp can be
    /// supplied so a pair is "within 5 minutes" for the deviation calculation.
    private func bg(_ reading: Int, _ meter: String, at offsetSeconds: TimeInterval = 0) -> GlucoseEvent {
        let baseline = Date(timeIntervalSinceReferenceDate: 800_000_000) // arbitrary anchor
        return GlucoseEvent(
            timestamp: baseline.addingTimeInterval(offsetSeconds),
            eventType: "Blood Glucose Measurement",
            bloodGlucose: reading,
            meterType: meter
        )
    }

    @Test("Empty input produces no deviations")
    func emptyInput() {
        let result = MultiMeterEstimator.computeDeviationsUncached(from: [])
        #expect(result.isEmpty)
    }

    @Test("Reference-meter-only readings produce no deviations")
    func referenceOnly() {
        let events = [
            bg(100, "Precision Neo", at: 0),
            bg(120, "Precision Neo", at: 60),
        ]
        let result = MultiMeterEstimator.computeDeviationsUncached(from: events)
        #expect(result.isEmpty)
    }

    @Test("Paired readings within 5 minutes yield a positive deviation when other meter reads high")
    func pairedHighReading() {
        let events = [
            bg(100, "Precision Neo", at: 0),    // reference
            bg(110, "Contour Next", at: 60),    // +10% within 1 minute
        ]
        let result = MultiMeterEstimator.computeDeviationsUncached(from: events)
        #expect(result.count == 1)
        #expect(result.first?.meterName == "Contour Next")
        #expect(result.first?.averagePercentDeviation == 0.10)
    }

    @Test("Pairs farther than 5 minutes apart are ignored")
    func unpaired() {
        let events = [
            bg(100, "Precision Neo", at: 0),
            bg(150, "Contour Next", at: 6 * 60), // 6 minutes — outside the window
        ]
        let result = MultiMeterEstimator.computeDeviationsUncached(from: events)
        #expect(result.isEmpty)
    }

    @Test("Multiple pairs average their per-pair deviations")
    func averagedPairs() {
        let events = [
            bg(100, "Precision Neo", at: 0),
            bg(110, "Contour Next", at: 30),     // +10%
            bg(200, "Precision Neo", at: 3600),  // 1h later, fresh pair
            bg(180, "Contour Next", at: 3600 + 60), // -10%
        ]
        let result = MultiMeterEstimator.computeDeviationsUncached(from: events)
        #expect(result.count == 1)
        #expect(abs((result.first?.averagePercentDeviation ?? 0)) < 1e-9)
    }

    @Test("Estimate returns nil when no deviation data exists")
    func estimateWithoutDeviations() {
        let value = MultiMeterEstimator.estimate(reading: 100, meterType: "Precision Neo", deviations: [])
        #expect(value == nil)
    }

    @Test("Estimate from reference meter scales by (N + Σd) / N")
    func estimateReferenceMeter() {
        let dev = MultiMeterEstimator.MeterDeviation(meterName: "Contour Next", averagePercentDeviation: 0.10)
        let value = MultiMeterEstimator.estimate(reading: 100, meterType: "Precision Neo", deviations: [dev])
        // n = 2, sumDev = 0.10  →  100 * (2 + 0.10) / 2 = 105
        #expect(value != nil)
        #expect(abs((value ?? 0) - 105.0) < 1e-9)
    }

    @Test("Estimate from a known non-reference meter inverts that meter's deviation")
    func estimateNonReferenceMeter() {
        let dev = MultiMeterEstimator.MeterDeviation(meterName: "Contour Next", averagePercentDeviation: 0.10)
        // A "110" on Contour Next implies a Precision Neo of 110 / 1.10 = 100, and the
        // multi-meter average is then 100 * (2 + 0.10) / 2 = 105.
        let value = MultiMeterEstimator.estimate(reading: 110, meterType: "Contour Next", deviations: [dev])
        #expect(value != nil)
        #expect(abs((value ?? 0) - 105.0) < 1e-9)
    }
}

// MARK: - ChartTimeRange

@Suite("ChartTimeRange")
struct ChartTimeRangeTests {
    private let reference = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test("Week range cutoff is 7 days before the reference")
    func weekCutoff() {
        let cutoff = ChartTimeRange.week.startDate(from: reference)
        let expected = Calendar.current.date(byAdding: .day, value: -7, to: reference)
        #expect(cutoff == expected)
    }

    @Test("Month range cutoff is 1 month before")
    func monthCutoff() {
        let cutoff = ChartTimeRange.month.startDate(from: reference)
        let expected = Calendar.current.date(byAdding: .month, value: -1, to: reference)
        #expect(cutoff == expected)
    }

    @Test("Year range cutoff is 1 year before")
    func yearCutoff() {
        let cutoff = ChartTimeRange.year.startDate(from: reference)
        let expected = Calendar.current.date(byAdding: .year, value: -1, to: reference)
        #expect(cutoff == expected)
    }

    @Test("All range returns the distant past")
    func allCutoff() {
        let cutoff = ChartTimeRange.all.startDate(from: reference)
        #expect(cutoff == .distantPast)
    }

    @Test("Cases enumerate in expected order")
    func allCases() {
        let cases = ChartTimeRange.allCases
        #expect(cases == [.week, .month, .year, .all])
    }
}

// MARK: - DataExporter

@Suite("DataExporter")
struct DataExporterTests {

    @Test("JSON round-trip preserves all new GlucoseEvent fields")
    func roundTripPreservesNewFields() throws {
        let original = GlucoseEvent(
            timestamp: Date(timeIntervalSinceReferenceDate: 800_000_000),
            eventType: "Blood Glucose Measurement",
            bloodGlucose: 124,
            meterType: "Contour Next",
            activityDescription: "post-walk check",
            notes: "felt fine",
            medicineName: "Lantis - long acting",
            medicineDose: 10,
            medicineDoseUnit: "units",
            locationName: "Home",
            streetAddress: "1 Maple St, Springfield, IL 62701, USA",
            gpsCoordinates: "39.781721,-89.650148",
            fingerUsed: "Left Index Finger",
            fingerSide: "Thumb Side"
        )
        original.injectionSite = "Left Abdomen"
        original.injectionAngleDegrees = 145
        original.injectionDistanceValue = 2.5
        original.injectionDistanceUnit = "in"
        original.carbGuess = 40
        original.glycemicIndexGuess = 55
        original.nonDiabeticMeal = true

        let data = try DataExporter.exportJSON(events: [original])
        let restored = try DataExporter.importJSON(data: data)
        let event = try #require(restored.first)

        #expect(event.bloodGlucose == 124)
        #expect(event.meterType == "Contour Next")
        #expect(event.fingerUsed == "Left Index Finger")
        #expect(event.fingerSide == "Thumb Side")
        #expect(event.injectionSite == "Left Abdomen")
        #expect(event.injectionAngleDegrees == 145)
        #expect(event.injectionDistanceValue == 2.5)
        #expect(event.injectionDistanceUnit == "in")
        #expect(event.streetAddress == "1 Maple St, Springfield, IL 62701, USA")
        #expect(event.gpsCoordinates == "39.781721,-89.650148")
        #expect(event.locationName == "Home")
        #expect(event.carbGuess == 40)
        #expect(event.glycemicIndexGuess == 55)
        #expect(event.nonDiabeticMeal == true)
        #expect(event.glycemicLoad == 22.0) // 55 × 40 / 100
    }

    @Test("Decoder accepts legacy JSON missing the new keys")
    func legacyJSONStillDecodes() throws {
        // Older exports won't carry any of the recently added optional fields.
        let legacy = """
        {
          "exportDate": "2026-04-01T12:00:00Z",
          "events": [
            {
              "timestamp": "2026-04-01T08:30:00Z",
              "eventType": "Blood Glucose Measurement",
              "bloodGlucose": 99,
              "meterType": "Precision Neo",
              "activityDescription": "",
              "notes": ""
            }
          ]
        }
        """.data(using: .utf8)!

        let restored = try DataExporter.importJSON(data: legacy)
        let event = try #require(restored.first)
        #expect(event.bloodGlucose == 99)
        #expect(event.meterType == "Precision Neo")
        #expect(event.injectionSite == nil)
        #expect(event.fingerUsed == nil)
        #expect(event.streetAddress == nil)
        // Newly added fields must default cleanly for legacy data.
        #expect(event.nonDiabeticMeal == false)
        #expect(event.glycemicLoad == nil)
    }
}

// MARK: - Glycemic Load & meal flags

@Suite("Glycemic Load")
struct GlycemicLoadTests {

    @Test("Glycemic Load = GI × carbs / 100 when both present")
    func computed() {
        let event = GlucoseEvent(eventType: "Start of Meal")
        event.carbGuess = 30
        event.glycemicIndexGuess = 70
        #expect(event.glycemicLoad == 21.0)
    }

    @Test("Glycemic Load is nil when carbs or GI is missing")
    func missing() {
        let noCarbs = GlucoseEvent(eventType: "Start of Meal")
        noCarbs.glycemicIndexGuess = 70
        #expect(noCarbs.glycemicLoad == nil)

        let noGI = GlucoseEvent(eventType: "Start of Meal")
        noGI.carbGuess = 30
        #expect(noGI.glycemicLoad == nil)

        #expect(GlucoseEvent(eventType: "Start of Meal").glycemicLoad == nil)
    }

    @Test("Non-diabetic meal flag defaults false and can be set")
    func nonDiabeticFlag() {
        #expect(GlucoseEvent().nonDiabeticMeal == false)
        let flagged = GlucoseEvent(eventType: "Start of Meal", nonDiabeticMeal: true)
        #expect(flagged.nonDiabeticMeal == true)
    }
}

// MARK: - NamedLocation (SettingsManager.NamedLocation type)

@Suite("NamedLocation Codable")
struct NamedLocationTests {

    @Test("Round-trip preserves all fields")
    func roundTrip() throws {
        let loc = NamedLocation(
            name: "Park",
            streetAddress: "100 Lake Ave",
            gpsCoordinates: "39.7,-89.6"
        )
        let data = try JSONEncoder().encode(loc)
        let restored = try JSONDecoder().decode(NamedLocation.self, from: data)
        #expect(restored == loc)
    }

    @Test("Encoding omits id (id is derived from name)")
    func idDerivedFromName() {
        let loc = NamedLocation(name: "Office")
        #expect(loc.id == "Office")
    }
}

// MARK: - GlucoseEvent / data sanity

@Suite("GlucoseEvent invariants")
struct GlucoseEventTests {

    @Test("Default initializer fills required scalar fields")
    func defaultsAreSane() {
        let event = GlucoseEvent()
        #expect(event.eventType == "Blood Glucose Measurement")
        #expect(event.activityDescription == "")
        #expect(event.notes == "")
        #expect(event.bloodGlucose == nil)
        #expect(event.injectionSite == nil)
        #expect(event.fingerUsed == nil)
    }

    @Test("All extended optional fields default to nil")
    func extendedFieldsDefaultNil() {
        let event = GlucoseEvent()
        #expect(event.medicineName == nil)
        #expect(event.medicineDose == nil)
        #expect(event.injectionAngleDegrees == nil)
        #expect(event.streetAddress == nil)
        #expect(event.gpsCoordinates == nil)
        #expect(event.testStripLot == nil)
        #expect(event.testStripExpiration == nil)
    }
}

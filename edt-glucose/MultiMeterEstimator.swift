//
//  MultiMeterEstimator.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/28/26.
//

import Foundation

enum MultiMeterEstimator {
    struct MeterDeviation {
        let meterName: String
        /// Average percentage deviation as a fraction (e.g., 0.05 for 5% higher than reference)
        let averagePercentDeviation: Double
    }

    static let referenceMeter = "Precision Neo"
    static let maxTimeDiff: TimeInterval = 5 * 60  // 5 minutes

    /// Compute average percentage deviations for each non-reference meter
    /// by pairing readings with Precision Neo readings within 5 minutes.
    static func computeDeviations(from events: [GlucoseEvent]) -> [MeterDeviation] {
        let bgEvents = events.filter {
            $0.eventType == "Blood Glucose Measurement"
            && $0.bloodGlucose != nil
            && $0.meterType != nil
            && !$0.meterType!.isEmpty
        }

        let precisionEvents = bgEvents.filter { $0.meterType == referenceMeter }
        let otherMeters = Set(bgEvents.compactMap(\.meterType)).filter {
            $0 != referenceMeter && $0 != "N/A"
        }

        var results: [MeterDeviation] = []

        for meter in otherMeters.sorted() {
            let meterEvents = bgEvents.filter { $0.meterType == meter }
            var percentDeviations: [Double] = []

            for meterEvent in meterEvents {
                if let match = precisionEvents.first(where: {
                    abs($0.timestamp.timeIntervalSince(meterEvent.timestamp)) <= maxTimeDiff
                }) {
                    let precisionBG = match.bloodGlucose!
                    let otherBG = meterEvent.bloodGlucose!
                    guard precisionBG != 0 else { continue }
                    let pctDev = Double(otherBG - precisionBG) / Double(precisionBG)
                    percentDeviations.append(pctDev)
                }
            }

            if !percentDeviations.isEmpty {
                let avgPctDev = percentDeviations.reduce(0, +) / Double(percentDeviations.count)
                results.append(MeterDeviation(meterName: meter, averagePercentDeviation: avgPctDev))
            }
        }

        return results
    }

    /// Estimate the multi-meter average for a given reading.
    ///
    /// Formula (generalized):
    ///   For Precision Neo reading P, with N total meters and deviations d1..d(N-1):
    ///     MultiMeterAvg = P * (N + d1 + d2 + ... + d(N-1)) / N
    ///
    ///   For a non-reference meter M with deviation d_M:
    ///     P_estimated = M_reading / (1 + d_M)
    ///     MultiMeterAvg = P_estimated * (N + sum_all_deviations) / N
    ///
    /// Returns nil if there are no deviation data points.
    static func estimate(
        reading: Int,
        meterType: String,
        deviations: [MeterDeviation]
    ) -> Double? {
        guard !deviations.isEmpty else { return nil }

        let n = Double(deviations.count + 1) // reference meter + others
        let sumDeviations = deviations.map(\.averagePercentDeviation).reduce(0, +)

        let precisionEstimate: Double
        if meterType == referenceMeter {
            precisionEstimate = Double(reading)
        } else if let myDev = deviations.first(where: { $0.meterName == meterType }) {
            precisionEstimate = Double(reading) / (1.0 + myDev.averagePercentDeviation)
        } else {
            // Unknown meter — treat reading as reference-equivalent
            precisionEstimate = Double(reading)
        }

        return precisionEstimate * (n + sumDeviations) / n
    }
}

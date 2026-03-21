//
//  MeterDeviationView.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/21/26.
//

import SwiftUI
import SwiftData

struct MeterPair {
    let precisionReading: Int
    let otherReading: Int
    let deviation: Int       // other - precision
    let timestamp: Date
}

struct MeterDeviationResult: Identifiable {
    let id = UUID()
    let meterName: String
    let pairs: [MeterPair]
    let averageDeviation: Double
    let averagePercentDeviation: Double
}

struct MeterDeviationView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GlucoseEvent.timestamp) private var events: [GlucoseEvent]

    private var settings = SettingsManager.shared
    private var theme: AppTheme { settings.currentTheme }

    private let referenceMeter = "Precision Neo"
    private let maxTimeDiff: TimeInterval = 5 * 60  // 5 minutes

    private var deviationResults: [MeterDeviationResult] {
        // Get all BG measurements with a meter and a glucose value
        let bgEvents = events.filter {
            $0.eventType == "Blood Glucose Measurement"
            && $0.bloodGlucose != nil
            && $0.meterType != nil
            && !$0.meterType!.isEmpty
        }

        let precisionEvents = bgEvents.filter { $0.meterType == referenceMeter }
        let otherMeters = Set(bgEvents.compactMap(\.meterType)).filter { $0 != referenceMeter && $0 != "N/A" }

        var results: [MeterDeviationResult] = []

        for meter in otherMeters.sorted() {
            let meterEvents = bgEvents.filter { $0.meterType == meter }
            var pairs: [MeterPair] = []

            for meterEvent in meterEvents {
                // Find a Precision Neo reading within 5 minutes
                if let match = precisionEvents.first(where: {
                    abs($0.timestamp.timeIntervalSince(meterEvent.timestamp)) <= maxTimeDiff
                }) {
                    let precisionBG = match.bloodGlucose!
                    let otherBG = meterEvent.bloodGlucose!
                    pairs.append(MeterPair(
                        precisionReading: precisionBG,
                        otherReading: otherBG,
                        deviation: otherBG - precisionBG,
                        timestamp: meterEvent.timestamp
                    ))
                }
            }

            if !pairs.isEmpty {
                let avgDev = Double(pairs.map(\.deviation).reduce(0, +)) / Double(pairs.count)
                let avgPctDev: Double = {
                    let pcts = pairs.map { pair -> Double in
                        guard pair.precisionReading != 0 else { return 0 }
                        return (Double(pair.deviation) / Double(pair.precisionReading)) * 100.0
                    }
                    return pcts.reduce(0, +) / Double(pcts.count)
                }()

                results.append(MeterDeviationResult(
                    meterName: meter,
                    pairs: pairs,
                    averageDeviation: avgDev,
                    averagePercentDeviation: avgPctDev
                ))
            }
        }

        return results
    }

    var body: some View {
        NavigationStack {
            Group {
                if deviationResults.isEmpty {
                    ContentUnavailableView(
                        "No Comparison Data",
                        systemImage: "arrow.left.arrow.right",
                        description: Text("To compare meters, take readings with the Precision Neo and another meter within 5 minutes of each other.")
                    )
                } else {
                    List {
                        Section {
                            Text("Compares each meter against the **\(referenceMeter)** using readings taken within 5 minutes of each other.")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryTextColor)
                        }

                        ForEach(deviationResults) { result in
                            Section {
                                // Summary row
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(result.meterName)
                                        .font(.headline)
                                        .foregroundStyle(theme.eventTypeColor)

                                    HStack(spacing: 24) {
                                        VStack(alignment: .leading) {
                                            Text("Avg Deviation")
                                                .font(.caption2)
                                                .foregroundStyle(theme.secondaryTextColor)
                                            Text(String(format: "%+.1f mg/dL", result.averageDeviation))
                                                .font(.title3)
                                                .fontWeight(.bold)
                                                .foregroundStyle(deviationColor(result.averageDeviation))
                                        }

                                        VStack(alignment: .leading) {
                                            Text("Avg % Deviation")
                                                .font(.caption2)
                                                .foregroundStyle(theme.secondaryTextColor)
                                            Text(String(format: "%+.1f%%", result.averagePercentDeviation))
                                                .font(.title3)
                                                .fontWeight(.bold)
                                                .foregroundStyle(deviationColor(result.averagePercentDeviation))
                                        }

                                        VStack(alignment: .leading) {
                                            Text("Pairs")
                                                .font(.caption2)
                                                .foregroundStyle(theme.secondaryTextColor)
                                            Text("\(result.pairs.count)")
                                                .font(.title3)
                                                .fontWeight(.bold)
                                                .foregroundStyle(theme.eventTypeColor)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)

                                // Individual readings
                                ForEach(Array(result.pairs.enumerated()), id: \.offset) { _, pair in
                                    HStack {
                                        Text(pair.timestamp, format: .dateTime.month().day().hour().minute())
                                            .font(.caption2)
                                            .foregroundStyle(theme.secondaryTextColor)
                                        Spacer()
                                        Text("\(referenceMeter): \(pair.precisionReading)")
                                            .font(.caption)
                                            .foregroundStyle(theme.secondaryTextColor)
                                        Text("vs \(pair.otherReading)")
                                            .font(.caption)
                                            .foregroundStyle(theme.meterColor)
                                        Text(String(format: "(%+d)", pair.deviation))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(deviationColor(Double(pair.deviation)))
                                    }
                                }
                            }
                            .listRowBackground(theme.rowBackground)
                        }
                    }
                }
            }
            .navigationTitle("Meter Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func deviationColor(_ value: Double) -> Color {
        let absVal = abs(value)
        if absVal <= 5 { return .green }
        else if absVal <= 15 { return .yellow }
        else { return .red }
    }
}

#Preview {
    MeterDeviationView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}

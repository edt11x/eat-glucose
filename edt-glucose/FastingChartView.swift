//
//  FastingChartView.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/21/26.
//

import SwiftUI
import SwiftData
import Charts

struct FastingDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let glucose: Int
}

struct FastingChartView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GlucoseEvent.timestamp) private var events: [GlucoseEvent]

    private var settings = SettingsManager.shared
    private var theme: AppTheme { settings.currentTheme }

    private var fastingReadings: [FastingDataPoint] {
        let calendar = Calendar.current

        // Group BG measurement events by calendar day
        let bgEvents = events.filter {
            $0.eventType == "Blood Glucose Measurement" && $0.bloodGlucose != nil
        }

        let grouped = Dictionary(grouping: bgEvents) { event in
            calendar.startOfDay(for: event.timestamp)
        }

        var results: [FastingDataPoint] = []

        for (dayStart, dayEvents) in grouped {
            // 5:00 AM on this day
            let fiveAM = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: dayStart)!

            // Find the first BG reading at or after 5:00 AM
            let afterFiveAM = dayEvents
                .filter { $0.timestamp >= fiveAM }
                .sorted { $0.timestamp < $1.timestamp }

            if let first = afterFiveAM.first, let glucose = first.bloodGlucose {
                results.append(FastingDataPoint(date: dayStart, glucose: glucose))
            }
        }

        return results.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if fastingReadings.isEmpty {
                    ContentUnavailableView(
                        "No Fasting Data",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Fasting readings are the first blood glucose measurement after 5:00 AM each day.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("First BG reading after 5:00 AM each day")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryTextColor)
                                .padding(.horizontal)

                            Chart(fastingReadings) { point in
                                LineMark(
                                    x: .value("Date", point.date, unit: .day),
                                    y: .value("mg/dL", point.glucose)
                                )
                                .foregroundStyle(Color.blue)
                                .interpolationMethod(.catmullRom)

                                PointMark(
                                    x: .value("Date", point.date, unit: .day),
                                    y: .value("mg/dL", point.glucose)
                                )
                                .foregroundStyle(glucoseColor(for: point.glucose))
                                .symbolSize(30)
                            }
                            .chartYAxisLabel("mg/dL")
                            .chartYScale(domain: yDomain)
                            .frame(height: 300)
                            .padding()

                            // Summary stats
                            VStack(alignment: .leading, spacing: 8) {
                                let values = fastingReadings.map(\.glucose)
                                let avg = values.reduce(0, +) / max(values.count, 1)
                                let minVal = values.min() ?? 0
                                let maxVal = values.max() ?? 0

                                Text("Summary")
                                    .font(.headline)
                                    .foregroundStyle(theme.eventTypeColor)

                                HStack(spacing: 24) {
                                    StatBox(label: "Average", value: "\(avg)", unit: "mg/dL", theme: theme)
                                    StatBox(label: "Min", value: "\(minVal)", unit: "mg/dL", theme: theme)
                                    StatBox(label: "Max", value: "\(maxVal)", unit: "mg/dL", theme: theme)
                                    StatBox(label: "Days", value: "\(values.count)", unit: "", theme: theme)
                                }
                            }
                            .padding()

                            // Table of readings
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Readings")
                                    .font(.headline)
                                    .foregroundStyle(theme.eventTypeColor)
                                    .padding(.horizontal)

                                ForEach(fastingReadings.reversed()) { point in
                                    HStack {
                                        Text(point.date, format: .dateTime.month().day().year())
                                            .font(.caption)
                                            .foregroundStyle(theme.secondaryTextColor)
                                        Spacer()
                                        Text("\(point.glucose) mg/dL")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(glucoseColor(for: point.glucose))
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding(.bottom)
                        }
                    }
                }
            }
            .navigationTitle("Fasting BG")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var yDomain: ClosedRange<Int> {
        let values = fastingReadings.map(\.glucose)
        let minVal = max((values.min() ?? 60) - 10, 0)
        let maxVal = (values.max() ?? 200) + 10
        return minVal...maxVal
    }

    private func glucoseColor(for value: Int) -> Color {
        if value <= 69 || value > 180 {
            return .red
        } else if value > 120 {
            return .yellow
        } else {
            return .green
        }
    }
}

struct StatBox: View {
    let label: String
    let value: String
    let unit: String
    var theme: AppTheme = .dark

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(theme.eventTypeColor)
            if !unit.isEmpty {
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(theme.tertiaryTextColor)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(theme.secondaryTextColor)
        }
    }
}

#Preview {
    FastingChartView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}

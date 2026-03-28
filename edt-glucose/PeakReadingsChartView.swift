//
//  PeakReadingsChartView.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/28/26.
//

import SwiftUI
import SwiftData
import Charts

struct PeakReadingsChartView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GlucoseEvent.timestamp) private var events: [GlucoseEvent]

    private var settings = SettingsManager.shared
    private var theme: AppTheme { settings.currentTheme }

    private var peakReadings: [FastingDataPoint] {
        let calendar = Calendar.current
        let bgEvents = events.filter {
            $0.eventType == "Blood Glucose Measurement" && $0.bloodGlucose != nil
        }
        let grouped = Dictionary(grouping: bgEvents) { event in
            calendar.startOfDay(for: event.timestamp)
        }
        var results: [FastingDataPoint] = []
        for (dayStart, dayEvents) in grouped {
            if let peak = dayEvents.compactMap(\.bloodGlucose).max() {
                results.append(FastingDataPoint(date: dayStart, glucose: peak))
            }
        }
        return results.sorted { $0.date < $1.date }
    }

    private var averagePeak: Int {
        let values = peakReadings.map(\.glucose)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / values.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if peakReadings.isEmpty {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "chart.line.flattrend.xyaxis",
                        description: Text("No blood glucose readings available.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Highest BG reading per day")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryTextColor)
                                .padding(.horizontal)

                            Chart {
                                ForEach(peakReadings) { point in
                                    LineMark(
                                        x: .value("Date", point.date, unit: .day),
                                        y: .value("mg/dL", point.glucose)
                                    )
                                    .foregroundStyle(Color.red.opacity(0.8))
                                    .interpolationMethod(.catmullRom)

                                    PointMark(
                                        x: .value("Date", point.date, unit: .day),
                                        y: .value("mg/dL", point.glucose)
                                    )
                                    .foregroundStyle(glucoseColor(for: point.glucose))
                                    .symbolSize(30)
                                }

                                RuleMark(y: .value("Average", averagePeak))
                                    .foregroundStyle(.orange.opacity(0.7))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                    .annotation(position: .top, alignment: .leading) {
                                        Text("Avg Peak: \(averagePeak)")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                            }
                            .chartYAxisLabel("mg/dL")
                            .chartYScale(domain: yDomain)
                            .frame(height: 300)
                            .padding()

                            // Summary stats
                            VStack(alignment: .leading, spacing: 8) {
                                let values = peakReadings.map(\.glucose)
                                let minVal = values.min() ?? 0
                                let maxVal = values.max() ?? 0

                                Text("Summary")
                                    .font(.headline)
                                    .foregroundStyle(theme.eventTypeColor)

                                HStack(spacing: 24) {
                                    StatBox(label: "Avg Peak", value: "\(averagePeak)", unit: "mg/dL", theme: theme)
                                    StatBox(label: "Min Peak", value: "\(minVal)", unit: "mg/dL", theme: theme)
                                    StatBox(label: "Max Peak", value: "\(maxVal)", unit: "mg/dL", theme: theme)
                                    StatBox(label: "Days", value: "\(values.count)", unit: "", theme: theme)
                                }
                            }
                            .padding()

                            // Readings table
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Daily Peaks")
                                    .font(.headline)
                                    .foregroundStyle(theme.eventTypeColor)
                                    .padding(.horizontal)

                                ForEach(peakReadings.reversed()) { point in
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
            .navigationTitle("Peak Readings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var yDomain: ClosedRange<Int> {
        let values = peakReadings.map(\.glucose)
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

#Preview {
    PeakReadingsChartView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}

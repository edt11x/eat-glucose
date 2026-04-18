//
//  AverageBGChartView.swift
//  edt-glucose
//
//  Created by Edward Thompson on 4/18/26.
//

import SwiftUI
import SwiftData
import Charts

struct AverageBGChartView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GlucoseEvent.timestamp) private var events: [GlucoseEvent]

    private var settings = SettingsManager.shared
    private var theme: AppTheme { settings.currentTheme }

    private var meterDeviations: [MultiMeterEstimator.MeterDeviation] {
        MultiMeterEstimator.computeDeviations(from: events)
    }

    private var averageReadings: [FastingDataPoint] {
        let calendar = Calendar.current
        let bgEvents = events.filter {
            $0.eventType == "Blood Glucose Measurement" && $0.bloodGlucose != nil
        }
        let grouped = Dictionary(grouping: bgEvents) { event in
            calendar.startOfDay(for: event.timestamp)
        }
        var results: [FastingDataPoint] = []
        for (dayStart, dayEvents) in grouped {
            let values = dayEvents.compactMap(\.bloodGlucose)
            guard !values.isEmpty else { continue }
            let avg = values.reduce(0, +) / values.count
            results.append(FastingDataPoint(date: dayStart, glucose: avg))
        }
        return results.sorted { $0.date < $1.date }
    }

    private var averageMultiMeterReadings: [FastingDataPoint] {
        let calendar = Calendar.current
        let bgEvents = events.filter {
            $0.eventType == "Blood Glucose Measurement" && $0.bloodGlucose != nil
        }
        let grouped = Dictionary(grouping: bgEvents) { event in
            calendar.startOfDay(for: event.timestamp)
        }
        var results: [FastingDataPoint] = []
        for (dayStart, dayEvents) in grouped {
            var estimates: [Double] = []
            for event in dayEvents {
                if let bg = event.bloodGlucose, let meter = event.meterType,
                   let estimate = MultiMeterEstimator.estimate(reading: bg, meterType: meter, deviations: meterDeviations) {
                    estimates.append(estimate)
                }
            }
            if !estimates.isEmpty {
                let avg = estimates.reduce(0, +) / Double(estimates.count)
                results.append(FastingDataPoint(date: dayStart, glucose: Int(avg.rounded())))
            }
        }
        return results.sorted { $0.date < $1.date }
    }

    private var overallAverage: Int {
        let values = averageReadings.map(\.glucose)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / values.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if averageReadings.isEmpty {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "chart.xyaxis.line",
                        description: Text("No blood glucose readings available.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Average of all BG readings per day")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryTextColor)
                                .padding(.horizontal)

                            Chart {
                                ForEach(averageReadings) { point in
                                    LineMark(
                                        x: .value("Date", point.date, unit: .day),
                                        y: .value("mg/dL", point.glucose),
                                        series: .value("Series", "Average BG")
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

                                RuleMark(y: .value("Average", overallAverage))
                                    .foregroundStyle(.orange.opacity(0.7))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                    .annotation(position: .top, alignment: .leading) {
                                        Text("Avg: \(overallAverage)")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }

                                if !averageMultiMeterReadings.isEmpty {
                                    ForEach(averageMultiMeterReadings) { point in
                                        LineMark(
                                            x: .value("Date", point.date, unit: .day),
                                            y: .value("mg/dL", point.glucose),
                                            series: .value("Series", "Multi-Meter")
                                        )
                                        .foregroundStyle(.orange)
                                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 2]))
                                        .interpolationMethod(.catmullRom)
                                    }
                                }
                            }
                            .chartYAxisLabel("mg/dL")
                            .chartYScale(domain: yDomain)
                            .frame(height: 300)
                            .padding()

                            // Legend
                            if !averageMultiMeterReadings.isEmpty {
                                HStack(spacing: 16) {
                                    HStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.blue)
                                            .frame(width: 16, height: 3)
                                        Text("Average BG")
                                    }
                                    HStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.orange)
                                            .frame(width: 16, height: 3)
                                        Text("Multi-Meter Est.")
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(theme.secondaryTextColor)
                                .padding(.horizontal)
                            }

                            // Summary stats
                            VStack(alignment: .leading, spacing: 8) {
                                let values = averageReadings.map(\.glucose)
                                let minVal = values.min() ?? 0
                                let maxVal = values.max() ?? 0

                                Text("Summary")
                                    .font(.headline)
                                    .foregroundStyle(theme.eventTypeColor)

                                HStack(spacing: 24) {
                                    StatBox(label: "Average", value: "\(overallAverage)", unit: "mg/dL", theme: theme)
                                    StatBox(label: "Min", value: "\(minVal)", unit: "mg/dL", theme: theme)
                                    StatBox(label: "Max", value: "\(maxVal)", unit: "mg/dL", theme: theme)
                                    StatBox(label: "Days", value: "\(values.count)", unit: "", theme: theme)
                                }
                            }
                            .padding()

                            // Readings table
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Daily Averages")
                                    .font(.headline)
                                    .foregroundStyle(theme.eventTypeColor)
                                    .padding(.horizontal)

                                ForEach(averageReadings.reversed()) { point in
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
            .navigationTitle("Average BG")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var yDomain: ClosedRange<Int> {
        let values = averageReadings.map(\.glucose)
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
    AverageBGChartView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}

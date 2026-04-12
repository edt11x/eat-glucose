//
//  BedtimeChartView.swift
//  edt-glucose
//
//  Created by Edward Thompson on 4/11/26.
//

import SwiftUI
import SwiftData
import Charts

struct BedtimeDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let glucose: Int
}

struct BedtimeChartView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GlucoseEvent.timestamp) private var events: [GlucoseEvent]

    private var settings = SettingsManager.shared
    private var theme: AppTheme { settings.currentTheme }

    private var meterDeviations: [MultiMeterEstimator.MeterDeviation] {
        MultiMeterEstimator.computeDeviations(from: events)
    }

    private var bedtimeMultiMeterReadings: [BedtimeDataPoint] {
        let calendar = Calendar.current
        let bgEvents = events.filter {
            $0.eventType == "Blood Glucose Measurement" && $0.bloodGlucose != nil
        }
        let grouped = Dictionary(grouping: bgEvents) { event in
            calendar.startOfDay(for: event.timestamp)
        }
        var results: [BedtimeDataPoint] = []
        for (dayStart, dayEvents) in grouped {
            let fiveAM = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: dayStart)!
            let beforeFiveAM = dayEvents
                .filter { $0.timestamp < fiveAM }
                .sorted { $0.timestamp > $1.timestamp }
            // Also include readings from the previous evening (after 5 AM previous day through midnight)
            let previousDayEvents = bgEvents.filter { event in
                let eventDay = calendar.startOfDay(for: event.timestamp)
                let previousDay = calendar.date(byAdding: .day, value: -1, to: dayStart)!
                return eventDay == previousDay && event.timestamp >= calendar.date(bySettingHour: 5, minute: 0, second: 0, of: previousDay)!
            }
            // The bedtime reading is the last BG reading before 5 AM on this day
            // This could be late the previous evening or early this morning (before 5 AM)
            let allCandidates = (beforeFiveAM + previousDayEvents)
                .sorted { $0.timestamp > $1.timestamp }
            if let last = allCandidates.first,
               let bg = last.bloodGlucose,
               let meter = last.meterType,
               let estimate = MultiMeterEstimator.estimate(reading: bg, meterType: meter, deviations: meterDeviations) {
                results.append(BedtimeDataPoint(date: dayStart, glucose: Int(estimate.rounded())))
            }
        }
        return results.sorted { $0.date < $1.date }
    }

    private var bedtimeReadings: [BedtimeDataPoint] {
        let calendar = Calendar.current

        let bgEvents = events.filter {
            $0.eventType == "Blood Glucose Measurement" && $0.bloodGlucose != nil
        }

        let grouped = Dictionary(grouping: bgEvents) { event in
            calendar.startOfDay(for: event.timestamp)
        }

        var results: [BedtimeDataPoint] = []

        for (dayStart, dayEvents) in grouped {
            // 5:00 AM on this day — the cutoff for "fasting" reading
            let fiveAM = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: dayStart)!

            // Readings before 5 AM on this calendar day (e.g., 12 AM - 4:59 AM)
            let beforeFiveAM = dayEvents
                .filter { $0.timestamp < fiveAM }
                .sorted { $0.timestamp > $1.timestamp }

            // Also look at previous evening readings (previous calendar day, after 5 AM)
            let previousDay = calendar.date(byAdding: .day, value: -1, to: dayStart)!
            let previousDayEvents = bgEvents.filter { event in
                let eventDay = calendar.startOfDay(for: event.timestamp)
                return eventDay == previousDay && event.timestamp >= calendar.date(bySettingHour: 5, minute: 0, second: 0, of: previousDay)!
            }

            // Combine: last reading before 5 AM today is the bedtime reading
            // Priority: readings from before 5 AM today, then previous evening
            let allCandidates = (beforeFiveAM + previousDayEvents)
                .sorted { $0.timestamp > $1.timestamp }

            if let last = allCandidates.first, let glucose = last.bloodGlucose {
                results.append(BedtimeDataPoint(date: dayStart, glucose: glucose))
            }
        }

        return results.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if bedtimeReadings.isEmpty {
                    ContentUnavailableView(
                        "No Bedtime Data",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Bedtime readings are the last blood glucose measurement before 5:00 AM each day.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Last BG reading before 5:00 AM each day")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryTextColor)
                                .padding(.horizontal)

                            Chart {
                                ForEach(bedtimeReadings) { point in
                                    LineMark(
                                        x: .value("Date", point.date, unit: .day),
                                        y: .value("mg/dL", point.glucose)
                                    )
                                    .foregroundStyle(Color.purple)
                                    .interpolationMethod(.catmullRom)

                                    PointMark(
                                        x: .value("Date", point.date, unit: .day),
                                        y: .value("mg/dL", point.glucose)
                                    )
                                    .foregroundStyle(glucoseColor(for: point.glucose))
                                    .symbolSize(30)
                                }

                                RuleMark(y: .value("Average", averageBedtimeGlucose))
                                    .foregroundStyle(.orange.opacity(0.7))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                    .annotation(position: .top, alignment: .leading) {
                                        Text("Avg: \(averageBedtimeGlucose)")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }

                                if !bedtimeMultiMeterReadings.isEmpty {
                                    ForEach(bedtimeMultiMeterReadings) { point in
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
                            if !bedtimeMultiMeterReadings.isEmpty {
                                HStack(spacing: 16) {
                                    HStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.purple)
                                            .frame(width: 16, height: 3)
                                        Text("Bedtime BG")
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
                                let values = bedtimeReadings.map(\.glucose)
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

                                ForEach(bedtimeReadings.reversed()) { point in
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
            .navigationTitle("Bedtime BG")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var averageBedtimeGlucose: Int {
        let values = bedtimeReadings.map(\.glucose)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / values.count
    }

    private var yDomain: ClosedRange<Int> {
        let values = bedtimeReadings.map(\.glucose)
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
    BedtimeChartView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}

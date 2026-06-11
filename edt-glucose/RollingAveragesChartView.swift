//
//  RollingAveragesChartView.swift
//  edt-glucose
//

import SwiftUI
import SwiftData
import Charts

struct RollingAveragePoint: Identifiable {
    let id = UUID()
    let date: Date
    let glucose: Double
    let windowDays: Int
}

struct RollingAveragesChartView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GlucoseEvent.timestamp) private var events: [GlucoseEvent]
    @State private var timeRange: ChartTimeRange = .month

    private var settings = SettingsManager.shared
    private var theme: AppTheme { settings.currentTheme }

    private let windows = [7, 14, 30, 90]

    private func color(for window: Int) -> Color {
        switch window {
        case 7:  return .green
        case 14: return .yellow
        case 30: return .blue
        case 90: return .purple
        default: return .gray
        }
    }

    private var meterDeviations: [MultiMeterEstimator.MeterDeviation] {
        MultiMeterEstimator.computeDeviations(from: events)
    }

    // (date, BG) for each BG reading
    private var bgReadings: [(Date, Double)] {
        events
            .filter { $0.eventType == "Blood Glucose Measurement" && $0.bloodGlucose != nil }
            .map { ($0.timestamp, Double($0.bloodGlucose!)) }
    }

    // (date, multi-meter-adjusted BG) for each BG reading that has a meter type with deviation data
    private var bgMultiMeterReadings: [(Date, Double)] {
        let deviations = meterDeviations
        return events.compactMap { event in
            guard event.eventType == "Blood Glucose Measurement",
                  let bg = event.bloodGlucose,
                  let meter = event.meterType,
                  let estimate = MultiMeterEstimator.estimate(
                      reading: bg, meterType: meter, deviations: deviations
                  ) else { return nil }
            return (event.timestamp, estimate)
        }
    }

    private func rollingPoints(from source: [(Date, Double)]) -> [RollingAveragePoint] {
        let calendar = Calendar.current
        guard !source.isEmpty else { return [] }

        let cutoff = timeRange.startDate()
        let dayStarts = Set(source.map { calendar.startOfDay(for: $0.0) })
            .filter { $0 >= cutoff }
            .sorted()
        var results: [RollingAveragePoint] = []

        for day in dayStarts {
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: day)!
            for window in windows {
                let windowStart = calendar.date(byAdding: .day, value: -window, to: day)!
                let values = source
                    .filter { $0.0 >= windowStart && $0.0 < dayEnd }
                    .map(\.1)
                guard values.count >= 3 else { continue }
                let avg = values.reduce(0, +) / Double(values.count)
                results.append(RollingAveragePoint(date: day, glucose: avg, windowDays: window))
            }
        }
        return results
    }

    private var rollingPoints: [RollingAveragePoint] { rollingPoints(from: bgReadings) }

    private var rollingMultiMeterPoints: [RollingAveragePoint] {
        rollingPoints(from: bgMultiMeterReadings)
    }

    private var yDomain: ClosedRange<Double> {
        let values = rollingPoints.map(\.glucose) + rollingMultiMeterPoints.map(\.glucose)
        let minVal = max((values.min() ?? 60) - 10, 0)
        let maxVal = (values.max() ?? 200) + 10
        return minVal...maxVal
    }

    private func latestAverage(for window: Int, multiMeter: Bool = false) -> Double? {
        (multiMeter ? rollingMultiMeterPoints : rollingPoints)
            .filter { $0.windowDays == window }
            .last?
            .glucose
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ChartTimeRangePicker(selection: $timeRange)
                    .padding(.top, 8)
                if rollingPoints.isEmpty {
                    ContentUnavailableView(
                        "Not Enough Data",
                        systemImage: "chart.line.uptrend.xyaxis.circle.fill",
                        description: Text("Need at least 3 blood glucose readings to compute rolling averages.")
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Trailing 7, 14, 30, and 90-day average BG, computed per day.")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryTextColor)
                                .padding(.horizontal)

                            Chart {
                                ForEach(rollingPoints) { point in
                                    LineMark(
                                        x: .value("Date", point.date, unit: .day),
                                        y: .value("mg/dL", point.glucose),
                                        series: .value("Window", "\(point.windowDays)d")
                                    )
                                    .foregroundStyle(color(for: point.windowDays))
                                    .interpolationMethod(.catmullRom)
                                }

                                // Multi-meter-adjusted overlay (dashed orange per window)
                                ForEach(rollingMultiMeterPoints) { point in
                                    LineMark(
                                        x: .value("Date", point.date, unit: .day),
                                        y: .value("mg/dL", point.glucose),
                                        series: .value("Window", "MM-\(point.windowDays)d")
                                    )
                                    .foregroundStyle(.orange)
                                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 2]))
                                    .interpolationMethod(.catmullRom)
                                }
                            }
                            .chartYAxisLabel("mg/dL")
                            .chartYScale(domain: yDomain)
                            .frame(height: 320)
                            .padding()

                            // Legend
                            HStack(spacing: 16) {
                                ForEach(windows, id: \.self) { w in
                                    HStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(color(for: w))
                                            .frame(width: 16, height: 3)
                                        Text("\(w)d")
                                            .font(.caption2)
                                            .foregroundStyle(theme.secondaryTextColor)
                                    }
                                }
                                HStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.orange)
                                        .frame(width: 16, height: 3)
                                    Text("MM Est.")
                                        .font(.caption2)
                                        .foregroundStyle(theme.secondaryTextColor)
                                }
                            }
                            .padding(.horizontal)

                            // Latest values
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Latest")
                                    .font(.headline)
                                    .foregroundStyle(theme.eventTypeColor)
                                HStack(spacing: 24) {
                                    ForEach(windows, id: \.self) { w in
                                        StatBox(
                                            label: "\(w)-day",
                                            value: latestAverage(for: w).map { String(format: "%.0f", $0) } ?? "—",
                                            unit: "mg/dL",
                                            theme: theme,
                                            valueColor: color(for: w)
                                        )
                                    }
                                }

                                if !rollingMultiMeterPoints.isEmpty {
                                    HStack(spacing: 24) {
                                        ForEach(windows, id: \.self) { w in
                                            StatBox(
                                                label: "\(w)d (MM)",
                                                value: latestAverage(for: w, multiMeter: true)
                                                    .map { String(format: "%.0f", $0) } ?? "—",
                                                unit: "mg/dL",
                                                theme: theme,
                                                valueColor: .orange
                                            )
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Rolling Averages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    RollingAveragesChartView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}

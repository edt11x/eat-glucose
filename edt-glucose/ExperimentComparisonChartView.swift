//
//  ExperimentComparisonChartView.swift
//  edt-glucose
//
//  Created by Edward Thompson on 4/18/26.
//

import SwiftUI
import SwiftData
import Charts

struct ExperimentDataPoint: Identifiable {
    let id = UUID()
    let dayOffset: Int // days from start of period
    let glucose: Int
    let series: String // "Before" or "During"
}

struct ExperimentComparisonChartView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GlucoseEvent.timestamp) private var events: [GlucoseEvent]

    private var settings = SettingsManager.shared
    private var theme: AppTheme { settings.currentTheme }

    @State private var selectedExperiment: String = ""
    @State private var comparisonMetric: ComparisonMetric = .averageBG

    enum ComparisonMetric: String, CaseIterable {
        case fastingBG = "Fasting BG"
        case averageBG = "Average BG"
    }

    // Date range of the experiment (first event to last event)
    private var experimentDateRange: (start: Date, end: Date)? {
        guard !selectedExperiment.isEmpty else { return nil }
        let expEvents = events
            .filter { $0.eventType == selectedExperiment }
            .sorted { $0.timestamp < $1.timestamp }
        guard let first = expEvents.first, let last = expEvents.last else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: first.timestamp)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last.timestamp))!
        return (start, end)
    }

    private var experimentDurationDays: Int {
        guard let range = experimentDateRange else { return 0 }
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: range.start, to: range.end).day ?? 0
    }

    // Before period: same duration ending at experiment start
    private var beforeDateRange: (start: Date, end: Date)? {
        guard let expRange = experimentDateRange else { return nil }
        let calendar = Calendar.current
        let duration = experimentDurationDays
        let beforeStart = calendar.date(byAdding: .day, value: -duration, to: expRange.start)!
        return (beforeStart, expRange.start)
    }

    // Compute daily BG values for a given date range using the selected metric
    private func dailyValues(in range: (start: Date, end: Date)) -> [FastingDataPoint] {
        let calendar = Calendar.current
        let bgEvents = events.filter {
            $0.eventType == "Blood Glucose Measurement"
            && $0.bloodGlucose != nil
            && $0.timestamp >= range.start
            && $0.timestamp < range.end
        }
        let grouped = Dictionary(grouping: bgEvents) { event in
            calendar.startOfDay(for: event.timestamp)
        }

        var results: [FastingDataPoint] = []

        switch comparisonMetric {
        case .fastingBG:
            for (dayStart, dayEvents) in grouped {
                let fiveAM = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: dayStart)!
                let afterFiveAM = dayEvents
                    .filter { $0.timestamp >= fiveAM }
                    .sorted { $0.timestamp < $1.timestamp }
                if let first = afterFiveAM.first, let glucose = first.bloodGlucose {
                    results.append(FastingDataPoint(date: dayStart, glucose: glucose))
                }
            }
        case .averageBG:
            for (dayStart, dayEvents) in grouped {
                let values = dayEvents.compactMap(\.bloodGlucose)
                guard !values.isEmpty else { continue }
                let avg = values.reduce(0, +) / values.count
                results.append(FastingDataPoint(date: dayStart, glucose: avg))
            }
        }

        return results.sorted { $0.date < $1.date }
    }

    private var chartData: [ExperimentDataPoint] {
        guard let expRange = experimentDateRange, let beforeRange = beforeDateRange else { return [] }
        let calendar = Calendar.current

        let beforeValues = dailyValues(in: beforeRange)
        let duringValues = dailyValues(in: expRange)

        var points: [ExperimentDataPoint] = []

        for point in beforeValues {
            let offset = calendar.dateComponents([.day], from: beforeRange.start, to: point.date).day ?? 0
            points.append(ExperimentDataPoint(dayOffset: offset, glucose: point.glucose, series: "Before"))
        }

        for point in duringValues {
            let offset = calendar.dateComponents([.day], from: expRange.start, to: point.date).day ?? 0
            points.append(ExperimentDataPoint(dayOffset: offset, glucose: point.glucose, series: "During"))
        }

        return points
    }

    private var beforeAvg: Int {
        let values = chartData.filter { $0.series == "Before" }.map(\.glucose)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / values.count
    }

    private var duringAvg: Int {
        let values = chartData.filter { $0.series == "During" }.map(\.glucose)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / values.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Experiment picker
                    if settings.experiments.isEmpty {
                        ContentUnavailableView(
                            "No Experiments",
                            systemImage: "flask",
                            description: Text("Add experiments in Settings first.")
                        )
                    } else {
                        Picker("Experiment", selection: $selectedExperiment) {
                            Text("Select...").tag("")
                            ForEach(settings.experiments, id: \.self) { exp in
                                Text(exp).tag(exp)
                            }
                        }
                        .padding(.horizontal)

                        Picker("Metric", selection: $comparisonMetric) {
                            ForEach(ComparisonMetric.allCases, id: \.self) { metric in
                                Text(metric.rawValue).tag(metric)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        if !selectedExperiment.isEmpty {
                            if let expRange = experimentDateRange, let beforeRange = beforeDateRange {
                                // Date range info
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Before: \(formatDate(beforeRange.start)) – \(formatDate(expRange.start))")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                    Text("During: \(formatDate(expRange.start)) – \(formatDate(expRange.end))")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                    Text("Duration: \(experimentDurationDays) days")
                                        .font(.caption)
                                        .foregroundStyle(theme.secondaryTextColor)
                                }
                                .padding(.horizontal)

                                if chartData.isEmpty {
                                    Text("No BG data available for these date ranges.")
                                        .font(.caption)
                                        .foregroundStyle(theme.tertiaryTextColor)
                                        .padding(.horizontal)
                                } else {
                                    Chart {
                                        ForEach(chartData) { point in
                                            LineMark(
                                                x: .value("Day", point.dayOffset),
                                                y: .value("mg/dL", point.glucose),
                                                series: .value("Period", point.series)
                                            )
                                            .foregroundStyle(point.series == "Before" ? Color.gray : Color.green)
                                            .interpolationMethod(.catmullRom)

                                            PointMark(
                                                x: .value("Day", point.dayOffset),
                                                y: .value("mg/dL", point.glucose)
                                            )
                                            .foregroundStyle(point.series == "Before" ? Color.gray : Color.green)
                                            .symbolSize(20)
                                        }

                                        // Average lines
                                        if beforeAvg > 0 {
                                            RuleMark(y: .value("Before Avg", beforeAvg))
                                                .foregroundStyle(.gray.opacity(0.5))
                                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                                .annotation(position: .top, alignment: .leading) {
                                                    Text("Before: \(beforeAvg)")
                                                        .font(.caption2)
                                                        .foregroundStyle(.gray)
                                                }
                                        }
                                        if duringAvg > 0 {
                                            RuleMark(y: .value("During Avg", duringAvg))
                                                .foregroundStyle(.green.opacity(0.5))
                                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                                .annotation(position: .bottom, alignment: .trailing) {
                                                    Text("During: \(duringAvg)")
                                                        .font(.caption2)
                                                        .foregroundStyle(.green)
                                                }
                                        }
                                    }
                                    .chartYAxisLabel("mg/dL")
                                    .chartXAxisLabel("Days from start")
                                    .frame(height: 300)
                                    .padding()

                                    // Legend
                                    HStack(spacing: 16) {
                                        legendItem(color: .gray, label: "Before Experiment")
                                        legendItem(color: .green, label: "During Experiment")
                                    }
                                    .font(.caption2)
                                    .padding(.horizontal)

                                    // Summary comparison
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Comparison")
                                            .font(.headline)
                                            .foregroundStyle(theme.eventTypeColor)

                                        let beforeValues = chartData.filter { $0.series == "Before" }.map(\.glucose)
                                        let duringValues = chartData.filter { $0.series == "During" }.map(\.glucose)
                                        let delta = duringAvg - beforeAvg

                                        HStack(spacing: 16) {
                                            VStack(spacing: 4) {
                                                Text("Before")
                                                    .font(.caption2)
                                                    .foregroundStyle(.gray)
                                                Text("\(beforeAvg)")
                                                    .font(.title3).fontWeight(.bold)
                                                    .foregroundStyle(.gray)
                                                Text("\(beforeValues.count) days")
                                                    .font(.caption2)
                                                    .foregroundStyle(theme.tertiaryTextColor)
                                            }

                                            VStack(spacing: 4) {
                                                Text("During")
                                                    .font(.caption2)
                                                    .foregroundStyle(.green)
                                                Text("\(duringAvg)")
                                                    .font(.title3).fontWeight(.bold)
                                                    .foregroundStyle(.green)
                                                Text("\(duringValues.count) days")
                                                    .font(.caption2)
                                                    .foregroundStyle(theme.tertiaryTextColor)
                                            }

                                            VStack(spacing: 4) {
                                                Text("Change")
                                                    .font(.caption2)
                                                    .foregroundStyle(theme.secondaryTextColor)
                                                Text("\(delta > 0 ? "+" : "")\(delta)")
                                                    .font(.title3).fontWeight(.bold)
                                                    .foregroundStyle(delta < 0 ? .green : delta > 0 ? .red : theme.eventTypeColor)
                                                Text("mg/dL")
                                                    .font(.caption2)
                                                    .foregroundStyle(theme.tertiaryTextColor)
                                            }
                                        }
                                    }
                                    .padding()
                                }
                            } else {
                                Text("No experiment events recorded for \"\(selectedExperiment)\" yet.")
                                    .font(.caption)
                                    .foregroundStyle(theme.tertiaryTextColor)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Experiment Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if selectedExperiment.isEmpty, let first = settings.experiments.first {
                    selectedExperiment = first
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 16, height: 3)
            Text(label)
                .foregroundStyle(theme.secondaryTextColor)
        }
    }
}

#Preview {
    ExperimentComparisonChartView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}

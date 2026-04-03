//
//  BestMealSpacingView.swift
//  edt-glucose
//
//  Created by Edward Thompson on 4/3/26.
//

import SwiftUI
import SwiftData
import Charts

struct DailyMealSpacingPoint: Identifiable {
    let id = UUID()
    let date: Date
    let avgDailyBG: Double
    let avgTimeBetweenMeals: Double // hours
}

struct BestMealSpacingView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GlucoseEvent.timestamp) private var events: [GlucoseEvent]

    private var settings = SettingsManager.shared
    private var theme: AppTheme { settings.currentTheme }

    private var scatterPoints: [DailyMealSpacingPoint] {
        let calendar = Calendar.current
        let bgEvents = events.filter {
            $0.eventType == "Blood Glucose Measurement" && $0.bloodGlucose != nil
        }
        let mealEvents = events.filter { $0.eventType == "Start of Meal" }

        let bgByDay = Dictionary(grouping: bgEvents) { calendar.startOfDay(for: $0.timestamp) }
        let mealsByDay = Dictionary(grouping: mealEvents) { calendar.startOfDay(for: $0.timestamp) }

        // Only include complete days that have both BG data and meals,
        // and where the next day also has BG data
        let allDays = Set(bgByDay.keys).intersection(Set(mealsByDay.keys)).sorted()
        var results: [DailyMealSpacingPoint] = []

        for day in allDays {
            guard let dayBGs = bgByDay[day], !dayBGs.isEmpty,
                  let dayMeals = mealsByDay[day], !dayMeals.isEmpty else { continue }

            let sortedMeals = dayMeals.sorted { $0.timestamp < $1.timestamp }

            // Find first BG of NEXT day
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
            guard let nextDayBGs = bgByDay[nextDay]?.sorted(by: { $0.timestamp < $1.timestamp }),
                  let firstBGNextDay = nextDayBGs.first,
                  let nextDayBGValue = firstBGNextDay.bloodGlucose else { continue }

            // Avg daily BG = (sum of day's BGs + first BG next day) / (count + 1)
            let dayBGValues = dayBGs.compactMap(\.bloodGlucose)
            let totalBG = Double(dayBGValues.reduce(0, +) + nextDayBGValue)
            let avgBG = totalBG / Double(dayBGValues.count + 1)

            // Time gaps: between consecutive meals + last meal to first BG next day
            var gaps: [TimeInterval] = []
            for i in 1..<sortedMeals.count {
                gaps.append(sortedMeals[i].timestamp.timeIntervalSince(sortedMeals[i-1].timestamp))
            }
            gaps.append(firstBGNextDay.timestamp.timeIntervalSince(sortedMeals.last!.timestamp))

            // Average = sum of gaps / N (N gaps from N meals)
            let avgGapHours = (gaps.reduce(0, +) / Double(gaps.count)) / 3600.0

            results.append(DailyMealSpacingPoint(
                date: day,
                avgDailyBG: avgBG,
                avgTimeBetweenMeals: avgGapHours
            ))
        }

        return results
    }

    private var bestDay: DailyMealSpacingPoint? {
        scatterPoints.min(by: { $0.avgDailyBG < $1.avgDailyBG })
    }

    private func mealTimesForDay(_ date: Date) -> [GlucoseEvent] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        return events
            .filter { $0.eventType == "Start of Meal" && $0.timestamp >= dayStart && $0.timestamp < dayEnd }
            .sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        NavigationStack {
            Group {
                if scatterPoints.isEmpty {
                    ContentUnavailableView(
                        "Not Enough Data",
                        systemImage: "chart.dots.scatter",
                        description: Text("Need complete days with meals, BG data, and next-day BG data.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Each point is one complete day. Lower BG with optimal meal spacing.")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryTextColor)
                                .padding(.horizontal)

                            Chart {
                                ForEach(scatterPoints) { point in
                                    PointMark(
                                        x: .value("Avg Hours Between Meals", point.avgTimeBetweenMeals),
                                        y: .value("Avg Daily BG", point.avgDailyBG)
                                    )
                                    .foregroundStyle(glucoseColor(for: Int(point.avgDailyBG)))
                                    .symbolSize(50)
                                }
                            }
                            .chartYAxisLabel("Avg Daily BG (mg/dL)")
                            .chartXAxisLabel("Avg Hours Between Meals")
                            .frame(height: 300)
                            .padding()

                            // Formula note
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Calculation")
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundStyle(theme.eventTypeColor)
                                Text("Daily Avg BG = (sum of day's BG + first BG next day) / (count + 1)")
                                    .font(.caption2)
                                    .foregroundStyle(theme.tertiaryTextColor)
                                Text("Avg Meal Spacing = sum of N gaps / N, where gaps are between consecutive meals and last meal to first BG next day")
                                    .font(.caption2)
                                    .foregroundStyle(theme.tertiaryTextColor)
                            }
                            .padding(.horizontal)

                            // Best day info
                            if let best = bestDay {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Best Day")
                                        .font(.headline)
                                        .foregroundStyle(theme.eventTypeColor)

                                    HStack(spacing: 24) {
                                        StatBox(label: "Date", value: formatShortDate(best.date), unit: "", theme: theme)
                                        StatBox(label: "Avg BG", value: String(format: "%.0f", best.avgDailyBG), unit: "mg/dL", theme: theme)
                                        StatBox(label: "Meal Spacing", value: String(format: "%.1f", best.avgTimeBetweenMeals), unit: "hours", theme: theme)
                                    }

                                    Text("Meals that day:")
                                        .font(.caption).fontWeight(.semibold)
                                        .foregroundStyle(theme.secondaryTextColor)

                                    let meals = mealTimesForDay(best.date)
                                    ForEach(meals, id: \.timestamp) { meal in
                                        HStack(spacing: 8) {
                                            Text(meal.timestamp, format: .dateTime.hour().minute())
                                                .font(.caption)
                                                .foregroundStyle(theme.secondaryTextColor)
                                            if let type = meal.mealType {
                                                Text(type)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            }
                                            if let food = meal.foodDescription {
                                                Text(food)
                                                    .font(.caption2)
                                                    .foregroundStyle(theme.tertiaryTextColor)
                                            }
                                        }
                                    }
                                }
                                .padding()
                            }

                            // All days table
                            VStack(alignment: .leading, spacing: 4) {
                                Text("All Days")
                                    .font(.headline)
                                    .foregroundStyle(theme.eventTypeColor)
                                    .padding(.horizontal)

                                ForEach(scatterPoints.sorted(by: { $0.avgDailyBG < $1.avgDailyBG })) { point in
                                    HStack {
                                        Text(point.date, format: .dateTime.month().day())
                                            .font(.caption)
                                            .foregroundStyle(theme.secondaryTextColor)
                                        Spacer()
                                        Text(String(format: "BG: %.0f", point.avgDailyBG))
                                            .font(.caption)
                                            .foregroundStyle(glucoseColor(for: Int(point.avgDailyBG)))
                                        Text(String(format: "%.1fh spacing", point.avgTimeBetweenMeals))
                                            .font(.caption)
                                            .foregroundStyle(theme.tertiaryTextColor)
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
            .navigationTitle("Best Meal Spacing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
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
    BestMealSpacingView()
        .modelContainer(for: GlucoseEvent.self, inMemory: true)
}

import Combine
import Foundation
import SwiftData

struct DailyCalorieSummary: Identifiable, Equatable {
    var id: Date { date }

    let date: Date
    let consumedCalories: Int
    let targetCalories: Int
    let hasLoggedFood: Bool
}

enum StatisticsRange: String, CaseIterable, Identifiable {
    case week
    case month
    case threeMonths

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .week:
            return "7D"
        case .month:
            return "1M"
        case .threeMonths:
            return "3M"
        }
    }

    var dayCount: Int {
        switch self {
        case .week:
            return 7
        case .month:
            return 30
        case .threeMonths:
            return 90
        }
    }

    var chartTitle: String {
        switch self {
        case .week:
            return "Last 7 Days"
        case .month:
            return "Last Month"
        case .threeMonths:
            return "Last 3 Months"
        }
    }
}

@MainActor
final class StatisticsViewModel: ObservableObject {
    @Published private(set) var summaries: [DailyCalorieSummary] = []
    @Published private(set) var dailyGoalTarget = 2_000
    @Published private(set) var maintenanceCalories: Int?
    @Published private(set) var errorMessage: String?

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    var totalCalories: Int {
        summaries.reduce(0) { total, summary in
            total + summary.consumedCalories
        }
    }

    var averageCalories: Int {
        guard !loggedSummaries.isEmpty else {
            return 0
        }

        return totalCalories / loggedSummaries.count
    }

    var daysCompleted: Int {
        summaries.filter { summary in
            summary.hasLoggedFood && summary.consumedCalories <= summary.targetCalories
        }.count
    }

    var daysMissed: Int {
        summaries.count - daysCompleted
    }

    var averageDeficitPerDay: Int {
        guard !loggedSummaries.isEmpty else {
            return 0
        }

        return totalDeficit / loggedSummaries.count
    }

    var averageSurplusPerDay: Int {
        guard !loggedSummaries.isEmpty else {
            return 0
        }

        return totalSurplus / loggedSummaries.count
    }

    var totalDeficit: Int {
        loggedSummaries.reduce(0) { total, summary in
            total + max(baselineCalories(for: summary) - summary.consumedCalories, 0)
        }
    }

    var totalSurplus: Int {
        loggedSummaries.reduce(0) { total, summary in
            total + max(summary.consumedCalories - baselineCalories(for: summary), 0)
        }
    }

    var netCalorieBalance: Int {
        loggedSummaries.reduce(0) { total, summary in
            total + (summary.consumedCalories - baselineCalories(for: summary))
        }
    }

    var netCalorieBalanceTitle: String {
        netCalorieBalance >= 0 ? "Total Kcal Gained" : "Total Kcal Lost"
    }

    var netCalorieBalanceMagnitude: Int {
        abs(netCalorieBalance)
    }

    private var loggedSummaries: [DailyCalorieSummary] {
        summaries.filter(\.hasLoggedFood)
    }

    var chartMaximumCalories: Double {
        let highestConsumedCalories = summaries.map(\.consumedCalories).max() ?? 0
        let highestValue = [
            highestConsumedCalories,
            dailyGoalTarget,
            maintenanceCalories ?? 0,
            500
        ].max() ?? 500
        let paddedValue = Double(highestValue) * 1.12
        return ceil(paddedValue / 250) * 250
    }

    func load(
        range: StatisticsRange = .week,
        maintenanceCalories: Int? = nil,
        using modelContext: ModelContext
    ) {
        do {
            self.maintenanceCalories = maintenanceCalories

            let today = calendar.startOfDay(for: Date())
            guard let startDate = calendar.date(byAdding: .day, value: -(range.dayCount - 1), to: today),
                  let endDate = calendar.date(byAdding: .day, value: 1, to: today) else {
                errorMessage = "Unable to calculate the statistics range."
                return
            }

            let goals = try fetchGoals(from: startDate, to: endDate, using: modelContext)
            for goal in goals {
                goal.recalculateTotalConsumedCalories()
            }

            dailyGoalTarget = targetForToday(from: goals, today: today)
            summaries = makeSummaries(from: goals, startDate: startDate, dayCount: range.dayCount)

            try modelContext.save()
        } catch {
            errorMessage = "Unable to load statistics. \(error.localizedDescription)"
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func fetchGoals(
        from startDate: Date,
        to endDate: Date,
        using modelContext: ModelContext
    ) throws -> [DailyGoal] {
        let descriptor = FetchDescriptor<DailyGoal>(
            predicate: #Predicate<DailyGoal> { goal in
                goal.date >= startDate && goal.date < endDate
            },
            sortBy: [SortDescriptor(\.date)]
        )

        return try modelContext.fetch(descriptor)
    }

    private func targetForToday(from goals: [DailyGoal], today: Date) -> Int {
        if let todayGoal = goals.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            return todayGoal.targetCalories
        }

        return goals.last?.targetCalories ?? DailyGoalTargets.current.calories
    }

    private func makeSummaries(
        from goals: [DailyGoal],
        startDate: Date,
        dayCount: Int
    ) -> [DailyCalorieSummary] {
        var summariesByDay: [Date: (consumedCalories: Int, targetCalories: Int, hasLoggedFood: Bool)] = [:]
        for goal in goals {
            let day = calendar.startOfDay(for: goal.date)
            let existingSummary = summariesByDay[day]
            let hasLoggedFood = !(goal.foodItems ?? []).isEmpty || goal.totalConsumedCalories > 0

            summariesByDay[day] = (
                consumedCalories: (existingSummary?.consumedCalories ?? 0) + goal.totalConsumedCalories,
                targetCalories: goal.targetCalories,
                hasLoggedFood: (existingSummary?.hasLoggedFood ?? false) || hasLoggedFood
            )
        }

        return (0..<dayCount).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
                return nil
            }

            let summary = summariesByDay[date]
            return DailyCalorieSummary(
                date: date,
                consumedCalories: summary?.consumedCalories ?? 0,
                targetCalories: summary?.targetCalories ?? dailyGoalTarget,
                hasLoggedFood: summary?.hasLoggedFood ?? false
            )
        }
    }

    private func baselineCalories(for summary: DailyCalorieSummary) -> Int {
        maintenanceCalories ?? summary.targetCalories
    }
}

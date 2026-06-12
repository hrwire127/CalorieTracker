import Combine
import Foundation
import SwiftData

struct DailyCalorieSummary: Identifiable, Equatable {
    var id: Date { date }

    let date: Date
    let consumedCalories: Int
    let targetCalories: Int
}

@MainActor
final class StatisticsViewModel: ObservableObject {
    @Published private(set) var summaries: [DailyCalorieSummary] = []
    @Published private(set) var dailyGoalTarget = 2_000
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
        guard !summaries.isEmpty else {
            return 0
        }

        return totalCalories / summaries.count
    }

    var daysMeetingGoal: Int {
        summaries.filter { summary in
            summary.consumedCalories >= summary.targetCalories
        }.count
    }

    var chartMaximumCalories: Double {
        let highestConsumedCalories = summaries.map(\.consumedCalories).max() ?? 0
        let highestValue = max(highestConsumedCalories, dailyGoalTarget, 500)
        let paddedValue = Double(highestValue) * 1.12
        return ceil(paddedValue / 250) * 250
    }

    func load(using modelContext: ModelContext) {
        do {
            let today = calendar.startOfDay(for: Date())
            guard let startDate = calendar.date(byAdding: .day, value: -6, to: today),
                  let endDate = calendar.date(byAdding: .day, value: 1, to: today) else {
                errorMessage = "Unable to calculate the statistics range."
                return
            }

            let goals = try fetchGoals(from: startDate, to: endDate, using: modelContext)
            for goal in goals {
                goal.recalculateTotalConsumedCalories()
            }

            dailyGoalTarget = targetForToday(from: goals, today: today)
            summaries = makeSummaries(from: goals, startDate: startDate)

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

        return goals.last?.targetCalories ?? 2_000
    }

    private func makeSummaries(from goals: [DailyGoal], startDate: Date) -> [DailyCalorieSummary] {
        var summariesByDay: [Date: (consumedCalories: Int, targetCalories: Int)] = [:]
        for goal in goals {
            let day = calendar.startOfDay(for: goal.date)
            let existingSummary = summariesByDay[day]

            summariesByDay[day] = (
                consumedCalories: (existingSummary?.consumedCalories ?? 0) + goal.totalConsumedCalories,
                targetCalories: goal.targetCalories
            )
        }

        return (0..<7).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
                return nil
            }

            let summary = summariesByDay[date]
            return DailyCalorieSummary(
                date: date,
                consumedCalories: summary?.consumedCalories ?? 0,
                targetCalories: summary?.targetCalories ?? dailyGoalTarget
            )
        }
    }
}

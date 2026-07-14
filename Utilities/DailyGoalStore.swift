import Foundation
import SwiftData

enum DailyGoalStore {
    static func goal(
        for date: Date,
        in modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws -> DailyGoal? {
        let interval = try dayInterval(containing: date, calendar: calendar)
        let startDate = interval.start
        let endDate = interval.end
        let descriptor = FetchDescriptor<DailyGoal>(
            predicate: #Predicate<DailyGoal> { goal in
                goal.date >= startDate && goal.date < endDate
            },
            sortBy: [SortDescriptor(\.date)]
        )

        let goals = try modelContext.fetch(descriptor)
        return consolidate(goals, day: interval.start, in: modelContext)
    }

    static func latestGoal(
        before date: Date,
        in modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws -> DailyGoal? {
        let startDate = calendar.startOfDay(for: date)
        var descriptor = FetchDescriptor<DailyGoal>(
            predicate: #Predicate<DailyGoal> { goal in
                goal.date < startDate
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    static func consolidateDuplicateDays(
        in modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws {
        let goals = try modelContext.fetch(
            FetchDescriptor<DailyGoal>(sortBy: [SortDescriptor(\.date)])
        )
        let goalsByDay = Dictionary(grouping: goals) { goal in
            calendar.startOfDay(for: goal.date)
        }

        for (day, duplicateGoals) in goalsByDay where duplicateGoals.count > 1 {
            _ = consolidate(duplicateGoals, day: day, in: modelContext)
        }
    }

    private static func consolidate(
        _ goals: [DailyGoal],
        day: Date,
        in modelContext: ModelContext
    ) -> DailyGoal? {
        guard let primaryGoal = goals.first else {
            return nil
        }

        primaryGoal.date = day
        if primaryGoal.foodItems == nil {
            primaryGoal.foodItems = []
        }

        var knownFoodIDs = Set((primaryGoal.foodItems ?? []).map(\.id))

        for duplicateGoal in goals.dropFirst() {
            for foodItem in duplicateGoal.foodItems ?? [] {
                if knownFoodIDs.insert(foodItem.id).inserted {
                    foodItem.dailyGoal = primaryGoal
                    if primaryGoal.foodItems?.contains(where: { $0.id == foodItem.id }) != true {
                        primaryGoal.foodItems?.append(foodItem)
                    }
                } else {
                    modelContext.delete(foodItem)
                }
            }

            duplicateGoal.foodItems = []
            modelContext.delete(duplicateGoal)
        }

        primaryGoal.recalculateTotalConsumedCalories()
        return primaryGoal
    }

    private static func dayInterval(
        containing date: Date,
        calendar: Calendar
    ) throws -> DateInterval {
        let startDate = calendar.startOfDay(for: date)
        guard let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) else {
            throw DailyGoalStoreError.invalidDay
        }
        return DateInterval(start: startDate, end: endDate)
    }
}

enum DailyGoalStoreError: LocalizedError {
    case invalidDay

    var errorDescription: String? {
        "The selected calendar day could not be calculated."
    }
}

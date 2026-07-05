import Combine
import Foundation
import SwiftData

enum HabitDayStatus: Equatable {
    case empty
    case success
    case surplus
}

struct HabitDaySummary: Identifiable, Equatable {
    var id: Date { date }

    let date: Date
    let status: HabitDayStatus
    let isToday: Bool

    var isLogged: Bool {
        status == .success || status == .surplus
    }
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var dailyGoal: DailyGoal?
    @Published private(set) var foodItems: [FoodItem] = []
    @Published private(set) var habitDays: [HabitDaySummary] = []
    @Published private(set) var currentStreak = 0
    @Published private(set) var errorMessage: String?

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    var targetCalories: Int {
        dailyGoal?.targetCalories ?? DailyGoalTargets.current.calories
    }

    var targetProteinGrams: Int {
        dailyGoal?.targetProteinGrams ?? DailyGoalTargets.current.proteinGrams
    }

    var targetCarbGrams: Int {
        dailyGoal?.targetCarbGrams ?? DailyGoalTargets.current.carbGrams
    }

    var targetFatGrams: Int {
        dailyGoal?.targetFatGrams ?? DailyGoalTargets.current.fatGrams
    }

    var consumedCalories: Int {
        dailyGoal?.totalConsumedCalories ?? 0
    }

    var consumedProteinGrams: Int {
        foodItems.reduce(0) { total, item in
            total + (item.proteinGrams ?? 0)
        }
    }

    var consumedCarbGrams: Int {
        foodItems.reduce(0) { total, item in
            total + (item.carbGrams ?? 0)
        }
    }

    var consumedFatGrams: Int {
        foodItems.reduce(0) { total, item in
            total + (item.fatGrams ?? 0)
        }
    }

    var remainingCalories: Int {
        max(targetCalories - consumedCalories, 0)
    }

    var overageCalories: Int {
        max(consumedCalories - targetCalories, 0)
    }

    var progress: Double {
        guard targetCalories > 0 else {
            return 0
        }

        return min(Double(consumedCalories) / Double(targetCalories), 1)
    }

    var isOverGoal: Bool {
        consumedCalories > targetCalories
    }

    func loadToday(using modelContext: ModelContext) {
        do {
            let goal = try fetchOrCreateTodayGoal(in: modelContext)
            saveCurrentTargetsIfNeeded(from: goal)
            goal.recalculateTotalConsumedCalories()

            try modelContext.save()
            updateState(with: goal)
            updateHabitState(using: modelContext)
        } catch {
            showError("Unable to load today's calorie goal.", underlyingError: error)
        }
    }

    func addFoodItem(
        name: String,
        calories: Int,
        grams: Int? = nil,
        proteinGrams: Int? = nil,
        carbGrams: Int? = nil,
        fatGrams: Int? = nil,
        healthScore: Int? = nil,
        imageData: Data? = nil,
        using modelContext: ModelContext
    ) {
        let entry: ValidatedFoodEntry
        do {
            entry = try FoodEntryValidator.validate(
                name: name,
                calories: calories,
                grams: grams,
                proteinGrams: proteinGrams,
                carbGrams: carbGrams,
                fatGrams: fatGrams,
                healthScore: healthScore
            )
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        do {
            let goal = try fetchOrCreateTodayGoal(in: modelContext)
            let foodItem = FoodItem(
                name: entry.name,
                calories: entry.calories,
                grams: entry.grams,
                proteinGrams: entry.proteinGrams,
                carbGrams: entry.carbGrams,
                fatGrams: entry.fatGrams,
                healthScore: entry.healthScore,
                timestamp: Date(),
                imageData: imageData, // the uploaded or generated image data
                dailyGoal: goal
            )

            modelContext.insert(foodItem)
            
            if goal.foodItems == nil {
                goal.foodItems = []
            }
            if let items = goal.foodItems, !items.contains(where: { item in item.id == foodItem.id }) {
                goal.foodItems?.append(foodItem)
            }
            goal.recalculateTotalConsumedCalories()

            try modelContext.save()
            updateState(with: goal)
            updateHabitState(using: modelContext)
        } catch {
            showError("Unable to save this food item.", underlyingError: error)
        }
    }

    func updateDailyGoal(targets: DailyGoalTargets, using modelContext: ModelContext) {
        guard targets.calories > 0 else {
            errorMessage = "Daily goal must be greater than zero."
            return
        }

        guard targets.proteinGrams >= 0, targets.carbGrams >= 0, targets.fatGrams >= 0 else {
            errorMessage = "Macro goals must be zero or greater."
            return
        }

        do {
            let goal = try fetchOrCreateTodayGoal(in: modelContext)
            targets.saveAsCurrent()
            goal.targetCalories = targets.calories
            goal.targetProteinGrams = targets.proteinGrams
            goal.targetCarbGrams = targets.carbGrams
            goal.targetFatGrams = targets.fatGrams
            goal.recalculateTotalConsumedCalories()

            try modelContext.save()
            updateState(with: goal)
            updateHabitState(using: modelContext)
        } catch {
            showError("Unable to update the daily goal.", underlyingError: error)
        }
    }

    func updateFoodItem(
        _ item: FoodItem,
        with entry: ValidatedFoodEntry,
        using modelContext: ModelContext
    ) {
        item.name = entry.name
        item.calories = entry.calories
        item.grams = entry.grams
        item.proteinGrams = entry.proteinGrams
        item.carbGrams = entry.carbGrams
        item.fatGrams = entry.fatGrams
        item.healthScore = entry.healthScore

        do {
            item.dailyGoal?.recalculateTotalConsumedCalories()
            try modelContext.save()

            if let goal = dailyGoal {
                updateState(with: goal)
            } else {
                loadToday(using: modelContext)
            }
            updateHabitState(using: modelContext)
        } catch {
            showError("Unable to update this food item.", underlyingError: error)
        }
    }

    func deleteFoodItems(at offsets: IndexSet, using modelContext: ModelContext) {
        guard let goal = dailyGoal else {
            return
        }

        do {
            let itemsToDelete = offsets.compactMap { offset in
                foodItems.indices.contains(offset) ? foodItems[offset] : nil
            }
            let deletedItemIDs = Set(itemsToDelete.map(\.id))

            goal.foodItems?.removeAll { foodItem in
                deletedItemIDs.contains(foodItem.id)
            }

            for item in itemsToDelete {
                modelContext.delete(item)
            }

            goal.recalculateTotalConsumedCalories()

            try modelContext.save()
            updateState(with: goal)
            updateHabitState(using: modelContext)
        } catch {
            showError("Unable to delete the selected food item.", underlyingError: error)
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func updateState(with goal: DailyGoal) {
        dailyGoal = goal
        foodItems = (goal.foodItems ?? []).sorted { firstItem, secondItem in
            firstItem.timestamp > secondItem.timestamp
        }
    }

    private func fetchOrCreateTodayGoal(in modelContext: ModelContext) throws -> DailyGoal {
        if let existingGoal = try fetchTodayGoal(in: modelContext) {
            return existingGoal
        }

        let newGoal = DailyGoal(date: Date(), targets: try targetsForNewGoal(in: modelContext))
        modelContext.insert(newGoal)
        return newGoal
    }

    private func targetsForNewGoal(in modelContext: ModelContext) throws -> DailyGoalTargets {
        guard !DailyGoalTargets.hasSavedCurrent,
              let latestGoal = try fetchLatestGoalBeforeToday(in: modelContext) else {
            return DailyGoalTargets.current
        }

        let targets = DailyGoalTargets(
            calories: latestGoal.targetCalories,
            proteinGrams: latestGoal.targetProteinGrams,
            carbGrams: latestGoal.targetCarbGrams,
            fatGrams: latestGoal.targetFatGrams
        )
        targets.saveAsCurrent()
        return targets
    }

    private func saveCurrentTargetsIfNeeded(from goal: DailyGoal) {
        guard !DailyGoalTargets.hasSavedCurrent else {
            return
        }

        DailyGoalTargets(
            calories: goal.targetCalories,
            proteinGrams: goal.targetProteinGrams,
            carbGrams: goal.targetCarbGrams,
            fatGrams: goal.targetFatGrams
        )
        .saveAsCurrent()
    }

    private func fetchLatestGoalBeforeToday(in modelContext: ModelContext) throws -> DailyGoal? {
        let startOfToday = calendar.startOfDay(for: Date())
        var descriptor = FetchDescriptor<DailyGoal>(
            predicate: #Predicate<DailyGoal> { goal in
                goal.date < startOfToday
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }

    private func fetchTodayGoal(in modelContext: ModelContext) throws -> DailyGoal? {
        let startOfToday = calendar.startOfDay(for: Date())
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return nil
        }

        var descriptor = FetchDescriptor<DailyGoal>(
            predicate: #Predicate<DailyGoal> { goal in
                goal.date >= startOfToday && goal.date < startOfTomorrow
            },
            sortBy: [SortDescriptor(\.date)]
        )
        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }

    private func updateHabitState(using modelContext: ModelContext) {
        do {
            let today = calendar.startOfDay(for: Date())
            guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -29, to: today),
                  let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
                return
            }

            let goals = try fetchGoals(from: thirtyDaysAgo, to: tomorrow, using: modelContext)
            for goal in goals {
                goal.recalculateTotalConsumedCalories()
            }

            let statusByDay = makeHabitStatusByDay(from: goals)
            let successDays = Set(statusByDay.compactMap { day, status in
                status == .success ? day : nil
            })

            habitDays = makeHabitDays(statusByDay: statusByDay, today: today)
            currentStreak = calculateCurrentStreak(successDays: successDays, today: today)
        } catch {
            showError("Unable to load habit tracking.", underlyingError: error)
        }
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

    private func makeHabitStatusByDay(from goals: [DailyGoal]) -> [Date: HabitDayStatus] {
        goals.reduce(into: [:]) { result, goal in
            let day = calendar.startOfDay(for: goal.date)
            let status = habitStatus(for: goal)
            let currentStatus = result[day] ?? .empty

            result[day] = mergedHabitStatus(currentStatus, status)
        }
    }

    private func habitStatus(for goal: DailyGoal) -> HabitDayStatus {
        guard isLogged(goal) else {
            return .empty
        }

        return goal.totalConsumedCalories <= goal.targetCalories ? .success : .surplus
    }

    private func mergedHabitStatus(_ currentStatus: HabitDayStatus, _ newStatus: HabitDayStatus) -> HabitDayStatus {
        if currentStatus == .surplus || newStatus == .surplus {
            return .surplus
        }

        if currentStatus == .success || newStatus == .success {
            return .success
        }

        return .empty
    }

    private func makeHabitDays(statusByDay: [Date: HabitDayStatus], today: Date) -> [HabitDaySummary] {
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: today) else {
            return []
        }

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else {
                return nil
            }

            let day = calendar.startOfDay(for: date)
            return HabitDaySummary(
                date: day,
                status: statusByDay[day] ?? .empty,
                isToday: calendar.isDate(day, inSameDayAs: today)
            )
        }
    }

    private func calculateCurrentStreak(successDays: Set<Date>, today: Date) -> Int {
        var streak = 0
        var day = today

        if !successDays.contains(day),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
           successDays.contains(yesterday) {
            day = yesterday
        }

        while successDays.contains(day) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else {
                break
            }
            day = previousDay
        }

        return streak
    }

    private func isLogged(_ goal: DailyGoal) -> Bool {
        !(goal.foodItems ?? []).isEmpty || goal.totalConsumedCalories > 0
    }

    private func showError(_ message: String, underlyingError: Error) {
        errorMessage = "\(message) \(underlyingError.localizedDescription)"
    }
}

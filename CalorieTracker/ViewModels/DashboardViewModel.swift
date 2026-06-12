import Combine
import Foundation
import SwiftData

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var dailyGoal: DailyGoal?
    @Published private(set) var foodItems: [FoodItem] = []
    @Published private(set) var errorMessage: String?

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    var targetCalories: Int {
        dailyGoal?.targetCalories ?? 2_000
    }

    var consumedCalories: Int {
        dailyGoal?.totalConsumedCalories ?? 0
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
            goal.recalculateTotalConsumedCalories()

            try modelContext.save()
            updateState(with: goal)
        } catch {
            showError("Unable to load today's calorie goal.", underlyingError: error)
        }
    }

    func addFoodItem(
        name: String,
        calories: Int,
        imageData: Data? = nil,
        using modelContext: ModelContext
    ) {
        let entry: ValidatedFoodEntry
        do {
            entry = try FoodEntryValidator.validate(name: name, calories: calories)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        do {
            let goal = try fetchOrCreateTodayGoal(in: modelContext)
            let foodItem = FoodItem(
                name: entry.name,
                calories: entry.calories,
                timestamp: Date(),
                imageData: imageData,
                dailyGoal: goal
            )

            modelContext.insert(foodItem)
            if !goal.foodItems.contains(where: { item in item.id == foodItem.id }) {
                goal.foodItems.append(foodItem)
            }
            goal.recalculateTotalConsumedCalories()

            try modelContext.save()
            updateState(with: goal)
        } catch {
            showError("Unable to save this food item.", underlyingError: error)
        }
    }

    func updateDailyGoal(targetCalories: Int, using modelContext: ModelContext) {
        guard targetCalories > 0 else {
            errorMessage = "Daily goal must be greater than zero."
            return
        }

        do {
            let goal = try fetchOrCreateTodayGoal(in: modelContext)
            goal.targetCalories = targetCalories
            goal.recalculateTotalConsumedCalories()

            try modelContext.save()
            updateState(with: goal)
        } catch {
            showError("Unable to update the daily goal.", underlyingError: error)
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

            goal.foodItems.removeAll { foodItem in
                deletedItemIDs.contains(foodItem.id)
            }

            for item in itemsToDelete {
                modelContext.delete(item)
            }

            goal.recalculateTotalConsumedCalories()

            try modelContext.save()
            updateState(with: goal)
        } catch {
            showError("Unable to delete the selected food item.", underlyingError: error)
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func updateState(with goal: DailyGoal) {
        dailyGoal = goal
        foodItems = goal.foodItems.sorted { firstItem, secondItem in
            firstItem.timestamp > secondItem.timestamp
        }
    }

    private func fetchOrCreateTodayGoal(in modelContext: ModelContext) throws -> DailyGoal {
        if let existingGoal = try fetchTodayGoal(in: modelContext) {
            return existingGoal
        }

        let newGoal = DailyGoal(date: Date())
        modelContext.insert(newGoal)
        return newGoal
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

    private func showError(_ message: String, underlyingError: Error) {
        errorMessage = "\(message) \(underlyingError.localizedDescription)"
    }
}

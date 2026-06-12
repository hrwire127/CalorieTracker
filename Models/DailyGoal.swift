import Foundation
import SwiftData

@Model
final class DailyGoal {
    var date: Date = Date()
    var targetCalories: Int = 2000
    var targetProteinGrams: Int = 100
    var targetCarbGrams: Int = 175
    var targetFatGrams: Int = 100
    var totalConsumedCalories: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \FoodItem.dailyGoal)
    var foodItems: [FoodItem]? = []

    init(
        date: Date = Calendar.current.startOfDay(for: Date()),
        targetCalories: Int = 2_000,
        targetProteinGrams: Int = 100,
        targetCarbGrams: Int? = nil,
        targetFatGrams: Int = 100,
        totalConsumedCalories: Int = 0,
        foodItems: [FoodItem] = []
    ) {
        self.date = Calendar.current.startOfDay(for: date)
        self.targetCalories = targetCalories
        self.targetProteinGrams = targetProteinGrams
        self.targetFatGrams = targetFatGrams
        self.targetCarbGrams = targetCarbGrams ?? DailyGoal.defaultCarbGoal(
            calories: targetCalories,
            proteinGrams: targetProteinGrams,
            fatGrams: targetFatGrams
        )
        self.totalConsumedCalories = totalConsumedCalories
        self.foodItems = foodItems
    }

    var remainingCalories: Int {
        max(targetCalories - totalConsumedCalories, 0)
    }

    func recalculateTotalConsumedCalories() {
        totalConsumedCalories = (foodItems ?? []).reduce(0) { total, item in
            total + item.calories
        }
    }

    static func defaultCarbGoal(calories: Int, proteinGrams: Int = 100, fatGrams: Int = 100) -> Int {
        let remainingCalories = max(calories - (proteinGrams * 4) - (fatGrams * 9), 0)
        return max(remainingCalories / 4, 0)
    }
}

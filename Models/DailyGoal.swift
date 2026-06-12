import Foundation
import SwiftData

@Model
final class DailyGoal {
    var date: Date = Date()
    var targetCalories: Int = 2000
    var totalConsumedCalories: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \FoodItem.dailyGoal)
    var foodItems: [FoodItem]? = []

    init(
        date: Date = Calendar.current.startOfDay(for: Date()),
        targetCalories: Int = 2_000,
        totalConsumedCalories: Int = 0,
        foodItems: [FoodItem] = []
    ) {
        self.date = Calendar.current.startOfDay(for: date)
        self.targetCalories = targetCalories
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
}

import Foundation
import SwiftData

@Model
final class FoodItem {
    var id: UUID = UUID()
    var name: String = ""
    var calories: Int = 0
    var grams: Int?
    var proteinGrams: Int?
    var carbGrams: Int?
    var fatGrams: Int?
    var healthScore: Int?
    var timestamp: Date = Date()

    @Attribute(.externalStorage)
    var imageData: Data?

    var dailyGoal: DailyGoal?

    init(
        id: UUID = UUID(),
        name: String,
        calories: Int,
        grams: Int? = nil,
        proteinGrams: Int? = nil,
        carbGrams: Int? = nil,
        fatGrams: Int? = nil,
        healthScore: Int? = nil,
        timestamp: Date = Date(),
        imageData: Data? = nil,
        dailyGoal: DailyGoal? = nil
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.grams = grams
        self.proteinGrams = proteinGrams
        self.carbGrams = carbGrams
        self.fatGrams = fatGrams
        self.healthScore = healthScore
        self.timestamp = timestamp
        self.imageData = imageData
        self.dailyGoal = dailyGoal
    }

    var caloriesPerGram: Double? {
        guard let grams, grams > 0 else {
            return nil
        }

        return Double(calories) / Double(grams)
    }
}

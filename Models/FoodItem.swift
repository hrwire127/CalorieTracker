import Foundation
import SwiftData

@Model
final class FoodItem {
    var id: UUID = UUID()
    var name: String = ""
    var calories: Int = 0
    var grams: Int?
    var timestamp: Date = Date()

    @Attribute(.externalStorage)
    var imageData: Data?

    var dailyGoal: DailyGoal?

    init(
        id: UUID = UUID(),
        name: String,
        calories: Int,
        grams: Int? = nil,
        timestamp: Date = Date(),
        imageData: Data? = nil,
        dailyGoal: DailyGoal? = nil
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.grams = grams
        self.timestamp = timestamp
        self.imageData = imageData
        self.dailyGoal = dailyGoal
    }
}

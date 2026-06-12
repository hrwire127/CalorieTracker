import Foundation
import SwiftData

@Model
final class FoodItem {
    @Attribute(.unique)
    var id: UUID

    var name: String
    var calories: Int
    var timestamp: Date

    @Attribute(.externalStorage)
    var imageData: Data?

    var dailyGoal: DailyGoal?

    init(
        id: UUID = UUID(),
        name: String,
        calories: Int,
        timestamp: Date = Date(),
        imageData: Data? = nil,
        dailyGoal: DailyGoal? = nil
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.timestamp = timestamp
        self.imageData = imageData
        self.dailyGoal = dailyGoal
    }
}

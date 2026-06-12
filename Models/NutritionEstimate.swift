import Foundation

struct NutritionEstimate: Codable, Equatable {
    let foodName: String
    let estimatedCalories: Int

    enum CodingKeys: String, CodingKey {
        case foodName = "food_name"
        case estimatedCalories = "estimated_calories"
    }
}

struct FoodEstimateDraft: Identifiable, Equatable {
    let id = UUID()
    var foodName: String
    var calories: Int
    var imageData: Data?
}

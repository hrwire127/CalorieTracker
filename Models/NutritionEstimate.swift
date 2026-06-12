import Foundation

struct NutritionEstimate: Codable, Equatable {
    let foodName: String
    let estimatedCalories: Int
    let estimatedGrams: Int?

    enum CodingKeys: String, CodingKey {
        case foodName = "food_name"
        case estimatedCalories = "estimated_calories"
        case estimatedGrams = "estimated_grams"
    }
}

struct FoodEstimateDraft: Identifiable, Equatable {
    let id = UUID()
    var foodName: String
    var calories: Int
    var grams: Int?
    var imageData: Data?
}

import Foundation

struct NutritionEstimate: Codable, Equatable {
    let foodName: String
    let estimatedCalories: Int
    let estimatedGrams: Int?
    let estimatedProteinGrams: Int?
    let estimatedCarbGrams: Int?
    let estimatedFatGrams: Int?
    let healthScore: Int?

    enum CodingKeys: String, CodingKey {
        case foodName = "food_name"
        case estimatedCalories = "estimated_calories"
        case estimatedGrams = "estimated_grams"
        case estimatedProteinGrams = "estimated_protein_grams"
        case estimatedCarbGrams = "estimated_carb_grams"
        case estimatedFatGrams = "estimated_fat_grams"
        case healthScore = "health_score"
    }
}

struct FoodEstimateDraft: Identifiable, Equatable {
    let id = UUID()
    var foodName: String
    var calories: Int
    var grams: Int?
    var proteinGrams: Int?
    var carbGrams: Int?
    var fatGrams: Int?
    var healthScore: Int?
    var imageData: Data?
}

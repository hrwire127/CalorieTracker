import Combine
import Foundation

@MainActor
final class ManualEntryViewModel: ObservableObject {
    @Published var foodName = ""
    @Published var caloriesText = ""
    @Published var gramsText = ""
    @Published var proteinText = ""
    @Published var carbText = ""
    @Published var fatText = ""
    @Published var healthScoreText = ""
    @Published var validationMessage: String?
    @Published var errorMessage: String?
    @Published private(set) var isGuessingNutrition = false

    private let networkManager: NetworkManager

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    var canSave: Bool {
        FoodEntryValidator.canSave(
            name: foodName,
            caloriesText: caloriesText,
            gramsText: gramsText,
            proteinText: proteinText,
            carbText: carbText,
            fatText: fatText,
            healthScoreText: healthScoreText
        )
    }

    var canGuessNutrition: Bool {
        cleanedFoodName.isEmpty == false && parsedGuessGrams != nil && !isGuessingNutrition
    }

    var caloriesPerGram: Double? {
        guard let calories = Int(caloriesText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let grams = Int(gramsText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        return NutritionCalculator.caloriesPerGram(calories: calories, grams: grams)
    }

    func guessNutrition() async {
        guard let grams = parsedGuessGrams else {
            validationMessage = FoodEntryValidationError.invalidGrams.localizedDescription
            return
        }

        guard cleanedFoodName.isEmpty == false else {
            validationMessage = FoodEntryValidationError.emptyName.localizedDescription
            return
        }

        isGuessingNutrition = true
        validationMessage = nil
        errorMessage = nil
        defer { isGuessingNutrition = false }

        do {
            let estimate = try await networkManager.estimateNutrition(
                foodName: cleanedFoodName,
                grams: grams
            )
            apply(estimate: estimate, originalGrams: grams)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func validatedEntry() throws -> ValidatedFoodEntry {
        try FoodEntryValidator.validate(
            name: foodName,
            caloriesText: caloriesText,
            gramsText: gramsText,
            proteinText: proteinText,
            carbText: carbText,
            fatText: fatText,
            healthScoreText: healthScoreText
        )
    }

    func clearError() {
        errorMessage = nil
    }

    private func apply(estimate: NutritionEstimate, originalGrams: Int) {
        let estimatedFoodName = estimate.foodName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !estimatedFoodName.isEmpty {
            foodName = estimatedFoodName
        }

        caloriesText = String(estimate.estimatedCalories)
        gramsText = String(originalGrams)
        proteinText = nonNegativeText(from: estimate.estimatedProteinGrams)
        carbText = nonNegativeText(from: estimate.estimatedCarbGrams)
        fatText = nonNegativeText(from: estimate.estimatedFatGrams)
        healthScoreText = healthScoreText(from: estimate.healthScore)
    }

    private func nonNegativeText(from value: Int?) -> String {
        guard let value, value >= 0 else {
            return ""
        }

        return String(value)
    }

    private func healthScoreText(from value: Int?) -> String {
        guard let value else {
            return ""
        }

        return String(min(max(value, 1), 10))
    }

    private var cleanedFoodName: String {
        foodName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedGuessGrams: Int? {
        let trimmedText = gramsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let grams = Int(trimmedText), grams > 0 else {
            return nil
        }

        return grams
    }
}

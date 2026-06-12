import Foundation

struct ValidatedFoodEntry {
    let name: String
    let calories: Int
    let grams: Int?
    let proteinGrams: Int?
    let carbGrams: Int?
    let fatGrams: Int?
    let healthScore: Int?
}

enum FoodEntryValidator {
    static func validate(
        name: String,
        caloriesText: String,
        gramsText: String? = nil,
        proteinText: String? = nil,
        carbText: String? = nil,
        fatText: String? = nil,
        healthScoreText: String? = nil
    ) throws -> ValidatedFoodEntry {
        guard let calories = parsedCalories(from: caloriesText) else {
            throw FoodEntryValidationError.invalidCalories
        }

        return try validate(
            name: name,
            calories: calories,
            gramsText: gramsText,
            proteinText: proteinText,
            carbText: carbText,
            fatText: fatText,
            healthScoreText: healthScoreText
        )
    }

    static func validate(
        name: String,
        calories: Int,
        grams: Int? = nil,
        proteinGrams: Int? = nil,
        carbGrams: Int? = nil,
        fatGrams: Int? = nil,
        healthScore: Int? = nil,
        gramsText: String? = nil,
        proteinText: String? = nil,
        carbText: String? = nil,
        fatText: String? = nil,
        healthScoreText: String? = nil
    ) throws -> ValidatedFoodEntry {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedName.isEmpty else {
            throw FoodEntryValidationError.emptyName
        }

        guard calories > 0 else {
            throw FoodEntryValidationError.invalidCalories
        }

        let validatedGrams: Int?
        if let gramsText {
            validatedGrams = try parsedOptionalGrams(from: gramsText)
        } else if let grams {
            guard grams > 0 else {
                throw FoodEntryValidationError.invalidGrams
            }
            validatedGrams = grams
        } else {
            validatedGrams = nil
        }

        let validatedProtein = try validateOptionalGramValue(
            directValue: proteinGrams,
            textValue: proteinText
        )
        let validatedCarbs = try validateOptionalGramValue(
            directValue: carbGrams,
            textValue: carbText
        )
        let validatedFat = try validateOptionalGramValue(
            directValue: fatGrams,
            textValue: fatText
        )
        let validatedHealthScore = try validateOptionalHealthScore(
            directValue: healthScore,
            textValue: healthScoreText
        )

        return ValidatedFoodEntry(
            name: cleanedName,
            calories: calories,
            grams: validatedGrams,
            proteinGrams: validatedProtein,
            carbGrams: validatedCarbs,
            fatGrams: validatedFat,
            healthScore: validatedHealthScore
        )
    }

    static func canSave(
        name: String,
        caloriesText: String,
        gramsText: String? = nil,
        proteinText: String? = nil,
        carbText: String? = nil,
        fatText: String? = nil,
        healthScoreText: String? = nil
    ) -> Bool {
        (try? validate(
            name: name,
            caloriesText: caloriesText,
            gramsText: gramsText,
            proteinText: proteinText,
            carbText: carbText,
            fatText: fatText,
            healthScoreText: healthScoreText
        )) != nil
    }

    private static func parsedCalories(from text: String) -> Int? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let calories = Int(trimmedText), calories > 0 else {
            return nil
        }

        return calories
    }

    private static func parsedOptionalGrams(from text: String) throws -> Int? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return nil
        }

        guard let grams = Int(trimmedText), grams > 0 else {
            throw FoodEntryValidationError.invalidGrams
        }

        return grams
    }

    private static func validateOptionalGramValue(directValue: Int?, textValue: String?) throws -> Int? {
        if let textValue {
            return try parsedOptionalMacroGrams(from: textValue)
        }

        guard let directValue else {
            return nil
        }

        guard directValue >= 0 else {
            throw FoodEntryValidationError.invalidMacro
        }

        return directValue
    }

    private static func parsedOptionalMacroGrams(from text: String) throws -> Int? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return nil
        }

        guard let grams = Int(trimmedText), grams >= 0 else {
            throw FoodEntryValidationError.invalidMacro
        }

        return grams
    }

    private static func validateOptionalHealthScore(directValue: Int?, textValue: String?) throws -> Int? {
        let score: Int?
        if let textValue {
            let trimmedText = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else {
                return nil
            }
            score = Int(trimmedText)
        } else {
            score = directValue
        }

        guard let score else {
            return nil
        }

        guard (1...10).contains(score) else {
            throw FoodEntryValidationError.invalidHealthScore
        }

        return score
    }
}

enum FoodEntryValidationError: LocalizedError {
    case emptyName
    case invalidCalories
    case invalidGrams
    case invalidMacro
    case invalidHealthScore

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Enter a food name."
        case .invalidCalories:
            return "Enter calories greater than zero."
        case .invalidGrams:
            return "Enter grams greater than zero, or leave the field empty."
        case .invalidMacro:
            return "Enter macro values as zero or greater, or leave them empty."
        case .invalidHealthScore:
            return "Enter a health score from 1 to 10, or leave it empty."
        }
    }
}

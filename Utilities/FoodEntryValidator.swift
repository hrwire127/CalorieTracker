import Foundation

struct ValidatedFoodEntry {
    let name: String
    let calories: Int
    let grams: Int?
}

enum FoodEntryValidator {
    static func validate(
        name: String,
        caloriesText: String,
        gramsText: String? = nil
    ) throws -> ValidatedFoodEntry {
        guard let calories = parsedCalories(from: caloriesText) else {
            throw FoodEntryValidationError.invalidCalories
        }

        return try validate(name: name, calories: calories, gramsText: gramsText)
    }

    static func validate(
        name: String,
        calories: Int,
        grams: Int? = nil,
        gramsText: String? = nil
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

        return ValidatedFoodEntry(name: cleanedName, calories: calories, grams: validatedGrams)
    }

    static func canSave(name: String, caloriesText: String, gramsText: String? = nil) -> Bool {
        (try? validate(name: name, caloriesText: caloriesText, gramsText: gramsText)) != nil
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
}

enum FoodEntryValidationError: LocalizedError {
    case emptyName
    case invalidCalories
    case invalidGrams

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Enter a food name."
        case .invalidCalories:
            return "Enter calories greater than zero."
        case .invalidGrams:
            return "Enter grams greater than zero, or leave the field empty."
        }
    }
}

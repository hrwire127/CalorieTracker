import Foundation

struct ValidatedFoodEntry {
    let name: String
    let calories: Int
}

enum FoodEntryValidator {
    static func validate(name: String, caloriesText: String) throws -> ValidatedFoodEntry {
        guard let calories = parsedCalories(from: caloriesText) else {
            throw FoodEntryValidationError.invalidCalories
        }

        return try validate(name: name, calories: calories)
    }

    static func validate(name: String, calories: Int) throws -> ValidatedFoodEntry {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedName.isEmpty else {
            throw FoodEntryValidationError.emptyName
        }

        guard calories > 0 else {
            throw FoodEntryValidationError.invalidCalories
        }

        return ValidatedFoodEntry(name: cleanedName, calories: calories)
    }

    static func canSave(name: String, caloriesText: String) -> Bool {
        (try? validate(name: name, caloriesText: caloriesText)) != nil
    }

    private static func parsedCalories(from text: String) -> Int? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let calories = Int(trimmedText), calories > 0 else {
            return nil
        }

        return calories
    }
}

enum FoodEntryValidationError: LocalizedError {
    case emptyName
    case invalidCalories

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Enter a food name."
        case .invalidCalories:
            return "Enter calories greater than zero."
        }
    }
}

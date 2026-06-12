import Foundation

enum ProfileSex: String, CaseIterable, Identifiable {
    case unspecified
    case male
    case female

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .unspecified:
            return "Not set"
        case .male:
            return "Male"
        case .female:
            return "Female"
        }
    }
}

enum ActivityLevel: String, CaseIterable, Identifiable {
    case sedentary
    case light
    case moderate
    case active
    case veryActive

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .sedentary:
            return "Sedentary"
        case .light:
            return "Light"
        case .moderate:
            return "Moderate"
        case .active:
            return "Active"
        case .veryActive:
            return "Very active"
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary:
            return 1.2
        case .light:
            return 1.375
        case .moderate:
            return 1.55
        case .active:
            return 1.725
        case .veryActive:
            return 1.9
        }
    }
}

enum NutritionCalculator {
    static func caloriesPerGram(calories: Int, grams: Int?) -> Double? {
        guard let grams, grams > 0 else {
            return nil
        }

        return Double(calories) / Double(grams)
    }

    static func macroCalories(proteinGrams: Int, carbGrams: Int, fatGrams: Int) -> Int {
        (proteinGrams * 4) + (carbGrams * 4) + (fatGrams * 9)
    }

    static func dietScore(
        targetCalories: Int,
        proteinGrams: Int,
        carbGrams: Int,
        fatGrams: Int,
        maintenanceCalories: Int?
    ) -> Int {
        guard targetCalories > 0 else {
            return 0
        }

        let macroCaloriesTotal = macroCalories(
            proteinGrams: proteinGrams,
            carbGrams: carbGrams,
            fatGrams: fatGrams
        )
        let macroCalorieMatch = max(0, 1 - abs(Double(macroCaloriesTotal - targetCalories)) / Double(targetCalories))

        let proteinRatio = Double(proteinGrams * 4) / Double(targetCalories)
        let carbRatio = Double(carbGrams * 4) / Double(targetCalories)
        let fatRatio = Double(fatGrams * 9) / Double(targetCalories)

        let proteinScore = rangeScore(value: proteinRatio, idealMin: 0.18, idealMax: 0.35)
        let carbScore = rangeScore(value: carbRatio, idealMin: 0.35, idealMax: 0.55)
        let fatScore = rangeScore(value: fatRatio, idealMin: 0.20, idealMax: 0.35)

        var score = (macroCalorieMatch * 0.35) + (proteinScore * 0.25) + (carbScore * 0.20) + (fatScore * 0.20)

        if let maintenanceCalories, maintenanceCalories > 0 {
            let calorieDeltaRatio = abs(Double(targetCalories - maintenanceCalories)) / Double(maintenanceCalories)
            let maintenanceScore = max(0, 1 - calorieDeltaRatio)
            score = (score * 0.75) + (maintenanceScore * 0.25)
        }

        return min(max(Int((score * 10).rounded()), 1), 10)
    }

    static func maintenanceCalories(
        weightKgText: String,
        heightCmText: String,
        birthDateTimestamp: Double,
        sexRawValue: String,
        activityRawValue: String
    ) -> Int? {
        let weightText = weightKgText.replacingOccurrences(of: ",", with: ".")
        let heightText = heightCmText.replacingOccurrences(of: ",", with: ".")

        guard let weightKg = Double(weightText),
              let heightCm = Double(heightText),
              weightKg > 0,
              heightCm > 0 else {
            return nil
        }

        let birthDate = Date(timeIntervalSince1970: birthDateTimestamp)
        let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
        guard age > 0 else {
            return nil
        }

        let sex = ProfileSex(rawValue: sexRawValue) ?? .unspecified
        let activityLevel = ActivityLevel(rawValue: activityRawValue) ?? .sedentary
        let sexConstant: Double

        switch sex {
        case .male:
            sexConstant = 5
        case .female:
            sexConstant = -161
        case .unspecified:
            sexConstant = -78
        }

        let bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) + sexConstant
        return Int((bmr * activityLevel.multiplier).rounded())
    }

    private static func rangeScore(value: Double, idealMin: Double, idealMax: Double) -> Double {
        if value >= idealMin && value <= idealMax {
            return 1
        }

        let closestBound = value < idealMin ? idealMin : idealMax
        let distance = abs(value - closestBound)
        return max(0, 1 - (distance / closestBound))
    }
}

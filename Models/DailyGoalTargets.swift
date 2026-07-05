import Foundation

struct DailyGoalTargets: Equatable {
    var calories: Int
    var proteinGrams: Int
    var carbGrams: Int
    var fatGrams: Int

    static let defaultTargets = DailyGoalTargets(
        calories: 2_000,
        proteinGrams: 100,
        carbGrams: DailyGoal.defaultCarbGoal(calories: 2_000),
        fatGrams: 100
    )

    static var current: DailyGoalTargets {
        let defaults = UserDefaults.standard
        let fallback = defaultTargets
        let calories = positiveInt(forKey: Keys.calories, fallback: fallback.calories, defaults: defaults)
        let proteinGrams = nonNegativeInt(forKey: Keys.proteinGrams, fallback: fallback.proteinGrams, defaults: defaults)
        let fatGrams = nonNegativeInt(forKey: Keys.fatGrams, fallback: fallback.fatGrams, defaults: defaults)
        let carbFallback = DailyGoal.defaultCarbGoal(
            calories: calories,
            proteinGrams: proteinGrams,
            fatGrams: fatGrams
        )
        let carbGrams = nonNegativeInt(forKey: Keys.carbGrams, fallback: carbFallback, defaults: defaults)

        return DailyGoalTargets(
            calories: calories,
            proteinGrams: proteinGrams,
            carbGrams: carbGrams,
            fatGrams: fatGrams
        )
    }

    static var hasSavedCurrent: Bool {
        UserDefaults.standard.object(forKey: Keys.calories) != nil
    }

    func saveAsCurrent() {
        let defaults = UserDefaults.standard
        defaults.set(calories, forKey: Keys.calories)
        defaults.set(proteinGrams, forKey: Keys.proteinGrams)
        defaults.set(carbGrams, forKey: Keys.carbGrams)
        defaults.set(fatGrams, forKey: Keys.fatGrams)
    }

    private static func positiveInt(forKey key: String, fallback: Int, defaults: UserDefaults) -> Int {
        guard defaults.object(forKey: key) != nil else {
            return fallback
        }

        let value = defaults.integer(forKey: key)
        return value > 0 ? value : fallback
    }

    private static func nonNegativeInt(forKey key: String, fallback: Int, defaults: UserDefaults) -> Int {
        guard defaults.object(forKey: key) != nil else {
            return fallback
        }

        return max(defaults.integer(forKey: key), 0)
    }

    private enum Keys {
        static let calories = "CurrentTargetCalories"
        static let proteinGrams = "CurrentTargetProteinGrams"
        static let carbGrams = "CurrentTargetCarbGrams"
        static let fatGrams = "CurrentTargetFatGrams"
    }
}

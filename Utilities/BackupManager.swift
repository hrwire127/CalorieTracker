import Foundation
import SwiftData

enum BackupManagerError: LocalizedError {
    case invalidBackup

    var errorDescription: String? {
        switch self {
        case .invalidBackup:
            return "The selected backup file could not be read."
        }
    }
}

enum BackupManager {
    static let fileName = "CalorieTrackerBackup.json"
    static let defaultBirthDateTimestamp = 631_152_000.0

    static func exportBackup(using modelContext: ModelContext) throws -> Data {
        let goals = try fetchDailyGoals(using: modelContext)
        for goal in goals {
            goal.recalculateTotalConsumedCalories()
        }

        let snapshot = CalorieTrackerBackupSnapshot(
            exportedAt: Date(),
            profile: BackupProfileSnapshot.fromUserDefaults(),
            goals: goals.map(BackupDailyGoalSnapshot.init(goal:))
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    static func importBackup(from data: Data, using modelContext: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let snapshot = try? decoder.decode(CalorieTrackerBackupSnapshot.self, from: data) else {
            throw BackupManagerError.invalidBackup
        }

        let existingGoals = try fetchDailyGoals(using: modelContext)
        for goal in existingGoals {
            modelContext.delete(goal)
        }

        for goalSnapshot in snapshot.goals {
            let goal = DailyGoal(
                date: goalSnapshot.date,
                targetCalories: goalSnapshot.targetCalories,
                targetProteinGrams: goalSnapshot.targetProteinGrams,
                targetCarbGrams: goalSnapshot.targetCarbGrams,
                targetFatGrams: goalSnapshot.targetFatGrams
            )

            let foodItems = goalSnapshot.foodItems.map { itemSnapshot in
                FoodItem(
                    id: itemSnapshot.id,
                    name: itemSnapshot.name,
                    calories: itemSnapshot.calories,
                    grams: itemSnapshot.grams,
                    proteinGrams: itemSnapshot.proteinGrams,
                    carbGrams: itemSnapshot.carbGrams,
                    fatGrams: itemSnapshot.fatGrams,
                    healthScore: itemSnapshot.healthScore,
                    timestamp: itemSnapshot.timestamp,
                    imageData: itemSnapshot.imageData,
                    dailyGoal: goal
                )
            }

            goal.foodItems = foodItems
            goal.recalculateTotalConsumedCalories()
            modelContext.insert(goal)
        }

        snapshot.profile.restoreToUserDefaults()
        try modelContext.save()
    }

    private static func fetchDailyGoals(using modelContext: ModelContext) throws -> [DailyGoal] {
        let descriptor = FetchDescriptor<DailyGoal>(
            sortBy: [SortDescriptor(\.date)]
        )

        return try modelContext.fetch(descriptor)
    }
}

struct CalorieTrackerBackupSnapshot: Codable {
    let schemaVersion = 1
    let exportedAt: Date
    let profile: BackupProfileSnapshot
    let goals: [BackupDailyGoalSnapshot]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case exportedAt
        case profile
        case goals
    }
}

struct BackupProfileSnapshot: Codable {
    let geminiApiKey: String
    let profileName: String
    let profileWeightKg: String
    let profileHeightCm: String
    let profileAbout: String
    let profileBirthDateTimestamp: Double
    let profileSex: String
    let profileActivityLevel: String
    let profileImageData: Data
    let appThemePreference: String
    let currentTargetCalories: Int?
    let currentTargetProteinGrams: Int?
    let currentTargetCarbGrams: Int?
    let currentTargetFatGrams: Int?

    static func fromUserDefaults() -> BackupProfileSnapshot {
        let defaults = UserDefaults.standard
        let currentTargets = DailyGoalTargets.current
        return BackupProfileSnapshot(
            geminiApiKey: defaults.string(forKey: "GeminiApiKey") ?? "",
            profileName: defaults.string(forKey: "ProfileName") ?? "",
            profileWeightKg: defaults.string(forKey: "ProfileWeightKg") ?? "",
            profileHeightCm: defaults.string(forKey: "ProfileHeightCm") ?? "",
            profileAbout: defaults.string(forKey: "ProfileAbout") ?? "",
            profileBirthDateTimestamp: defaults.object(forKey: "ProfileBirthDateTimestamp") as? Double ?? BackupManager.defaultBirthDateTimestamp,
            profileSex: defaults.string(forKey: "ProfileSex") ?? ProfileSex.unspecified.rawValue,
            profileActivityLevel: defaults.string(forKey: "ProfileActivityLevel") ?? ActivityLevel.sedentary.rawValue,
            profileImageData: defaults.data(forKey: "ProfileImageData") ?? Data(),
            appThemePreference: defaults.string(forKey: "AppThemePreference") ?? AppThemePreference.system.rawValue,
            currentTargetCalories: currentTargets.calories,
            currentTargetProteinGrams: currentTargets.proteinGrams,
            currentTargetCarbGrams: currentTargets.carbGrams,
            currentTargetFatGrams: currentTargets.fatGrams
        )
    }

    func restoreToUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(geminiApiKey, forKey: "GeminiApiKey")
        defaults.set(profileName, forKey: "ProfileName")
        defaults.set(profileWeightKg, forKey: "ProfileWeightKg")
        defaults.set(profileHeightCm, forKey: "ProfileHeightCm")
        defaults.set(profileAbout, forKey: "ProfileAbout")
        defaults.set(profileBirthDateTimestamp, forKey: "ProfileBirthDateTimestamp")
        defaults.set(profileSex, forKey: "ProfileSex")
        defaults.set(profileActivityLevel, forKey: "ProfileActivityLevel")
        defaults.set(profileImageData, forKey: "ProfileImageData")
        defaults.set(appThemePreference, forKey: "AppThemePreference")

        if let currentTargetCalories,
           let currentTargetProteinGrams,
           let currentTargetCarbGrams,
           let currentTargetFatGrams {
            DailyGoalTargets(
                calories: currentTargetCalories,
                proteinGrams: currentTargetProteinGrams,
                carbGrams: currentTargetCarbGrams,
                fatGrams: currentTargetFatGrams
            )
            .saveAsCurrent()
        }
    }
}

struct BackupDailyGoalSnapshot: Codable {
    let date: Date
    let targetCalories: Int
    let targetProteinGrams: Int
    let targetCarbGrams: Int
    let targetFatGrams: Int
    let foodItems: [BackupFoodItemSnapshot]

    init(goal: DailyGoal) {
        date = goal.date
        targetCalories = goal.targetCalories
        targetProteinGrams = goal.targetProteinGrams
        targetCarbGrams = goal.targetCarbGrams
        targetFatGrams = goal.targetFatGrams
        foodItems = (goal.foodItems ?? [])
            .sorted { $0.timestamp < $1.timestamp }
            .map(BackupFoodItemSnapshot.init(item:))
    }
}

struct BackupFoodItemSnapshot: Codable {
    let id: UUID
    let name: String
    let calories: Int
    let grams: Int?
    let proteinGrams: Int?
    let carbGrams: Int?
    let fatGrams: Int?
    let healthScore: Int?
    let timestamp: Date
    let imageData: Data?

    init(item: FoodItem) {
        id = item.id
        name = item.name
        calories = item.calories
        grams = item.grams
        proteinGrams = item.proteinGrams
        carbGrams = item.carbGrams
        fatGrams = item.fatGrams
        healthScore = item.healthScore
        timestamp = item.timestamp
        imageData = item.imageData
    }
}

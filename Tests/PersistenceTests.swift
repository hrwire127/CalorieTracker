import Foundation
import SwiftData
import XCTest
@testable import CalorieTracker

@MainActor
final class PersistenceTests: XCTestCase {
    func testDietTargetsPersistForCurrentAndFutureLoads() throws {
        let defaults = UserDefaults.standard
        let targetKeys = [
            "CurrentTargetCalories",
            "CurrentTargetProteinGrams",
            "CurrentTargetCarbGrams",
            "CurrentTargetFatGrams"
        ]
        var previousValues: [String: Any] = [:]
        for key in targetKeys {
            previousValues[key] = defaults.object(forKey: key)
            defaults.removeObject(forKey: key)
        }
        defer {
            for key in targetKeys {
                if let value = previousValues[key] {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        let container = try makeContainer()
        let context = container.mainContext
        let targets = DailyGoalTargets(
            calories: 2_300,
            proteinGrams: 140,
            carbGrams: 250,
            fatGrams: 80
        )
        let viewModel = DashboardViewModel()

        viewModel.loadToday(using: context)
        viewModel.updateDailyGoal(targets: targets, using: context)

        XCTAssertEqual(viewModel.targetCalories, 2_300)
        XCTAssertEqual(viewModel.targetProteinGrams, 140)
        XCTAssertEqual(DailyGoalTargets.current, targets)

        let reloadedViewModel = DashboardViewModel()
        reloadedViewModel.loadToday(using: context)
        XCTAssertEqual(reloadedViewModel.targetCalories, 2_300)
        XCTAssertEqual(reloadedViewModel.targetCarbGrams, 250)
    }

    func testDuplicateDaysAreConsolidatedWithoutLosingMeals() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let date = try XCTUnwrap(
            Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 10, hour: 12))
        )

        let firstGoal = DailyGoal(date: date, targetCalories: 2_000)
        let secondGoal = DailyGoal(date: date.addingTimeInterval(120), targetCalories: 2_000)
        let breakfast = FoodItem(name: "Breakfast", calories: 350, dailyGoal: firstGoal)
        let lunch = FoodItem(name: "Lunch", calories: 600, dailyGoal: secondGoal)
        firstGoal.foodItems = [breakfast]
        secondGoal.foodItems = [lunch]

        context.insert(firstGoal)
        context.insert(secondGoal)
        context.insert(breakfast)
        context.insert(lunch)
        try context.save()

        try DailyGoalStore.consolidateDuplicateDays(in: context)
        try context.save()

        let goals = try context.fetch(FetchDescriptor<DailyGoal>())
        let consolidatedGoal = try XCTUnwrap(goals.first)
        XCTAssertEqual(goals.count, 1)
        XCTAssertEqual(consolidatedGoal.foodItems?.count, 2)
        XCTAssertEqual(consolidatedGoal.totalConsumedCalories, 950)
    }

    func testBackupRoundTripPreservesMealsButExcludesAPIKey() throws {
        let sourceContainer = try makeContainer()
        let sourceContext = sourceContainer.mainContext
        let goal = DailyGoal(date: Date(), targetCalories: 2_100)
        let meal = FoodItem(
            name: "Pasta",
            calories: 520,
            grams: 300,
            proteinGrams: 22,
            carbGrams: 78,
            fatGrams: 14,
            healthScore: 7,
            dailyGoal: goal
        )
        goal.foodItems = [meal]
        goal.recalculateTotalConsumedCalories()
        sourceContext.insert(goal)
        sourceContext.insert(meal)
        try sourceContext.save()

        let secret = "demo-secret-that-must-not-be-exported"
        let previousAPIKey = UserDefaults.standard.object(forKey: "GeminiApiKey")
        UserDefaults.standard.set(secret, forKey: "GeminiApiKey")
        defer {
            if let previousAPIKey {
                UserDefaults.standard.set(previousAPIKey, forKey: "GeminiApiKey")
            } else {
                UserDefaults.standard.removeObject(forKey: "GeminiApiKey")
            }
        }

        let data = try BackupManager.exportBackup(using: sourceContext)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains(secret))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(CalorieTrackerBackupSnapshot.self, from: data)
        XCTAssertEqual(snapshot.schemaVersion, CalorieTrackerBackupSnapshot.currentSchemaVersion)
        let exportedJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let exportedProfile = try XCTUnwrap(exportedJSON["profile"] as? [String: Any])
        XCTAssertNil(exportedProfile["geminiApiKey"])

        let destinationContainer = try makeContainer()
        let destinationContext = destinationContainer.mainContext
        try BackupManager.importBackup(from: data, using: destinationContext)

        let importedGoals = try destinationContext.fetch(FetchDescriptor<DailyGoal>())
        let importedGoal = try XCTUnwrap(importedGoals.first)
        let importedMeal = try XCTUnwrap(importedGoal.foodItems?.first)
        XCTAssertEqual(importedGoals.count, 1)
        XCTAssertEqual(importedGoal.targetCalories, 2_100)
        XCTAssertEqual(importedGoal.totalConsumedCalories, 520)
        XCTAssertEqual(importedMeal.name, "Pasta")
        XCTAssertEqual(importedMeal.grams, 300)
        XCTAssertEqual(importedMeal.healthScore, 7)
    }

    func testInvalidBackupDoesNotDeleteExistingData() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let existingGoal = DailyGoal(date: Date(), targetCalories: 2_000)
        context.insert(existingGoal)
        try context.save()

        let validData = try BackupManager.exportBackup(using: context)
        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: validData) as? [String: Any]
        )
        var goals = try XCTUnwrap(json["goals"] as? [[String: Any]])
        goals[0]["targetCalories"] = 0
        json["goals"] = goals
        let invalidData = try JSONSerialization.data(withJSONObject: json)

        XCTAssertThrowsError(
            try BackupManager.importBackup(from: invalidData, using: context)
        )

        let remainingGoals = try context.fetch(FetchDescriptor<DailyGoal>())
        XCTAssertEqual(remainingGoals.count, 1)
        XCTAssertEqual(remainingGoals.first?.targetCalories, 2_000)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([DailyGoal.self, FoodItem.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

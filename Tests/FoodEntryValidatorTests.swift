import XCTest
@testable import CalorieTracker

final class FoodEntryValidatorTests: XCTestCase {
    func testOptionalNutritionFieldsMayBeEmpty() throws {
        let entry = try FoodEntryValidator.validate(
            name: "  Apple  ",
            caloriesText: "95",
            gramsText: "",
            proteinText: "",
            carbText: "",
            fatText: "",
            healthScoreText: ""
        )

        XCTAssertEqual(entry.name, "Apple")
        XCTAssertEqual(entry.calories, 95)
        XCTAssertNil(entry.grams)
        XCTAssertNil(entry.proteinGrams)
        XCTAssertNil(entry.healthScore)
    }

    func testInvalidHealthScoreIsRejected() {
        XCTAssertThrowsError(
            try FoodEntryValidator.validate(
                name: "Apple",
                caloriesText: "95",
                healthScoreText: "11"
            )
        ) { error in
            guard case FoodEntryValidationError.invalidHealthScore = error else {
                return XCTFail("Expected invalidHealthScore, received \(error)")
            }
        }
    }
}

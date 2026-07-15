import XCTest
@testable import CalorieTracker

final class GeminiConfigurationTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: GeminiConfiguration.selectedModelKey)
        super.tearDown()
    }

    func testSelectedModelControlsImageAndTextModels() {
        UserDefaults.standard.set(
            GeminiModelOption.gemini25FlashLite.rawValue,
            forKey: GeminiConfiguration.selectedModelKey
        )

        XCTAssertEqual(GeminiConfiguration.selectedModel, .gemini25FlashLite)
        XCTAssertEqual(GeminiConfiguration.imageModel, "gemini-2.5-flash-lite")
        XCTAssertEqual(GeminiConfiguration.textModel, "gemini-2.5-flash-lite")
    }

    func testInvalidSelectedModelFallsBackToDefault() {
        UserDefaults.standard.set(
            "not-a-real-model",
            forKey: GeminiConfiguration.selectedModelKey
        )

        XCTAssertEqual(GeminiConfiguration.selectedModel, .defaultOption)
        XCTAssertEqual(GeminiConfiguration.imageModel, GeminiModelOption.defaultOption.rawValue)
        XCTAssertEqual(GeminiConfiguration.textModel, GeminiModelOption.defaultOption.rawValue)
    }
}

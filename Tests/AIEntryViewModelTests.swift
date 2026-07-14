import UIKit
import XCTest
@testable import CalorieTracker

@MainActor
final class AIEntryViewModelTests: XCTestCase {
    func testManualGuessFillsEditableNutritionFields() async {
        let estimator = StubNutritionEstimator(
            response: .success(Self.estimate)
        )
        let viewModel = ManualEntryViewModel(networkManager: estimator)
        viewModel.foodName = "Chicken breast"
        viewModel.gramsText = "180"

        await viewModel.guessNutrition()

        XCTAssertEqual(viewModel.caloriesText, "297")
        XCTAssertEqual(viewModel.gramsText, "180")
        XCTAssertEqual(viewModel.proteinText, "56")
        XCTAssertEqual(viewModel.carbText, "0")
        XCTAssertEqual(viewModel.fatText, "6")
        XCTAssertEqual(viewModel.healthScoreText, "9")
        XCTAssertTrue(viewModel.hasAIResult)
        XCTAssertNil(viewModel.failure)
    }

    func testManualGuessFailurePreservesRequiredInputs() async {
        let estimator = StubNutritionEstimator(
            response: .failure(.serviceUnavailable)
        )
        let viewModel = ManualEntryViewModel(networkManager: estimator)
        viewModel.foodName = "Rice"
        viewModel.gramsText = "100"

        await viewModel.guessNutrition()

        XCTAssertEqual(viewModel.foodName, "Rice")
        XCTAssertEqual(viewModel.gramsText, "100")
        XCTAssertEqual(viewModel.failure?.title, "AI Service Busy")
        XCTAssertTrue(viewModel.canRetryFailure)
    }

    func testImageFailureKeepsCompressedPhotoForManualFallback() async {
        let estimator = StubNutritionEstimator(
            response: .failure(.rateLimited(retryAfter: 30))
        )
        let viewModel = AICameraEntryViewModel(networkManager: estimator)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80)).image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
        }

        await viewModel.analyze(image: image)

        XCTAssertNotNil(viewModel.selectedImageData)
        XCTAssertTrue(viewModel.canContinueManually)
        XCTAssertEqual(viewModel.failure?.title, "AI Limit Reached")

        viewModel.prepareManualEntry()

        XCTAssertEqual(viewModel.pendingDraft?.calories, 0)
        XCTAssertNotNil(viewModel.pendingDraft?.imageData)
        XCTAssertNil(viewModel.failure)
    }

    private static let estimate = NutritionEstimate(
        foodName: "Chicken Breast",
        estimatedCalories: 297,
        estimatedGrams: 180,
        estimatedProteinGrams: 56,
        estimatedCarbGrams: 0,
        estimatedFatGrams: 6,
        healthScore: 9
    )
}

private actor StubNutritionEstimator: NutritionEstimating {
    enum Response {
        case success(NutritionEstimate)
        case failure(NetworkManagerError)
    }

    private let response: Response

    init(response: Response) {
        self.response = response
    }

    func estimateCalories(fromBase64Image base64Image: String) async throws -> NutritionEstimate {
        try result()
    }

    func estimateNutrition(foodName: String, grams: Int) async throws -> NutritionEstimate {
        try result()
    }

    private func result() throws -> NutritionEstimate {
        switch response {
        case .success(let estimate):
            return estimate
        case .failure(let error):
            throw error
        }
    }
}

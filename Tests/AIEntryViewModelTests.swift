import UIKit
import XCTest
@testable import CalorieTracker

@MainActor
final class AIEntryViewModelTests: XCTestCase {
    func testManualGuessFillsEditableNutritionFields() async {
        let estimator = StubNutritionEstimator(
            response: .success(Self.estimate),
            progressEvents: [
                AIRequestProgressEvent(
                    kind: .active,
                    title: "Sending request to Gemini",
                    detail: "Model test-model."
                )
            ]
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
        XCTAssertTrue(viewModel.progressEntries.contains { $0.event.title == "Preparing food prompt" })
        XCTAssertTrue(viewModel.progressEntries.contains { $0.event.title == "Sending request to Gemini" })
        XCTAssertTrue(viewModel.progressEntries.contains { $0.event.title == "Estimate ready" })
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
            response: .failure(.rateLimited(retryAfter: 30)),
            progressEvents: [
                AIRequestProgressEvent(
                    kind: .warning,
                    title: "Gemini returned HTTP 429",
                    detail: "Rate limit hit. Retry after about 30s."
                )
            ]
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
        XCTAssertTrue(viewModel.progressEntries.contains { $0.event.title == "Photo ready" })
        XCTAssertTrue(viewModel.progressEntries.contains { $0.event.title == "Gemini returned HTTP 429" })
        XCTAssertTrue(viewModel.progressEntries.contains { $0.event.title == "Analysis stopped" })
        XCTAssertEqual(viewModel.currentProgressTitle, "Analysis stopped")
        XCTAssertTrue(viewModel.canRetryAnalysis)

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
    private let progressEvents: [AIRequestProgressEvent]

    init(response: Response, progressEvents: [AIRequestProgressEvent] = []) {
        self.response = response
        self.progressEvents = progressEvents
    }

    func estimateCalories(
        fromBase64Image base64Image: String,
        progress: AIRequestProgressHandler?
    ) async throws -> NutritionEstimate {
        for event in progressEvents {
            await progress?(event)
        }
        try result()
    }

    func estimateNutrition(
        foodName: String,
        grams: Int,
        progress: AIRequestProgressHandler?
    ) async throws -> NutritionEstimate {
        for event in progressEvents {
            await progress?(event)
        }
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

import Combine
import Foundation
import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class AICameraEntryViewModel: ObservableObject {
    @Published private(set) var selectedImage: UIImage?
    @Published private(set) var selectedImageData: Data?
    @Published var pendingDraft: FoodEstimateDraft?
    @Published private(set) var isAnalyzing = false
    @Published private(set) var failure: AIRequestFailure?

    private let networkManager: any NutritionEstimating

    init(networkManager: any NutritionEstimating = NetworkManager.shared) {
        self.networkManager = networkManager
    }

    var errorMessage: String? {
        failure?.message
    }

    var errorTitle: String {
        failure?.title ?? "AI Analysis"
    }

    var canRetryAnalysis: Bool {
        selectedImage != nil && !isAnalyzing
    }

    var canRetryFailure: Bool {
        failure?.canRetry == true && canRetryAnalysis
    }

    var canContinueManually: Bool {
        selectedImageData != nil && !isAnalyzing
    }

    func loadPhoto(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw ImageProcessorError.invalidImageData
            }

            await analyze(image: image)
        } catch {
            showError(error)
        }
    }

    func analyze(image: UIImage) async {
        guard beginAnalysis() else {
            return
        }

        defer { isAnalyzing = false }

        do {
            let compressedData = try ImageProcessor.compressedJPEGData(from: image)
            let previewImage = UIImage(data: compressedData) ?? image
            selectedImage = previewImage
            selectedImageData = compressedData
            try await populateDraft(using: compressedData)
        } catch {
            showError(error)
        }
    }

    func retryLastAnalysis() async {
        guard let selectedImageData, beginAnalysis() else {
            return
        }

        defer { isAnalyzing = false }

        do {
            try await populateDraft(using: selectedImageData)
        } catch {
            showError(error)
        }
    }

    func clearError() {
        failure = nil
    }

    func prepareManualEntry() {
        guard let selectedImageData else {
            return
        }

        failure = nil
        pendingDraft = FoodEstimateDraft(
            foodName: "",
            calories: 0,
            grams: nil,
            proteinGrams: nil,
            carbGrams: nil,
            fatGrams: nil,
            healthScore: nil,
            imageData: selectedImageData
        )
    }

    func showLocalError(title: String, message: String, canRetry: Bool = false) {
        failure = AIRequestFailure(title: title, message: message, canRetry: canRetry)
    }

    private func showError(_ error: Error) {
        failure = AIRequestFailure(error: error, fallbackTitle: "AI Analysis")
    }

    private func beginAnalysis() -> Bool {
        guard !isAnalyzing else {
            return false
        }

        isAnalyzing = true
        failure = nil
        pendingDraft = nil
        return true
    }

    private func populateDraft(using imageData: Data) async throws {
        let estimate = try await networkManager.estimateCalories(
            fromBase64Image: imageData.base64EncodedString()
        )

        pendingDraft = FoodEstimateDraft(
            foodName: estimate.foodName,
            calories: estimate.estimatedCalories,
            grams: estimate.estimatedGrams,
            proteinGrams: estimate.estimatedProteinGrams,
            carbGrams: estimate.estimatedCarbGrams,
            fatGrams: estimate.estimatedFatGrams,
            healthScore: estimate.healthScore,
            imageData: imageData
        )
    }
}

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
    @Published private(set) var progressEntries: [AIRequestProgressEntry] = []

    private let networkManager: any NutritionEstimating
    private let maximumProgressEntryCount = 8

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
        selectedImageData != nil && !isAnalyzing
    }

    var canRetryFailure: Bool {
        failure?.canRetry == true && canRetryAnalysis
    }

    var canContinueManually: Bool {
        selectedImageData != nil && !isAnalyzing
    }

    var currentProgressTitle: String {
        progressEntries.last?.event.title ?? "Ready for AI scan"
    }

    var currentProgressDetail: String {
        progressEntries.last?.event.detail ?? "Select or capture a food photo to start."
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
            recordProgress(
                AIRequestProgressEvent(
                    kind: .active,
                    title: "Compressing photo",
                    detail: "Preparing the image before sending it to Gemini."
                )
            )
            let compressedData = try ImageProcessor.compressedJPEGData(from: image)
            let previewImage = UIImage(data: compressedData) ?? image
            selectedImage = previewImage
            selectedImageData = compressedData
            recordProgress(
                AIRequestProgressEvent(
                    kind: .success,
                    title: "Photo ready",
                    detail: ByteCountFormatter.string(fromByteCount: Int64(compressedData.count), countStyle: .file)
                )
            )
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
            recordProgress(
                AIRequestProgressEvent(
                    kind: .active,
                    title: "Reusing last photo",
                    detail: "Sending the already compressed image again."
                )
            )
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
        recordProgress(
            AIRequestProgressEvent(
                kind: .failure,
                title: "Analysis stopped",
                detail: failure?.message
            )
        )
    }

    private func beginAnalysis() -> Bool {
        guard !isAnalyzing else {
            return false
        }

        isAnalyzing = true
        failure = nil
        pendingDraft = nil
        progressEntries = []
        return true
    }

    private func populateDraft(using imageData: Data) async throws {
        let estimate = try await networkManager.estimateCalories(
            fromBase64Image: imageData.base64EncodedString(),
            progress: progressHandler()
        )

        recordProgress(
            AIRequestProgressEvent(
                kind: .success,
                title: "Estimate ready",
                detail: estimate.aiProgressSummary
            )
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

    private func progressHandler() -> AIRequestProgressHandler {
        { [weak self] event in
            await self?.recordProgress(event)
        }
    }

    private func recordProgress(_ event: AIRequestProgressEvent) {
        progressEntries.append(AIRequestProgressEntry(event: event))
        if progressEntries.count > maximumProgressEntryCount {
            progressEntries.removeFirst(progressEntries.count - maximumProgressEntryCount)
        }
    }
}

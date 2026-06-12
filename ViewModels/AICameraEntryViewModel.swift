import Combine
import Foundation
import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class AICameraEntryViewModel: ObservableObject {
    @Published private(set) var selectedImage: UIImage?
    @Published var pendingDraft: FoodEstimateDraft?
    @Published private(set) var isAnalyzing = false
    @Published var errorMessage: String?

    private let networkManager: NetworkManager

    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
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
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let compressedData = try ImageProcessor.compressedJPEGData(from: image)
            let previewImage = UIImage(data: compressedData) ?? image
            selectedImage = previewImage

            let base64Image = compressedData.base64EncodedString()
            let estimate = try await networkManager.estimateCalories(fromBase64Image: base64Image)

            pendingDraft = FoodEstimateDraft(
                foodName: estimate.foodName,
                calories: estimate.estimatedCalories,
                grams: estimate.estimatedGrams,
                proteinGrams: estimate.estimatedProteinGrams,
                carbGrams: estimate.estimatedCarbGrams,
                fatGrams: estimate.estimatedFatGrams,
                healthScore: estimate.healthScore,
                imageData: compressedData
            )
        } catch {
            showError(error)
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}

import PhotosUI
import SwiftUI
import UIKit

struct AICameraEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AICameraEntryViewModel()

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingCamera = false

    let onSave: (String, Int, Int?, Int?, Int?, Int?, Int?, Data?) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                imagePreview

                HStack(spacing: 12) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Photos", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isAnalyzing)

                    Button {
                        openCamera()
                    } label: {
                        Label("Camera", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isAnalyzing)
                }

                if viewModel.isAnalyzing {
                    ProgressView("Analyzing")
                        .padding(.top, 4)
                }

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("AI Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else {
                    return
                }

                Task {
                    await viewModel.loadPhoto(from: newItem)
                    await MainActor.run {
                        selectedPhotoItem = nil
                    }
                }
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraPickerView { image in
                    Task {
                        await viewModel.analyze(image: image)
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(item: $viewModel.pendingDraft) { draft in
                FoodConfirmationView(draft: draft) { name, calories, grams, protein, carbs, fat, healthScore, imageData in
                    onSave(name, calories, grams, protein, carbs, fat, healthScore, imageData)
                    viewModel.pendingDraft = nil
                    dismiss()
                }
            }
            .alert("AI Analysis", isPresented: errorBinding) {
                Button("OK", role: .cancel) {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let image = viewModel.selectedImage {
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.secondary.opacity(0.16))
                    }

                if viewModel.isAnalyzing {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.black.opacity(0.28))

                    ProgressView()
                        .tint(.white)
                }
            }
        } else {
            ContentUnavailableView("Select a Food Photo", systemImage: "camera.viewfinder")
                .frame(maxWidth: .infinity)
                .frame(height: 340)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding {
            viewModel.errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                viewModel.clearError()
            }
        }
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            viewModel.errorMessage = "Camera is not available on this device."
            return
        }

        Task {
            let hasAccess = await CameraAuthorization.requestAccess()

            await MainActor.run {
                if hasAccess {
                    isShowingCamera = true
                } else {
                    viewModel.errorMessage = "Camera access is required to capture food photos."
                }
            }
        }
    }
}

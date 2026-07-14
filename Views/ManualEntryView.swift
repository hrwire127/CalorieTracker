import PhotosUI
import SwiftUI
import UIKit

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @StateObject private var viewModel = ManualEntryViewModel()
    @State private var selectedMode: EntryMode = .manual
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?

    let onSave: (String, Int, Int?, Int?, Int?, Int?, Int?, Data?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Entry Mode", selection: $selectedMode) {
                        ForEach(EntryMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                switch selectedMode {
                case .manual:
                    manualSections
                case .aiGuess:
                    aiGuessSections
                }

                imageSection

                if let validationMessage = viewModel.validationMessage {
                    Section {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .onAppear {
                focusedField = .name
            }
            .onChange(of: selectedMode) { _, _ in
                focusedField = .name
            }
            .alert(viewModel.errorTitle, isPresented: errorBinding) {
                if viewModel.canRetryFailure {
                    Button("Retry") {
                        Task {
                            await viewModel.guessNutrition()
                        }
                    }
                }

                Button("Continue Manually") {
                    viewModel.clearError()
                    selectedMode = .manual
                }

                Button("OK", role: .cancel) {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var manualSections: some View {
        Section("Food Details") {
            foodNameInput
            caloriesInput
            weightInput
            caloriesPerGramRow
        }

        nutritionSection(title: "Nutrition (Optional)")
    }

    @ViewBuilder
    private var aiGuessSections: some View {
        Section("AI Guess") {
            foodNameInput
            weightInput

            Button {
                Task {
                    await viewModel.guessNutrition()
                }
            } label: {
                HStack {
                    if viewModel.isGuessingNutrition {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "sparkles")
                    }

                    Text(viewModel.isGuessingNutrition ? "Guessing" : "AI Guess")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(!viewModel.canGuessNutrition)

            if viewModel.hasAIResult {
                Label("Estimate ready to review", systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
        }

        Section("Editable Estimate") {
            caloriesInput
            caloriesPerGramRow
        }

        nutritionSection(title: "Nutrition Estimate")
    }

    private var imageSection: some View {
        Section("Image (Optional)") {
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    if let selectedImageData, let uiImage = UIImage(data: selectedImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 4)
                    }

                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(selectedImageData == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                            .font(.headline)
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                selectedImageData = data
                            }
                        }
                    }

                    if selectedImageData != nil {
                        Button("Remove Photo", role: .destructive) {
                            selectedItem = nil
                            selectedImageData = nil
                        }
                        .font(.footnote)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    private var foodNameInput: some View {
        HStack(spacing: 10) {
            FieldIcon(systemName: "fork.knife", tint: .green)
            TextField("Food Name", text: $viewModel.foodName)
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .name)
        }
    }

    private var caloriesInput: some View {
        MacroInputRow(
            title: "Calories",
            systemImage: "flame.fill",
            tint: .red,
            placeholder: "kcal",
            text: $viewModel.caloriesText
        )
        .focused($focusedField, equals: .calories)
    }

    private var weightInput: some View {
        MacroInputRow(
            title: "Weight",
            systemImage: "scalemass.fill",
            tint: .teal,
            placeholder: "grams",
            text: $viewModel.gramsText
        )
        .focused($focusedField, equals: .grams)
    }

    @ViewBuilder
    private var caloriesPerGramRow: some View {
        if let caloriesPerGram = viewModel.caloriesPerGram {
            LabeledContent("Calories per gram", value: caloriesPerGram.formatted(.number.precision(.fractionLength(2))))
        }
    }

    private func nutritionSection(title: String) -> some View {
        Section(title) {
            MacroInputRow(title: "Protein", systemImage: "bolt.fill", tint: .purple, placeholder: "g", text: $viewModel.proteinText)
                .focused($focusedField, equals: .protein)

            MacroInputRow(title: "Carbs", systemImage: "leaf.fill", tint: .blue, placeholder: "g", text: $viewModel.carbText)
                .focused($focusedField, equals: .carbs)

            MacroInputRow(title: "Fat", systemImage: "drop.fill", tint: .orange, placeholder: "g", text: $viewModel.fatText)
                .focused($focusedField, equals: .fat)

            MacroInputRow(title: "Health", systemImage: "heart.fill", tint: .pink, placeholder: "1-10", text: $viewModel.healthScoreText)
                .focused($focusedField, equals: .healthScore)
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

    private func save() {
        do {
            viewModel.validationMessage = nil
            let entry = try viewModel.validatedEntry()
            onSave(
                entry.name,
                entry.calories,
                entry.grams,
                entry.proteinGrams,
                entry.carbGrams,
                entry.fatGrams,
                entry.healthScore,
                selectedImageData
            )
            dismiss()
        } catch {
            viewModel.validationMessage = error.localizedDescription
        }
    }

    private enum EntryMode: CaseIterable, Hashable, Identifiable {
        case manual
        case aiGuess

        var id: Self { self }

        var title: String {
            switch self {
            case .manual:
                return "Manual"
            case .aiGuess:
                return "AI Guess"
            }
        }
    }

    private enum Field: Hashable {
        case name
        case calories
        case grams
        case protein
        case carbs
        case fat
        case healthScore
    }
}

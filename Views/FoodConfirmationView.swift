import SwiftUI
import UIKit

struct FoodConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var foodName: String
    @State private var caloriesText: String
    @State private var gramsText: String
    @State private var proteinText: String
    @State private var carbText: String
    @State private var fatText: String
    @State private var healthScoreText: String
    @State private var validationMessage: String?

    private let imageData: Data?
    private let onSave: (String, Int, Int?, Int?, Int?, Int?, Int?, Data?) -> Void

    init(
        draft: FoodEstimateDraft,
        onSave: @escaping (String, Int, Int?, Int?, Int?, Int?, Int?, Data?) -> Void
    ) {
        _foodName = State(initialValue: draft.foodName)
        _caloriesText = State(initialValue: draft.calories > 0 ? "\(draft.calories)" : "")
        _gramsText = State(initialValue: draft.grams.map { String($0) } ?? "")
        _proteinText = State(initialValue: draft.proteinGrams.map { String($0) } ?? "")
        _carbText = State(initialValue: draft.carbGrams.map { String($0) } ?? "")
        _fatText = State(initialValue: draft.fatGrams.map { String($0) } ?? "")
        _healthScoreText = State(initialValue: draft.healthScore.map { String($0) } ?? "")
        self.imageData = draft.imageData
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                if let imageData,
                   let image = UIImage(data: imageData) {
                    Section {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }

                Section("Estimate") {
                    HStack(spacing: 10) {
                        FieldIcon(systemName: "fork.knife", tint: .green)
                        TextField("Food Name", text: $foodName)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .name)
                    }

                    MacroInputRow(
                        title: "Calories",
                        systemImage: "flame.fill",
                        tint: .red,
                        placeholder: "kcal",
                        text: $caloriesText
                    )
                        .focused($focusedField, equals: .calories)

                    MacroInputRow(
                        title: "Weight",
                        systemImage: "scalemass.fill",
                        tint: .teal,
                        placeholder: "grams",
                        text: $gramsText
                    )
                        .focused($focusedField, equals: .grams)

                    if let caloriesPerGram {
                        LabeledContent("Calories per gram", value: caloriesPerGram.formatted(.number.precision(.fractionLength(2))))
                    }
                }

                Section("Nutrition Estimate") {
                    MacroInputRow(title: "Protein", systemImage: "bolt.fill", tint: .purple, placeholder: "g", text: $proteinText)
                        .focused($focusedField, equals: .protein)

                    MacroInputRow(title: "Carbs", systemImage: "leaf.fill", tint: .blue, placeholder: "g", text: $carbText)
                        .focused($focusedField, equals: .carbs)

                    MacroInputRow(title: "Fat", systemImage: "drop.fill", tint: .orange, placeholder: "g", text: $fatText)
                        .focused($focusedField, equals: .fat)

                    MacroInputRow(title: "Health", systemImage: "heart.fill", tint: .pink, placeholder: "1-10", text: $healthScoreText)
                        .focused($focusedField, equals: .healthScore)
                }

                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Confirm Food")
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
                    .disabled(!canSave)
                }
            }
            .onAppear {
                focusedField = .name
            }
        }
    }

    private var canSave: Bool {
        FoodEntryValidator.canSave(
            name: foodName,
            caloriesText: caloriesText,
            gramsText: gramsText,
            proteinText: proteinText,
            carbText: carbText,
            fatText: fatText,
            healthScoreText: healthScoreText
        )
    }

    private func save() {
        do {
            let entry = try FoodEntryValidator.validate(
                name: foodName,
                caloriesText: caloriesText,
                gramsText: gramsText,
                proteinText: proteinText,
                carbText: carbText,
                fatText: fatText,
                healthScoreText: healthScoreText
            )
            onSave(
                entry.name,
                entry.calories,
                entry.grams,
                entry.proteinGrams,
                entry.carbGrams,
                entry.fatGrams,
                entry.healthScore,
                imageData
            )
            dismiss()
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    private var caloriesPerGram: Double? {
        guard let calories = Int(caloriesText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let grams = Int(gramsText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        return NutritionCalculator.caloriesPerGram(calories: calories, grams: grams)
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

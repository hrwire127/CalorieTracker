import SwiftUI
import UIKit

struct FoodEditorView: View {
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

    private let item: FoodItem
    private let onSave: (ValidatedFoodEntry) -> Void

    init(item: FoodItem, onSave: @escaping (ValidatedFoodEntry) -> Void) {
        self.item = item
        self.onSave = onSave
        _foodName = State(initialValue: item.name)
        _caloriesText = State(initialValue: "\(item.calories)")
        _gramsText = State(initialValue: item.grams.map { String($0) } ?? "")
        _proteinText = State(initialValue: item.proteinGrams.map { String($0) } ?? "")
        _carbText = State(initialValue: item.carbGrams.map { String($0) } ?? "")
        _fatText = State(initialValue: item.fatGrams.map { String($0) } ?? "")
        _healthScoreText = State(initialValue: item.healthScore.map { String($0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                if let imageData = item.imageData,
                   let image = UIImage(data: imageData) {
                    Section {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 190)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }

                Section("Food Details") {
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

                Section("Nutrition") {
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
            .navigationTitle("Edit Food")
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

    private var caloriesPerGram: Double? {
        guard let calories = Int(caloriesText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let grams = Int(gramsText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        return NutritionCalculator.caloriesPerGram(calories: calories, grams: grams)
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
            onSave(entry)
            dismiss()
        } catch {
            validationMessage = error.localizedDescription
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

struct MacroInputRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            FieldIcon(systemName: systemImage, tint: tint)

            Text(title)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
    }
}

struct FieldIcon: View {
    let systemName: String
    let tint: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.caption.weight(.bold))
            .foregroundStyle(tint)
            .frame(width: 26, height: 26)
            .background(tint.opacity(0.12), in: Circle())
    }
}

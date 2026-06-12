import SwiftUI
import UIKit

struct FoodConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var foodName: String
    @State private var caloriesText: String
    @State private var validationMessage: String?

    private let imageData: Data?
    private let onSave: (String, Int, Data?) -> Void

    init(
        draft: FoodEstimateDraft,
        onSave: @escaping (String, Int, Data?) -> Void
    ) {
        _foodName = State(initialValue: draft.foodName)
        _caloriesText = State(initialValue: "\(draft.calories)")
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
                    TextField("Food Name", text: $foodName)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)

                    TextField("Calories", text: $caloriesText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .calories)
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
        FoodEntryValidator.canSave(name: foodName, caloriesText: caloriesText)
    }

    private func save() {
        do {
            let entry = try FoodEntryValidator.validate(
                name: foodName,
                caloriesText: caloriesText
            )
            onSave(entry.name, entry.calories, imageData)
            dismiss()
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    private enum Field: Hashable {
        case name
        case calories
    }
}

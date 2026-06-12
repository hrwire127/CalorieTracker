import SwiftUI

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var foodName = ""
    @State private var caloriesText = ""
    @State private var validationMessage: String?

    let onSave: (String, Int) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
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
            onSave(entry.name, entry.calories)
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

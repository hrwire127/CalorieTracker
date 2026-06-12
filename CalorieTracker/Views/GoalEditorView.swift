import SwiftUI

struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var targetCalories: Int

    let onSave: (Int) -> Void

    init(initialGoal: Int, onSave: @escaping (Int) -> Void) {
        _targetCalories = State(initialValue: initialGoal)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily Goal") {
                    Stepper(value: $targetCalories, in: 500...8_000, step: 50) {
                        LabeledContent("Target", value: "\(targetCalories) kcal")
                    }
                }
            }
            .navigationTitle("Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(targetCalories)
                        dismiss()
                    }
                }
            }
        }
    }
}

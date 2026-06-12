import SwiftUI

struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("ProfileWeightKg") private var profileWeightKg: String = ""
    @AppStorage("ProfileHeightCm") private var profileHeightCm: String = ""
    @AppStorage("ProfileBirthDateTimestamp") private var profileBirthDateTimestamp: Double = 631_152_000
    @AppStorage("ProfileSex") private var profileSex = ProfileSex.unspecified.rawValue
    @AppStorage("ProfileActivityLevel") private var profileActivityLevel = ActivityLevel.sedentary.rawValue

    @State private var targetCalories: Int
    @State private var targetProteinGrams: Int
    @State private var targetCarbGrams: Int
    @State private var targetFatGrams: Int

    let onSave: (DailyGoalTargets) -> Void

    init(initialTargets: DailyGoalTargets, onSave: @escaping (DailyGoalTargets) -> Void) {
        _targetCalories = State(initialValue: initialTargets.calories)
        _targetProteinGrams = State(initialValue: initialTargets.proteinGrams)
        _targetCarbGrams = State(initialValue: initialTargets.carbGrams)
        _targetFatGrams = State(initialValue: initialTargets.fatGrams)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily Calories") {
                    Stepper(value: $targetCalories, in: 500...8_000, step: 50) {
                        LabeledContent("Target", value: "\(targetCalories) kcal")
                    }

                    if let maintenanceCalories {
                        LabeledContent("Maintenance", value: "\(maintenanceCalories) kcal")
                    } else {
                        Text("Complete your profile to estimate maintenance calories.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Macro Goals") {
                    Stepper(value: $targetProteinGrams, in: 0...400, step: 5) {
                        LabeledContent("Protein", value: "\(targetProteinGrams) g")
                    }

                    Stepper(value: $targetCarbGrams, in: 0...700, step: 5) {
                        LabeledContent("Carbs", value: "\(targetCarbGrams) g")
                    }

                    Stepper(value: $targetFatGrams, in: 0...300, step: 5) {
                        LabeledContent("Fat", value: "\(targetFatGrams) g")
                    }

                    Button {
                        targetCarbGrams = DailyGoal.defaultCarbGoal(
                            calories: targetCalories,
                            proteinGrams: targetProteinGrams,
                            fatGrams: targetFatGrams
                        )
                    } label: {
                        Label("Set remaining calories as carbs", systemImage: "scalemass")
                    }
                }

                Section("Diet Score") {
                    LabeledContent("Score", value: "\(dietScore)/10")

                    LabeledContent("Macro Calories", value: "\(macroCalories) kcal")

                    Text(scoreDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                        onSave(
                            DailyGoalTargets(
                                calories: targetCalories,
                                proteinGrams: targetProteinGrams,
                                carbGrams: targetCarbGrams,
                                fatGrams: targetFatGrams
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
    }

    private var maintenanceCalories: Int? {
        NutritionCalculator.maintenanceCalories(
            weightKgText: profileWeightKg,
            heightCmText: profileHeightCm,
            birthDateTimestamp: profileBirthDateTimestamp,
            sexRawValue: profileSex,
            activityRawValue: profileActivityLevel
        )
    }

    private var macroCalories: Int {
        NutritionCalculator.macroCalories(
            proteinGrams: targetProteinGrams,
            carbGrams: targetCarbGrams,
            fatGrams: targetFatGrams
        )
    }

    private var dietScore: Int {
        NutritionCalculator.dietScore(
            targetCalories: targetCalories,
            proteinGrams: targetProteinGrams,
            carbGrams: targetCarbGrams,
            fatGrams: targetFatGrams,
            maintenanceCalories: maintenanceCalories
        )
    }

    private var scoreDescription: String {
        let calorieDifference = macroCalories - targetCalories
        if abs(calorieDifference) <= 100 {
            return "Your macro targets are close to the calorie goal. The score also considers your profile maintenance estimate when available."
        }

        if calorieDifference > 0 {
            return "Macro targets add up above your calorie goal. Lower carbs, fat, or protein to make the plan tighter."
        }

        return "Macro targets add up below your calorie goal. Add carbs, protein, or fat to better match the plan."
    }
}

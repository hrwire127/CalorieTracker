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
                Section {
                    DietScorePanelView(
                        score: dietScore,
                        targetCalories: targetCalories,
                        macroCalories: macroCalories,
                        maintenanceCalories: maintenanceCalories,
                        dailyDeficit: dailyDeficit
                    )
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))

                Section("Daily Calories") {
                    Stepper(value: $targetCalories, in: 500...8_000, step: 50) {
                        GoalStepperLabel(
                            title: "Target",
                            value: "\(targetCalories) kcal",
                            systemImage: "flame.fill",
                            tint: .red
                        )
                    }

                    if let maintenanceCalories {
                        GoalInfoRow(
                            title: "Maintenance",
                            value: "\(maintenanceCalories) kcal",
                            systemImage: "speedometer",
                            tint: .blue
                        )

                        GoalInfoRow(
                            title: deficitTitle,
                            value: "\(abs(dailyDeficit)) kcal/day",
                            systemImage: dailyDeficit >= 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill",
                            tint: dailyDeficit >= 0 ? .green : .orange
                        )

                        GoalInfoRow(
                            title: "7-day total",
                            value: "\(abs(dailyDeficit * 7)) kcal",
                            systemImage: "calendar",
                            tint: dailyDeficit >= 0 ? .green : .orange
                        )
                    } else {
                        Text("Complete your profile to estimate maintenance and deficit.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Macro Goals") {
                    Stepper(value: $targetProteinGrams, in: 0...400, step: 5) {
                        GoalStepperLabel(title: "Protein", value: "\(targetProteinGrams) g", systemImage: "bolt.fill", tint: .purple)
                    }

                    Stepper(value: $targetCarbGrams, in: 0...700, step: 5) {
                        GoalStepperLabel(title: "Carbs", value: "\(targetCarbGrams) g", systemImage: "leaf.fill", tint: .blue)
                    }

                    Stepper(value: $targetFatGrams, in: 0...300, step: 5) {
                        GoalStepperLabel(title: "Fat", value: "\(targetFatGrams) g", systemImage: "drop.fill", tint: .orange)
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

                Section("Plan Notes") {
                    Text(scoreDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Diet Goal")
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

    private var dailyDeficit: Int {
        guard let maintenanceCalories else {
            return 0
        }

        return maintenanceCalories - targetCalories
    }

    private var deficitTitle: String {
        dailyDeficit >= 0 ? "Deficit" : "Surplus"
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
            return "Your macro targets are close to your calorie goal. The score also considers your maintenance estimate when available."
        }

        if calorieDifference > 0 {
            return "Macro targets add up above your calorie goal. Lower carbs, fat, or protein to make the plan tighter."
        }

        return "Macro targets add up below your calorie goal. Add carbs, protein, or fat to better match the plan."
    }
}

private struct DietScorePanelView: View {
    let score: Int
    let targetCalories: Int
    let macroCalories: Int
    let maintenanceCalories: Int?
    let dailyDeficit: Int

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 11)

                Circle()
                    .trim(from: 0, to: Double(score) / 10)
                    .stroke(scoreTint, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text("/10")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 8) {
                Text("Diet Score")
                    .font(.headline)

                Text("Target \(targetCalories) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Text("Macros \(macroCalories) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                if let maintenanceCalories {
                    Text("Maintenance \(maintenanceCalories) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Text("\(dailyDeficit >= 0 ? "Deficit" : "Surplus") \(abs(dailyDeficit)) kcal/day")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(dailyDeficit >= 0 ? .green : .orange)
                        .monospacedDigit()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(scoreTint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var scoreTint: Color {
        switch score {
        case 8...10:
            return .green
        case 5...7:
            return .orange
        default:
            return .red
        }
    }
}

private struct GoalStepperLabel: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            FieldIcon(systemName: systemImage, tint: tint)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

private struct GoalInfoRow: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            FieldIcon(systemName: systemImage, tint: tint)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

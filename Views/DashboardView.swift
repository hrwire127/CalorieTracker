import SwiftData
import SwiftUI
import UIKit

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = DashboardViewModel()

    @State private var isShowingManualEntry = false
    @State private var isShowingGoalEditor = false
    @State private var editingFoodItem: FoodItem?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 4) {
                        HStack {
                            Button {
                                isShowingGoalEditor = true
                            } label: {
                                Image(systemName: "target")
                                    .font(.headline)
                                    .frame(width: 36, height: 36)
                                    .background(.regularMaterial, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Diet Goal")

                            Spacer()

                            Text("Today")
                                .font(.headline.weight(.semibold))

                            Spacer()

                            Button {
                                isShowingManualEntry = true
                            } label: {
                                Image(systemName: "square.and.pencil")
                                    .font(.headline)
                                    .frame(width: 36, height: 36)
                                    .background(.regularMaterial, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Manual Entry")
                        }
                        .padding(.top, 2)

                        HabitHeaderView(
                            habitDays: viewModel.habitDays,
                            currentStreak: viewModel.currentStreak
                        )

                        DashboardSummaryView(viewModel: viewModel)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 14, trailing: 18))
                    .listRowBackground(Color.clear)
                }

                Section("Today's Food") {
                    if viewModel.foodItems.isEmpty {
                        ContentUnavailableView(
                            "No Food Logged",
                            systemImage: "fork.knife"
                        )
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(viewModel.foodItems, id: \.id) { item in
                            FoodItemRowView(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingFoodItem = item
                                }
                        }
                        .onDelete { offsets in
                            viewModel.deleteFoodItems(at: offsets, using: modelContext)
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $isShowingManualEntry) {
                ManualEntryView { name, calories, grams, protein, carbs, fat, healthScore, imageData in
                    viewModel.addFoodItem(
                        name: name,
                        calories: calories,
                        grams: grams,
                        proteinGrams: protein,
                        carbGrams: carbs,
                        fatGrams: fat,
                        healthScore: healthScore,
                        imageData: imageData,
                        using: modelContext
                    )
                }
            }
            .sheet(isPresented: $isShowingGoalEditor) {
                GoalEditorView(
                    initialTargets: DailyGoalTargets(
                        calories: viewModel.targetCalories,
                        proteinGrams: viewModel.targetProteinGrams,
                        carbGrams: viewModel.targetCarbGrams,
                        fatGrams: viewModel.targetFatGrams
                    )
                ) { targets in
                    viewModel.updateDailyGoal(targets: targets, using: modelContext)
                }
            }
            .sheet(item: $editingFoodItem) { item in
                FoodEditorView(item: item) { entry in
                    viewModel.updateFoodItem(item, with: entry, using: modelContext)
                }
            }
            .alert("Calorie Tracker", isPresented: errorBinding) {
                Button("OK", role: .cancel) {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear {
                viewModel.loadToday(using: modelContext)
            }
            .onReceive(NotificationCenter.default.publisher(for: .foodItemsDidChange)) { _ in
                viewModel.loadToday(using: modelContext)
            }
            .refreshable {
                viewModel.loadToday(using: modelContext)
            }
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
}

private struct HabitHeaderView: View {
    let habitDays: [HabitDaySummary]
    let currentStreak: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(habitDays) { day in
                    HabitDayPillView(day: day)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 0)
    }
}

private struct HabitDayPillView: View {
    let day: HabitDaySummary

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(day.isLogged ? Color.primary.opacity(0.10) : Color.clear)

                Circle()
                    .strokeBorder(
                        day.isToday ? Color.primary : Color.secondary.opacity(0.55),
                        style: StrokeStyle(
                            lineWidth: day.isToday ? 2.5 : 2,
                            lineCap: .round,
                            dash: strokeDash
                        )
                    )

                Text(weekdaySymbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(day.isLogged || day.isToday ? .primary : .secondary)
            }
            .frame(width: 34, height: 34)

            Text(dayNumber)
                .font(.caption.weight(day.isToday ? .bold : .regular))
                .foregroundStyle(day.isToday ? .primary : .secondary)
                .monospacedDigit()

            Circle()
                .fill(day.isLogged ? Color.green : Color.clear)
                .frame(width: 4, height: 4)
        }
    }

    private var weekdaySymbol: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: day.date).prefix(1))
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: day.date)
    }

    private var strokeDash: [CGFloat] {
        day.isLogged || day.isToday ? [] : [5, 5]
    }
}

private struct DashboardSummaryView: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: 22) {
            ProgressRingView(
                progress: viewModel.progress,
                remainingCalories: viewModel.remainingCalories,
                consumedCalories: viewModel.consumedCalories,
                targetCalories: viewModel.targetCalories,
                isOverGoal: viewModel.isOverGoal
            )
            .frame(width: 210, height: 210)
            .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                CalorieMetricView(
                    title: "Consumed Calories",
                    value: viewModel.consumedCalories,
                    tint: viewModel.isOverGoal ? .red : .green
                )

                CalorieMetricView(
                    title: viewModel.isOverGoal ? "Over Goal" : "Daily Goal",
                    value: viewModel.isOverGoal ? viewModel.overageCalories : viewModel.targetCalories,
                    tint: viewModel.isOverGoal ? .red : .blue
                )
            }

            VStack(spacing: 10) {
                MacroProgressRowView(
                    title: "Protein",
                    consumed: viewModel.consumedProteinGrams,
                    target: viewModel.targetProteinGrams,
                    tint: .purple
                )

                MacroProgressRowView(
                    title: "Carbs",
                    consumed: viewModel.consumedCarbGrams,
                    target: viewModel.targetCarbGrams,
                    tint: .blue
                )

                MacroProgressRowView(
                    title: "Fat",
                    consumed: viewModel.consumedFatGrams,
                    target: viewModel.targetFatGrams,
                    tint: .orange
                )
            }
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 8)
    }
}

private struct ProgressRingView: View {
    let progress: Double
    let remainingCalories: Int
    let consumedCalories: Int
    let targetCalories: Int
    let isOverGoal: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.14), lineWidth: 18)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progressStyle,
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: progress)

            VStack(spacing: 6) {
                Text("\(remainingCalories)")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(isOverGoal ? .red : .primary)

                Text("kcal remaining")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("\(consumedCalories) used of \(targetCalories)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(remainingCalories) calories remaining. \(consumedCalories) used of \(targetCalories).")
    }

    private var progressStyle: AngularGradient {
        AngularGradient(
            colors: isOverGoal ? [.red, .orange, .red] : [.green, .teal, .blue],
            center: .center
        )
    }
}

private struct CalorieMetricView: View {
    let title: String
    let value: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(value)")
                    .font(.title2.bold())
                    .monospacedDigit()
                    .foregroundStyle(tint)

                Text("kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MacroProgressRowView: View {
    let title: String
    let consumed: Int
    let target: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))

                Spacer()

                Text("\(consumed) / \(target) g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ProgressView(value: progress)
                .tint(tint)
        }
    }

    private var progress: Double {
        guard target > 0 else {
            return 0
        }

        return min(Double(consumed) / Double(target), 1)
    }
}

private struct FoodItemRowView: View {
    let item: FoodItem

    var body: some View {
        HStack(spacing: 12) {
            itemImage
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body.weight(.medium))

                Text(itemDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !macroDescription.isEmpty {
                    Text(macroDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(item.calories) kcal")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                if let healthScore = item.healthScore {
                    Text("\(healthScore)/10")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(healthScore >= 7 ? .green : .orange)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var itemImage: some View {
        if let imageData = item.imageData,
           let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Image(systemName: "fork.knife.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
        }
    }

    private var itemDescription: String {
        let time = item.timestamp.formatted(date: .omitted, time: .shortened)
        var details = [time]

        if let grams = item.grams {
            details.append("\(grams) g")
        }

        if let caloriesPerGram = item.caloriesPerGram {
            details.append("\(caloriesPerGram.formatted(.number.precision(.fractionLength(2)))) kcal/g")
        }

        return details.joined(separator: " - ")
    }

    private var macroDescription: String {
        var parts: [String] = []

        if let protein = item.proteinGrams {
            parts.append("P \(protein)g")
        }

        if let carbs = item.carbGrams {
            parts.append("C \(carbs)g")
        }

        if let fat = item.fatGrams {
            parts.append("F \(fat)g")
        }

        return parts.joined(separator: " - ")
    }
}

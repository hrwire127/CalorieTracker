import SwiftData
import SwiftUI
import UIKit

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = DashboardViewModel()

    @State private var isShowingManualEntry = false
    @State private var isShowingAIEntry = false
    @State private var isShowingGoalEditor = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DashboardSummaryView(viewModel: viewModel)
                        .listRowInsets(EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18))
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
                        }
                        .onDelete { offsets in
                            viewModel.deleteFoodItems(at: offsets, using: modelContext)
                        }
                    }
                }
            }
            .navigationTitle("Today")
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingGoalEditor = true
                    } label: {
                        Label("Goal", systemImage: "target")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            isShowingManualEntry = true
                        } label: {
                            Label("Manual", systemImage: "keyboard")
                        }

                        Button {
                            isShowingAIEntry = true
                        } label: {
                            Label("AI Scan", systemImage: "camera.viewfinder")
                        }
                    } label: {
                        Label("Add Food", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $isShowingManualEntry) {
                ManualEntryView { name, calories, imageData in
                    viewModel.addFoodItem(
                        name: name,
                        calories: calories,
                        imageData: imageData,
                        using: modelContext
                    )
                }
            }
            .sheet(isPresented: $isShowingAIEntry) {
                AICameraEntryView { name, calories, imageData in
                    viewModel.addFoodItem(
                        name: name,
                        calories: calories,
                        imageData: imageData,
                        using: modelContext
                    )
                }
            }
            .sheet(isPresented: $isShowingGoalEditor) {
                GoalEditorView(initialGoal: viewModel.targetCalories) { targetCalories in
                    viewModel.updateDailyGoal(
                        targetCalories: targetCalories,
                        using: modelContext
                    )
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

private struct DashboardSummaryView: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: 22) {
            ProgressRingView(
                progress: viewModel.progress,
                consumedCalories: viewModel.consumedCalories,
                targetCalories: viewModel.targetCalories,
                isOverGoal: viewModel.isOverGoal
            )
            .frame(width: 210, height: 210)
            .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                CalorieMetricView(
                    title: "Remaining Calories",
                    value: viewModel.remainingCalories,
                    tint: viewModel.isOverGoal ? .red : .green
                )

                CalorieMetricView(
                    title: viewModel.isOverGoal ? "Over Goal" : "Daily Goal",
                    value: viewModel.isOverGoal ? viewModel.overageCalories : viewModel.targetCalories,
                    tint: viewModel.isOverGoal ? .red : .blue
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
                Text("\(consumedCalories)")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()

                Text("of \(targetCalories) kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Consumed \(consumedCalories) of \(targetCalories) calories")
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

private struct FoodItemRowView: View {
    let item: FoodItem

    var body: some View {
        HStack(spacing: 12) {
            itemImage
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body.weight(.medium))

                Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text("\(item.calories) kcal")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
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
}

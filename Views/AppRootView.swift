import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("AppThemePreference") private var appThemePreference = AppThemePreference.system.rawValue
    @State private var isShowingAIEntry = false
    @State private var persistenceErrorMessage: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                DashboardView()
                    .tabItem {
                        Label("Today", systemImage: "fork.knife")
                    }

                HistoryView()
                    .tabItem {
                        Label("History", systemImage: "calendar.badge.clock")
                    }

                StatisticsView()
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar.xaxis")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }

            Button {
                isShowingAIEntry = true
            } label: {
                ZStack {
                    Circle()
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 7)

                    Image(systemName: "plus")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                .frame(width: 72, height: 72)
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.36), lineWidth: 1)
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.14), lineWidth: 0.8)
                }
            }
            .accessibilityLabel("AI Scan")
            .padding(.bottom, 18)
        }
        .preferredColorScheme(selectedTheme.colorScheme)
        .sheet(isPresented: $isShowingAIEntry) {
            AICameraEntryView { name, calories, grams, protein, carbs, fat, healthScore, imageData in
                addFoodItem(
                    name: name,
                    calories: calories,
                    grams: grams,
                    proteinGrams: protein,
                    carbGrams: carbs,
                    fatGrams: fat,
                    healthScore: healthScore,
                    imageData: imageData
                )
            }
        }
        .alert("Unable to Save", isPresented: persistenceErrorBinding) {
            Button("OK", role: .cancel) {
                persistenceErrorMessage = nil
            }
        } message: {
            Text(persistenceErrorMessage ?? "")
        }
    }

    private var selectedTheme: AppThemePreference {
        AppThemePreference(rawValue: appThemePreference) ?? .system
    }

    private func addFoodItem(
        name: String,
        calories: Int,
        grams: Int?,
        proteinGrams: Int?,
        carbGrams: Int?,
        fatGrams: Int?,
        healthScore: Int?,
        imageData: Data?
    ) {
        let entry: ValidatedFoodEntry
        do {
            entry = try FoodEntryValidator.validate(
                name: name,
                calories: calories,
                grams: grams,
                proteinGrams: proteinGrams,
                carbGrams: carbGrams,
                fatGrams: fatGrams,
                healthScore: healthScore
            )
        } catch {
            persistenceErrorMessage = error.localizedDescription
            return
        }

        do {
            let goal = try fetchOrCreateTodayGoal()
            let foodItem = FoodItem(
                name: entry.name,
                calories: entry.calories,
                grams: entry.grams,
                proteinGrams: entry.proteinGrams,
                carbGrams: entry.carbGrams,
                fatGrams: entry.fatGrams,
                healthScore: entry.healthScore,
                timestamp: Date(),
                imageData: imageData,
                dailyGoal: goal
            )

            modelContext.insert(foodItem)

            if goal.foodItems == nil {
                goal.foodItems = []
            }

            if let items = goal.foodItems, !items.contains(where: { $0.id == foodItem.id }) {
                goal.foodItems?.append(foodItem)
            }

            goal.recalculateTotalConsumedCalories()
            try modelContext.save()
            NotificationCenter.default.post(name: .foodItemsDidChange, object: nil)
        } catch {
            modelContext.rollback()
            persistenceErrorMessage = error.localizedDescription
        }
    }

    private func fetchOrCreateTodayGoal() throws -> DailyGoal {
        if let existingGoal = try fetchTodayGoal() {
            return existingGoal
        }

        let newGoal = DailyGoal(date: Date(), targets: try targetsForNewGoal())
        modelContext.insert(newGoal)
        return newGoal
    }

    private func targetsForNewGoal() throws -> DailyGoalTargets {
        guard !DailyGoalTargets.hasSavedCurrent,
              let latestGoal = try fetchLatestGoalBeforeToday() else {
            return DailyGoalTargets.current
        }

        let targets = DailyGoalTargets(
            calories: latestGoal.targetCalories,
            proteinGrams: latestGoal.targetProteinGrams,
            carbGrams: latestGoal.targetCarbGrams,
            fatGrams: latestGoal.targetFatGrams
        )
        targets.saveAsCurrent()
        return targets
    }

    private func fetchLatestGoalBeforeToday() throws -> DailyGoal? {
        try DailyGoalStore.latestGoal(before: Date(), in: modelContext)
    }

    private func fetchTodayGoal() throws -> DailyGoal? {
        try DailyGoalStore.goal(for: Date(), in: modelContext)
    }

    private var persistenceErrorBinding: Binding<Bool> {
        Binding {
            persistenceErrorMessage != nil
        } set: { isPresented in
            if !isPresented {
                persistenceErrorMessage = nil
            }
        }
    }
}

extension Notification.Name {
    static let foodItemsDidChange = Notification.Name("foodItemsDidChange")
}

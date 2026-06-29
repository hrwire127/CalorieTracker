import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("AppThemePreference") private var appThemePreference = AppThemePreference.system.rawValue
    @State private var isShowingAIEntry = false

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
                        .fill(
                            LinearGradient(
                                colors: [.teal, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .blue.opacity(0.30), radius: 18, x: 0, y: 8)

                    Text("=")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .offset(y: -1)
                }
                .frame(width: 76, height: 76)
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.92), lineWidth: 5)
                }
            }
            .accessibilityLabel("AI Scan")
            .padding(.bottom, 20)
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
        guard let entry = try? FoodEntryValidator.validate(
            name: name,
            calories: calories,
            grams: grams,
            proteinGrams: proteinGrams,
            carbGrams: carbGrams,
            fatGrams: fatGrams,
            healthScore: healthScore
        ) else {
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
            // Dashboard will surface persistence errors when it reloads.
        }
    }

    private func fetchOrCreateTodayGoal() throws -> DailyGoal {
        if let existingGoal = try fetchTodayGoal() {
            return existingGoal
        }

        let newGoal = DailyGoal(date: Date())
        modelContext.insert(newGoal)
        return newGoal
    }

    private func fetchTodayGoal() throws -> DailyGoal? {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return nil
        }

        var descriptor = FetchDescriptor<DailyGoal>(
            predicate: #Predicate<DailyGoal> { goal in
                goal.date >= startOfToday && goal.date < startOfTomorrow
            },
            sortBy: [SortDescriptor(\.date)]
        )
        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }
}

extension Notification.Name {
    static let foodItemsDidChange = Notification.Name("foodItemsDidChange")
}

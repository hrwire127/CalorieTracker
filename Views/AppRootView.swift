import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("AppThemePreference") private var appThemePreference = AppThemePreference.system.rawValue
    @State private var isShowingAIEntry = false
    @State private var selectedTab: RootTab = .dashboard

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tag(RootTab.dashboard)

                HistoryView()
                    .tag(RootTab.history)

                StatisticsView()
                    .tag(RootTab.stats)

                SettingsView()
                    .tag(RootTab.settings)
            }
            .toolbar(.hidden, for: .tabBar)

            CustomTabBar(selectedTab: $selectedTab) {
                isShowingAIEntry = true
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
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

private enum RootTab: CaseIterable, Hashable {
    case dashboard
    case history
    case stats
    case settings

    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .history:
            return "History"
        case .stats:
            return "Insights"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            return "house"
        case .history:
            return "calendar.badge.clock"
        case .stats:
            return "waveform.path.ecg"
        case .settings:
            return "gearshape"
        }
    }

    var selectedSystemImage: String {
        switch self {
        case .dashboard:
            return "house.fill"
        case .history:
            return "calendar.badge.clock"
        case .stats:
            return "waveform.path.ecg"
        case .settings:
            return "gearshape.fill"
        }
    }
}

private struct CustomTabBar: View {
    @Binding var selectedTab: RootTab
    let onPlusTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0)
                .fill(.bar)
                .frame(height: 92)
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: -5)
                .frame(maxHeight: .infinity, alignment: .bottom)

            HStack(alignment: .bottom, spacing: 0) {
                tabButton(.dashboard)
                tabButton(.history)

                Color.clear
                    .frame(maxWidth: .infinity)

                tabButton(.stats)
                tabButton(.settings)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)

            Button(action: onPlusTap) {
                ZStack {
                    Circle()
                        .fill(Color.primary)
                        .shadow(color: .black.opacity(0.26), radius: 16, x: 0, y: 8)

                    Image(systemName: "plus")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color(.systemBackground))
                }
                .frame(width: 84, height: 84)
            }
            .accessibilityLabel("AI Scan")
            .offset(y: -24)
        }
        .frame(height: 112)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private func tabButton(_ tab: RootTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: selectedTab == tab ? tab.selectedSystemImage : tab.systemImage)
                    .font(.system(size: 25, weight: .semibold))

                Text(tab.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary.opacity(0.62))
            .frame(maxWidth: .infinity)
            .frame(height: 58)
        }
        .buttonStyle(.plain)
    }
}

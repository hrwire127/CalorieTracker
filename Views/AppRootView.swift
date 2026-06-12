import SwiftUI

struct AppRootView: View {
    @AppStorage("AppThemePreference") private var appThemePreference = AppThemePreference.system.rawValue

    var body: some View {
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
        .preferredColorScheme(selectedTheme.colorScheme)
    }

    private var selectedTheme: AppThemePreference {
        AppThemePreference(rawValue: appThemePreference) ?? .system
    }
}

import SwiftData
import SwiftUI

@main
struct CalorieTrackerApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                DailyGoal.self,
                FoodItem.self
            ])

            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )

            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(modelContainer)
    }
}

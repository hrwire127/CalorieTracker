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

            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            do {
                try DailyGoalStore.consolidateDuplicateDays(in: container.mainContext)
                if container.mainContext.hasChanges {
                    try container.mainContext.save()
                }
            } catch {
                container.mainContext.rollback()
            }
            modelContainer = container
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

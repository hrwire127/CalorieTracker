import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyGoal.date, order: .reverse) private var dailyGoals: [DailyGoal]
    
    var body: some View {
        NavigationStack {
            List {
                if dailyGoals.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "calendar.badge.clock"
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(dailyGoals) { goal in
                        Section {
                            let sortedItems = (goal.foodItems ?? []).sorted { $0.timestamp > $1.timestamp }
                            
                            if sortedItems.isEmpty {
                                Text("No food logged on this day.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(sortedItems) { item in
                                    HistoryFoodItemRowView(item: item)
                                }
                                .onDelete { offsets in
                                    deleteFoodItems(from: goal, sortedItems: sortedItems, at: offsets)
                                }
                            }
                        } header: {
                            HStack {
                                Text(formattedDate(goal.date))
                                Spacer()
                                Text("\(goal.totalConsumedCalories) / \(goal.targetCalories) kcal")
                                    .font(.subheadline)
                                    .textCase(nil)
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }
    
    private func deleteFoodItems(from goal: DailyGoal, sortedItems: [FoodItem], at offsets: IndexSet) {
        let itemsToDelete = offsets.map { sortedItems[$0] }
        let idsToDelete = Set(itemsToDelete.map(\.id))
        
        goal.foodItems?.removeAll { idsToDelete.contains($0.id) }
        
        for item in itemsToDelete {
            modelContext.delete(item)
        }
        
        goal.recalculateTotalConsumedCalories()
        try? modelContext.save()
    }
}

private struct HistoryFoodItemRowView: View {
    let item: FoodItem

    var body: some View {
        HStack(spacing: 12) {
            if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(.secondary)
                    }
            }

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
    }
}

#Preview {
    HistoryView()
}
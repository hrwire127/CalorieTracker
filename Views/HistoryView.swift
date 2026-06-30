import SwiftUI
import SwiftData
import UIKit

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyGoal.date, order: .reverse) private var dailyGoals: [DailyGoal]
    @State private var editingFoodItem: FoodItem?
    private let calendar = Calendar.current
    
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
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            editingFoodItem = item
                                        }
                                }
                                .onDelete { offsets in
                                    deleteFoodItems(from: goal, sortedItems: sortedItems, at: offsets)
                                }
                            }
                        } header: {
                            HistoryDayHeaderView(
                                dateTitle: formattedDate(goal.date),
                                consumedCalories: goal.totalConsumedCalories,
                                targetCalories: goal.targetCalories,
                                isPastDay: isPastDay(goal.date)
                            )
                        }
                    }
                }
            }
            .navigationTitle("History")
            .onAppear {
                refreshTotals()
            }
            .sheet(item: $editingFoodItem) { item in
                FoodEditorView(item: item) { entry in
                    updateFoodItem(item, with: entry)
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }

    private func isPastDay(_ date: Date) -> Bool {
        calendar.startOfDay(for: date) < calendar.startOfDay(for: Date())
    }

    private func refreshTotals() {
        for goal in dailyGoals {
            goal.recalculateTotalConsumedCalories()
        }

        try? modelContext.save()
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

    private func updateFoodItem(_ item: FoodItem, with entry: ValidatedFoodEntry) {
        item.name = entry.name
        item.calories = entry.calories
        item.grams = entry.grams
        item.proteinGrams = entry.proteinGrams
        item.carbGrams = entry.carbGrams
        item.fatGrams = entry.fatGrams
        item.healthScore = entry.healthScore
        item.dailyGoal?.recalculateTotalConsumedCalories()
        try? modelContext.save()
    }
}

private struct HistoryDayHeaderView: View {
    let dateTitle: String
    let consumedCalories: Int
    let targetCalories: Int
    let isPastDay: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(dateTitle)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(consumedCalories) / \(targetCalories) kcal")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: progress)
                    .tint(consumedCalories > targetCalories ? .orange : .green)

                Text(descriptionText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
        .textCase(nil)
        .padding(.vertical, 4)
    }

    private var progress: Double {
        guard targetCalories > 0 else {
            return 0
        }

        return min(Double(consumedCalories) / Double(targetCalories), 1)
    }

    private var descriptionText: String {
        if isPastDay {
            return "Consumed \(consumedCalories) of \(targetCalories) kcal that day."
        }

        return "Consumed \(consumedCalories) of \(targetCalories) kcal today."
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

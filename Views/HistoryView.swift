import SwiftUI
import SwiftData
import UIKit

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyGoal.date, order: .reverse) private var dailyGoals: [DailyGoal]
    @State private var editingFoodItem: FoodItem?
    @State private var displayedMonth = Date()
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    MonthCalendarHeatmapView(
                        displayedMonth: $displayedMonth,
                        dayMetrics: calendarDayMetrics
                    )
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)
                }

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

    private var calendarDayMetrics: [Date: CalendarDayMetrics] {
        var metrics: [Date: CalendarDayMetrics] = [:]

        for goal in dailyGoals {
            let day = calendar.startOfDay(for: goal.date)
            let existing = metrics[day]
            let consumedCalories = (existing?.consumedCalories ?? 0) + goal.totalConsumedCalories
            let foodCount = (existing?.foodCount ?? 0) + (goal.foodItems ?? []).count

            metrics[day] = CalendarDayMetrics(
                date: day,
                consumedCalories: consumedCalories,
                targetCalories: goal.targetCalories,
                foodCount: foodCount
            )
        }

        return metrics
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

private struct CalendarDayMetrics: Equatable {
    let date: Date
    let consumedCalories: Int
    let targetCalories: Int
    let foodCount: Int

    var hasLoggedFood: Bool {
        foodCount > 0 || consumedCalories > 0
    }

    var progress: Double {
        guard targetCalories > 0 else {
            return 0
        }

        return min(Double(consumedCalories) / Double(targetCalories), 1)
    }

    var isOverTarget: Bool {
        consumedCalories > targetCalories
    }
}

private struct MonthCalendarHeatmapView: View {
    @Binding var displayedMonth: Date
    let dayMetrics: [Date: CalendarDayMetrics]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(monthTitle)
                        .font(.headline)
                }

                Spacer()

                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendarDays) { day in
                    CalendarHeatmapDayView(day: day, metrics: dayMetrics[day.date])
                }
            }

            HStack(spacing: 12) {
                legendDot(color: .green, title: "Logged")
                legendDot(color: .orange, title: "Over goal")
                legendDot(color: .secondary.opacity(0.25), title: "No log")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 6)
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let firstWeekdayIndex = calendar.firstWeekday - 1
        return Array(symbols[firstWeekdayIndex...]) + Array(symbols[..<firstWeekdayIndex])
    }

    private var calendarDays: [CalendarHeatmapDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let monthRange = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }

        let firstOfMonth = monthInterval.start
        let leadingBlankCount = leadingBlankDays(for: firstOfMonth)

        var days: [CalendarHeatmapDay] = (0..<leadingBlankCount).map { index in
            CalendarHeatmapDay(id: "blank-\(index)", date: Date.distantPast, dayNumber: "", isInDisplayedMonth: false)
        }

        for day in monthRange {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) else {
                continue
            }

            days.append(
                CalendarHeatmapDay(
                    id: date.ISO8601Format(),
                    date: calendar.startOfDay(for: date),
                    dayNumber: "\(day)",
                    isInDisplayedMonth: true
                )
            )
        }

        return days
    }

    private func leadingBlankDays(for date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private func moveMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    private func legendDot(color: Color, title: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(title)
        }
    }
}

private struct CalendarHeatmapDay: Identifiable {
    let id: String
    let date: Date
    let dayNumber: String
    let isInDisplayedMonth: Bool
}

private struct CalendarHeatmapDayView: View {
    let day: CalendarHeatmapDay
    let metrics: CalendarDayMetrics?

    var body: some View {
        ZStack {
            if day.isInDisplayedMonth {
                Circle()
                    .fill(fillColor)

                Circle()
                    .strokeBorder(strokeColor, lineWidth: isToday ? 2 : 1)

                Text(day.dayNumber)
                    .font(.caption.weight(isToday ? .bold : .semibold))
                    .foregroundStyle(textColor)
                    .monospacedDigit()
            }
        }
        .frame(height: 34)
        .accessibilityLabel(accessibilityLabel)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(day.date)
    }

    private var fillColor: Color {
        guard let metrics, metrics.hasLoggedFood else {
            return Color.secondary.opacity(0.08)
        }

        if metrics.isOverTarget {
            return .orange.opacity(0.24)
        }

        return .green.opacity(0.20 + (metrics.progress * 0.28))
    }

    private var strokeColor: Color {
        if isToday {
            return .primary
        }

        guard let metrics, metrics.hasLoggedFood else {
            return .secondary.opacity(0.20)
        }

        return metrics.isOverTarget ? .orange.opacity(0.75) : .green.opacity(0.75)
    }

    private var textColor: Color {
        guard let metrics, metrics.hasLoggedFood else {
            return .secondary
        }

        return .primary
    }

    private var accessibilityLabel: String {
        guard day.isInDisplayedMonth else {
            return "Empty calendar day"
        }

        guard let metrics, metrics.hasLoggedFood else {
            return "No food logged on day \(day.dayNumber)"
        }

        return "\(metrics.consumedCalories) calories logged on day \(day.dayNumber)"
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

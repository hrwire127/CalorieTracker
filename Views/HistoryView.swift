import SwiftData
import SwiftUI
import UIKit

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var editingFoodItem: FoodItem?
    @State private var displayedMonth = Date()
    @State private var selectedDate = Date()
    @State private var calendarMode: HistoryCalendarMode = .week
    @State private var visibleGoals: [DailyGoal] = []
    @State private var errorMessage: String?

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Calendar Mode", selection: $calendarMode) {
                        ForEach(HistoryCalendarMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    HistoryCalendarView(
                        displayedMonth: $displayedMonth,
                        selectedDate: $selectedDate,
                        calendarMode: calendarMode,
                        dayMetrics: calendarDayMetrics
                    )
                    .padding(.top, 8)
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(Color.clear)

                if visibleLoggedGoals.isEmpty {
                    ContentUnavailableView(
                        "No Food Logged",
                        systemImage: "calendar.badge.clock",
                        description: Text(calendarMode.emptyDescription)
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        HistoryPeriodSummaryView(
                            title: calendarMode.foodListTitle,
                            foodCount: visibleFoodCount,
                            consumedCalories: visibleConsumedCalories,
                            targetCalories: visibleTargetCalories
                        )
                    }
                    .listRowBackground(Color.clear)

                    ForEach(visibleLoggedGoals) { goal in
                        Section {
                            let sortedItems = sortedFoodItems(for: goal)

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
                reloadVisibleGoals()
            }
            .onReceive(NotificationCenter.default.publisher(for: .foodItemsDidChange)) { _ in
                reloadVisibleGoals()
            }
            .onChange(of: selectedDate) { _, newDate in
                displayedMonth = newDate
                reloadVisibleGoals()
            }
            .onChange(of: calendarMode) { _, _ in
                displayedMonth = selectedDate
                reloadVisibleGoals()
            }
            .sheet(item: $editingFoodItem) { item in
                FoodEditorView(item: item) { entry in
                    updateFoodItem(item, with: entry)
                }
            }
            .alert("History", isPresented: errorBinding) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .refreshable {
                reloadVisibleGoals()
            }
        }
    }

    private var periodInterval: DateInterval? {
        calendarMode.dateInterval(containing: selectedDate, calendar: calendar)
    }

    private var visibleFoodCount: Int {
        visibleLoggedGoals.reduce(0) { total, goal in
            total + (goal.foodItems ?? []).count
        }
    }

    private var visibleConsumedCalories: Int {
        visibleLoggedGoals.reduce(0) { total, goal in
            total + goal.totalConsumedCalories
        }
    }

    private var visibleTargetCalories: Int {
        visibleLoggedGoals.reduce(0) { total, goal in
            total + goal.targetCalories
        }
    }

    private var visibleLoggedGoals: [DailyGoal] {
        visibleGoals.filter { goal in
            !(goal.foodItems ?? []).isEmpty || goal.totalConsumedCalories > 0
        }
    }

    private var calendarDayMetrics: [Date: CalendarDayMetrics] {
        var metrics: [Date: CalendarDayMetrics] = [:]

        for goal in visibleGoals {
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

    private var errorBinding: Binding<Bool> {
        Binding {
            errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                errorMessage = nil
            }
        }
    }

    private func reloadVisibleGoals() {
        guard let interval = periodInterval else {
            visibleGoals = []
            return
        }

        do {
            let startDate = interval.start
            let endDate = interval.end
            let descriptor = FetchDescriptor<DailyGoal>(
                predicate: #Predicate<DailyGoal> { goal in
                    goal.date >= startDate && goal.date < endDate
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )

            let goals = try modelContext.fetch(descriptor)
            for goal in goals {
                goal.recalculateTotalConsumedCalories()
            }

            visibleGoals = goals
            try modelContext.save()
        } catch {
            errorMessage = "Unable to load history. \(error.localizedDescription)"
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

    private func sortedFoodItems(for goal: DailyGoal) -> [FoodItem] {
        (goal.foodItems ?? []).sorted { $0.timestamp > $1.timestamp }
    }

    private func deleteFoodItems(from goal: DailyGoal, sortedItems: [FoodItem], at offsets: IndexSet) {
        let itemsToDelete = offsets.map { sortedItems[$0] }
        let idsToDelete = Set(itemsToDelete.map(\.id))

        goal.foodItems?.removeAll { idsToDelete.contains($0.id) }

        for item in itemsToDelete {
            modelContext.delete(item)
        }

        goal.recalculateTotalConsumedCalories()

        do {
            try modelContext.save()
            reloadVisibleGoals()
            NotificationCenter.default.post(name: .foodItemsDidChange, object: nil)
        } catch {
            errorMessage = "Unable to delete food. \(error.localizedDescription)"
        }
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

        do {
            try modelContext.save()
            reloadVisibleGoals()
            NotificationCenter.default.post(name: .foodItemsDidChange, object: nil)
        } catch {
            errorMessage = "Unable to update food. \(error.localizedDescription)"
        }
    }
}

private enum HistoryCalendarMode: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week:
            return "Week"
        case .month:
            return "Month"
        }
    }

    var foodListTitle: String {
        switch self {
        case .week:
            return "Food logged this week"
        case .month:
            return "Food logged this month"
        }
    }

    var emptyDescription: String {
        switch self {
        case .week:
            return "No meals were logged in the selected week."
        case .month:
            return "No meals were logged in the selected month."
        }
    }

    func dateInterval(containing date: Date, calendar: Calendar) -> DateInterval? {
        switch self {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)
        case .month:
            return calendar.dateInterval(of: .month, for: date)
        }
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

private struct HistoryCalendarView: View {
    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date
    let calendarMode: HistoryCalendarMode
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

                    Text(calendarTitle)
                        .font(.headline)
                }

                Spacer()

                Button {
                    movePeriod(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Button {
                    movePeriod(by: 1)
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
                    CalendarHeatmapDayView(
                        day: day,
                        metrics: dayMetrics[day.date],
                        isSelected: isSelected(day.date),
                        isHighlighted: isHighlighted(day.date)
                    ) {
                        guard day.isInDisplayedPeriod else {
                            return
                        }

                        selectedDate = day.date
                        displayedMonth = day.date
                    }
                }
            }

            HStack(spacing: 12) {
                legendDot(color: .blue, title: calendarMode.title)
                legendDot(color: .green, title: "Goal met")
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

    private var calendarTitle: String {
        switch calendarMode {
        case .week:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDate),
                  let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) else {
                return selectedDate.formatted(.dateTime.month(.wide).day().year())
            }

            return "\(interval.start.formatted(.dateTime.month(.abbreviated).day())) - \(lastDay.formatted(.dateTime.month(.abbreviated).day().year()))"
        case .month:
            return displayedMonth.formatted(.dateTime.month(.wide).year())
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let firstWeekdayIndex = calendar.firstWeekday - 1
        return Array(symbols[firstWeekdayIndex...]) + Array(symbols[..<firstWeekdayIndex])
    }

    private var calendarDays: [CalendarHeatmapDay] {
        switch calendarMode {
        case .week:
            return weekCalendarDays()
        case .month:
            return monthCalendarDays()
        }
    }

    private func weekCalendarDays() -> [CalendarHeatmapDay] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return []
        }

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekInterval.start) else {
                return nil
            }

            let day = calendar.startOfDay(for: date)
            return CalendarHeatmapDay(
                id: day.ISO8601Format(),
                date: day,
                dayNumber: "\(calendar.component(.day, from: day))",
                isInDisplayedPeriod: true
            )
        }
    }

    private func monthCalendarDays() -> [CalendarHeatmapDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let monthRange = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }

        let firstOfMonth = monthInterval.start
        let leadingBlankCount = leadingBlankDays(for: firstOfMonth)

        var days: [CalendarHeatmapDay] = (0..<leadingBlankCount).map { index in
            CalendarHeatmapDay(id: "blank-\(index)", date: Date.distantPast, dayNumber: "", isInDisplayedPeriod: false)
        }

        for day in monthRange {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) else {
                continue
            }

            let calendarDay = calendar.startOfDay(for: date)
            days.append(
                CalendarHeatmapDay(
                    id: calendarDay.ISO8601Format(),
                    date: calendarDay,
                    dayNumber: "\(day)",
                    isInDisplayedPeriod: true
                )
            )
        }

        return days
    }

    private func leadingBlankDays(for date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private func movePeriod(by value: Int) {
        let component: Calendar.Component = calendarMode == .week ? .weekOfYear : .month
        guard let newDate = calendar.date(byAdding: component, value: value, to: selectedDate) else {
            return
        }

        selectedDate = newDate
        displayedMonth = newDate
    }

    private func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private func isHighlighted(_ date: Date) -> Bool {
        guard let interval = calendarMode.dateInterval(containing: selectedDate, calendar: calendar) else {
            return false
        }

        return date >= interval.start && date < interval.end
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
    let isInDisplayedPeriod: Bool
}

private struct CalendarHeatmapDayView: View {
    let day: CalendarHeatmapDay
    let metrics: CalendarDayMetrics?
    let isSelected: Bool
    let isHighlighted: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                if day.isInDisplayedPeriod {
                    Circle()
                        .fill(fillColor)

                    Circle()
                        .strokeBorder(strokeColor, lineWidth: strokeWidth)

                    Text(day.dayNumber)
                        .font(.caption.weight(isToday || isSelected ? .bold : .semibold))
                        .foregroundStyle(textColor)
                        .monospacedDigit()
                }
            }
            .frame(height: 34)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!day.isInDisplayedPeriod)
        .accessibilityLabel(accessibilityLabel)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(day.date)
    }

    private var fillColor: Color {
        if isSelected {
            return Color.blue.opacity(0.28)
        }

        guard let metrics, metrics.hasLoggedFood else {
            return isHighlighted ? Color.blue.opacity(0.09) : Color.secondary.opacity(0.08)
        }

        if metrics.isOverTarget {
            return .orange.opacity(isHighlighted ? 0.30 : 0.24)
        }

        return .green.opacity(0.20 + (metrics.progress * 0.28))
    }

    private var strokeColor: Color {
        if isSelected {
            return .blue
        }

        if isToday {
            return .primary
        }

        guard let metrics, metrics.hasLoggedFood else {
            return isHighlighted ? Color.blue.opacity(0.45) : Color.secondary.opacity(0.20)
        }

        return metrics.isOverTarget ? .orange.opacity(0.75) : .green.opacity(0.75)
    }

    private var strokeWidth: CGFloat {
        isSelected || isToday ? 2 : 1
    }

    private var textColor: Color {
        if isSelected {
            return .blue
        }

        guard let metrics, metrics.hasLoggedFood else {
            return .secondary
        }

        return .primary
    }

    private var accessibilityLabel: String {
        guard day.isInDisplayedPeriod else {
            return "Empty calendar day"
        }

        guard let metrics, metrics.hasLoggedFood else {
            return "No food logged on day \(day.dayNumber)"
        }

        return "\(metrics.consumedCalories) calories logged on day \(day.dayNumber)"
    }
}

private struct HistoryPeriodSummaryView: View {
    let title: String
    let foodCount: Int
    let consumedCalories: Int
    let targetCalories: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            HStack(spacing: 12) {
                HistoryPeriodMetricView(
                    title: "Foods",
                    value: "\(foodCount)",
                    suffix: "items",
                    systemImage: "fork.knife",
                    tint: .green
                )

                HistoryPeriodMetricView(
                    title: "Calories",
                    value: "\(consumedCalories)",
                    suffix: "of \(targetCalories)",
                    systemImage: "flame.fill",
                    tint: consumedCalories > targetCalories ? .orange : .blue
                )
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 6)
    }
}

private struct HistoryPeriodMetricView: View {
    let title: String
    let value: String
    let suffix: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldIcon(systemName: systemImage, tint: tint)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(tint)
                    .monospacedDigit()

                Text(suffix)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

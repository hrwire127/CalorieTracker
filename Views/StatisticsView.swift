import Charts
import SwiftData
import SwiftUI

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = StatisticsViewModel()

    @AppStorage("ProfileWeightKg") private var profileWeightKg: String = ""
    @AppStorage("ProfileHeightCm") private var profileHeightCm: String = ""
    @AppStorage("ProfileBirthDateTimestamp") private var profileBirthDateTimestamp: Double = 631_152_000
    @AppStorage("ProfileSex") private var profileSex = ProfileSex.unspecified.rawValue
    @AppStorage("ProfileActivityLevel") private var profileActivityLevel = ActivityLevel.sedentary.rawValue

    @State private var selectedRange: StatisticsRange = .week

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Range", selection: $selectedRange) {
                        ForEach(StatisticsRange.allCases) { range in
                            Text(range.title)
                                .tag(range)
                        }
                    }
                    .pickerStyle(.segmented)

                    summaryMetrics
                    calorieChart
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Stats")
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 92)
            }
            .alert("Statistics", isPresented: errorBinding) {
                Button("OK", role: .cancel) {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear {
                loadStats()
            }
            .onChange(of: selectedRange) {
                loadStats()
            }
            .refreshable {
                loadStats()
            }
        }
    }

    private var summaryMetrics: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatisticsMetricView(
                title: "Average",
                value: "\(viewModel.averageCalories)",
                suffix: "kcal/day",
                systemImage: "chart.line.uptrend.xyaxis",
                tint: .blue
            )

            StatisticsMetricView(
                title: "Total",
                value: "\(viewModel.totalCalories)",
                suffix: "kcal",
                systemImage: "sum",
                tint: .green
            )

            StatisticsMetricView(
                title: "Deficit",
                value: "\(viewModel.totalDeficit)",
                suffix: "kcal",
                systemImage: "arrow.down.circle.fill",
                tint: .teal
            )

            StatisticsMetricView(
                title: "Goal Days",
                value: "\(viewModel.daysMeetingGoal)",
                suffix: "days",
                systemImage: "target",
                tint: .orange
            )
        }
    }

    private var calorieChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedRange.chartTitle)
                        .font(.headline)

                    if let maintenanceCalories {
                        Text("Maintenance \(maintenanceCalories) kcal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    } else {
                        Text("Complete profile for maintenance line")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chart.bar.xaxis")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }

            Chart {
                ForEach(viewModel.summaries) { summary in
                    BarMark(
                        x: .value("Day", summary.date, unit: .day),
                        y: .value("Calories", summary.consumedCalories)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: summary.consumedCalories >= summary.targetCalories ? [.orange, .red] : [.blue, .teal],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(5)
                }

                RuleMark(y: .value("Goal", viewModel.dailyGoalTarget))
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Goal")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.red)
                    }

                if let maintenanceCalories = viewModel.maintenanceCalories {
                    RuleMark(y: .value("Maintenance", maintenanceCalories))
                        .foregroundStyle(.purple)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [2, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Maintenance")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.purple)
                        }
                }
            }
            .chartYScale(domain: 0...viewModel.chartMaximumCalories)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: selectedRange == .week ? 7 : 6)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .frame(height: 340)
            .accessibilityLabel("Calorie intake chart")
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 8)
    }

    private var maintenanceCalories: Int? {
        NutritionCalculator.maintenanceCalories(
            weightKgText: profileWeightKg,
            heightCmText: profileHeightCm,
            birthDateTimestamp: profileBirthDateTimestamp,
            sexRawValue: profileSex,
            activityRawValue: profileActivityLevel
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding {
            viewModel.errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                viewModel.clearError()
            }
        }
    }

    private func loadStats() {
        viewModel.load(
            range: selectedRange,
            maintenanceCalories: maintenanceCalories,
            using: modelContext
        )
    }
}

private struct StatisticsMetricView: View {
    let title: String
    let value: String
    let suffix: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                FieldIcon(systemName: systemImage, tint: tint)

                Spacer()
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(tint)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(suffix)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

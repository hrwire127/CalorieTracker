import Charts
import SwiftData
import SwiftUI

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = StatisticsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summaryMetrics
                    calorieChart
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Stats")
            .alert("Statistics", isPresented: errorBinding) {
                Button("OK", role: .cancel) {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear {
                viewModel.load(using: modelContext)
            }
            .refreshable {
                viewModel.load(using: modelContext)
            }
        }
    }

    private var summaryMetrics: some View {
        HStack(spacing: 12) {
            StatisticsMetricView(
                title: "Average",
                value: "\(viewModel.averageCalories)",
                suffix: "kcal",
                tint: .blue
            )

            StatisticsMetricView(
                title: "Total",
                value: "\(viewModel.totalCalories)",
                suffix: "kcal",
                tint: .green
            )

            StatisticsMetricView(
                title: "Goal Days",
                value: "\(viewModel.daysMeetingGoal)",
                suffix: "days",
                tint: .orange
            )
        }
    }

    private var calorieChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last 7 Days")
                        .font(.headline)

                    Text("Goal \(viewModel.dailyGoalTarget) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
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
                    .foregroundStyle(summary.consumedCalories >= summary.targetCalories ? .orange : .blue)
                    .cornerRadius(6)
                    .annotation(position: .top, alignment: .center) {
                        if summary.consumedCalories > 0 {
                            Text("\(summary.consumedCalories)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                RuleMark(y: .value("Daily Goal", viewModel.dailyGoalTarget))
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Goal")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.red)
                    }
            }
            .chartYScale(domain: 0...viewModel.chartMaximumCalories)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .frame(height: 320)
            .accessibilityLabel("Calorie intake over the last seven days")
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 8)
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
}

private struct StatisticsMetricView: View {
    let title: String
    let value: String
    let suffix: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
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
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

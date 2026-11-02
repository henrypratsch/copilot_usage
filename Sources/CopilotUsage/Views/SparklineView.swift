import Charts
import CopilotUsageCore
import SwiftUI

/// Cumulative usage of the period with the projection until the reset.
/// Segments between days that were not both recorded are dashed.
struct SparklineView: View {
    let history: [HistoryPoint]
    let metrics: UsageMetrics
    let color: Color

    private let height: CGFloat = 60

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Chart {
                ForEach(Array(zip(history, history.dropFirst()).enumerated()), id: \.offset) { index, pair in
                    let style = isConsecutive(pair.0, pair.1)
                        ? StrokeStyle(lineWidth: 2)
                        : StrokeStyle(lineWidth: 2, dash: [4, 3])
                    ForEach([pair.0, pair.1], id: \.date) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Used", capped(point.cumulativeUsed)), series: .value("Segment", index))
                            .lineStyle(style)
                            .foregroundStyle(color.opacity(style.dash.isEmpty ? 1 : 0.6))
                    }
                }

                ForEach(projection, id: \.date) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Used", point.used), series: .value("Segment", "projection"))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        .foregroundStyle(color.opacity(0.5))
                }

                RuleMark(y: .value("Limit", metrics.entitlement))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("\(Formatting.count(metrics.entitlement)) limit")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                if let exhaustionDate = metrics.exhaustionDate {
                    RuleMark(x: .value("Runs out", exhaustionDate))
                        .foregroundStyle(color.opacity(0.5))
                }

                if let last = history.last {
                    PointMark(x: .value("Date", last.date), y: .value("Used", capped(last.cumulativeUsed)))
                        .symbolSize(49)
                        .foregroundStyle(color)
                }
            }
            .chartXScale(domain: metrics.periodStart...max(metrics.resetDate, metrics.periodStart.addingTimeInterval(86400)))
            .chartYScale(domain: 0...max(Double(metrics.entitlement) * 1.05, 1))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .chartPlotStyle { $0.padding(.top, 12) }
            .frame(width: contentWidth, height: height)

            HStack {
                Text(Formatting.day(metrics.periodStart))
                Spacer()
                Text("today")
                Spacer()
                Text(Formatting.day(Calendar.current.date(byAdding: .day, value: -1, to: metrics.resetDate) ?? metrics.resetDate))
            }
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .frame(width: contentWidth)
        }
    }

    private var projection: [(date: Date, used: Double)] {
        let start = Double(capped(history.last?.cumulativeUsed ?? metrics.used))
        let limit = Double(metrics.entitlement)
        if let exhaustionDate = metrics.exhaustionDate, exhaustionDate > metrics.today {
            return [(metrics.today, start), (exhaustionDate, limit)]
        }
        return [(metrics.today, start), (metrics.resetDate, min(metrics.projectedTotal, limit))]
    }

    private func capped(_ used: Int) -> Int {
        min(used, metrics.entitlement)
    }

    private func isConsecutive(_ previous: HistoryPoint, _ current: HistoryPoint) -> Bool {
        Calendar.current.dateComponents([.day], from: previous.date, to: current.date).day == 1
    }
}

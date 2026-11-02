import CopilotUsageCore
import SwiftUI

/// Status dot with a headline, and the remaining requests below.
struct StatusHeaderView: View {
    let metrics: UsageMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(StatusColor.period(metrics.status))
                    .frame(width: 9, height: 9)
                Text(headline)
                    .font(.popoverHeadline)
            }
            Text("\(Formatting.count(max(metrics.remaining, 0))) requests left · resets \(Formatting.day(metrics.resetDate))")
                .font(.popoverLabel)
                .foregroundStyle(.secondary)
                .padding(.leading, 15)
        }
    }

    private var headline: String {
        switch metrics.status {
        case .onTrack: "On track"
        case .warm: "Running warm"
        case .behind: metrics.exhaustionDate.map { "Runs out around \(Formatting.day($0))" } ?? "Behind pace"
        case .overLimit: "Over limit"
        }
    }
}

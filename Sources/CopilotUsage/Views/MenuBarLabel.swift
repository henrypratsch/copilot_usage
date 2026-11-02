import CopilotUsageCore
import SwiftUI

struct MenuBarLabel: View {
    let model: UsageModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(color)
                .accessibilityLabel(accessibilityLabel)
            Text(title).monospacedDigit()
        }
    }

    private var title: String {
        if let metrics = model.metrics { return Formatting.menuBarTitle(for: metrics, mode: model.settings.menuBarMode) }
        if model.snapshot?.unlimited == true { return "∞" }
        if !model.hasToken { return "Copilot: set token" }
        return "Copilot"
    }

    private var icon: String {
        model.metrics == nil && model.error != nil ? "exclamationmark.triangle.fill" : "circle.fill"
    }

    private var color: Color {
        guard let metrics = model.metrics else { return .secondary }
        return StatusColor.period(metrics.status)
    }

    private var accessibilityLabel: String {
        switch model.metrics?.status {
        case .onTrack: "On track"
        case .warm: "Running warm"
        case .behind: "Behind pace"
        case .overLimit: "Over limit"
        case nil: model.error?.message ?? "No data"
        }
    }
}

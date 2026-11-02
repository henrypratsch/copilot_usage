import CopilotUsageCore
import SwiftUI

enum StatusColor {
    static let green = Color.green.opacity(0.85)
    static let orange = Color.orange
    static let red = Color.red

    static func period(_ status: UsageStatus) -> Color {
        switch status {
        case .onTrack: green
        case .warm: orange
        case .behind, .overLimit: red
        }
    }

    static func today(_ metrics: UsageMetrics) -> Color {
        let fraction = metrics.dailyBudget > 0 ? Double(metrics.usedToday) / Double(metrics.dailyBudget) : 0
        if fraction > 1 { return red }
        if fraction > 0.8 { return orange }
        return green
    }
}

extension Font {
    static let popoverHeadline = Font.system(size: 15, weight: .medium)
    static let popoverLabel = Font.system(size: 11.5)
    static let popoverCaption = Font.system(size: 10.5)
}

/// Popover width 340 pt minus 16 pt insets on both sides.
let contentWidth: CGFloat = 308

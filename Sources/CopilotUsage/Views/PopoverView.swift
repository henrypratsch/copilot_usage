import AppKit
import CopilotUsageCore
import SwiftUI

struct PopoverView: View {
    let model: UsageModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let metrics = model.metrics {
                content(metrics)
            } else {
                Text(message)
                    .font(.popoverHeadline)
                    .foregroundStyle(model.hasToken ? .secondary : .primary)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            }
            footer
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
        }
        .frame(width: contentWidth + 32)
        .background(.thickMaterial)
    }

    private var message: String {
        if !model.hasToken { return "Set a GitHub token in Settings" }
        if model.snapshot?.unlimited == true { return "Unlimited premium requests" }
        return model.error?.message ?? "Loading usage…"
    }

    @ViewBuilder
    private func content(_ metrics: UsageMetrics) -> some View {
        Group {
            section {
                HStack(alignment: .top) {
                    StatusHeaderView(metrics: metrics)
                    Spacer()
                    if let error = model.error {
                        Circle()
                            .fill(StatusColor.orange)
                            .frame(width: 8, height: 8)
                            .help("\(error.message) – showing last known values")
                    }
                }
            }

            if let snapshot = model.snapshot, snapshot.resetDateIsFallback {
                Divider()
                Text("Reset date unavailable – assuming \(Formatting.day(snapshot.resetDate))")
                    .font(.popoverCaption)
                    .foregroundStyle(StatusColor.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }

            Divider()
            section { MonthSection(metrics: metrics) }
            Divider()
            section { TodaySection(metrics: metrics, workdays: model.settings.workdayCalendar) }

            if metrics.elapsedWorkdays > 0 {
                Divider()
                section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(projection(metrics))
                            .font(.popoverLabel)
                            .foregroundStyle(.secondary)
                        SparklineView(history: model.history, metrics: metrics, color: StatusColor.period(metrics.status))
                    }
                }
            }
            Divider()
        }
        .opacity(model.isStale ? 0.55 : 1)
    }

    private func section(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    private func projection(_ metrics: UsageMetrics) -> String {
        let total = Formatting.count(metrics.entitlement)
        switch metrics.status {
        case .onTrack, .warm:
            return "At this pace: \(Formatting.count(Int(metrics.projectedTotal.rounded()))) of \(total) by \(Formatting.day(metrics.resetDate))"
        case .behind:
            return "Runs out \(Formatting.day(metrics.exhaustionDate ?? metrics.resetDate)) – \(metrics.workdaysWithoutCredits) workdays without requests"
        case .overLimit:
            return "Over limit – \(Formatting.count(metrics.used)) of \(total) used"
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            FooterRow(title: "Refresh now", trailing: model.lastUpdated.map { Formatting.time($0) }) {
                Task { await model.refresh() }
            }
            .disabled(!model.hasToken)
            SettingsRow()
            FooterRow(title: "Quit", trailing: "v\(appVersion)") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

private struct MonthSection: View {
    let metrics: UsageMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("This month")
                    .font(.popoverLabel.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Formatting.count(metrics.used)) of \(Formatting.count(metrics.entitlement))")
                    .font(.popoverLabel)
                    .monospacedDigit()
            }
            MonthBarView(usedFraction: metrics.usedFraction, paceFraction: metrics.paceFraction, color: StatusColor.period(metrics.status))
            HStack {
                Text("\(Formatting.percent(metrics.usedFraction))% used")
                Spacer()
                Text("\(Formatting.percent(metrics.paceFraction))% expected by now")
            }
            .font(.popoverCaption)
            .foregroundStyle(.tertiary)
        }
    }
}

private struct TodaySection: View {
    let metrics: UsageMetrics
    let workdays: WorkdayCalendar

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.popoverLabel.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Formatting.count(metrics.usedToday)) of \(Formatting.count(metrics.dailyBudget))")
                    .font(.popoverLabel)
                    .monospacedDigit()
            }
            TodaySegmentsView(
                fraction: metrics.dailyBudget > 0 ? Double(metrics.usedToday) / Double(metrics.dailyBudget) : 0,
                color: StatusColor.today(metrics),
                disabled: !metrics.todayIsWorkday
            )
            Text(caption)
                .font(.popoverCaption)
                .foregroundStyle(.tertiary)
        }
    }

    private var trackingStart: String {
        Formatting.time(metrics.trackingStartedAt ?? metrics.today)
    }

    private var title: String {
        if metrics.isFirstDayOfTracking { return "Since \(trackingStart)" }
        return metrics.todayIsWorkday ? "Today" : "Today (day off)"
    }

    private var caption: String {
        if metrics.isFirstDayOfTracking {
            return "Usage before \(trackingStart) today is not known"
        }
        if metrics.todayIsWorkday {
            return "\(Formatting.count(metrics.todayRemaining)) left today · \(Formatting.count(max(metrics.remaining, 0))) requests ÷ \(metrics.remainingWorkdays) workdays"
        }
        let nextWorkday = workdays.nextWorkday(onOrAfter: metrics.today)
        return "Day off · next budget \(Formatting.count(metrics.dailyBudget)) on \(Formatting.weekday(nextWorkday))"
    }
}

private struct FooterRow: View {
    let title: String
    var trailing: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            FooterRowLabel(title: title, trailing: trailing)
        }
        .buttonStyle(.plain)
    }
}

/// `SettingsLink` is the only way to open the Settings scene from a menu bar window.
/// The app has no Dock icon, so it is activated to bring the window to the front.
private struct SettingsRow: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SettingsLink {
            FooterRowLabel(title: "Settings…", trailing: nil)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded {
            NSApp.activate()
            dismiss()
        })
    }
}

private struct FooterRowLabel: View {
    let title: String
    let trailing: String?

    @State private var isHovering = false

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5))
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.popoverCaption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(isHovering ? Color.gray.opacity(0.15) : .clear))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}

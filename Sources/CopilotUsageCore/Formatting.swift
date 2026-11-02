import Foundation

public enum Formatting {
    public static func count(_ value: Int, locale: Locale = .current) -> String {
        value.formatted(.number.locale(locale))
    }

    /// `part` as a whole percentage of `total`, without the percent sign.
    public static func percent(_ part: Int, of total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(part) / Double(total) * 100).rounded())
    }

    public static func percent(_ fraction: Double) -> Int {
        Int((fraction * 100).rounded())
    }

    public static func menuBarTitle(for metrics: UsageMetrics, mode: MenuBarMode, locale: Locale = .current) -> String {
        let total = count(metrics.entitlement, locale: locale)
        switch mode {
        case .usedPercentage: return "\(percent(metrics.used, of: metrics.entitlement))% / \(total)"
        case .remainingPercentage: return "\(percent(max(metrics.remaining, 0), of: metrics.entitlement))% / \(total)"
        case .usedRequests: return "\(count(metrics.used, locale: locale)) / \(total)"
        case .remainingRequests: return "\(count(max(metrics.remaining, 0), locale: locale)) / \(total)"
        }
    }

    public static func day(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(locale: locale).month(.abbreviated).day())
    }

    public static func weekday(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(locale: locale).weekday(.abbreviated))
    }

    public static func time(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale))
    }
}

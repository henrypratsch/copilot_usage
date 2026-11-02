import Foundation

public struct HistoryDay: Codable, Sendable, Equatable {
    /// Local calendar day as `yyyy-MM-dd`.
    public let date: String
    public let cumulativeUsed: Int
    public let baselineAtStart: Int
}

public struct HistoryPoint: Sendable, Equatable {
    public let date: Date
    public let cumulativeUsed: Int

    public init(date: Date, cumulativeUsed: Int) {
        self.date = date
        self.cumulativeUsed = cumulativeUsed
    }
}

/// The cumulative usage at the end of each day of the current period.
public struct History: Codable, Sendable, Equatable {
    public private(set) var periodStart: String
    public private(set) var days: [HistoryDay]
    public private(set) var trackingStartedAt: Date?

    public struct Baseline: Sendable, Equatable {
        /// Usage at the start of today, so that today's usage is `used - used(baseline)`.
        public let used: Int
        public let isFirstDayOfTracking: Bool
        public let trackingStartedAt: Date?
    }

    public init() {
        periodStart = ""
        days = []
        trackingStartedAt = nil
    }

    /// Records the usage for the day of `date` and returns the baseline for today.
    ///
    /// A new period starts a fresh history. Without an earlier day the baseline is the current usage,
    /// so the usage before tracking started is not attributed to today.
    public mutating func record(used: Int, at date: Date, periodStart: Date, calendar: Calendar = .current) -> Baseline {
        let today = Self.key(for: date, calendar: calendar)
        let period = Self.key(for: periodStart, calendar: calendar)

        if self.periodStart != period {
            self = History()
            self.periodStart = period
        }

        let baseline: Int
        if let existing = days.first(where: { $0.date == today }) {
            baseline = existing.baselineAtStart
            days.removeAll { $0.date == today }
        } else {
            baseline = days.last(where: { $0.date < today })?.cumulativeUsed ?? used
        }

        days.append(HistoryDay(date: today, cumulativeUsed: used, baselineAtStart: baseline))
        days.sort { $0.date < $1.date }
        if trackingStartedAt == nil { trackingStartedAt = date }

        return Baseline(used: baseline, isFirstDayOfTracking: days.first?.date == today, trackingStartedAt: trackingStartedAt)
    }

    /// Recorded days as points, preceded by zero usage at the period start if that day was not recorded.
    public func points(periodStart: Date, calendar: Calendar = .current) -> [HistoryPoint] {
        let observed = days.compactMap { day in
            Self.date(for: day.date, calendar: calendar).map { HistoryPoint(date: $0, cumulativeUsed: max(day.cumulativeUsed, 0)) }
        }
        if observed.contains(where: { calendar.isDate($0.date, inSameDayAs: periodStart) }) {
            return observed
        }
        return [HistoryPoint(date: calendar.startOfDay(for: periodStart), cumulativeUsed: 0)] + observed
    }

    static func key(for date: Date, calendar: Calendar) -> String {
        formatter(calendar: calendar).string(from: date)
    }

    static func date(for key: String, calendar: Calendar) -> Date? {
        formatter(calendar: calendar).date(from: key)
    }

    private static func formatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

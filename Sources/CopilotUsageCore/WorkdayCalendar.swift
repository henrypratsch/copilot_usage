import Foundation

/// Counts workdays for the pace and budget calculations in the user's local calendar.
public struct WorkdayCalendar: Codable, Sendable, Equatable {
    /// Calendar weekday numbers (Sunday = 1 … Saturday = 7).
    public var weekdays: Set<Int>
    /// Days off such as vacation, as year/month/day components.
    public var daysOff: Set<DateComponents>

    public static let `default` = WorkdayCalendar(weekdays: [2, 3, 4, 5, 6], daysOff: [])

    public init(weekdays: Set<Int>, daysOff: Set<DateComponents>) {
        self.weekdays = weekdays
        self.daysOff = daysOff
    }

    private var calendar: Calendar { .current }

    public func isWorkday(_ date: Date) -> Bool {
        let day = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
        guard let weekday = day.weekday, weekdays.contains(weekday) else { return false }
        return !daysOff.contains { $0.year == day.year && $0.month == day.month && $0.day == day.day }
    }

    /// Workdays in the half-open range `[from, to)` of local days, or 0 if `to <= from`.
    public func count(from: Date, to: Date) -> Int {
        var count = 0
        var day = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        while day < end {
            if isWorkday(day) { count += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return count
    }

    /// Workdays in the closed range `[from, to]` of local days.
    public func countInclusive(from: Date, to: Date) -> Int {
        guard let dayAfter = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: to)) else { return 0 }
        return count(from: from, to: dayAfter)
    }

    /// The first workday on or after `date`, or `date` itself if there is none within a year.
    public func nextWorkday(onOrAfter date: Date) -> Date {
        var day = calendar.startOfDay(for: date)
        for _ in 0..<366 {
            if isWorkday(day) { return day }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return calendar.startOfDay(for: date)
    }
}

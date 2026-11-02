import Foundation

/// Status is based on the projected usage at the end of the period, not on what is left.
public enum UsageStatus: Sendable, Equatable {
    case onTrack
    case warm
    case behind
    case overLimit
}

/// Every number shown in the UI, derived from a snapshot, the workday calendar and today's baseline.
public struct UsageMetrics: Sendable, Equatable {
    public let entitlement: Int
    public let used: Int
    public let remaining: Int

    public let periodStart: Date
    public let resetDate: Date
    public let today: Date
    public let todayIsWorkday: Bool

    public let totalWorkdays: Int
    public let elapsedWorkdays: Int
    /// Workdays from today until the day before the reset, including today.
    public let remainingWorkdays: Int

    public let dailyBudget: Int
    public let usedToday: Int
    public let todayRemaining: Int

    /// Fraction of the entitlement used, clamped to 0…1.
    public let usedFraction: Double
    /// Fraction of the period's workdays elapsed, clamped to 0…1.
    public let paceFraction: Double
    /// Requests per elapsed workday.
    public let runRate: Double
    public let projectedTotal: Double
    /// Not clamped: values above 1 mean the quota runs out before the reset.
    public let projectedFraction: Double

    public let exhaustionDate: Date?
    public let workdaysWithoutCredits: Int
    public let status: UsageStatus

    /// True when there is no earlier day to compare against, so today's usage is only counted since tracking started.
    public let isFirstDayOfTracking: Bool
    public let trackingStartedAt: Date?

    public init(
        snapshot: UsageSnapshot,
        calendar workdays: WorkdayCalendar,
        today now: Date,
        baselineUsedAtStartOfToday baseline: Int,
        isFirstDayOfTracking: Bool = false,
        trackingStartedAt: Date? = nil
    ) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let resetDate = calendar.startOfDay(for: snapshot.resetDate)
        let periodStart = Self.periodStart(forReset: snapshot.resetDate, calendar: calendar)

        let used = snapshot.used
        let entitlement = snapshot.entitlement
        let remaining = entitlement - used

        self.entitlement = entitlement
        self.used = used
        self.remaining = remaining
        self.periodStart = periodStart
        self.resetDate = resetDate
        self.today = today
        self.todayIsWorkday = workdays.isWorkday(today)
        self.isFirstDayOfTracking = isFirstDayOfTracking
        self.trackingStartedAt = trackingStartedAt

        let totalWorkdays = workdays.count(from: periodStart, to: resetDate)
        let elapsedWorkdays = min(workdays.countInclusive(from: periodStart, to: today), totalWorkdays)
        let remainingWorkdays = workdays.count(from: today, to: resetDate)
        self.totalWorkdays = totalWorkdays
        self.elapsedWorkdays = elapsedWorkdays
        self.remainingWorkdays = remainingWorkdays

        let dailyBudget = max(remaining, 0) / max(remainingWorkdays, 1)
        let usedToday = min(max(used - baseline, 0), used)
        self.dailyBudget = dailyBudget
        self.usedToday = usedToday
        self.todayRemaining = max(dailyBudget - usedToday, 0)

        self.usedFraction = Self.clamp(entitlement > 0 ? Double(used) / Double(entitlement) : 0)
        self.paceFraction = Self.clamp(totalWorkdays > 0 ? Double(elapsedWorkdays) / Double(totalWorkdays) : 0)

        let runRate = elapsedWorkdays > 0 ? Double(used) / Double(elapsedWorkdays) : 0
        let projectedTotal = Double(used) + runRate * Double(max(remainingWorkdays - 1, 0))
        self.runRate = runRate
        self.projectedTotal = projectedTotal
        self.projectedFraction = entitlement > 0 ? projectedTotal / Double(entitlement) : 0

        let exhaustionDate = Self.exhaustionDate(
            used: used, entitlement: entitlement, runRate: runRate,
            from: today, to: resetDate, workdays: workdays, calendar: calendar
        )
        self.exhaustionDate = exhaustionDate
        self.workdaysWithoutCredits = exhaustionDate.map { workdays.count(from: $0, to: resetDate) } ?? 0

        if used >= entitlement {
            self.status = .overLimit
        } else if projectedFraction > 1 {
            self.status = .behind
        } else if projectedFraction > 0.9 {
            self.status = .warm
        } else {
            self.status = .onTrack
        }
    }

    /// The first day of the month before the month of the reset, in local time.
    public static func periodStart(forReset resetDate: Date, calendar: Calendar = .current) -> Date {
        let reset = calendar.startOfDay(for: resetDate)
        let resetMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: reset)) ?? reset
        return calendar.date(byAdding: .month, value: -1, to: resetMonth) ?? resetMonth
    }

    /// The first workday on which the projected usage reaches the entitlement, if before the reset.
    private static func exhaustionDate(
        used: Int, entitlement: Int, runRate: Double,
        from today: Date, to resetDate: Date,
        workdays: WorkdayCalendar, calendar: Calendar
    ) -> Date? {
        guard runRate > 0 else { return nil }
        var day = today
        var workdaysFromToday = 0
        while day < resetDate {
            if workdays.isWorkday(day) {
                if Double(used) + runRate * Double(workdaysFromToday) >= Double(entitlement) { return day }
                workdaysFromToday += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return nil
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

import CopilotUsageCore
import Foundation
import Testing

func localDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

/// Entitlement 7,000, 5,552 remaining on Fri Aug 7 2026 with the reset on Sep 1, Mon–Fri workdays.
struct UsageMetricsTests {
    private func metrics(remaining: Int = 5552, today: Date = localDate(2026, 8, 7), baseline: Int = 0,
                         calendar: WorkdayCalendar = .default) -> UsageMetrics {
        UsageMetrics(
            snapshot: UsageSnapshot(entitlement: 7000, remaining: remaining, resetDate: localDate(2026, 9, 1)),
            calendar: calendar,
            today: today,
            baselineUsedAtStartOfToday: baseline
        )
    }

    @Test func workedExample() {
        let metrics = metrics()
        #expect(metrics.used == 1448)
        #expect(metrics.totalWorkdays == 21)
        #expect(metrics.elapsedWorkdays == 5)
        #expect(metrics.remainingWorkdays == 17)
        #expect(metrics.dailyBudget == 326)
        #expect(abs(metrics.usedFraction - 0.207) < 0.001)
        #expect(abs(metrics.paceFraction - 0.238) < 0.001)
        #expect(abs(metrics.runRate - 289.6) < 0.05)
        #expect(abs(metrics.projectedTotal - 6082) < 1)
        #expect(abs(metrics.projectedFraction - 0.869) < 0.001)
        #expect(metrics.status == .onTrack)
    }

    @Test func lastWorkdayBudgetIsEverythingLeft() {
        let metrics = metrics(remaining: 100, today: localDate(2026, 8, 31), baseline: 6900)
        #expect(metrics.remainingWorkdays == 1)
        #expect(metrics.dailyBudget == 100)
    }

    @Test func overLimit() {
        let metrics = metrics(remaining: -50)
        #expect(metrics.status == .overLimit)
        #expect(metrics.dailyBudget == 0)
        #expect(metrics.todayRemaining == 0)
    }

    @Test func dayOffIsExcluded() {
        var calendar = WorkdayCalendar.default
        calendar.daysOff = [DateComponents(year: 2026, month: 8, day: 10)]
        let withDayOff = metrics(today: localDate(2026, 8, 10), calendar: calendar)
        #expect(!withDayOff.todayIsWorkday)
        #expect(withDayOff.remainingWorkdays == metrics(today: localDate(2026, 8, 10)).remainingWorkdays - 1)
    }

    @Test func behindPaceRunsOutBeforeReset() throws {
        let metrics = metrics(remaining: 3000)
        #expect(metrics.status == .behind)
        let exhaustionDate = try #require(metrics.exhaustionDate)
        #expect(exhaustionDate < metrics.resetDate)
        #expect(metrics.workdaysWithoutCredits == WorkdayCalendar.default.count(from: exhaustionDate, to: metrics.resetDate))
    }

    @Test func noElapsedWorkdaysHasNoRunRate() {
        let metrics = metrics(remaining: 7000, today: localDate(2026, 8, 1))
        #expect(metrics.elapsedWorkdays == 0)
        #expect(metrics.runRate == 0)
        #expect(metrics.exhaustionDate == nil)
    }

    @Test func resetInThePastDoesNotCrash() {
        let metrics = metrics(today: localDate(2026, 9, 5))
        #expect(metrics.remainingWorkdays == 0)
        #expect(metrics.paceFraction == 1)
    }

    @Test(arguments: [(1359, 89), (5000, 0), (-100, 1448)])
    func usedTodayIsClamped(baseline: Int, expected: Int) {
        #expect(metrics(baseline: baseline).usedToday == expected)
    }

    @Test func entitlementOverrideKeepsUsed() {
        let snapshot = UsageSnapshot(entitlement: 300, remaining: 100, resetDate: .now).withEntitlement(1000)
        #expect(snapshot.used == 200)
        #expect(snapshot.remaining == 800)
    }
}

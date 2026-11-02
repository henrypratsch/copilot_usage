import CopilotUsageCore
import Foundation
import Testing

struct HistoryTests {
    private let periodStart = localDate(2026, 8, 1)

    @Test func firstRecordStartsCountingNow() {
        var history = History()
        let baseline = history.record(used: 1853, at: localDate(2026, 8, 7), periodStart: periodStart)
        #expect(baseline.used == 1853)
        #expect(baseline.isFirstDayOfTracking)
    }

    @Test func newDayStartsFromPreviousDay() {
        var history = History()
        _ = history.record(used: 300, at: localDate(2026, 8, 3), periodStart: periodStart)
        let baseline = history.record(used: 631, at: localDate(2026, 8, 4), periodStart: periodStart)
        #expect(baseline.used == 300)
        #expect(!baseline.isFirstDayOfTracking)
    }

    @Test func sameDayKeepsBaselineAndUpdatesUsage() {
        var history = History()
        _ = history.record(used: 300, at: localDate(2026, 8, 3), periodStart: periodStart)
        _ = history.record(used: 631, at: localDate(2026, 8, 4), periodStart: periodStart)
        let baseline = history.record(used: 650, at: localDate(2026, 8, 4, hour: 18), periodStart: periodStart)
        #expect(baseline.used == 300)
        #expect(history.days.count == 2)
        #expect(history.days.last?.cumulativeUsed == 650)
    }

    @Test func newPeriodStartsFresh() {
        var history = History()
        _ = history.record(used: 300, at: localDate(2026, 8, 3), periodStart: periodStart)
        let baseline = history.record(used: 50, at: localDate(2026, 9, 2), periodStart: localDate(2026, 9, 1))
        #expect(baseline.used == 50)
        #expect(baseline.isFirstDayOfTracking)
        #expect(history.days.count == 1)
    }

    @Test func lateEveningBelongsToThatLocalDay() {
        var history = History()
        _ = history.record(used: 100, at: localDate(2026, 8, 7, hour: 23, minute: 30), periodStart: periodStart)
        #expect(history.days.first?.date == "2026-08-07")
    }

    @Test func pointsStartAtZeroOnPeriodStart() {
        var history = History()
        _ = history.record(used: 100, at: localDate(2026, 8, 7), periodStart: periodStart)
        let points = history.points(periodStart: periodStart)
        #expect(points.map(\.cumulativeUsed) == [0, 100])
        #expect(points.first?.date == Calendar.current.startOfDay(for: periodStart))
    }

    @Test func storeRoundTripsAndDeletes() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "history.json")
        let store = HistoryStore(url: url)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        var history = History()
        _ = history.record(used: 1853, at: localDate(2026, 8, 7), periodStart: periodStart)
        #expect(store.save(history))
        #expect(store.load() == history)

        store.delete()
        #expect(store.load() == nil)
    }

    @Test func corruptFileLoadsAsNil() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not json".utf8).write(to: url)
        #expect(HistoryStore(url: url).load() == nil)
    }
}

import CopilotUsageCore
import Foundation
import Testing

struct UsageSnapshotTests {
    private func decode(_ json: String) throws(UsageError) -> UsageSnapshot {
        try UsageSnapshot.decode(from: Data(json.utf8), now: localDate(2026, 8, 7))
    }

    @Test func decodesQuota() throws {
        let usage = try decode(#"{ "quota_reset_date_utc": "2026-09-01T00:00:00Z", "quota_snapshots": { "premium_interactions": { "entitlement": 7000, "remaining": 5552.0, "unlimited": false } } }"#)
        #expect(usage.entitlement == 7000)
        #expect(usage.used == 1448)
        #expect(!usage.resetDateIsFallback)
    }

    @Test(arguments: ["2026-09-01T00:00:00Z", "2026-09-01T00:00:00.000Z", "2026-09-01"])
    func parsesResetDateShapes(string: String) {
        #expect(UsageSnapshot.parseDate(string) == UsageSnapshot.parseDate("2026-09-01T00:00:00Z"))
    }

    @Test func missingResetDateFallsBackToNextMonth() throws {
        let usage = try decode(#"{ "quota_snapshots": { "premium_interactions": { "entitlement": 100, "remaining": 40 } } }"#)
        #expect(usage.resetDateIsFallback)
        #expect(Calendar.current.dateComponents([.month, .day], from: usage.resetDate) == DateComponents(month: 9, day: 1))
    }

    @Test func decodesUnlimited() throws {
        #expect(try decode(#"{ "quota_snapshots": { "premium_interactions": { "unlimited": true } } }"#).unlimited)
    }

    @Test(arguments: [
        #"{}"#,
        #"{ "quota_snapshots": { "premium_interactions": { "entitlement": 0, "remaining": 0 } } }"#,
        #"{ "quota_snapshots": { "premium_interactions": { "entitlement": 1e300, "remaining": 0 } } }"#,
    ])
    func rejectsMissingOrInvalidQuota(json: String) {
        #expect(throws: UsageError.noQuota) { try decode(json) }
    }

    @Test func rejectsInvalidJSON() {
        #expect(throws: UsageError.unexpectedResponse) { try decode("<html>") }
    }

    @Test(arguments: [
        ("ghp_abc123", true),
        ("github_pat_11A-b_c", true),
        ("", false),
        ("ghp_abc\nX-Header: 1", false),
        ("ghp abc", false),
        ("tökén", false),
    ])
    func validatesTokenShape(token: String, valid: Bool) {
        #expect(TokenStore.isWellFormed(token) == valid)
    }
}

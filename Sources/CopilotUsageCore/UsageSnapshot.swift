import Foundation

/// Premium request quota as reported by GitHub. Derived numbers live in `UsageMetrics`.
public struct UsageSnapshot: Sendable, Equatable {
    public let entitlement: Int
    public let remaining: Int
    public let unlimited: Bool
    public let resetDate: Date
    /// True when the API reported no usable reset date and the first day of the next month is assumed.
    public let resetDateIsFallback: Bool

    public var used: Int { max(entitlement - remaining, 0) }

    public init(entitlement: Int, remaining: Int, unlimited: Bool = false, resetDate: Date, resetDateIsFallback: Bool = false) {
        self.entitlement = entitlement
        self.remaining = remaining
        self.unlimited = unlimited
        self.resetDate = resetDate
        self.resetDateIsFallback = resetDateIsFallback
    }

    /// Replaces the entitlement, e.g. with a user override, keeping the used count.
    public func withEntitlement(_ entitlement: Int) -> UsageSnapshot {
        UsageSnapshot(
            entitlement: entitlement,
            remaining: entitlement - used,
            unlimited: unlimited,
            resetDate: resetDate,
            resetDateIsFallback: resetDateIsFallback
        )
    }
}

extension UsageSnapshot {
    /// Decodes the response of `GET /copilot_internal/user`. The endpoint is undocumented,
    /// so only the fields we need are decoded and all of them are optional.
    public static func decode(from data: Data, now: Date = .now, calendar: Calendar = .current) throws(UsageError) -> UsageSnapshot {
        let response: Response
        do {
            response = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw .unexpectedResponse
        }

        guard let quota = response.quota_snapshots?.premium_interactions else {
            throw .noQuota
        }

        let parsedResetDate = response.quota_reset_date_utc.flatMap(parseDate)
        let resetDate = parsedResetDate ?? fallbackResetDate(after: now, calendar: calendar)

        if quota.unlimited == true {
            return UsageSnapshot(entitlement: 0, remaining: 0, unlimited: true, resetDate: resetDate, resetDateIsFallback: parsedResetDate == nil)
        }

        guard let entitlement = quota.entitlement, let remaining = quota.remaining,
              entitlement.isFinite, remaining.isFinite, entitlement > 0,
              abs(entitlement) < Double(Int32.max), abs(remaining) < Double(Int32.max)
        else { throw .noQuota }

        return UsageSnapshot(
            entitlement: Int(entitlement),
            remaining: Int(remaining),
            resetDate: resetDate,
            resetDateIsFallback: parsedResetDate == nil
        )
    }

    /// Parses the timestamp shapes GitHub uses, with and without fractional seconds, or a plain date.
    public static func parseDate(_ string: String) -> Date? {
        let optionSets: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime],
            [.withInternetDateTime, .withFractionalSeconds],
            [.withFullDate],
        ]
        for options in optionSets {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = options
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }

    /// The first day of the month after `date`. Never `date` itself, which would make the period end today.
    public static func fallbackResetDate(after date: Date, calendar: Calendar = .current) -> Date {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        return calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? date.addingTimeInterval(31 * 86400)
    }

    private struct Response: Decodable {
        let quota_snapshots: Snapshots?
        let quota_reset_date_utc: String?
    }

    private struct Snapshots: Decodable {
        let premium_interactions: Quota?
    }

    private struct Quota: Decodable {
        let entitlement: Double?
        let remaining: Double?
        let unlimited: Bool?
    }
}

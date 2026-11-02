import Foundation

/// What the menu bar shows next to the status dot.
public enum MenuBarMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case usedPercentage
    case remainingPercentage
    case usedRequests
    case remainingRequests

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .usedPercentage: "Used percentage"
        case .remainingPercentage: "Remaining percentage"
        case .usedRequests: "Used requests"
        case .remainingRequests: "Remaining requests"
        }
    }
}

/// User preferences. The token is not part of them, it lives in the keychain.
public struct AppSettings: Codable, Sendable, Equatable {
    public var menuBarMode: MenuBarMode = .usedPercentage
    public var workdayCalendar: WorkdayCalendar = .default
    /// Replaces the entitlement reported by the API when set to a positive value.
    public var monthlyLimitOverride: Int?

    public init() {}

    /// Decodes each field on its own so that one invalid value does not reset all settings.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        menuBarMode = (try? container.decodeIfPresent(MenuBarMode.self, forKey: .menuBarMode)) ?? defaults.menuBarMode
        workdayCalendar = (try? container.decodeIfPresent(WorkdayCalendar.self, forKey: .workdayCalendar)) ?? defaults.workdayCalendar
        monthlyLimitOverride = (try? container.decodeIfPresent(Int.self, forKey: .monthlyLimitOverride)) ?? nil
    }

    /// The override if it is a usable limit, otherwise the entitlement from the API.
    public func entitlement(reported: Int) -> Int {
        guard let monthlyLimitOverride, monthlyLimitOverride > 0 else { return reported }
        return monthlyLimitOverride
    }
}

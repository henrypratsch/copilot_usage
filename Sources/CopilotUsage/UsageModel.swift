import AppKit
import CopilotUsageCore
import Observation
import os

@MainActor
@Observable
final class UsageModel {
    private(set) var snapshot: UsageSnapshot?
    private(set) var metrics: UsageMetrics?
    private(set) var history: [HistoryPoint] = []
    private(set) var error: UsageError?
    private(set) var lastUpdated: Date?
    private(set) var hasToken = false

    var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            settingsStore.save(settings)
            updateMetrics()
        }
    }

    /// Showing the last known values while the most recent refresh failed.
    var isStale: Bool { metrics != nil && error != nil }

    private let client = UsageClient(userAgent: "CopilotUsage/\(appVersion)")
    private let tokenStore = TokenStore()
    private let historyStore = HistoryStore.history
    private let settingsStore = SettingsStore.settings
    private let logger = Logger(subsystem: "CopilotUsage", category: "usage")
    private var token: String?
    private var baseline: History.Baseline?
    private var isRefreshing = false

    init() {
        settings = settingsStore.load() ?? AppSettings()
        token = tokenStore.read()
        hasToken = token != nil
        startRefreshLoop()
        refreshOnWake()
    }

    func refresh() async {
        guard let token, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let fetched = try await client.fetch(token: token)
            guard token == self.token else { return }
            apply(fetched)
        } catch {
            guard token == self.token else { return }
            self.error = error
            if error == .unauthorized { clearUsage() }
            logger.error("Refresh failed: \(error.message, privacy: .public)")
        }
    }

    /// Validates the token against the API and only stores it if it works.
    func setToken(_ newToken: String) async throws(UsageError) {
        let trimmed = newToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let fetched = try await client.fetch(token: trimmed)
        guard tokenStore.save(trimmed) else { throw .keychain }
        token = trimmed
        hasToken = true
        apply(fetched)
    }

    func removeToken() {
        tokenStore.delete()
        token = nil
        hasToken = false
        error = nil
        clearUsage()
    }

    func clearHistory() {
        historyStore.delete()
        baseline = nil
        if let snapshot { apply(snapshot) } else { history = [] }
    }

    private func apply(_ fetched: UsageSnapshot) {
        let now = Date.now
        snapshot = fetched
        error = nil
        lastUpdated = now

        if !fetched.unlimited {
            let periodStart = UsageMetrics.periodStart(forReset: fetched.resetDate)
            var stored = historyStore.load() ?? History()
            baseline = stored.record(used: fetched.used, at: now, periodStart: periodStart)
            if !historyStore.save(stored) {
                logger.error("Could not save history to \(self.historyStore.url.path(percentEncoded: false), privacy: .public)")
            }
            history = stored.points(periodStart: periodStart)
        }
        updateMetrics()
    }

    private func updateMetrics() {
        guard let snapshot, !snapshot.unlimited, let baseline else {
            metrics = nil
            return
        }
        metrics = UsageMetrics(
            snapshot: snapshot.withEntitlement(settings.entitlement(reported: snapshot.entitlement)),
            calendar: settings.workdayCalendar,
            today: .now,
            baselineUsedAtStartOfToday: baseline.used,
            isFirstDayOfTracking: baseline.isFirstDayOfTracking,
            trackingStartedAt: baseline.trackingStartedAt
        )
    }

    private func clearUsage() {
        snapshot = nil
        metrics = nil
        baseline = nil
        history = []
        lastUpdated = nil
    }

    private func startRefreshLoop() {
        Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    private func refreshOnWake() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(5))
                await self?.refresh()
            }
        }
    }
}

//
//  ClaudeUsageManager.swift
//  Notcher
//
//  Manages Claude usage data fetching with session cookie authentication
//

import Foundation
import Combine
import WebKit
import SwiftUI

// MARK: - Pacing Models

/// Pacing state based on usage rate
enum ClaudeStatsPacingState {
    case wayUnder   // < 0.5 pace ratio
    case under      // 0.5-0.8
    case optimal    // 0.8-1.2
    case fast       // 1.2-1.5
    case veryFast   // 1.5-2.0
    case critical   // > 2.0

    var arrow: String {
        switch self {
        case .wayUnder: return "↓"
        case .under: return "↘"
        case .optimal: return "→"
        case .fast: return "↗"
        case .veryFast: return "↑"
        case .critical: return "⬆"
        }
    }

    var color: Color {
        switch self {
        case .wayUnder: return .blue
        case .under: return Color(red: 0.45, green: 0.75, blue: 0.70) // claudeTeal
        case .optimal: return Color(red: 0.45, green: 0.75, blue: 0.70) // claudeTeal
        case .fast: return Color(red: 0.95, green: 0.70, blue: 0.35) // claudeAmber
        case .veryFast: return .orange
        case .critical: return .red
        }
    }
}

/// Pacing data for usage windows
struct ClaudeStatsPacingData {
    let paceRatio: Double           // actual/ideal (1.0 = perfect)
    let minutesUntilExhaustion: Double?
    let minutesRemaining: Double

    var state: ClaudeStatsPacingState {
        if paceRatio < 0.5 { return .wayUnder }
        if paceRatio < 0.8 { return .under }
        if paceRatio <= 1.2 { return .optimal }
        if paceRatio <= 1.5 { return .fast }
        if paceRatio <= 2.0 { return .veryFast }
        return .critical
    }

    /// Time surplus (positive) or deficit (negative) in minutes
    var timeDelta: Double? {
        guard let exhaustion = minutesUntilExhaustion else { return nil }
        return exhaustion - minutesRemaining
    }

    /// Formatted time delta string like "+2h buffer" or "out in 1h"
    var timeDeltaText: String? {
        guard let delta = timeDelta else { return nil }

        if delta > 0 {
            // Surplus time - buffer before hitting cap
            return "+\(formatDuration(delta)) buffer"
        } else {
            // Deficit - will run out before window resets
            return "out in \(formatDuration(abs(delta)))"
        }
    }

    private func formatDuration(_ minutes: Double) -> String {
        if minutes < 60 {
            return "\(Int(minutes))m"
        } else {
            let hours = Int(minutes / 60)
            let mins = Int(minutes.truncatingRemainder(dividingBy: 60))
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(mins)m"
        }
    }

    static let unknown = ClaudeStatsPacingData(paceRatio: 1.0, minutesUntilExhaustion: nil, minutesRemaining: 0)
}

/// Model for Claude usage data
struct ClaudeUsageData {
    // These are already percentages (0-100)
    var sessionUtilization: Double = 0      // five_hour
    var weeklyUtilization: Double = 0       // seven_day (all models)
    var sonnetUtilization: Double = 0       // seven_day_sonnet
    var opusUtilization: Double = 0         // seven_day_opus
    var extraUsageUtilization: Double = 0   // extra_usage

    var sessionResetsAt: Date?
    var weeklyResetsAt: Date?
    var sonnetResetsAt: Date?
    var opusResetsAt: Date?

    var lastUpdated: Date?

    // Plan info
    var planName: String?  // e.g., "claude_pro", "claude_max"
    var planDisplayName: String? // e.g., "Pro", "Max"

    // Computed percentages (already stored as percentages)
    var opusPercentage: Double { opusUtilization }
    var sonnetPercentage: Double { sonnetUtilization }
    var weeklyPercentage: Double { weeklyUtilization }
    var sessionPercentage: Double { sessionUtilization }

    // MARK: - Pacing Calculations

    /// Session pacing (5-hour window = 300 minutes)
    var sessionPacing: ClaudeStatsPacingData {
        calculatePacing(
            utilization: sessionUtilization,
            resetsAt: sessionResetsAt,
            windowMinutes: 300
        )
    }

    /// Weekly pacing (7-day window = 10080 minutes)
    var weeklyPacing: ClaudeStatsPacingData {
        calculatePacing(
            utilization: weeklyUtilization,
            resetsAt: weeklyResetsAt,
            windowMinutes: 10080
        )
    }

    /// Calculate pacing data for a usage window
    private func calculatePacing(utilization: Double, resetsAt: Date?, windowMinutes: Double) -> ClaudeStatsPacingData {
        guard let resetsAt = resetsAt else {
            return .unknown
        }

        let now = Date()

        // If reset time is in the past, return unknown (triggers refresh)
        guard resetsAt > now else {
            return .unknown
        }

        let minutesRemaining = resetsAt.timeIntervalSince(now) / 60.0
        let minutesElapsed = windowMinutes - minutesRemaining

        // Early in window with 0% usage is fine (optimal)
        if utilization <= 0 && minutesElapsed < windowMinutes * 0.1 {
            return ClaudeStatsPacingData(paceRatio: 1.0, minutesUntilExhaustion: nil, minutesRemaining: minutesRemaining)
        }

        // Ideal pace: should use 100% over the full window
        // At any point, ideal usage = (elapsed / total) * 100
        let idealUsage = (minutesElapsed / windowMinutes) * 100.0

        // Prevent division by zero
        let paceRatio: Double
        if idealUsage <= 0 {
            // Very early in window - any usage is technically infinite pace
            // But let's be generous and treat small usage as fast, larger as critical
            paceRatio = utilization > 10 ? 2.5 : (utilization > 0 ? 1.5 : 1.0)
        } else {
            paceRatio = utilization / idealUsage
        }

        // Calculate when we'd hit 100% at current pace
        var minutesUntilExhaustion: Double? = nil
        if utilization > 0 && minutesElapsed > 0 {
            let usageRatePerMinute = utilization / minutesElapsed
            let remainingUsage = 100.0 - utilization
            if usageRatePerMinute > 0 {
                minutesUntilExhaustion = remainingUsage / usageRatePerMinute
            }
        }

        return ClaudeStatsPacingData(
            paceRatio: paceRatio,
            minutesUntilExhaustion: minutesUntilExhaustion,
            minutesRemaining: minutesRemaining
        )
    }
}

/// Manages Claude usage data via session cookie authentication
final class ClaudeUsageManager: NSObject, ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published private(set) var usageData = ClaudeUsageData()

    private var sessionCookie: String?
    @Published private(set) var organizationId: String?
    private var refreshTimer: Timer?

    // UserDefaults keys - use original keys for backward compatibility
    private static let sessionCookieKey = "claudeSessionCookie"
    private static let organizationIdKey = "claudeOrganizationId"

    override init() {
        super.init()
        loadStoredCredentials()
    }

    // MARK: - Authentication

    /// Load stored credentials from UserDefaults
    private func loadStoredCredentials() {
        sessionCookie = UserDefaults.standard.string(forKey: Self.sessionCookieKey)
        organizationId = UserDefaults.standard.string(forKey: Self.organizationIdKey)
        if sessionCookie != nil {
            isAuthenticated = true
            startPolling()
            Task { await fetchUsageData() }
        }
    }

    /// Store credentials to UserDefaults
    private func storeCredentials() {
        UserDefaults.standard.set(sessionCookie, forKey: Self.sessionCookieKey)
        UserDefaults.standard.set(organizationId, forKey: Self.organizationIdKey)
    }

    /// Clear stored credentials
    func logout() {
        sessionCookie = nil
        organizationId = nil
        isAuthenticated = false
        usageData = ClaudeUsageData()
        UserDefaults.standard.removeObject(forKey: Self.sessionCookieKey)
        UserDefaults.standard.removeObject(forKey: Self.organizationIdKey)
        stopPolling()
    }

    /// Set session cookie after WebView login
    func setSession(cookie: String, organizationId: String?) {
        self.sessionCookie = cookie
        self.organizationId = organizationId
        self.isAuthenticated = true
        storeCredentials()
        startPolling()
        Task { await fetchUsageData() }
    }

    // MARK: - Data Fetching

    /// Fetch usage data from Claude API
    func fetchUsageData() async {
        guard let cookie = sessionCookie else {
            lastError = "Not authenticated"
            return
        }

        isLoading = true
        lastError = nil

        do {
            // First get organization ID if we don't have it
            if organizationId == nil {
                organizationId = try await fetchOrganizationId(cookie: cookie)
                storeCredentials()
            }

            guard let orgId = organizationId else {
                throw URLError(.badServerResponse)
            }

            // Fetch usage data and subscription details in parallel
            async let usageTask = fetchUsage(cookie: cookie, orgId: orgId)
            async let subscriptionTask = fetchSubscriptionDetails(cookie: cookie, orgId: orgId)

            var usageResult = try await usageTask
            let planName = try? await subscriptionTask
            usageResult.planDisplayName = planName
            let finalData = usageResult

            await MainActor.run {
                self.usageData = finalData
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
                self.isLoading = false
                // If auth error, clear session
                if let urlError = error as? URLError, urlError.code == .userAuthenticationRequired {
                    self.logout()
                }
            }
        }
    }

    /// Fetch organization ID from Claude API
    private func fetchOrganizationId(cookie: String) async throws -> String {
        guard let url = URL(string: "https://claude.ai/api/organizations") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("sessionKey=\(cookie)", forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        }

        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        // Parse organizations array and get first org ID
        if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let firstOrg = json.first,
           let uuid = firstOrg["uuid"] as? String {
            return uuid
        }

        throw URLError(.cannotParseResponse)
    }

    /// Fetch usage data from Claude API - fetches from /usage endpoint
    private func fetchUsage(cookie: String, orgId: String) async throws -> ClaudeUsageData {
        // Use the /usage endpoint
        guard let url = URL(string: "https://claude.ai/api/organizations/\(orgId)/usage") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("sessionKey=\(cookie)", forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.2 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("https://claude.ai/settings/usage", forHTTPHeaderField: "Referer")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        }

        // Parse the response
        return try parseUsageEndpoint(data)
    }

    /// Fetch subscription details to get plan name
    private func fetchSubscriptionDetails(cookie: String, orgId: String) async throws -> String? {
        guard let url = URL(string: "https://claude.ai/api/organizations/\(orgId)/subscription_details") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("sessionKey=\(cookie)", forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.2 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }

        // Parse to find plan name
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Try different possible keys for plan name
            if let plan = json["plan"] as? [String: Any],
               let name = plan["name"] as? String {
                return formatPlanName(name)
            }
            if let planName = json["plan_name"] as? String {
                return formatPlanName(planName)
            }
            if let type = json["type"] as? String {
                return formatPlanName(type)
            }
            // Check for tier info
            if let tier = json["tier"] as? String {
                return formatPlanName(tier)
            }
        }

        return nil
    }

    /// Format plan name for display (e.g., "claude_max_200" -> "Max $200")
    private func formatPlanName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("max") {
            if lower.contains("200") { return "Max $200" }
            if lower.contains("100") { return "Max $100" }
            return "Max"
        }
        if lower.contains("pro") { return "Pro" }
        if lower.contains("free") { return "Free" }
        if lower.contains("team") { return "Team" }
        if lower.contains("enterprise") { return "Enterprise" }
        return name.capitalized
    }

    /// Parse /usage API response
    /// Expected format:
    /// {
    ///     "five_hour": { "utilization": 17, "resets_at": "2026-01-26T06:00:00.209169+00:00" },
    ///     "seven_day": { "utilization": 89, "resets_at": "2026-01-26T04:00:00.209191+00:00" },
    ///     "seven_day_sonnet": { "utilization": 1, "resets_at": "..." },
    ///     "seven_day_opus": null,
    ///     "extra_usage": null
    /// }
    private func parseUsageEndpoint(_ data: Data) throws -> ClaudeUsageData {
        var usage = ClaudeUsageData()
        usage.lastUpdated = Date()

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return usage
        }

        // Parse five_hour (current session)
        if let fiveHour = json["five_hour"] as? [String: Any] {
            if let utilization = fiveHour["utilization"] as? Double {
                usage.sessionUtilization = utilization
            }
            if let resetsAt = fiveHour["resets_at"] as? String {
                usage.sessionResetsAt = dateFormatter.date(from: resetsAt)
            }
        }

        // Parse seven_day (weekly - all models)
        if let sevenDay = json["seven_day"] as? [String: Any] {
            if let utilization = sevenDay["utilization"] as? Double {
                usage.weeklyUtilization = utilization
            }
            if let resetsAt = sevenDay["resets_at"] as? String {
                usage.weeklyResetsAt = dateFormatter.date(from: resetsAt)
            }
        }

        // Parse seven_day_sonnet
        if let sonnet = json["seven_day_sonnet"] as? [String: Any] {
            if let utilization = sonnet["utilization"] as? Double {
                usage.sonnetUtilization = utilization
            }
            if let resetsAt = sonnet["resets_at"] as? String {
                usage.sonnetResetsAt = dateFormatter.date(from: resetsAt)
            }
        }

        // Parse seven_day_opus
        if let opus = json["seven_day_opus"] as? [String: Any] {
            if let utilization = opus["utilization"] as? Double {
                usage.opusUtilization = utilization
            }
            if let resetsAt = opus["resets_at"] as? String {
                usage.opusResetsAt = dateFormatter.date(from: resetsAt)
            }
        }

        // Parse extra_usage if present
        if let extraUsage = json["extra_usage"] as? [String: Any] {
            if let utilization = extraUsage["utilization"] as? Double {
                usage.extraUsageUtilization = utilization
            }
        }

        return usage
    }


    // MARK: - Polling

    /// Start periodic polling for usage data
    func startPolling(interval: TimeInterval = 300) { // 5 minutes default
        stopPolling()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.fetchUsageData() }
        }
    }

    /// Stop polling
    func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    /// Manual refresh
    func refresh() {
        Task { await fetchUsageData() }
    }
}

// MARK: - WebView Login Coordinator

/// Coordinates WebView login to capture session cookie
final class ClaudeLoginCoordinator: NSObject, WKNavigationDelegate {
    var onSessionCaptured: ((String, String?) -> Void)?
    var onLoginCancelled: (() -> Void)?

    private weak var webView: WKWebView?

    func setupWebView(_ webView: WKWebView) {
        self.webView = webView
        webView.navigationDelegate = self
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Check if we're on the main Claude page (logged in)
        if let url = webView.url, url.host == "claude.ai" {
            // Check for session cookie
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                for cookie in cookies {
                    if cookie.name == "sessionKey" && cookie.domain.contains("claude.ai") {
                        // Try to get organization ID from page
                        self?.extractOrganizationId(from: webView) { orgId in
                            self?.onSessionCaptured?(cookie.value, orgId)
                        }
                        return
                    }
                }
            }
        }
    }

    private func extractOrganizationId(from webView: WKWebView, completion: @escaping (String?) -> Void) {
        // Try to extract org ID from page state or make API call
        let script = """
        (function() {
            try {
                // Try to find org ID in window state
                if (window.__NEXT_DATA__ && window.__NEXT_DATA__.props) {
                    return JSON.stringify(window.__NEXT_DATA__.props);
                }
                return null;
            } catch(e) {
                return null;
            }
        })()
        """

        webView.evaluateJavaScript(script) { result, error in
            if let jsonString = result as? String,
               let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Try to find organization UUID in the response
                if let pageProps = json["pageProps"] as? [String: Any],
                   let org = pageProps["organization"] as? [String: Any],
                   let uuid = org["uuid"] as? String {
                    completion(uuid)
                    return
                }
            }
            completion(nil)
        }
    }
}

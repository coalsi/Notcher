//
//  ClaudeStatsView.swift
//  Notcher
//
//  Content view showing Claude usage stats inside the notch
//

import SwiftUI
import AppKit

// MARK: - Claude Brand Colors

extension Color {
    /// Claude's signature coral/terracotta
    static let claudeCoral = Color(red: 0.85, green: 0.47, blue: 0.34)
    /// Lighter coral for highlights
    static let claudeCoralLight = Color(red: 0.95, green: 0.60, blue: 0.45)
    /// Warm beige/cream
    static let claudeBeige = Color(red: 0.96, green: 0.93, blue: 0.88)
    /// Soft teal for low usage
    static let claudeTeal = Color(red: 0.45, green: 0.75, blue: 0.70)
    /// Warning amber
    static let claudeAmber = Color(red: 0.95, green: 0.70, blue: 0.35)
    /// Alert coral-red
    static let claudeAlert = Color(red: 0.90, green: 0.40, blue: 0.35)
}

/// Plan badge showing user's Claude plan
struct ClaudeStatsPlanBadge: View {
    let planName: String?
    let fontSize: CGFloat

    var body: some View {
        Text(planName ?? "Claude")
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [.claudeCoralLight, .claudeCoral],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

/// Single stat display with label, percentage, and optional reset time
struct ClaudeStatsStatItem: View {
    let label: String
    let percentage: Double
    let fontSize: CGFloat
    let resetsAt: Date?
    var pacing: ClaudeStatsPacingData? = nil
    var pacingDisplayMode: ClaudeStatsPacingDisplayMode = .arrowWithTime

    private var percentageColor: Color {
        if percentage >= 90 { return .claudeAlert }
        if percentage >= 75 { return .claudeAmber }
        if percentage >= 50 { return .claudeCoral }
        return .claudeTeal
    }

    /// Format time remaining until reset in a clean way
    private var timeRemainingText: String? {
        guard let resetsAt = resetsAt else { return nil }
        let now = Date()
        guard resetsAt > now else { return nil }

        let seconds = resetsAt.timeIntervalSince(now)
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        let days = hours / 24

        if days > 0 {
            let remainingHours = hours % 24
            if remainingHours > 0 {
                return "\(days)d \(remainingHours)h left"
            }
            return "\(days)d left"
        } else if hours > 0 {
            let remainingMins = minutes % 60
            if remainingMins > 0 {
                return "\(hours)h \(remainingMins)m left"
            }
            return "\(hours)h left"
        } else {
            return "\(minutes)m left"
        }
    }

    var body: some View {
        VStack(spacing: 1) {
            // Show time remaining only for arrowWithTime mode
            if pacingDisplayMode == .arrowWithTime, let timeText = timeRemainingText {
                Text(timeText)
                    .font(.system(size: fontSize - 2, weight: .regular))
                    .foregroundColor(.claudeBeige.opacity(0.5))
            }
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: fontSize + 1, weight: .medium))
                    .foregroundColor(.claudeBeige.opacity(0.7))
                HStack(spacing: 2) {
                    Text("\(Int(percentage))%")
                        .font(.system(size: fontSize + 3, weight: .bold, design: .rounded))
                        .foregroundColor(percentageColor)
                    // Show pacing arrow for arrowOnly and arrowWithTime
                    if pacingDisplayMode != .hidden, let pacing = pacing {
                        Text(pacing.state.arrow)
                            .font(.system(size: fontSize + 2, weight: .semibold))
                            .foregroundColor(pacing.state.color)
                    }
                }
            }
        }
    }
}

/// Content view showing Claude usage stats inside the notch
struct ClaudeStatsView: View {
    @ObservedObject var manager: ClaudeUsageManager
    @ObservedObject var settings: ClaudeStatsSettings

    var body: some View {
        Group {
            if manager.isAuthenticated {
                authenticatedView
            } else {
                unauthenticatedView
            }
        }
        .padding(.horizontal, settings.sizePreset.horizontalPadding)
        .padding(.top, 0)
        .padding(.bottom, settings.sizePreset.bottomPadding)
        .opacity(manager.isLoading ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: manager.isLoading)
    }

    /// View when authenticated - shows usage stats
    private var authenticatedView: some View {
        // Stats row - centered
        HStack(spacing: settings.sizePreset.statSpacing + 4) {
            // Current Session (5-hour window)
            ClaudeStatsStatItem(
                label: "Session",
                percentage: manager.usageData.sessionPercentage,
                fontSize: settings.sizePreset.titleFontSize,
                resetsAt: manager.usageData.sessionResetsAt,
                pacing: manager.usageData.sessionPacing,
                pacingDisplayMode: settings.pacingDisplayMode
            )

            // Claude logo divider
            Image("ClaudeLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: settings.sizePreset.artworkSize * 1.1)

            // Weekly (all models - 7 day)
            ClaudeStatsStatItem(
                label: "Weekly",
                percentage: manager.usageData.weeklyPercentage,
                fontSize: settings.sizePreset.titleFontSize,
                resetsAt: manager.usageData.weeklyResetsAt,
                pacing: manager.usageData.weeklyPacing,
                pacingDisplayMode: settings.pacingDisplayMode
            )

            // Only show Opus if it has usage
            if manager.usageData.opusPercentage > 0 {
                // Subtle divider before Opus
                Rectangle()
                    .fill(Color.claudeBeige.opacity(0.15))
                    .frame(width: 1, height: settings.sizePreset.artworkSize * 0.7)

                ClaudeStatsStatItem(
                    label: "Opus",
                    percentage: manager.usageData.opusPercentage,
                    fontSize: settings.sizePreset.titleFontSize,
                    resetsAt: manager.usageData.opusResetsAt
                )
            }
        }
    }

    /// View when not authenticated - shows login prompt
    private var unauthenticatedView: some View {
        HStack(spacing: 8) {
            Text("Claude")
                .font(.system(size: settings.sizePreset.titleFontSize, weight: .semibold, design: .rounded))
                .foregroundColor(.claudeCoral.opacity(0.5))

            Text("Click menu to login")
                .font(.system(size: settings.sizePreset.artistFontSize + 1, weight: .medium))
                .foregroundColor(.claudeBeige.opacity(0.5))
        }
    }
}

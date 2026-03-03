//
//  ClaudeStatsSettings.swift
//  Notcher
//
//  Settings for ClaudeStats module
//

import SwiftUI

/// Size presets for the notch display
/// Each preset scales all dimensions proportionally
enum ClaudeStatsSizePreset: String, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extraLarge"

    /// Display name for menu items
    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }

    /// Width of the notch body (excluding ears)
    var notchWidth: CGFloat {
        switch self {
        case .small: return 260
        case .medium: return 305
        case .large: return 360
        case .extraLarge: return 420
        }
    }

    /// Height of the notch (artwork + bottom padding + clearance)
    var notchHeight: CGFloat {
        switch self {
        case .small: return 44
        case .medium: return 52
        case .large: return 60
        case .extraLarge: return 68
        }
    }

    /// Size of the album artwork
    var artworkSize: CGFloat {
        switch self {
        case .small: return 26
        case .medium: return 32
        case .large: return 40
        case .extraLarge: return 48
        }
    }

    /// Size of the ear curves at top corners
    var earSize: CGFloat {
        switch self {
        case .small: return 10
        case .medium: return 12
        case .large: return 14
        case .extraLarge: return 16
        }
    }

    /// Font size for track title
    var titleFontSize: CGFloat {
        switch self {
        case .small: return 9
        case .medium: return 10
        case .large: return 12
        case .extraLarge: return 14
        }
    }

    /// Font size for artist name
    var artistFontSize: CGFloat {
        switch self {
        case .small: return 7
        case .medium: return 8
        case .large: return 10
        case .extraLarge: return 12
        }
    }

    /// Bottom corner radius for the notch shape
    var bottomCornerRadius: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 16
        case .large: return 20
        case .extraLarge: return 24
        }
    }

    /// Horizontal padding inside the notch
    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 4
        case .medium: return 6
        case .large: return 8
        case .extraLarge: return 10
        }
    }

    /// Bottom padding inside the notch (keeps content away from bottom edge)
    var bottomPadding: CGFloat {
        switch self {
        case .small: return 6
        case .medium: return 8
        case .large: return 10
        case .extraLarge: return 12
        }
    }

    /// Spacing between stat items
    var statSpacing: CGFloat {
        switch self {
        case .small: return 6
        case .medium: return 8
        case .large: return 10
        case .extraLarge: return 12
        }
    }

    /// Icon size for the Claude brain icon
    var iconSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 14
        case .large: return 16
        case .extraLarge: return 18
        }
    }
}

/// Text alignment options for track info
enum ClaudeStatsTextAlignment: String, CaseIterable {
    case leading = "leading"
    case center = "center"
    case trailing = "trailing"

    /// Display name for menu items
    var displayName: String {
        switch self {
        case .leading: return "Left"
        case .center: return "Center"
        case .trailing: return "Right"
        }
    }

    /// SwiftUI HorizontalAlignment for VStack
    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    /// SwiftUI Alignment for text frames
    var alignment: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

/// Pacing display mode options
enum ClaudeStatsPacingDisplayMode: String, CaseIterable {
    case hidden = "hidden"
    case arrowOnly = "arrowOnly"
    case arrowWithTime = "arrowWithTime"

    var displayName: String {
        switch self {
        case .hidden: return "% Only"
        case .arrowOnly: return "% + Arrow"
        case .arrowWithTime: return "% + Time + Arrow"
        }
    }
}

/// Refresh interval options
enum ClaudeStatsRefreshInterval: Int, CaseIterable {
    case oneMinute = 60
    case twoMinutes = 120
    case fiveMinutes = 300
    case tenMinutes = 600
    case fifteenMinutes = 900
    case thirtyMinutes = 1800

    var displayName: String {
        switch self {
        case .oneMinute: return "1 minute"
        case .twoMinutes: return "2 minutes"
        case .fiveMinutes: return "5 minutes"
        case .tenMinutes: return "10 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .thirtyMinutes: return "30 minutes"
        }
    }

    var seconds: TimeInterval {
        TimeInterval(rawValue)
    }
}

/// User settings for ClaudeStats module
/// Persisted via UserDefaults - uses original keys for backward compatibility
final class ClaudeStatsSettings: ObservableObject {
    /// UserDefaults keys for persistence - original keys from ClaudeStatsNotch
    private static let sizePresetKey = "notchSizePreset"
    private static let textAlignmentKey = "notchTextAlignment"
    private static let refreshIntervalKey = "notchRefreshInterval"
    private static let pacingDisplayModeKey = "notchPacingDisplayMode"

    /// Current size preset
    @Published var sizePreset: ClaudeStatsSizePreset {
        didSet { save() }
    }

    /// Current text alignment
    @Published var textAlignment: ClaudeStatsTextAlignment {
        didSet { save() }
    }

    /// Refresh interval for API polling
    @Published var refreshInterval: ClaudeStatsRefreshInterval {
        didSet { save() }
    }

    /// Pacing display mode
    @Published var pacingDisplayMode: ClaudeStatsPacingDisplayMode {
        didSet { save() }
    }

    init() {
        let defaults = UserDefaults.standard

        let sizeRaw = defaults.string(forKey: Self.sizePresetKey) ?? ClaudeStatsSizePreset.medium.rawValue
        self.sizePreset = ClaudeStatsSizePreset(rawValue: sizeRaw) ?? .medium

        let alignmentRaw = defaults.string(forKey: Self.textAlignmentKey) ?? ClaudeStatsTextAlignment.leading.rawValue
        self.textAlignment = ClaudeStatsTextAlignment(rawValue: alignmentRaw) ?? .leading

        let refreshRaw = defaults.integer(forKey: Self.refreshIntervalKey)
        self.refreshInterval = ClaudeStatsRefreshInterval(rawValue: refreshRaw) ?? .fiveMinutes

        let pacingRaw = defaults.string(forKey: Self.pacingDisplayModeKey) ?? ClaudeStatsPacingDisplayMode.arrowWithTime.rawValue
        self.pacingDisplayMode = ClaudeStatsPacingDisplayMode(rawValue: pacingRaw) ?? .arrowWithTime
    }

    /// Save current settings to UserDefaults
    func save() {
        let defaults = UserDefaults.standard
        defaults.set(sizePreset.rawValue, forKey: Self.sizePresetKey)
        defaults.set(textAlignment.rawValue, forKey: Self.textAlignmentKey)
        defaults.set(refreshInterval.rawValue, forKey: Self.refreshIntervalKey)
        defaults.set(pacingDisplayMode.rawValue, forKey: Self.pacingDisplayModeKey)
    }
}

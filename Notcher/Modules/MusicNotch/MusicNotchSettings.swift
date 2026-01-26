//
//  MusicNotchSettings.swift
//  Notcher
//
//  Settings for MusicNotch module
//

import SwiftUI

enum MusicSizePreset: String, CaseIterable {
    case small, medium, large, extraLarge

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }

    var notchWidth: CGFloat {
        switch self {
        case .small: return 180
        case .medium: return 220
        case .large: return 280
        case .extraLarge: return 340
        }
    }

    var notchHeight: CGFloat {
        switch self {
        case .small: return 32
        case .medium: return 40
        case .large: return 48
        case .extraLarge: return 56
        }
    }

    var artworkSize: CGFloat {
        switch self {
        case .small: return 26
        case .medium: return 32
        case .large: return 40
        case .extraLarge: return 48
        }
    }

    var earSize: CGFloat {
        switch self {
        case .small: return 10
        case .medium: return 12
        case .large: return 14
        case .extraLarge: return 16
        }
    }

    var titleFontSize: CGFloat {
        switch self {
        case .small: return 10
        case .medium: return 12
        case .large: return 14
        case .extraLarge: return 16
        }
    }

    var artistFontSize: CGFloat {
        switch self {
        case .small: return 8
        case .medium: return 10
        case .large: return 12
        case .extraLarge: return 14
        }
    }

    var bottomCornerRadius: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 16
        case .large: return 20
        case .extraLarge: return 24
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 8
        case .medium: return 12
        case .large: return 16
        case .extraLarge: return 20
        }
    }

    var bottomPadding: CGFloat {
        switch self {
        case .small: return 4
        case .medium: return 6
        case .large: return 6
        case .extraLarge: return 6
        }
    }
}

enum MusicTextAlignment: String, CaseIterable {
    case leading, center, trailing

    var displayName: String {
        switch self {
        case .leading: return "Left"
        case .center: return "Center"
        case .trailing: return "Right"
        }
    }

    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var alignment: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

final class MusicNotchSettings: ObservableObject {
    // Use original keys for backward compatibility (shared with ClaudeStats)
    private static let sizeKey = "notchSizePreset"
    private static let alignmentKey = "notchTextAlignment"

    @Published var sizePreset: MusicSizePreset {
        didSet { save() }
    }

    @Published var textAlignment: MusicTextAlignment {
        didSet { save() }
    }

    init() {
        let sizeRaw = UserDefaults.standard.string(forKey: Self.sizeKey) ?? MusicSizePreset.medium.rawValue
        self.sizePreset = MusicSizePreset(rawValue: sizeRaw) ?? .medium

        let alignRaw = UserDefaults.standard.string(forKey: Self.alignmentKey) ?? MusicTextAlignment.leading.rawValue
        self.textAlignment = MusicTextAlignment(rawValue: alignRaw) ?? .leading
    }

    func save() {
        UserDefaults.standard.set(sizePreset.rawValue, forKey: Self.sizeKey)
        UserDefaults.standard.set(textAlignment.rawValue, forKey: Self.alignmentKey)
    }
}

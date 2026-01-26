//
//  CornerRadiusSettings.swift
//  Notcher
//
//  Settings for the CornerRadius module
//

import Foundation
import Combine
import CoreGraphics

enum RadiusSize: String, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .small: return "Small (12px)"
        case .medium: return "Medium (20px)"
        case .large: return "Large (30px)"
        case .custom: return "Custom..."
        }
    }

    var pixelValue: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 20
        case .large: return 30
        case .custom: return 20 // Default for custom, actual value comes from customSize
        }
    }
}

class CornerRadiusSettings: ObservableObject {
    static let shared = CornerRadiusSettings()

    // Use original keys for backward compatibility with CornerRadius app
    private let sizePresetKey = "CornerRadiusSizePreset"
    private let customSizeKey = "CornerRadiusCustomSize"
    private let disabledDisplaysKey = "CornerRadiusDisabledDisplays"
    private let topLeftEnabledKey = "CornerRadiusTopLeftEnabled"
    private let topRightEnabledKey = "CornerRadiusTopRightEnabled"
    private let bottomLeftEnabledKey = "CornerRadiusBottomLeftEnabled"
    private let bottomRightEnabledKey = "CornerRadiusBottomRightEnabled"

    @Published var sizePreset: RadiusSize {
        didSet {
            UserDefaults.standard.set(sizePreset.rawValue, forKey: sizePresetKey)
        }
    }

    @Published var customSize: CGFloat {
        didSet {
            UserDefaults.standard.set(customSize, forKey: customSizeKey)
        }
    }

    @Published var disabledDisplays: Set<CGDirectDisplayID> {
        didSet {
            let array = Array(disabledDisplays).map { Int($0) }
            UserDefaults.standard.set(array, forKey: disabledDisplaysKey)
        }
    }

    @Published var topLeftEnabled: Bool {
        didSet { UserDefaults.standard.set(topLeftEnabled, forKey: topLeftEnabledKey) }
    }

    @Published var topRightEnabled: Bool {
        didSet { UserDefaults.standard.set(topRightEnabled, forKey: topRightEnabledKey) }
    }

    @Published var bottomLeftEnabled: Bool {
        didSet { UserDefaults.standard.set(bottomLeftEnabled, forKey: bottomLeftEnabledKey) }
    }

    @Published var bottomRightEnabled: Bool {
        didSet { UserDefaults.standard.set(bottomRightEnabled, forKey: bottomRightEnabledKey) }
    }

    var currentSize: CGFloat {
        if sizePreset == .custom {
            return customSize
        }
        return sizePreset.pixelValue
    }

    private init() {
        // Load size preset
        if let savedPreset = UserDefaults.standard.string(forKey: sizePresetKey),
           let preset = RadiusSize(rawValue: savedPreset) {
            self.sizePreset = preset
        } else {
            self.sizePreset = .medium
        }

        // Load custom size
        let savedCustomSize = UserDefaults.standard.double(forKey: customSizeKey)
        self.customSize = savedCustomSize > 0 ? CGFloat(savedCustomSize) : 20

        // Load disabled displays
        if let savedDisplays = UserDefaults.standard.array(forKey: disabledDisplaysKey) as? [Int] {
            self.disabledDisplays = Set(savedDisplays.map { CGDirectDisplayID($0) })
        } else {
            self.disabledDisplays = Set()
        }

        // Load corner enabled states (default to true if not set)
        self.topLeftEnabled = UserDefaults.standard.object(forKey: topLeftEnabledKey) as? Bool ?? true
        self.topRightEnabled = UserDefaults.standard.object(forKey: topRightEnabledKey) as? Bool ?? true
        self.bottomLeftEnabled = UserDefaults.standard.object(forKey: bottomLeftEnabledKey) as? Bool ?? true
        self.bottomRightEnabled = UserDefaults.standard.object(forKey: bottomRightEnabledKey) as? Bool ?? true
    }

    func isDisplayEnabled(_ displayID: CGDirectDisplayID) -> Bool {
        !disabledDisplays.contains(displayID)
    }

    func toggleDisplay(_ displayID: CGDirectDisplayID) {
        if disabledDisplays.contains(displayID) {
            disabledDisplays.remove(displayID)
        } else {
            disabledDisplays.insert(displayID)
        }
    }

    func isCornerEnabled(_ corner: String) -> Bool {
        switch corner {
        case "topLeft": return topLeftEnabled
        case "topRight": return topRightEnabled
        case "bottomLeft": return bottomLeftEnabled
        case "bottomRight": return bottomRightEnabled
        default: return true
        }
    }

    func toggleCorner(_ corner: String) {
        switch corner {
        case "topLeft": topLeftEnabled.toggle()
        case "topRight": topRightEnabled.toggle()
        case "bottomLeft": bottomLeftEnabled.toggle()
        case "bottomRight": bottomRightEnabled.toggle()
        default: break
        }
    }
}

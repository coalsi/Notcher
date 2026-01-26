//
//  DisplayManager.swift
//  Notcher
//
//  Utility for display-related calculations including notch detection
//

import AppKit

/// Utility enum for display-related calculations including notch detection
enum DisplayManager {

    /// Determines if a screen has a hardware notch
    static func hasNotch(screen: NSScreen) -> Bool {
        if #available(macOS 12.0, *) {
            return screen.safeAreaInsets.top > 0
        }
        return false
    }

    /// Calculates the frame of the hardware notch for a given screen
    static func notchFrame(for screen: NSScreen) -> CGRect? {
        guard hasNotch(screen: screen) else { return nil }

        if #available(macOS 12.0, *) {
            guard let leftArea = screen.auxiliaryTopLeftArea,
                  let rightArea = screen.auxiliaryTopRightArea else {
                return nil
            }

            let notchX = leftArea.maxX
            let notchWidth = screen.frame.width - leftArea.width - rightArea.width
            let notchHeight = screen.safeAreaInsets.top
            let notchY = screen.frame.maxY - notchHeight

            return CGRect(x: screen.frame.origin.x + notchX, y: notchY, width: notchWidth, height: notchHeight)
        }

        return nil
    }

    /// Calculates the menu bar height for a given screen
    static func menuBarHeight(for screen: NSScreen) -> CGFloat {
        return screen.frame.maxY - screen.visibleFrame.maxY
    }
}

/// Extension to get CGDirectDisplayID from NSScreen
extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? 0
    }
}

//
//  CornerWindowController.swift
//  Notcher
//
//  Window controller for managing corner overlay windows on a single display
//

import AppKit
import SwiftUI

class CornerWindowController {
    let displayID: CGDirectDisplayID
    let screen: NSScreen
    private var windows: [CornerPosition: NSWindow] = [:]
    private let settings = CornerRadiusSettings.shared

    init(screen: NSScreen) {
        self.screen = screen
        self.displayID = screen.displayID
        createWindows()
    }

    private func createWindows() {
        for position in CornerPosition.allCases {
            let window = createWindow(for: position)
            windows[position] = window
        }
        updatePositions()
    }

    private func createWindow(for position: CornerPosition) -> NSWindow {
        let size = settings.currentSize
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true

        let cornerView = CornerView(position: position, size: size)
        window.contentView = NSHostingView(rootView: cornerView)

        return window
    }

    func updatePositions() {
        let size = settings.currentSize
        let frame = screen.frame

        for (position, window) in windows {
            let origin: NSPoint
            switch position {
            case .topLeft:
                origin = NSPoint(x: frame.minX, y: frame.maxY - size)
            case .topRight:
                origin = NSPoint(x: frame.maxX - size, y: frame.maxY - size)
            case .bottomLeft:
                origin = NSPoint(x: frame.minX, y: frame.minY)
            case .bottomRight:
                origin = NSPoint(x: frame.maxX - size, y: frame.minY)
            }

            window.setFrame(NSRect(origin: origin, size: NSSize(width: size, height: size)), display: true)

            // Update the content view with new size
            let cornerView = CornerView(position: position, size: size)
            window.contentView = NSHostingView(rootView: cornerView)
        }
    }

    func show() {
        for (position, window) in windows {
            if isCornerEnabled(position) {
                window.orderFront(nil)
            } else {
                window.orderOut(nil)
            }
        }
    }

    func hide() {
        for window in windows.values {
            window.orderOut(nil)
        }
    }

    func updateSize() {
        updatePositions()
        // Re-apply corner visibility
        show()
    }

    private func isCornerEnabled(_ position: CornerPosition) -> Bool {
        switch position {
        case .topLeft: return settings.topLeftEnabled
        case .topRight: return settings.topRightEnabled
        case .bottomLeft: return settings.bottomLeftEnabled
        case .bottomRight: return settings.bottomRightEnabled
        }
    }
}

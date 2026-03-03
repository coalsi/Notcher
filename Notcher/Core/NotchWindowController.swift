//
//  NotchWindowController.swift
//  Notcher
//
//  Base window controller for notch-style floating windows
//

import AppKit
import SwiftUI

/// Base window controller for notch-style modules
class NotchWindowController: NSWindowController {
    private var targetDisplayID: CGDirectDisplayID?

    /// The content view to display in the notch
    private var contentView: AnyView

    /// Size configuration
    var notchWidth: CGFloat = 220
    var notchHeight: CGFloat = 40
    var earSize: CGFloat = 12
    var bottomCornerRadius: CGFloat = 16

    init(contentView: AnyView, displayID: CGDirectDisplayID? = nil) {
        self.contentView = contentView
        self.targetDisplayID = displayID

        let window = NSWindow(
            contentRect: .zero,
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

        super.init(window: window)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        rebuildNotchView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Update the content view
    func updateContentView(_ newContent: AnyView) {
        self.contentView = newContent
        rebuildNotchView()
    }

    /// Update size configuration
    func updateSize(width: CGFloat, height: CGFloat, earSize: CGFloat, bottomCornerRadius: CGFloat) {
        self.notchWidth = width
        self.notchHeight = height
        self.earSize = earSize
        self.bottomCornerRadius = bottomCornerRadius
        rebuildNotchView()
        positionAtScreenTop()
    }

    private func rebuildNotchView() {
        guard let window = window else { return }

        let notchView = HStack(alignment: .top, spacing: 0) {
            NotchEarShape(isLeftSide: true)
                .fill(.black)
                .frame(width: earSize, height: earSize)

            ZStack {
                NotchLiquidShape(earRadius: 0, bottomCornerRadius: bottomCornerRadius)
                    .fill(.black)
                contentView
            }
            .frame(width: notchWidth, height: notchHeight)

            NotchEarShape(isLeftSide: false)
                .fill(.black)
                .frame(width: earSize, height: earSize)
        }

        let hostingController = NSHostingController(rootView: notchView)
        window.contentViewController = hostingController
    }

    @objc private func screenParametersDidChange(_ notification: Notification) {
        positionAtScreenTop()
    }

    func setTargetDisplay(_ displayID: CGDirectDisplayID?) {
        targetDisplayID = displayID
        positionAtScreenTop()
    }

    private func screenForDisplayID(_ displayID: CGDirectDisplayID) -> NSScreen? {
        return NSScreen.screens.first { $0.displayID == displayID }
    }

    func positionAtScreenTop() {
        guard let window = window else { return }

        let screen: NSScreen?
        if let targetID = targetDisplayID, let targetScreen = screenForDisplayID(targetID) {
            screen = targetScreen
        } else {
            screen = NSScreen.main ?? NSScreen.screens.first
        }

        guard let screen = screen else { return }

        let windowWidth = notchWidth + (earSize * 2)
        let windowHeight = notchHeight

        window.setContentSize(NSSize(width: windowWidth, height: windowHeight))

        let screenFrame = screen.frame
        let x = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
        let y = screenFrame.maxY - windowHeight

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func showNotchWindow() {
        positionAtScreenTop()
        showWindow(nil)
        window?.orderFrontRegardless()
    }

    func hideNotchWindow() {
        window?.orderOut(nil)
    }
}

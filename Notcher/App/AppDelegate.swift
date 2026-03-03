//
//  AppDelegate.swift
//  Notcher
//
//  Main application delegate - manages menu bar and modules
//

import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let registry = ModuleRegistry.shared
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupModules()
        setupStatusItem()
        setupObservers()
    }

    private func setupModules() {
        registry.register(MusicNotchModule())
        registry.register(CornerRadiusModule())
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = createNotcherMenuBarIcon()
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupObservers() {
        // Display configuration changes
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.handleDisplayChange()
            }
            .store(in: &cancellables)

        // Sleep/Wake
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.handleWake()
                }
            }
            .store(in: &cancellables)
    }

    @objc private func togglePopover() {
        if let popover = popover, popover.isShown {
            popover.close()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.animates = true

        let menuView = NotcherMenuView(registry: registry) {
            popover.close()
        }
        popover.contentViewController = NSHostingController(rootView: menuView)

        if let button = statusItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }

        self.popover = popover
    }

    private func handleDisplayChange() {
        // Notify active notch modules of display change
        for (_, module) in registry.activeNotchModules {
            module.deactivate()
            module.activate()
        }
        // Notify active effect modules
        for module in registry.effectModules where module.isEnabled {
            module.deactivate()
            module.activate()
        }
    }

    private func handleWake() {
        // Refresh all active notch modules after wake (deactivate first to avoid leaking windows)
        for (_, module) in registry.activeNotchModules {
            module.deactivate()
            module.activate()
        }
        // Refresh active effect modules
        for module in registry.effectModules where module.isEnabled {
            module.deactivate()
            module.activate()
        }
    }
}

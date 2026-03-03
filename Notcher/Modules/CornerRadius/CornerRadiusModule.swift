//
//  CornerRadiusModule.swift
//  Notcher
//
//  CornerRadius module - adds rounded corner overlays to screen corners
//

import SwiftUI
import Combine
import AppKit

final class CornerRadiusModule: NotcherModule, ObservableObject {
    let id = "cornerradius"
    let name = "CornerRadius"
    let icon = "rectangle.roundedtop"
    let category: ModuleCategory = .effect

    @Published var isEnabled = false

    private let settings = CornerRadiusSettings.shared
    private var windowControllers: [CGDirectDisplayID: CornerWindowController] = [:]
    private var settingsCancellables = Set<AnyCancellable>()
    private var lifecycleCancellables = Set<AnyCancellable>()

    init() {
        // Observe settings changes
        settings.$sizePreset
            .sink { [weak self] _ in self?.updateAllCorners() }
            .store(in: &settingsCancellables)
        settings.$customSize
            .sink { [weak self] _ in self?.updateAllCorners() }
            .store(in: &settingsCancellables)
        settings.$topLeftEnabled
            .sink { [weak self] _ in self?.updateAllCorners() }
            .store(in: &settingsCancellables)
        settings.$topRightEnabled
            .sink { [weak self] _ in self?.updateAllCorners() }
            .store(in: &settingsCancellables)
        settings.$bottomLeftEnabled
            .sink { [weak self] _ in self?.updateAllCorners() }
            .store(in: &settingsCancellables)
        settings.$bottomRightEnabled
            .sink { [weak self] _ in self?.updateAllCorners() }
            .store(in: &settingsCancellables)
    }

    func activate() {
        setupWindowControllers()
        setupObservers()
    }

    func deactivate() {
        hideAllCorners()
        windowControllers.removeAll()
        lifecycleCancellables.removeAll()
    }

    // MARK: - Window Controllers

    private func setupWindowControllers() {
        for screen in NSScreen.screens {
            let displayID = screen.displayID
            if settings.isDisplayEnabled(displayID) {
                let controller = CornerWindowController(screen: screen)
                controller.show()
                windowControllers[displayID] = controller
            }
        }
    }

    private func updateAllCorners() {
        guard isEnabled else { return }
        for controller in windowControllers.values {
            controller.updateSize()
        }
    }

    private func hideAllCorners() {
        for controller in windowControllers.values {
            controller.hide()
        }
    }

    private func refreshAllCorners() {
        guard isEnabled else { return }
        windowControllers.removeAll()

        for screen in NSScreen.screens {
            let displayID = screen.displayID
            if settings.isDisplayEnabled(displayID) {
                let controller = CornerWindowController(screen: screen)
                controller.show()
                windowControllers[displayID] = controller
            }
        }
    }

    // MARK: - Observers

    private func setupObservers() {
        // Display configuration changes
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.handleDisplayChange()
            }
            .store(in: &lifecycleCancellables)

        // Sleep/Wake notifications
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)
            .sink { [weak self] _ in
                self?.hideAllCorners()
            }
            .store(in: &lifecycleCancellables)

        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                // Delay slightly to let display come back
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.refreshAllCorners()
                }
            }
            .store(in: &lifecycleCancellables)
    }

    private func handleDisplayChange() {
        guard isEnabled else { return }

        // Remove controllers for disconnected displays
        let currentDisplayIDs = Set(NSScreen.screens.map { $0.displayID })
        let existingDisplayIDs = Set(windowControllers.keys)

        for displayID in existingDisplayIDs.subtracting(currentDisplayIDs) {
            windowControllers[displayID]?.hide()
            windowControllers.removeValue(forKey: displayID)
        }

        // Add controllers for new displays
        for screen in NSScreen.screens {
            let displayID = screen.displayID
            if settings.isDisplayEnabled(displayID) && windowControllers[displayID] == nil {
                let controller = CornerWindowController(screen: screen)
                controller.show()
                windowControllers[displayID] = controller
            }
        }

        // Update positions for existing displays (in case resolution changed)
        for (displayID, controller) in windowControllers {
            if NSScreen.screens.first(where: { $0.displayID == displayID }) != nil {
                controller.updateSize()
            }
        }
    }

    // MARK: - Display Management

    func toggleDisplay(_ displayID: CGDirectDisplayID) {
        settings.toggleDisplay(displayID)

        guard isEnabled else { return }

        if settings.isDisplayEnabled(displayID) {
            if let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) {
                let controller = CornerWindowController(screen: screen)
                controller.show()
                windowControllers[displayID] = controller
            }
        } else {
            windowControllers[displayID]?.hide()
            windowControllers.removeValue(forKey: displayID)
        }
    }

    // MARK: - Settings Views

    @ViewBuilder
    var quickSettingsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Size picker
            HStack {
                Text("Size")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: Binding(
                    get: { self.settings.sizePreset },
                    set: { self.settings.sizePreset = $0 }
                )) {
                    ForEach(RadiusSize.allCases, id: \.self) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }

            // Custom size slider
            if self.settings.sizePreset == .custom {
                HStack {
                    Slider(value: Binding(
                        get: { self.settings.customSize },
                        set: { self.settings.customSize = $0 }
                    ), in: 1...100, step: 1)
                    Text("\(Int(self.settings.customSize))px")
                        .font(.system(size: 11))
                        .frame(width: 35, alignment: .trailing)
                }
            }

            // Corners toggles
            HStack(spacing: 12) {
                Toggle("TL", isOn: Binding(
                    get: { self.settings.topLeftEnabled },
                    set: { self.settings.topLeftEnabled = $0 }
                ))
                    .toggleStyle(.checkbox)
                Toggle("TR", isOn: Binding(
                    get: { self.settings.topRightEnabled },
                    set: { self.settings.topRightEnabled = $0 }
                ))
                    .toggleStyle(.checkbox)
                Toggle("BL", isOn: Binding(
                    get: { self.settings.bottomLeftEnabled },
                    set: { self.settings.bottomLeftEnabled = $0 }
                ))
                    .toggleStyle(.checkbox)
                Toggle("BR", isOn: Binding(
                    get: { self.settings.bottomRightEnabled },
                    set: { self.settings.bottomRightEnabled = $0 }
                ))
                    .toggleStyle(.checkbox)
            }
            .font(.system(size: 11))

            // Displays section
            if NSScreen.screens.count > 1 {
                Divider()
                    .padding(.vertical, 4)
                Text("Displays")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                ForEach(NSScreen.screens, id: \.displayID) { screen in
                    Toggle(screen.localizedName, isOn: Binding(
                        get: { self.settings.isDisplayEnabled(screen.displayID) },
                        set: { _ in self.toggleDisplay(screen.displayID) }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                }
            }
        }
    }

    @ViewBuilder
    var settingsView: some View {
        Form {
            Section("Size") {
                Picker("Corner Size", selection: Binding(
                    get: { self.settings.sizePreset },
                    set: { self.settings.sizePreset = $0 }
                )) {
                    ForEach(RadiusSize.allCases, id: \.self) { size in
                        Text(size.displayName).tag(size)
                    }
                }

                if self.settings.sizePreset == .custom {
                    HStack {
                        Text("Custom Size:")
                        Slider(value: Binding(
                            get: { self.settings.customSize },
                            set: { self.settings.customSize = $0 }
                        ), in: 1...100, step: 1)
                        Text("\(Int(self.settings.customSize))px")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }

            Section("Corners") {
                Toggle("Top Left", isOn: Binding(
                    get: { self.settings.topLeftEnabled },
                    set: { self.settings.topLeftEnabled = $0 }
                ))
                Toggle("Top Right", isOn: Binding(
                    get: { self.settings.topRightEnabled },
                    set: { self.settings.topRightEnabled = $0 }
                ))
                Toggle("Bottom Left", isOn: Binding(
                    get: { self.settings.bottomLeftEnabled },
                    set: { self.settings.bottomLeftEnabled = $0 }
                ))
                Toggle("Bottom Right", isOn: Binding(
                    get: { self.settings.bottomRightEnabled },
                    set: { self.settings.bottomRightEnabled = $0 }
                ))
            }

            Section("Displays") {
                ForEach(NSScreen.screens, id: \.displayID) { screen in
                    Toggle(screen.localizedName, isOn: Binding(
                        get: { self.settings.isDisplayEnabled(screen.displayID) },
                        set: { _ in self.toggleDisplay(screen.displayID) }
                    ))
                }
            }
        }
    }
}

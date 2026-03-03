//
//  ClaudeStatsModule.swift
//  Notcher
//
//  ClaudeStats module - displays Claude API usage statistics
//

import SwiftUI
import Combine
import AppKit

final class ClaudeStatsModule: NotcherModule, ObservableObject {
    let id = "claudestats"
    let name = "ClaudeStats"
    let icon = "chart.bar.fill"
    let category: ModuleCategory = .notch

    @Published var isEnabled = false

    @Published var assignedDisplayID: CGDirectDisplayID {
        didSet {
            UserDefaults.standard.set(Int(assignedDisplayID), forKey: "notcher.claudestats.displayID")
            // If active, move to new display
            if isEnabled {
                deactivate()
                activate()
            }
        }
    }

    private let manager = ClaudeUsageManager()
    private let settings = ClaudeStatsSettings()
    private var windowController: NotchWindowController?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Load saved display ID
        if let savedID = UserDefaults.standard.object(forKey: "notcher.claudestats.displayID") as? Int {
            self.assignedDisplayID = CGDirectDisplayID(savedID)
        } else {
            self.assignedDisplayID = CGMainDisplayID()
        }

        // Only observe size changes (need to resize window) - other settings handled by SwiftUI
        settings.$sizePreset
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateWindowSize() }
            .store(in: &cancellables)

        // Refresh interval needs to restart polling
        settings.$refreshInterval
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] interval in
                self?.manager.startPolling(interval: interval.seconds)
            }
            .store(in: &cancellables)
    }

    func activate() {
        let contentView = ClaudeStatsView(manager: manager, settings: settings)
        windowController = NotchWindowController(contentView: AnyView(contentView), displayID: assignedDisplayID)
        updateWindowSize()
        windowController?.showNotchWindow()
        manager.startPolling(interval: settings.refreshInterval.seconds)
    }

    func deactivate() {
        windowController?.hideNotchWindow()
        windowController = nil
        manager.stopPolling()
    }

    private func updateWindowSize() {
        guard windowController != nil else { return }
        let preset = settings.sizePreset
        windowController?.updateSize(
            width: preset.notchWidth,
            height: preset.notchHeight,
            earSize: preset.earSize,
            bottomCornerRadius: preset.bottomCornerRadius
        )
    }

    @ViewBuilder
    var quickSettingsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Display picker
            HStack {
                Text("Display")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: Binding(
                    get: { self.assignedDisplayID },
                    set: { self.assignedDisplayID = $0 }
                )) {
                    ForEach(NSScreen.screens, id: \.displayID) { screen in
                        Text(screen.localizedName).tag(screen.displayID)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }

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
                    ForEach(ClaudeStatsSizePreset.allCases, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }

            // Pacing display mode
            HStack {
                Text("Pacing")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: Binding(
                    get: { self.settings.pacingDisplayMode },
                    set: { self.settings.pacingDisplayMode = $0 }
                )) {
                    ForEach(ClaudeStatsPacingDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }

            // Refresh interval
            HStack {
                Text("Refresh")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: Binding(
                    get: { self.settings.refreshInterval },
                    set: { self.settings.refreshInterval = $0 }
                )) {
                    ForEach(ClaudeStatsRefreshInterval.allCases, id: \.self) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }

            // Refresh button
            Button(action: { self.manager.refresh() }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Now")
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.accentColor)

            // Login/Logout button
            if self.manager.isAuthenticated {
                Button(action: { self.manager.logout() }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Logout")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.red)
            } else {
                Button(action: { ClaudeLoginWindowController.shared.showLogin(manager: self.manager) }) {
                    HStack {
                        Image(systemName: "key.fill")
                        Text("Login")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.orange)
            }
        }
    }

    @ViewBuilder
    var settingsView: some View {
        Form {
            Section("Display") {
                Picker("Monitor", selection: Binding(
                    get: { self.assignedDisplayID },
                    set: { self.assignedDisplayID = $0 }
                )) {
                    ForEach(NSScreen.screens, id: \.displayID) { screen in
                        Text(screen.localizedName).tag(screen.displayID)
                    }
                }
            }

            Section("Appearance") {
                Picker("Size", selection: Binding(
                    get: { self.settings.sizePreset },
                    set: { self.settings.sizePreset = $0 }
                )) {
                    ForEach(ClaudeStatsSizePreset.allCases, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }

                Picker("Text Alignment", selection: Binding(
                    get: { self.settings.textAlignment },
                    set: { self.settings.textAlignment = $0 }
                )) {
                    ForEach(ClaudeStatsTextAlignment.allCases, id: \.self) { align in
                        Text(align.displayName).tag(align)
                    }
                }

                Picker("Pacing Display", selection: Binding(
                    get: { self.settings.pacingDisplayMode },
                    set: { self.settings.pacingDisplayMode = $0 }
                )) {
                    ForEach(ClaudeStatsPacingDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            Section("Data") {
                Picker("Refresh Interval", selection: Binding(
                    get: { self.settings.refreshInterval },
                    set: { self.settings.refreshInterval = $0 }
                )) {
                    ForEach(ClaudeStatsRefreshInterval.allCases, id: \.self) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }

                Button("Refresh Now") {
                    self.manager.refresh()
                }
            }

            Section("Authentication") {
                if self.manager.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Authenticated")
                        Spacer()
                        Button("Logout") {
                            self.manager.logout()
                        }
                        .foregroundColor(.red)
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("Not authenticated")
                        Spacer()
                        Button("Login") {
                            ClaudeLoginWindowController.shared.showLogin(manager: self.manager)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
}

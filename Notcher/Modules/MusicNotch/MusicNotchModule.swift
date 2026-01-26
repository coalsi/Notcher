//
//  MusicNotchModule.swift
//  Notcher
//
//  MusicNotch module - displays currently playing music
//

import SwiftUI
import Combine
import AppKit

final class MusicNotchModule: NotcherModule, ObservableObject {
    let id = "musicnotch"
    let name = "MusicNotch"
    let icon = "music.note"
    let category: ModuleCategory = .notch

    @Published var isEnabled = false

    @Published var assignedDisplayID: CGDirectDisplayID {
        didSet {
            UserDefaults.standard.set(Int(assignedDisplayID), forKey: "notcher.musicnotch.displayID")
            // If active, move to new display
            if isEnabled {
                deactivate()
                activate()
            }
        }
    }

    private let manager = MusicNowPlayingManager()
    private let settings = MusicNotchSettings()
    private var windowController: NotchWindowController?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Load saved display ID
        if let savedID = UserDefaults.standard.object(forKey: "notcher.musicnotch.displayID") as? Int {
            self.assignedDisplayID = CGDirectDisplayID(savedID)
        } else {
            self.assignedDisplayID = CGMainDisplayID()
        }

        // Only observe size changes (need to resize window) - text alignment handled by SwiftUI
        settings.$sizePreset
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateWindowSize() }
            .store(in: &cancellables)
    }

    func activate() {
        Task {
            await manager.requestAuthorization()
        }

        let contentView = MusicNotchView(manager: manager, settings: settings)
        windowController = NotchWindowController(contentView: AnyView(contentView), displayID: assignedDisplayID)
        updateWindowSize()
        windowController?.showNotchWindow()
    }

    func deactivate() {
        windowController?.hideNotchWindow()
        windowController = nil
        manager.stopObserving()
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
                    ForEach(MusicSizePreset.allCases, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }

            // Text alignment picker
            HStack {
                Text("Alignment")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: Binding(
                    get: { self.settings.textAlignment },
                    set: { self.settings.textAlignment = $0 }
                )) {
                    ForEach(MusicTextAlignment.allCases, id: \.self) { align in
                        Text(align.displayName).tag(align)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
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
                    ForEach(MusicSizePreset.allCases, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }

                Picker("Text Alignment", selection: Binding(
                    get: { self.settings.textAlignment },
                    set: { self.settings.textAlignment = $0 }
                )) {
                    ForEach(MusicTextAlignment.allCases, id: \.self) { align in
                        Text(align.displayName).tag(align)
                    }
                }
            }
        }
    }
}

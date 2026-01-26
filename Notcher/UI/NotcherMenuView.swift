//
//  NotcherMenuView.swift
//  Notcher
//
//  Glassmorphism dropdown menu for module selection
//

import SwiftUI

struct NotcherMenuView: View {
    @ObservedObject var registry: ModuleRegistry
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Notch modules section
            if !registry.notchModules.isEmpty {
                SectionHeader(title: "NOTCH DISPLAY")

                ForEach(registry.notchModules, id: \.id) { module in
                    ModuleRowView(
                        module: module,
                        isSelected: registry.isNotchModuleActive(module),
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                registry.toggleNotchModule(module)
                            }
                        }
                    )
                }
            }

            // Effect modules section
            if !registry.effectModules.isEmpty {
                if !registry.notchModules.isEmpty {
                    Divider()
                        .padding(.vertical, 8)
                }

                SectionHeader(title: "SCREEN EFFECTS")

                ForEach(registry.effectModules, id: \.id) { module in
                    ModuleRowView(
                        module: module,
                        isSelected: module.isEnabled,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                registry.toggleEffectModule(module)
                            }
                        }
                    )
                }
            }

            // Placeholder when no modules
            if registry.modules.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No modules loaded")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }

            Divider()
                .padding(.vertical, 8)

            // Footer
            HStack {
                Button(action: {
                    onDismiss()
                    SettingsWindowController.shared.showGeneralSettings()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(",", modifiers: .command)

                Spacer()

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    HStack(spacing: 4) {
                        Text("Quit")
                        Text("Q")
                            .font(.system(size: 11))
                            .foregroundColor(Color.secondary.opacity(0.6))
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow))
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - Settings Window Controller

final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var windowController: NSWindowController?

    private init() {}

    func showSettings(for module: AnyNotcherModule) {
        closeExistingWindow()

        let contentView = SettingsWindowView(module: module)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "\(module.name) Settings"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 450, height: 350))
        window.center()
        window.isReleasedWhenClosed = false

        windowController = NSWindowController(window: window)
        windowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showGeneralSettings() {
        closeExistingWindow()

        let contentView = GeneralSettingsView()
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Notcher Settings"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 450, height: 300))
        window.center()
        window.isReleasedWhenClosed = false

        windowController = NSWindowController(window: window)
        windowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeExistingWindow() {
        windowController?.close()
        windowController = nil
    }
}

struct SettingsWindowView: View {
    let module: AnyNotcherModule

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: module.icon)
                    .font(.title2)
                Text(module.name)
                    .font(.title2.weight(.semibold))
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                module.settingsView
                    .padding()
            }
        }
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Notcher")
                .font(.title.weight(.semibold))

            Text("Version 1.0")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()
                .padding(.vertical)

            Text("General settings coming soon")
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(32)
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

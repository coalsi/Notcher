//
//  ClaudeLoginView.swift
//  Notcher
//
//  Manual session key entry for Claude authentication
//

import SwiftUI
import AppKit

struct ClaudeLoginView: View {
    let manager: ClaudeUsageManager
    let onComplete: () -> Void

    @State private var sessionKey: String = ""
    @State private var showingInstructions = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "key.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("Connect to Claude")
                    .font(.title2.weight(.semibold))
                Spacer()
            }
            .padding(.bottom, 8)

            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("To connect, you'll need your Claude session key:")
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 8) {
                    instructionStep(1, "Open Safari and go to claude.ai")
                    instructionStep(2, "Log in if you haven't already")
                    instructionStep(3, "Open Safari → Settings → Privacy → Manage Website Data")
                    instructionStep(4, "Search for \"claude.ai\" and click Details")
                    instructionStep(5, "Find the cookie named \"sessionKey\" and copy its value")
                }
                .padding(.vertical, 8)

                // Quick Safari button
                Button(action: openClaudeInSafari) {
                    HStack {
                        Image(systemName: "safari")
                        Text("Open claude.ai in Safari")
                    }
                }
                .buttonStyle(.link)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            // Session key input
            VStack(alignment: .leading, spacing: 8) {
                Text("Session Key:")
                    .font(.subheadline.weight(.medium))

                TextField("Paste your sessionKey here...", text: $sessionKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            Spacer()

            // Buttons
            HStack {
                Button("Cancel") {
                    onComplete()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Connect") {
                    connect()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(sessionKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 480, height: 420)
    }

    private func instructionStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .trailing)
            Text(text)
                .font(.subheadline)
        }
    }

    private func openClaudeInSafari() {
        if let url = URL(string: "https://claude.ai") {
            NSWorkspace.shared.open(url)
        }
    }

    private func connect() {
        let key = sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        manager.setSession(cookie: key, organizationId: nil)
        onComplete()
    }
}

// MARK: - Login Window Controller

final class ClaudeLoginWindowController {
    static let shared = ClaudeLoginWindowController()

    private var windowController: NSWindowController?

    private init() {}

    func showLogin(manager: ClaudeUsageManager) {
        closeExistingWindow()

        let contentView = ClaudeLoginView(manager: manager) { [weak self] in
            self?.closeExistingWindow()
        }
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Connect to Claude"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 480, height: 420))
        window.center()
        window.isReleasedWhenClosed = false

        windowController = NSWindowController(window: window)
        windowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeExistingWindow() {
        windowController?.close()
        windowController = nil
    }
}

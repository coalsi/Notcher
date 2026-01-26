//
//  NotcherApp.swift
//  Notcher
//
//  Unified menu bar app for display customization modules
//

import SwiftUI

@main
struct NotcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

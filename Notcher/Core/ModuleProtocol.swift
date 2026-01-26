//
//  ModuleProtocol.swift
//  Notcher
//
//  Protocol that all Notcher modules must implement
//

import SwiftUI
import AppKit

/// Category of module - determines behavior rules
enum ModuleCategory: String {
    /// Notch modules - one per display max, multiple can be active on different displays
    case notch
    /// Effect modules run independently alongside any other modules
    case effect
}

/// Protocol that all Notcher modules must implement
protocol NotcherModule: ObservableObject {
    /// Unique identifier for this module
    var id: String { get }

    /// Display name shown in menu
    var name: String { get }

    /// SF Symbol name for icon
    var icon: String { get }

    /// Category determines behavior (notch vs effect)
    var category: ModuleCategory { get }

    /// Whether this module is currently enabled/active
    var isEnabled: Bool { get set }

    /// The display ID this module is assigned to (for notch modules)
    var assignedDisplayID: CGDirectDisplayID { get set }

    /// Activate this module (show windows, start polling, etc.)
    func activate()

    /// Deactivate this module (hide windows, stop polling, etc.)
    func deactivate()

    /// Quick settings view shown inline in the menu dropdown
    associatedtype QuickSettingsView: View
    @ViewBuilder var quickSettingsView: QuickSettingsView { get }

    /// Full settings view shown in the settings window
    associatedtype SettingsView: View
    @ViewBuilder var settingsView: SettingsView { get }
}

// MARK: - Default Implementation

extension NotcherModule {
    /// Default to main display
    var assignedDisplayID: CGDirectDisplayID {
        get { CGMainDisplayID() }
        set { }
    }
}

/// Type-erased wrapper for NotcherModule to allow heterogeneous collections
final class AnyNotcherModule: ObservableObject {
    let id: String
    let name: String
    let icon: String
    let category: ModuleCategory

    private let _isEnabledGetter: () -> Bool
    private let _isEnabledSetter: (Bool) -> Void
    private let _assignedDisplayIDGetter: () -> CGDirectDisplayID
    private let _assignedDisplayIDSetter: (CGDirectDisplayID) -> Void
    private let _activate: () -> Void
    private let _deactivate: () -> Void
    private let _quickSettingsView: () -> AnyView
    private let _settingsView: () -> AnyView

    var isEnabled: Bool {
        get { _isEnabledGetter() }
        set { _isEnabledSetter(newValue) }
    }

    var assignedDisplayID: CGDirectDisplayID {
        get { _assignedDisplayIDGetter() }
        set { _assignedDisplayIDSetter(newValue) }
    }

    init<M: NotcherModule>(_ module: M) {
        self.id = module.id
        self.name = module.name
        self.icon = module.icon
        self.category = module.category
        self._isEnabledGetter = { module.isEnabled }
        self._isEnabledSetter = { module.isEnabled = $0 }
        self._assignedDisplayIDGetter = { module.assignedDisplayID }
        self._assignedDisplayIDSetter = { module.assignedDisplayID = $0 }
        self._activate = { module.activate() }
        self._deactivate = { module.deactivate() }
        self._quickSettingsView = { AnyView(module.quickSettingsView) }
        self._settingsView = { AnyView(module.settingsView) }
    }

    func activate() { _activate() }
    func deactivate() { _deactivate() }
    var quickSettingsView: AnyView { _quickSettingsView() }
    var settingsView: AnyView { _settingsView() }
}

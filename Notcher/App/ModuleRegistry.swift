//
//  ModuleRegistry.swift
//  Notcher
//
//  Central registry for all Notcher modules
//

import Foundation
import Combine
import AppKit

/// Central registry that manages all Notcher modules
final class ModuleRegistry: ObservableObject {
    static let shared = ModuleRegistry()

    @Published private(set) var modules: [AnyNotcherModule] = []

    /// Tracks which notch module is active on each display (displayID -> module)
    @Published private(set) var activeNotchModules: [CGDirectDisplayID: AnyNotcherModule] = [:]

    private var cancellables = Set<AnyCancellable>()

    private init() {}

    /// Register a module with the registry
    func register<M: NotcherModule>(_ module: M) {
        let wrapped = AnyNotcherModule(module)
        modules.append(wrapped)

        // Load saved enabled state
        let enabledKey = "notcher.module.\(wrapped.id).enabled"
        if UserDefaults.standard.object(forKey: enabledKey) != nil {
            wrapped.isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        }

        // If enabled, activate on its assigned display
        if wrapped.isEnabled {
            if wrapped.category == .notch {
                let displayID = wrapped.assignedDisplayID
                // Only activate if no other notch module is on this display
                if activeNotchModules[displayID] == nil {
                    activeNotchModules[displayID] = wrapped
                    wrapped.activate()
                }
            } else if wrapped.category == .effect {
                wrapped.activate()
            }
        }
    }

    /// Get all notch-category modules
    var notchModules: [AnyNotcherModule] {
        modules.filter { $0.category == .notch }
    }

    /// Get all effect-category modules
    var effectModules: [AnyNotcherModule] {
        modules.filter { $0.category == .effect }
    }

    /// Check if a notch module is active (on any display)
    func isNotchModuleActive(_ module: AnyNotcherModule) -> Bool {
        activeNotchModules.values.contains { $0.id == module.id }
    }

    /// Get the display a notch module is currently active on
    func activeDisplayForModule(_ module: AnyNotcherModule) -> CGDirectDisplayID? {
        for (displayID, activeModule) in activeNotchModules {
            if activeModule.id == module.id {
                return displayID
            }
        }
        return nil
    }

    /// Activate a notch module on its assigned display
    /// If another notch module is on that display, it will be deactivated
    func activateNotchModule(_ module: AnyNotcherModule) {
        guard module.category == .notch else { return }

        let targetDisplayID = module.assignedDisplayID

        // If this module is already active on this display, do nothing
        if let existing = activeNotchModules[targetDisplayID], existing.id == module.id {
            return
        }

        // If this module is active on a different display, deactivate it there first
        if let currentDisplayID = activeDisplayForModule(module) {
            activeNotchModules.removeValue(forKey: currentDisplayID)
            module.deactivate()
        }

        // Deactivate any existing module on the target display
        if let existing = activeNotchModules[targetDisplayID], existing.id != module.id {
            existing.deactivate()
            existing.isEnabled = false
            saveModuleState(existing)
        }

        // Activate new module
        activeNotchModules[targetDisplayID] = module
        module.isEnabled = true
        module.activate()
        saveModuleState(module)

        objectWillChange.send()
    }

    /// Deactivate a specific notch module
    func deactivateNotchModule(_ module: AnyNotcherModule) {
        guard module.category == .notch else { return }

        // Find and remove from active modules
        for (displayID, activeModule) in activeNotchModules {
            if activeModule.id == module.id {
                activeNotchModules.removeValue(forKey: displayID)
                break
            }
        }

        module.deactivate()
        module.isEnabled = false
        saveModuleState(module)

        objectWillChange.send()
    }

    /// Toggle a notch module on/off
    func toggleNotchModule(_ module: AnyNotcherModule) {
        if isNotchModuleActive(module) {
            deactivateNotchModule(module)
        } else {
            activateNotchModule(module)
        }
    }

    /// Toggle an effect module
    func toggleEffectModule(_ module: AnyNotcherModule) {
        guard module.category == .effect else { return }

        if module.isEnabled {
            module.deactivate()
            module.isEnabled = false
        } else {
            module.activate()
            module.isEnabled = true
        }
        saveModuleState(module)
    }

    /// Called when a module's display assignment changes
    func moduleDisplayChanged(_ module: AnyNotcherModule, to newDisplayID: CGDirectDisplayID) {
        guard module.category == .notch else { return }

        // If module is currently active, move it to the new display
        if isNotchModuleActive(module) {
            // Remove from old display
            if let oldDisplayID = activeDisplayForModule(module) {
                activeNotchModules.removeValue(forKey: oldDisplayID)
            }

            // Deactivate any existing module on the new display
            if let existing = activeNotchModules[newDisplayID], existing.id != module.id {
                existing.deactivate()
                existing.isEnabled = false
                saveModuleState(existing)
            }

            // Reactivate on new display
            module.deactivate()
            activeNotchModules[newDisplayID] = module
            module.activate()

            objectWillChange.send()
        }
    }

    private func saveModuleState(_ module: AnyNotcherModule) {
        let key = "notcher.module.\(module.id).enabled"
        UserDefaults.standard.set(module.isEnabled, forKey: key)
    }
}

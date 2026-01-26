//
//  ModuleRowView.swift
//  Notcher
//
//  Individual module row in the menu dropdown
//

import SwiftUI

struct ModuleRowView: View {
    @ObservedObject var module: AnyNotcherModule
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                // Icon
                Image(systemName: module.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 24)

                // Name
                Text(module.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                // Expand settings
                if isSelected || module.isEnabled {
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                }

                // Toggle switch for all module types
                Toggle("", isOn: Binding(
                    get: { isSelected },
                    set: { _ in onTap() }
                ))
                .toggleStyle(.switch)
                .scaleEffect(0.7)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }

            // Settings (expandable) - all settings inline, no external window
            if isExpanded && (isSelected || module.isEnabled) {
                VStack(spacing: 8) {
                    module.quickSettingsView
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

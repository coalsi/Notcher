# Notcher

A modular macOS menu bar app that puts useful information in your MacBook's notch area.

Notcher runs as a menu bar app with a unified dropdown menu, inline per-module settings, and full App Store sandbox compliance.

## Modules

### MusicNotch
Displays the currently playing track from Apple Music alongside album artwork in the notch area. Uses MusicKit and the iTunes Search API for artwork — no AppleScript, no permissions prompts. Configurable size presets and text alignment.

### CornerRadius
Adds rounded corner overlays to your screen edges as a visual polish layer. Per-corner toggles, custom sizing, and multi-display support. Runs independently alongside any notch module.

## Features

- **Single menu bar icon** with glassmorphism dropdown
- **Modular architecture** — each module implements `NotcherModule` protocol
- **Multi-display support** — assign modules to different screens
- **Inline quick settings** in the dropdown, plus full settings windows
- **App sandbox** enabled with network-only entitlement
- **Privacy manifest** included (UserDefaults CA92.1)
- **Accessibility labels** on all interactive controls
- **Dark mode aware** menu bar icon (template image)

## Architecture

```swift
protocol NotcherModule: ObservableObject {
    var id: String { get }
    var name: String { get }
    var icon: String { get }
    var category: ModuleCategory { get }  // .notch or .effect
    var isEnabled: Bool { get set }

    func activate()
    func deactivate()

    var quickSettingsView: some View { get }
    var settingsView: some View { get }
}
```

Two categories control behavior:
- **Notch** modules (MusicNotch) — mutually exclusive per display
- **Effect** modules (CornerRadius) — run alongside any notch module

## Requirements

- macOS 12.0 (Monterey) or later
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (generates the Xcode project from `project.yml`)

## Build

```bash
# Generate the Xcode project
xcodegen generate

# Build via command line
xcodebuild -scheme Notcher -configuration Release build

# Or open in Xcode
open Notcher.xcodeproj
```

## Project Structure

```
Notcher/
├── project.yml                  # XcodeGen project definition
└── Notcher/
    ├── App/                     # AppDelegate, ModuleRegistry, MenuBarIcon
    ├── Core/                    # ModuleProtocol, NotchWindow, DisplayManager
    ├── Modules/
    │   ├── MusicNotch/          # Apple Music now-playing display
    │   └── CornerRadius/        # Screen corner overlays
    ├── UI/                      # Shared menu and settings views
    └── PrivacyInfo.xcprivacy    # App privacy manifest
```

## License

MIT

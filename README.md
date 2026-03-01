# Notcher

A modular macOS menu bar app that puts useful information in your MacBook's notch area.

Notcher consolidates multiple notch utilities into a single app with a unified menu bar icon, glassmorphism dropdown, and per-module settings.

## Modules

### Music Notch
Displays the currently playing track from Apple Music alongside album artwork, tucked into the notch area. Configurable size presets, text alignment, and color schemes.

### Claude Stats
Shows your Claude API usage at a glance — session usage, weekly totals, and Opus model efficiency. Supports multiple slots so you can track different metrics simultaneously.

### Corner Radius
Adds rounded corner overlays to your screen edges as a visual polish layer. Runs independently alongside any notch module.

## Features

- **Single menu bar icon** — one app replaces three
- **Modular architecture** — each module implements a shared protocol, making it easy to add new ones
- **Multi-display support** — assign different modules to different screens
- **Per-module quick settings** inline in the dropdown menu
- **Full settings window** with dedicated tabs per module
- **Persistent state** — module assignments, sizes, and preferences survive restarts
- **Glassmorphism UI** — translucent dropdown menu with vibrancy

## Architecture

Modules conform to the `NotcherModule` protocol:

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
- **Notch** modules (Music, Claude Stats) — mutually exclusive per display
- **Effect** modules (Corner Radius) — run alongside any notch module

## Requirements

- macOS 12.0 (Monterey) or later
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (generates the Xcode project from `project.yml`)

## Build

```bash
cd Notcher

# Generate the Xcode project
xcodegen generate

# Build via command line
xcodebuild -scheme Notcher -configuration Release build

# Or open in Xcode
open Notcher.xcodeproj
```

## Usage

Notcher runs as a menu bar app (no Dock icon). After launching:

1. Click the menu bar icon to open the dropdown
2. Toggle modules on/off per display
3. Expand quick settings with the chevron for inline adjustments
4. Open the full settings window for detailed configuration

## Project Structure

```
Notcher/
├── project.yml                  # XcodeGen project definition
└── Notcher/
    ├── App/                     # AppDelegate, ModuleRegistry, MenuBarIcon
    ├── Core/                    # ModuleProtocol, NotchWindow, DisplayManager
    ├── Modules/
    │   ├── MusicNotch/          # Apple Music now-playing display
    │   ├── ClaudeStats/         # Claude API usage tracking
    │   └── CornerRadius/        # Screen corner overlays
    └── UI/                      # Shared menu and settings views
```

## License

MIT

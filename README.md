# KeyGlass

KeyGlass is a Swift-native macOS menu bar utility that reimplements the practical keyboard-visualization workflow of KeyCastr.

## Current Features

- Menu bar utility mode with `LSUIElement`
- Capture enable and disable controls
- Input Monitoring permission checks and requests
- Session event taps for keyboard input and mouse clicks
- Transparent overlay window with fade-out behavior
- Display modes for modifier-only, modified keys, and all keys
- Layout-aware keyboard translation via macOS keyboard layout APIs
- Special key coverage for arrows, return, delete, function keys, and JIS-related keys
- Persistent display settings for position, size, opacity, and timing
- Optional mouse click visualization
- Settings window with built-in preview actions

## Architecture

- `AppCoordinator`
- `SettingsStore`
- `SystemInputPermissionManager`
- `SystemEventTapService`
- `KeystrokeFormatter`
- `OverlayWindowController`
- `SettingsWindowController`

## Development

Build:

```bash
xcodebuild -scheme KeyGlass -project KeyGlass.xcodeproj -destination 'platform=macOS' build
```

Test:

```bash
xcodebuild test -scheme KeyGlass -project KeyGlass.xcodeproj -destination 'platform=macOS' -skip-testing:KeyGlassUITests
```

## Testing Notes

- Hosted AppKit tests in `KeyGlassTests` cover the current user-visible behavior and settings flow.
- The `KeyGlassUITests` target is kept in the project, but its `XCUIApplication` runner hangs in the current CLI environment. The suite is intentionally skipped in the command above, and the hosted UI coverage is the authoritative test path for now.

## Specifications

- English spec: `SPEC.md`
- Japanese spec: `SPEC.ja.md`
- Phase checklist: `TODO.md`

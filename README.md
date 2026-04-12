# KeyGlass

KeyGlass is a Swift-native macOS menu bar utility that reimplements the practical keyboard-visualization workflow of KeyCastr.

## Current Features

- Menu bar utility mode with `LSUIElement`
- Capture enable and disable controls
- Input Monitoring permission checks and requests
- Session event taps for keyboard input and mouse clicks
- Transparent stacked overlay with per-entry fade-out behavior
- Rapid plain-key coalescing into a single visible history entry
- Display modes for modifier-only, modified keys, and all keys
- Layout-aware keyboard translation via macOS keyboard layout APIs
- Special key coverage for arrows, return, delete, function keys, and JIS-related keys
- Persistent display settings for position, size, opacity, and timing
- Persistent history settings for merge window, stack size, and stack direction
- Start-at-login support via macOS login items
- Optional mouse click visualization
- Drag-to-reposition behavior that pauses automatic fade while the overlay is being moved
- Settings window with built-in preview actions

## Architecture

- `AppCoordinator`
- `SettingsStore`
- `SystemInputPermissionManager`
- `SystemEventTapService`
- `SystemLaunchAtLoginManager`
- `KeystrokeFormatter`
- `OverlayWindowController`
- `SettingsWindowController`

## Tooling

This repository uses `mise` to pin the CLI tools used for linting and formatting.

```bash
brew install mise
mise trust
mise install
```

## Development

Build:

```bash
xcodebuild -scheme KeyGlass -project KeyGlass.xcodeproj -destination 'platform=macOS' build
```

Test:

```bash
xcodebuild test -scheme KeyGlass -project KeyGlass.xcodeproj -destination 'platform=macOS' -skip-testing:KeyGlassUITests
```

Format:

```bash
mise exec -- swiftformat .
```

Lint:

```bash
mise exec -- swiftformat --lint .
mise exec -- swiftlint lint --quiet
```

UI test attempt:

```bash
xcodebuild test KEYGLASS_LSUIELEMENT=NO -scheme KeyGlass -project KeyGlass.xcodeproj -destination 'platform=macOS' -only-testing:KeyGlassUITests
```

## Testing Notes

- Hosted AppKit tests in `KeyGlassTests` cover the current user-visible behavior and settings flow.
- Hosted coverage now includes rapid-input merge, stack trimming, and drag-paused fade behavior.
- The `KeyGlassUITests` target has been expanded for the new history controls and merge behavior, but it still needs a non-agent build (`KEYGLASS_LSUIELEMENT=NO`) and remains unstable in this CLI environment.

## Specifications

- English spec: `SPEC.md`
- Japanese spec: `SPEC.ja.md`
- Phase checklist: `TODO.md`

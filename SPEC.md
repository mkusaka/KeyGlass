# KeyGlass Specification

## Summary

KeyGlass is a native macOS menu bar utility written in Swift that reimplements the core keyboard visualization behavior of KeyCastr.

This project is not intended to be a line-by-line port of the existing Objective-C codebase. The goal is to preserve the important user-facing behavior while rebuilding the app with a modern Swift architecture that is easier to maintain and extend.

## Goals

- Build a stable Swift-based replacement for the core KeyCastr experience.
- Run as a lightweight menu bar app instead of a regular dock app.
- Capture keyboard events reliably with the correct macOS permissions model.
- Render keystrokes in a transparent, unobtrusive on-screen overlay.
- Prioritize correctness of displayed text, especially for modifiers, special keys, and non-US keyboard layouts.
- Ship a focused v1 before pursuing full feature parity.

## Final Product Scope

The intended final scope of KeyGlass is a native macOS menu bar utility that covers the practical day-to-day use cases of KeyCastr's default built-in experience without copying its legacy implementation model.

### Capture Scope

- Capture keyboard input through listen-only session event taps.
- Support `keyDown` and `flagsChanged` as first-class inputs.
- Detect and surface missing permission states clearly.
- Recover cleanly when taps are disabled or invalidated.
- Respect secure input limitations instead of trying to bypass them.

### Display Scope

- Show modifier-only events.
- Show combined keystrokes.
- Render common special keys using macOS-style glyphs.
- Render function keys and extended special keys.
- Support transparent overlay presentation with fade-out behavior.
- Support queueing or coalescing behavior so rapid keystrokes remain readable.
- Support configurable overlay position, size, opacity, and visual style.
- Support display behavior that works across Spaces and normal presentation scenarios.

### Formatting Scope

- Translate events into correct output for the active keyboard layout.
- Track input source changes and refresh formatter state accordingly.
- Support non-US layouts, including JIS-specific behavior where practical.
- Avoid relying on US-only key maps for final display behavior.
- Format keystrokes in a way that is recognizable to existing KeyCastr users even if the internal code structure is different.

### App Scope

- Run as a menu bar utility using `LSUIElement`.
- Provide menu bar controls for enabling and disabling capture.
- Provide a settings UI for overlay behavior and display modes.
- Persist core user settings such as enabled state, overlay configuration, and display mode.
- Keep runtime responsibilities separated into coordinator, permission, capture, formatting, overlay, and persistence layers.

### Extended Feature Scope

- Support multiple display modes similar to KeyCastr's practical modes, such as modifier-only, modified keys, or all keys.
- Add basic mouse click visualization after the keyboard experience is stable.
- Add launch-at-login and related utility-app polish if it materially improves daily usability.

## Release Scope Breakdown

### V1 Scope

- Menu bar app shell.
- Permission check and request flow.
- Listen-only keyboard event tap.
- Capture state that can be toggled on and off.
- Transparent overlay window.
- Automatic fade-out after a short delay.
- Modifier-only display.
- Combined keystroke display.
- Common special key mapping for arrows, escape, return, delete, tab, and space.
- Keyboard-only implementation with no mouse visualization.

### V1.1 Scope

- Overlay position persistence.
- Basic appearance controls such as size, opacity, and timing.
- Better display queueing or coalescing for rapid input.
- Display mode selection such as modifier-only, modified keys, or all keys.
- Better menu bar controls and clearer disabled or permission-missing states.

### V2 Scope

- Input source tracking.
- Layout-aware translation using macOS keyboard layout APIs.
- Improved support for JIS and other non-US layouts.
- Expanded special key coverage including function keys and less common keys.
- Basic mouse click visualization.
- Better multi-display behavior and overlay placement policy.

### Final Parity Target

- Functional parity with the default KeyCastr usage model for keyboard visualization.
- Functional parity for the default overlay experience, not binary compatibility with the old app.
- Equivalent user-facing behavior for common capture modes.
- Equivalent user-facing behavior for layout-aware key display.
- Basic mouse visualization if it proves useful enough to keep.

## Target Parity Definition

For this project, "parity" means user-facing functional equivalence for the default built-in visualization workflow. It does not mean matching upstream source structure, plugin APIs, preference formats, or every historical feature one-to-one.

KeyGlass should be considered successful when a presenter can use it in place of KeyCastr for normal keyboard visualization on modern macOS and get comparably correct, readable, and unobtrusive output.

## Non-Goals For V1

- Full feature parity with upstream KeyCastr.
- Visualizer plugin architecture.
- Mouse click and drag visualization.
- Importing existing KeyCastr preferences.
- Auto-update, analytics, cloud sync, or other distribution features.
- Advanced theming beyond what is needed for a usable overlay.

## Permanently Out Of Scope

- Rewriting the upstream Objective-C project line-by-line in Swift.
- Loading legacy KeyCastr visualizer plugins.
- Maintaining compatibility with upstream preference files or bundle structure.
- Capturing, storing, or replaying raw keystroke history.
- Bypassing secure input or attempting to expose protected password entry.
- Adding cloud sync, analytics, account systems, or service-backed features.
- Expanding the product into a general automation or macro tool.

## Target Platform

- Native macOS application.
- Menu bar utility using `LSUIElement`.
- Initial implementation target is macOS 13 or later.
- Core runtime uses AppKit, CoreGraphics, and ApplicationServices.
- SwiftUI may be used for settings and lightweight UI, but event capture and overlay management should remain AppKit-driven.

## Product Requirements

### Core Behavior

- The app launches into the menu bar and stays resident.
- The app can be enabled or disabled from the menu bar UI.
- The app checks and requests the required input-listening permissions.
- The app captures `keyDown` and `flagsChanged` events via listen-only session event taps.
- The app displays modifier-only input such as `Command`, `Shift`, `Option`, and `Control`.
- The app displays combined keystrokes such as `⌘K`, `⌥⇧2`, or arrow keys.
- The app renders output in a transparent overlay window above normal app content.
- The overlay fades out automatically after a short delay.

### Privacy And Safety

- The app must not persist raw captured keystrokes.
- The app should respect secure input behavior and accept that some protected input cannot be captured or displayed.
- The app should fail clearly when permissions are missing instead of pretending capture is active.

### Display Correctness

- Modifier glyphs must match macOS conventions.
- Special keys such as arrows, escape, return, delete, tab, and space must be rendered explicitly.
- The formatter must eventually support layout-aware translation for the active keyboard input source.
- US-only keycode tables and `charactersIgnoringModifiers` alone are not sufficient for the final implementation.

## Architecture

The app should be structured around the following responsibilities:

- `AppCoordinator`
  Owns application lifecycle, status item wiring, capture state, and high-level coordination.
- `PermissionManager`
  Checks and requests Input Monitoring or Accessibility access as required by the running macOS version.
- `EventTapService`
  Installs, starts, stops, and monitors event taps for keyboard events.
- `KeystrokeFormatter`
  Converts captured events into display strings, including modifier glyphs, special key symbols, and layout-aware translation.
- `OverlayWindowController`
  Manages the borderless overlay window, text updates, animation, and screen positioning.
- `SettingsStore`
  Persists user-facing configuration such as overlay position, size, opacity, and enabled state.

## Implementation Principles

- Start with the smallest working keyboard-only version.
- Keep permission handling separate from event capture logic.
- Keep event capture separate from formatting logic.
- Keep formatting separate from rendering logic.
- Prefer clear service boundaries over large view-driven code paths.
- Optimize for reliability and debuggability before polishing secondary features.

## Milestones

### Milestone 1: Working Scaffold

- Menu bar app shell.
- Permission check and request flow.
- Listen-only keyboard event tap.
- Basic transparent overlay window.
- Raw keystroke display sufficient to prove end-to-end capture.

### Milestone 2: MVP

- Modifier-only display.
- Special key symbol mapping.
- Fade timing and queueing behavior.
- Overlay positioning and basic persistence.
- Status item controls for enabling and disabling capture.

### Milestone 3: Display Correctness

- Active input source tracking.
- Layout-aware translation using macOS keyboard layout APIs.
- Better coverage for JIS and other non-US layouts.
- Formatter behavior closer to KeyCastr expectations.

### Milestone 4: Post-V1 Expansion

- Mouse event visualization.
- Additional style customization.
- More advanced settings UI.
- Future evaluation of plugin-style visualizers if needed.

## Testing Strategy

- Build verification with `xcodebuild`.
- Unit tests for formatter behavior and event-to-display reduction.
- Manual verification for permission flows and failure states.
- Manual verification across multiple keyboard layouts.
- Manual verification across Spaces, full-screen apps, and overlay z-order behavior.

## Open Questions

- Whether macOS 13 remains the minimum supported version or should be raised.
- How much settings UI should be included in v1.
- Whether mouse visualization should remain part of the final parity target or stay optional.
- Which multi-display policy is least surprising for presenters.
- How the app should be signed and distributed once the MVP is stable.

# KeyGlass TODO

## Rules

- Complete one scoped implementation batch at a time.
- After each implementation batch, add or update UI tests.
- Run the relevant tests immediately.
- Do not move to the next batch until tests pass.
- Commit after each completed batch.

## Phase 0: Specification And Delivery Setup

- [x] Write the English spec in `SPEC.md`.
- [x] Write the Japanese spec in `SPEC.ja.md`.
- [x] Commit the spec and TODO baseline.

## Phase 1: Menu Bar Shell And Keyboard Overlay MVP

- [x] Convert the app into a menu bar utility with `LSUIElement`.
- [x] Add a shared app coordinator and app container.
- [x] Add a settings window that can be opened programmatically.
- [x] Add a menu bar menu with capture toggle, settings entry, permission action, and quit action.
- [x] Add a permission manager abstraction for production and test modes.
- [x] Add an event tap service abstraction for production and test modes.
- [x] Add a basic overlay window controller.
- [x] Add a keystroke formatter for modifier glyphs, plain keys, and common special keys.
- [x] Connect capture state to permission checking and event tap lifecycle.
- [x] Add UI-test launch handling so the settings window opens automatically in UI tests.
- [x] Add UI tests for settings window launch, capture toggle, permission state, and preview flow.
- [x] Run Phase 1 tests and fix failures.
- [x] Commit Phase 1.

## Phase 1.1: Settings, Persistence, And Display Modes

- [x] Add a persistent settings store for enabled state and overlay configuration.
- [x] Add overlay position options and persistence.
- [x] Add font size, opacity, fade delay, and fade duration controls.
- [x] Add display mode selection for modifier-only, modified keys, and all keys.
- [x] Add preview actions for representative keystrokes.
- [x] Reflect settings changes in overlay behavior.
- [x] Add UI tests for persistence-backed settings and display mode changes.
- [x] Run Phase 1.1 tests and fix failures.
- [x] Commit Phase 1.1.

## Phase 2: Layout-Aware Formatting And Input Source Handling

- [x] Add active keyboard layout loading.
- [x] Add layout-aware character translation with macOS keyboard layout APIs.
- [x] Add input source change observation and formatter refresh.
- [x] Expand special-key coverage including function keys and JIS-related keys where available.
- [x] Add unit tests for formatter behavior across representative inputs.
- [x] Add UI tests that cover the user-visible results of formatter preview scenarios.
- [x] Run Phase 2 tests and fix failures.
- [x] Commit Phase 2.

## Phase 3: Mouse Visualization And Multi-Display Behavior

- [x] Add basic mouse click visualization events.
- [x] Extend overlay presentation to handle mouse output.
- [x] Improve overlay placement policy for multi-display setups.
- [x] Add settings coverage for mouse visualization behavior if needed.
- [x] Add UI tests for mouse preview behavior and overlay-related settings.
- [x] Run Phase 3 tests and fix failures.
- [x] Commit Phase 3.

## Phase 4: Final Cleanup And Verification

- [x] Remove template code that is no longer needed.
- [x] Ensure the README reflects the current project state.
- [x] Run the full test suite.
- [x] Run a final build verification.
- [x] Commit the final cleanup.

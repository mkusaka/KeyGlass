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

- [ ] Convert the app into a menu bar utility with `LSUIElement`.
- [ ] Add a shared app coordinator and app container.
- [ ] Add a settings window that can be opened programmatically.
- [ ] Add a menu bar menu with capture toggle, settings entry, permission action, and quit action.
- [ ] Add a permission manager abstraction for production and test modes.
- [ ] Add an event tap service abstraction for production and test modes.
- [ ] Add a basic overlay window controller.
- [ ] Add a keystroke formatter for modifier glyphs, plain keys, and common special keys.
- [ ] Connect capture state to permission checking and event tap lifecycle.
- [ ] Add UI-test launch handling so the settings window opens automatically in UI tests.
- [ ] Add UI tests for settings window launch, capture toggle, permission state, and preview flow.
- [ ] Run Phase 1 tests and fix failures.
- [ ] Commit Phase 1.

## Phase 1.1: Settings, Persistence, And Display Modes

- [ ] Add a persistent settings store for enabled state and overlay configuration.
- [ ] Add overlay position options and persistence.
- [ ] Add font size, opacity, fade delay, and fade duration controls.
- [ ] Add display mode selection for modifier-only, modified keys, and all keys.
- [ ] Add preview actions for representative keystrokes.
- [ ] Reflect settings changes in overlay behavior.
- [ ] Add UI tests for persistence-backed settings and display mode changes.
- [ ] Run Phase 1.1 tests and fix failures.
- [ ] Commit Phase 1.1.

## Phase 2: Layout-Aware Formatting And Input Source Handling

- [ ] Add active keyboard layout loading.
- [ ] Add layout-aware character translation with macOS keyboard layout APIs.
- [ ] Add input source change observation and formatter refresh.
- [ ] Expand special-key coverage including function keys and JIS-related keys where available.
- [ ] Add unit tests for formatter behavior across representative inputs.
- [ ] Add UI tests that cover the user-visible results of formatter preview scenarios.
- [ ] Run Phase 2 tests and fix failures.
- [ ] Commit Phase 2.

## Phase 3: Mouse Visualization And Multi-Display Behavior

- [ ] Add basic mouse click visualization events.
- [ ] Extend overlay presentation to handle mouse output.
- [ ] Improve overlay placement policy for multi-display setups.
- [ ] Add settings coverage for mouse visualization behavior if needed.
- [ ] Add UI tests for mouse preview behavior and overlay-related settings.
- [ ] Run Phase 3 tests and fix failures.
- [ ] Commit Phase 3.

## Phase 4: Final Cleanup And Verification

- [ ] Remove template code that is no longer needed.
- [ ] Ensure the README reflects the current project state.
- [ ] Run the full test suite.
- [ ] Run a final build verification.
- [ ] Commit the final cleanup.

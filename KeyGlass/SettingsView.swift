import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                captureSection
                diagnosticsSection
                displaySection
                previewSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 520, minHeight: 420)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("KeyGlass")
                .font(.largeTitle.bold())

            Text("Swift-native KeyCastr-style keyboard visualizer for macOS")
                .foregroundStyle(.secondary)

            if coordinator.shouldShowUITestBanner {
                Text("UI Test Mode")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.15), in: Capsule())
                    .accessibilityIdentifier("ui-test-mode-badge")
            }
        }
    }

    private var captureSection: some View {
        GroupBox("Capture") {
            VStack(alignment: .leading, spacing: 14) {
                statusRow(title: "Permission", value: coordinator.permissionDescription, identifier: "permission-state-value")
                statusRow(title: "Status", value: coordinator.captureStatusDescription, identifier: "capture-status-value")

                Toggle(
                    "Enable Capture",
                    isOn: Binding(
                        get: { settingsStore.captureEnabled },
                        set: { coordinator.toggleCaptureEnabled($0) }
                    )
                )
                .accessibilityIdentifier("capture-enabled-toggle")

                statusRow(
                    title: "Start at Login",
                    value: coordinator.launchAtLoginDescription,
                    identifier: "launch-at-login-state-value"
                )

                Toggle(
                    "Start at Login",
                    isOn: Binding(
                        get: { coordinator.isLaunchAtLoginEnabled },
                        set: { coordinator.toggleLaunchAtLogin($0) }
                    )
                )
                .disabled(coordinator.launchAtLoginState == .unavailable)
                .accessibilityIdentifier("launch-at-login-toggle")

                if let launchAtLoginHint = coordinator.launchAtLoginHint {
                    Text(launchAtLoginHint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(launchAtLoginHint)
                        .accessibilityValue(launchAtLoginHint)
                        .accessibilityIdentifier("launch-at-login-hint")
                }

                Button(coordinator.permissionActionTitle) {
                    coordinator.performPermissionAction()
                }
                .accessibilityIdentifier("request-permission-button")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var diagnosticsSection: some View {
        GroupBox("Diagnostics") {
            VStack(alignment: .leading, spacing: 12) {
                diagnosticValue(title: "Last Live Event", value: coordinator.liveCaptureDiagnostics.lastEventSummary, identifier: "live-last-event-value")
                statusRow(title: "Live KeyDown Count", value: String(coordinator.liveCaptureDiagnostics.keyDownCount), identifier: "live-keydown-count-value")
                statusRow(title: "Live Modifier Count", value: String(coordinator.liveCaptureDiagnostics.modifierEventCount), identifier: "live-modifier-count-value")
                statusRow(title: "Live Mouse Count", value: String(coordinator.liveCaptureDiagnostics.mouseClickCount), identifier: "live-mouse-count-value")

                if let liveCaptureHint = coordinator.liveCaptureHint {
                    Text(liveCaptureHint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(liveCaptureHint)
                        .accessibilityValue(liveCaptureHint)
                        .accessibilityIdentifier("live-capture-hint")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var previewSection: some View {
        GroupBox("Preview") {
            VStack(alignment: .leading, spacing: 12) {
                Text(coordinator.lastPresentedText)
                    .font(.title3.monospaced())
                    .accessibilityLabel(coordinator.lastPresentedText)
                    .accessibilityValue(coordinator.lastPresentedText)
                    .accessibilityIdentifier("last-output-value")

                HStack {
                    Button("Preview A") {
                        coordinator.previewPlainA()
                    }
                    .accessibilityIdentifier("preview-a-button")

                    Button("Preview Command-K") {
                        coordinator.previewCommandK()
                    }
                    .accessibilityIdentifier("preview-command-k-button")

                    Button("Preview Shift-Tab") {
                        coordinator.previewShiftTab()
                    }
                    .accessibilityIdentifier("preview-shift-tab-button")

                    Button("Preview Shift") {
                        coordinator.previewModifierOnly()
                    }
                    .accessibilityIdentifier("preview-shift-button")

                    Button("Preview Left Click") {
                        coordinator.previewLeftClick()
                    }
                    .accessibilityIdentifier("preview-left-click-button")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var displaySection: some View {
        GroupBox("Display") {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Display Mode", selection: $settingsStore.displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .accessibilityIdentifier("display-mode-picker")

                Picker("Overlay Position", selection: $settingsStore.overlayAnchor) {
                    ForEach(OverlayAnchor.allCases) { anchor in
                        Text(anchor.title).tag(anchor)
                    }
                }
                .accessibilityIdentifier("overlay-anchor-picker")

                Button("Reset Overlay Position") {
                    settingsStore.resetCustomOverlayOrigin()
                }
                .accessibilityIdentifier("reset-overlay-position-button")

                Toggle("Show Mouse Clicks", isOn: $settingsStore.showMouseClicks)
                    .accessibilityIdentifier("show-mouse-clicks-toggle")

                settingSlider(
                    title: "Font Size",
                    value: $settingsStore.overlayFontSize,
                    range: 16 ... 40,
                    identifier: "font-size-slider"
                )

                settingSlider(
                    title: "Opacity",
                    value: $settingsStore.overlayOpacity,
                    range: 0.4 ... 1.0,
                    step: 0.05,
                    identifier: "opacity-slider"
                )

                settingSlider(
                    title: "Fade Delay",
                    value: $settingsStore.fadeDelay,
                    range: 0.2 ... 2.5,
                    step: 0.1,
                    identifier: "fade-delay-slider"
                )

                settingSlider(
                    title: "Fade Duration",
                    value: $settingsStore.fadeDuration,
                    range: 0.1 ... 1.0,
                    step: 0.05,
                    identifier: "fade-duration-slider"
                )

                settingSlider(
                    title: "Merge Window",
                    value: $settingsStore.overlayMergeWindow,
                    range: 0.1 ... 1.5,
                    step: 0.05,
                    identifier: "merge-window-slider",
                    valueIdentifier: "merge-window-value"
                )

                settingStepper(
                    title: "Stack Size",
                    value: $settingsStore.overlayStackMaxCount,
                    range: 1 ... 10,
                    identifier: "stack-max-count-stepper",
                    valueIdentifier: "stack-max-count-value"
                )

                Picker("Stack Direction", selection: $settingsStore.overlayStackDirection) {
                    ForEach(OverlayStackDirection.allCases) { direction in
                        Text(direction.title).tag(direction)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("stack-direction-picker")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statusRow(title: String, value: String, identifier: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .monospaced()
                .accessibilityLabel(value)
                .accessibilityValue(value)
                .accessibilityIdentifier(identifier)
        }
    }

    private func diagnosticValue(title: String, value: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body.monospaced())
                .textSelection(.enabled)
                .accessibilityLabel(value)
                .accessibilityValue(value)
                .accessibilityIdentifier(identifier)
        }
    }

    private func settingSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1,
        identifier: String,
        valueIdentifier: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .foregroundStyle(.secondary)

                Spacer()

                if let valueIdentifier {
                    Text(value.wrappedValue, format: .number.precision(.fractionLength(2)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(valueIdentifier)
                } else {
                    Text(value.wrappedValue, format: .number.precision(.fractionLength(2)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Slider(value: value, in: range, step: step)
                .accessibilityIdentifier(identifier)
        }
    }

    private func settingStepper(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        identifier: String,
        valueIdentifier: String
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(String(value.wrappedValue))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(valueIdentifier)

            Stepper("", value: value, in: range)
                .labelsHidden()
                .accessibilityIdentifier(identifier)
        }
    }
}

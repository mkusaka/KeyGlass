import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                captureSection
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

                Button("Request Permission") {
                    coordinator.requestPermission()
                }
                .accessibilityIdentifier("request-permission-button")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var previewSection: some View {
        GroupBox("Preview") {
            VStack(alignment: .leading, spacing: 12) {
                Text(coordinator.lastPresentedText)
                    .font(.title3.monospaced())
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

                settingSlider(
                    title: "Font Size",
                    value: $settingsStore.overlayFontSize,
                    range: 18...48,
                    identifier: "font-size-slider"
                )

                settingSlider(
                    title: "Opacity",
                    value: $settingsStore.overlayOpacity,
                    range: 0.4...1.0,
                    step: 0.05,
                    identifier: "opacity-slider"
                )

                settingSlider(
                    title: "Fade Delay",
                    value: $settingsStore.fadeDelay,
                    range: 0.2...2.5,
                    step: 0.1,
                    identifier: "fade-delay-slider"
                )

                settingSlider(
                    title: "Fade Duration",
                    value: $settingsStore.fadeDuration,
                    range: 0.1...1.0,
                    step: 0.05,
                    identifier: "fade-duration-slider"
                )
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
                .accessibilityIdentifier(identifier)
        }
    }

    private func settingSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(value.wrappedValue, format: .number.precision(.fractionLength(2)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: range, step: step)
                .accessibilityIdentifier(identifier)
        }
    }
}

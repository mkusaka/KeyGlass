import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                captureSection
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
}

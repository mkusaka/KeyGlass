import AppKit
import XCTest
@testable import KeyGlass

@MainActor
final class KeyGlassHostedUITests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        let suiteName = "KeyGlassHostedUITests"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.synchronize()
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: "KeyGlassHostedUITests")
        defaults = nil

        NSApp.windows
            .filter { $0.title == "KeyGlass" }
            .forEach { window in
                window.close()
            }
    }

    func testSettingsWindowOpensFromCoordinator() {
        let coordinator = makeCoordinator()

        coordinator.openSettings()

        let settingsWindow = NSApp.windows.first { $0.title == "KeyGlass" }
        XCTAssertNotNil(settingsWindow)
        XCTAssertEqual(settingsWindow?.title, "KeyGlass")
        XCTAssertTrue(settingsWindow?.isVisible ?? false)
    }

    func testCaptureToggleTransitionsBetweenStoppedAndRunning() {
        let coordinator = makeCoordinator()

        coordinator.toggleCaptureEnabled(true)
        XCTAssertEqual(coordinator.captureStatusDescription, "Running")

        coordinator.toggleCaptureEnabled(false)
        XCTAssertEqual(coordinator.captureStatusDescription, "Stopped")
    }

    func testPreviewActionsUpdatePresentedText() {
        let overlayPresenter = RecordingOverlayPresenter()
        let coordinator = makeCoordinator(overlayPresenter: overlayPresenter)

        coordinator.previewCommandK()
        XCTAssertEqual(coordinator.lastPresentedText, "⌘K")
        XCTAssertEqual(overlayPresenter.lastText, "⌘K")

        coordinator.previewShiftTab()
        XCTAssertEqual(coordinator.lastPresentedText, "⇧⇥")
        XCTAssertEqual(overlayPresenter.lastText, "⇧⇥")

        coordinator.previewModifierOnly()
        XCTAssertEqual(coordinator.lastPresentedText, "⇧")
        XCTAssertEqual(overlayPresenter.lastText, "⇧")
    }

    func testPermissionRequiredStatePreventsCaptureStart() {
        let settingsStore = SettingsStore(defaults: defaults)
        let coordinator = AppCoordinator(
            launchConfiguration: LaunchConfiguration(
                isUITestMode: true,
                shouldOpenSettingsOnLaunch: false,
                shouldResetDefaults: false,
                defaultsSuiteName: "KeyGlassHostedUITests"
            ),
            settingsStore: settingsStore,
            permissionManager: StubInputPermissionManager(state: .requiresApproval),
            eventTapService: NoOpEventTapService(),
            formatter: KeystrokeFormatter(),
            overlayWindowController: RecordingOverlayPresenter()
        )

        coordinator.toggleCaptureEnabled(true)

        XCTAssertEqual(coordinator.permissionDescription, "Input Monitoring required")
        XCTAssertEqual(coordinator.captureStatusDescription, "Permission required")
    }

    private func makeCoordinator(overlayPresenter: RecordingOverlayPresenter = RecordingOverlayPresenter()) -> AppCoordinator {
        AppCoordinator(
            launchConfiguration: LaunchConfiguration(
                isUITestMode: true,
                shouldOpenSettingsOnLaunch: false,
                shouldResetDefaults: false,
                defaultsSuiteName: "KeyGlassHostedUITests"
            ),
            settingsStore: SettingsStore(defaults: defaults),
            permissionManager: StubInputPermissionManager(state: .granted),
            eventTapService: NoOpEventTapService(),
            formatter: KeystrokeFormatter(),
            overlayWindowController: overlayPresenter
        )
    }
}

private final class RecordingOverlayPresenter: OverlayPresenting {
    private(set) var lastText: String?

    func show(text: String, settings: OverlayPresentationSettings) {
        lastText = text
    }
}

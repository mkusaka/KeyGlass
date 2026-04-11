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

        let deadline = Date().addingTimeInterval(1)
        var settingsWindow = visibleSettingsWindow()

        while settingsWindow == nil, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
            settingsWindow = visibleSettingsWindow()
        }

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

    func testEnablingCaptureRequestsPermissionWhenApprovalIsMissing() {
        let permissionManager = TrackingPermissionManager(state: .requiresApproval)
        let settingsStore = SettingsStore(defaults: defaults)
        let coordinator = AppCoordinator(
            launchConfiguration: LaunchConfiguration(
                isUITestMode: false,
                shouldOpenSettingsOnLaunch: false,
                shouldResetDefaults: false,
                defaultsSuiteName: "KeyGlassHostedUITests"
            ),
            settingsStore: settingsStore,
            permissionManager: permissionManager,
            eventTapService: NoOpEventTapService(),
            formatter: KeystrokeFormatter(),
            overlayWindowController: RecordingOverlayPresenter()
        )

        coordinator.toggleCaptureEnabled(true)

        XCTAssertTrue(settingsStore.captureEnabled)
        XCTAssertEqual(permissionManager.requestCount, 1)
        XCTAssertTrue(settingsStore.hasPromptedForInputMonitoring)
        XCTAssertEqual(coordinator.captureStatusDescription, "Permission required")
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

    func testDisplayModeFiltersPlainPreviewAndAllowsModifiedShortcut() {
        let overlayPresenter = RecordingOverlayPresenter()
        let settingsStore = SettingsStore(defaults: defaults)
        settingsStore.displayMode = .modifiedKeys

        let coordinator = AppCoordinator(
            launchConfiguration: LaunchConfiguration(
                isUITestMode: true,
                shouldOpenSettingsOnLaunch: false,
                shouldResetDefaults: false,
                defaultsSuiteName: "KeyGlassHostedUITests"
            ),
            settingsStore: settingsStore,
            permissionManager: StubInputPermissionManager(state: .granted),
            eventTapService: NoOpEventTapService(),
            formatter: KeystrokeFormatter(),
            overlayWindowController: overlayPresenter
        )

        coordinator.previewPlainA()
        XCTAssertEqual(coordinator.lastPresentedText, "No input yet")
        XCTAssertNil(overlayPresenter.lastText)

        coordinator.previewCommandK()
        XCTAssertEqual(coordinator.lastPresentedText, "⌘K")
        XCTAssertEqual(overlayPresenter.lastText, "⌘K")
    }

    func testSettingsPersistAcrossStoreInstances() {
        let settingsStore = SettingsStore(defaults: defaults)
        settingsStore.displayMode = .modifierOnly
        settingsStore.overlayAnchor = .bottomRight
        settingsStore.overlayFontSize = 33
        settingsStore.overlayOpacity = 0.75
        settingsStore.fadeDelay = 1.8
        settingsStore.fadeDuration = 0.35
        settingsStore.showMouseClicks = true

        let reloadedStore = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloadedStore.displayMode, .modifierOnly)
        XCTAssertEqual(reloadedStore.overlayAnchor, .bottomRight)
        XCTAssertEqual(reloadedStore.overlayFontSize, 33, accuracy: 0.001)
        XCTAssertEqual(reloadedStore.overlayOpacity, 0.75, accuracy: 0.001)
        XCTAssertEqual(reloadedStore.fadeDelay, 1.8, accuracy: 0.001)
        XCTAssertEqual(reloadedStore.fadeDuration, 0.35, accuracy: 0.001)
        XCTAssertTrue(reloadedStore.showMouseClicks)
    }

    func testDefaultDisplayModeShowsAllKeys() {
        let settingsStore = SettingsStore(defaults: defaults)

        XCTAssertEqual(settingsStore.displayMode, .allKeys)
    }

    func testOverlaySettingsFlowIntoPresenter() throws {
        let overlayPresenter = RecordingOverlayPresenter()
        let settingsStore = SettingsStore(defaults: defaults)
        settingsStore.overlayAnchor = .bottomLeft
        settingsStore.overlayFontSize = 42
        settingsStore.overlayOpacity = 0.7
        settingsStore.fadeDelay = 2.0
        settingsStore.fadeDuration = 0.4

        let coordinator = AppCoordinator(
            launchConfiguration: LaunchConfiguration(
                isUITestMode: true,
                shouldOpenSettingsOnLaunch: false,
                shouldResetDefaults: false,
                defaultsSuiteName: "KeyGlassHostedUITests"
            ),
            settingsStore: settingsStore,
            permissionManager: StubInputPermissionManager(state: .granted),
            eventTapService: NoOpEventTapService(),
            formatter: KeystrokeFormatter(),
            overlayWindowController: overlayPresenter
        )

        coordinator.previewCommandK()

        XCTAssertEqual(overlayPresenter.lastText, "⌘K")
        let lastSettings = try XCTUnwrap(overlayPresenter.lastSettings)
        XCTAssertEqual(lastSettings.overlayAnchor, .bottomLeft)
        XCTAssertEqual(lastSettings.overlayFontSize, 42, accuracy: 0.001)
        XCTAssertEqual(lastSettings.overlayOpacity, 0.7, accuracy: 0.001)
        XCTAssertEqual(lastSettings.fadeDelay, 2.0, accuracy: 0.001)
        XCTAssertEqual(lastSettings.fadeDuration, 0.4, accuracy: 0.001)
    }

    func testTranslatedPreviewUsesFormatterTranslation() {
        let overlayPresenter = RecordingOverlayPresenter()
        let formatter = KeystrokeFormatter(translator: StubKeyTranslator(values: [0: "あ"]))
        let settingsStore = SettingsStore(defaults: defaults)
        settingsStore.displayMode = .allKeys
        let coordinator = AppCoordinator(
            launchConfiguration: LaunchConfiguration(
                isUITestMode: true,
                shouldOpenSettingsOnLaunch: false,
                shouldResetDefaults: false,
                defaultsSuiteName: "KeyGlassHostedUITests"
            ),
            settingsStore: settingsStore,
            permissionManager: StubInputPermissionManager(state: .granted),
            eventTapService: NoOpEventTapService(),
            formatter: formatter,
            overlayWindowController: overlayPresenter
        )

        coordinator.previewPlainA()

        XCTAssertEqual(coordinator.lastPresentedText, "あ")
        XCTAssertEqual(overlayPresenter.lastText, "あ")
    }

    func testOverlayWindowShowsWithoutBecomingKey() throws {
        let overlayWindowController = OverlayWindowController()
        let settingsStore = SettingsStore(defaults: defaults)
        settingsStore.displayMode = .allKeys
        let coordinator = AppCoordinator(
            launchConfiguration: LaunchConfiguration(
                isUITestMode: true,
                shouldOpenSettingsOnLaunch: false,
                shouldResetDefaults: false,
                defaultsSuiteName: "KeyGlassHostedUITests"
            ),
            settingsStore: settingsStore,
            permissionManager: StubInputPermissionManager(state: .granted),
            eventTapService: NoOpEventTapService(),
            formatter: KeystrokeFormatter(),
            overlayWindowController: overlayWindowController
        )

        coordinator.previewCommandK()

        let window = try XCTUnwrap(overlayWindowController.testingWindow)
        XCTAssertTrue(window.isVisible)
        XCTAssertFalse(window.canBecomeKey)
        XCTAssertFalse(window.canBecomeMain)
    }

    func testFirstLaunchPermissionFlowRequestsAccessOnce() {
        let permissionManager = TrackingPermissionManager(state: .requiresApproval)
        let settingsStore = SettingsStore(defaults: defaults)
        let coordinator = AppCoordinator(
            launchConfiguration: LaunchConfiguration(
                isUITestMode: false,
                shouldOpenSettingsOnLaunch: false,
                shouldResetDefaults: false,
                defaultsSuiteName: "KeyGlassHostedUITests"
            ),
            settingsStore: settingsStore,
            permissionManager: permissionManager,
            eventTapService: NoOpEventTapService(),
            formatter: KeystrokeFormatter(),
            overlayWindowController: RecordingOverlayPresenter()
        )

        coordinator.applicationDidFinishLaunching()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))

        XCTAssertEqual(permissionManager.requestCount, 1)
        XCTAssertTrue(settingsStore.hasPromptedForInputMonitoring)
        XCTAssertTrue(settingsStore.captureEnabled)
        XCTAssertEqual(coordinator.captureStatusDescription, "Permission required")
    }

    func testDraggedOverlayPositionPersistsThroughMoveCallback() throws {
        let settingsStore = SettingsStore(defaults: defaults)
        let overlayWindowController = OverlayWindowController()
        let coordinator = AppCoordinator(
            launchConfiguration: LaunchConfiguration(
                isUITestMode: true,
                shouldOpenSettingsOnLaunch: false,
                shouldResetDefaults: false,
                defaultsSuiteName: "KeyGlassHostedUITests"
            ),
            settingsStore: settingsStore,
            permissionManager: StubInputPermissionManager(state: .granted),
            eventTapService: NoOpEventTapService(),
            formatter: KeystrokeFormatter(),
            overlayWindowController: overlayWindowController
        )

        coordinator.previewCommandK()

        let window = try XCTUnwrap(overlayWindowController.testingWindow)
        let newOrigin = CGPoint(x: 320, y: 260)
        window.setFrameOrigin(newOrigin)
        NotificationCenter.default.post(name: NSWindow.didMoveNotification, object: window)

        XCTAssertEqual(settingsStore.customOverlayOrigin, newOrigin)
    }

    func testMousePreviewRequiresSettingAndPersistsWhenEnabled() {
        let overlayPresenter = RecordingOverlayPresenter()
        let settingsStore = SettingsStore(defaults: defaults)
        let coordinator = AppCoordinator(
            launchConfiguration: LaunchConfiguration(
                isUITestMode: true,
                shouldOpenSettingsOnLaunch: false,
                shouldResetDefaults: false,
                defaultsSuiteName: "KeyGlassHostedUITests"
            ),
            settingsStore: settingsStore,
            permissionManager: StubInputPermissionManager(state: .granted),
            eventTapService: NoOpEventTapService(),
            formatter: KeystrokeFormatter(),
            overlayWindowController: overlayPresenter
        )

        coordinator.previewLeftClick()
        XCTAssertEqual(coordinator.lastPresentedText, "No input yet")
        XCTAssertNil(overlayPresenter.lastText)

        settingsStore.showMouseClicks = true
        coordinator.previewLeftClick()
        XCTAssertEqual(coordinator.lastPresentedText, "L Click")
        XCTAssertEqual(overlayPresenter.lastText, "L Click")
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

    func testLiveDiagnosticsTrackKeyDownEvents() {
        let coordinator = makeCoordinator(eventTapService: ScriptedEventTapService(script: "keyDown:48:shift"))

        coordinator.toggleCaptureEnabled(true)
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))

        XCTAssertEqual(coordinator.captureStatusDescription, "Running")
        XCTAssertEqual(coordinator.liveCaptureDiagnostics.keyDownCount, 1)
        XCTAssertEqual(coordinator.liveCaptureDiagnostics.modifierEventCount, 0)
        XCTAssertEqual(coordinator.liveCaptureDiagnostics.lastEventSummary, "keyDown keyCode=48 flags=shift")
        XCTAssertEqual(coordinator.lastPresentedText, "⇧⇥")
        XCTAssertNil(coordinator.liveCaptureHint)
    }

    func testLiveDiagnosticsExposeModifierOnlyHint() {
        let coordinator = makeCoordinator(eventTapService: ScriptedEventTapService(script: "flagsChanged:56:shift"))

        coordinator.toggleCaptureEnabled(true)
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))

        XCTAssertEqual(coordinator.liveCaptureDiagnostics.keyDownCount, 0)
        XCTAssertEqual(coordinator.liveCaptureDiagnostics.modifierEventCount, 1)
        XCTAssertEqual(coordinator.liveCaptureDiagnostics.lastEventSummary, "flagsChanged keyCode=56 flags=shift")
        XCTAssertEqual(coordinator.lastPresentedText, "⇧")
        XCTAssertEqual(
            coordinator.liveCaptureHint,
            "Only modifier events have been seen so far. Check Input Monitoring approval and whether the active app is using Secure Input."
        )
    }

    func testDiagnosticsStillCountFilteredPlainKeyInput() {
        let settingsStore = SettingsStore(defaults: defaults)
        settingsStore.displayMode = .modifiedKeys
        let coordinator = AppCoordinator(
            launchConfiguration: LaunchConfiguration(
                isUITestMode: true,
                shouldOpenSettingsOnLaunch: false,
                shouldResetDefaults: false,
                defaultsSuiteName: "KeyGlassHostedUITests"
            ),
            settingsStore: settingsStore,
            permissionManager: StubInputPermissionManager(state: .granted),
            eventTapService: ScriptedEventTapService(script: "keyDown:0:none"),
            formatter: KeystrokeFormatter(),
            overlayWindowController: RecordingOverlayPresenter()
        )

        coordinator.toggleCaptureEnabled(true)
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))

        XCTAssertEqual(coordinator.liveCaptureDiagnostics.keyDownCount, 1)
        XCTAssertEqual(coordinator.lastPresentedText, "No input yet")
        XCTAssertEqual(coordinator.liveCaptureDiagnostics.lastEventSummary, "keyDown keyCode=0 flags=none")
        XCTAssertNil(coordinator.liveCaptureHint)
    }

    private func makeCoordinator(
        overlayPresenter: OverlayPresenting = RecordingOverlayPresenter(),
        formatter: KeystrokeFormatter? = nil,
        eventTapService: EventTapServicing = NoOpEventTapService()
    ) -> AppCoordinator {
        AppCoordinator(
            launchConfiguration: LaunchConfiguration(
                isUITestMode: true,
                shouldOpenSettingsOnLaunch: false,
                shouldResetDefaults: false,
                defaultsSuiteName: "KeyGlassHostedUITests"
            ),
            settingsStore: SettingsStore(defaults: defaults),
            permissionManager: StubInputPermissionManager(state: .granted),
            eventTapService: eventTapService,
            formatter: formatter ?? KeystrokeFormatter(),
            overlayWindowController: overlayPresenter
        )
    }

    private func visibleSettingsWindow() -> NSWindow? {
        NSApp.windows.reversed().first { window in
            window.title == "KeyGlass" && window.isVisible
        }
    }
}

private final class RecordingOverlayPresenter: OverlayPresenting {
    private(set) var lastText: String?
    private(set) var lastSettings: OverlayPresentationSettings?

    func show(text: String, settings: OverlayPresentationSettings) {
        lastText = text
        lastSettings = settings
    }
}

private final class TrackingPermissionManager: InputPermissionManaging {
    private(set) var requestCount = 0
    private let state: InputPermissionState

    init(state: InputPermissionState) {
        self.state = state
    }

    func currentState() -> InputPermissionState {
        state
    }

    func requestAccess() -> InputPermissionState {
        requestCount += 1
        return state
    }
}

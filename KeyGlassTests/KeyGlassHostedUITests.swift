import AppKit
@testable import KeyGlass
import XCTest

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
            launchAtLoginManager: StubLaunchAtLoginManager(),
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

    func testStatusMenuKeepsStableCaptureToggleTitleAndRemovesPreviewEntry() {
        let coordinator = makeCoordinator()

        coordinator.applicationDidFinishLaunching()

        XCTAssertTrue(coordinator.testingStatusMenuItems.contains { item in
            item.title == "Enable Capture" && item.state == .off
        })
        XCTAssertFalse(coordinator.testingStatusMenuItems.contains { item in
            item.title == "Preview Command-K"
        })

        coordinator.toggleCaptureEnabled(true)

        XCTAssertTrue(coordinator.testingStatusMenuItems.contains { item in
            item.title == "Enable Capture" && item.state == .on
        })
        XCTAssertFalse(coordinator.testingStatusMenuItems.contains { item in
            item.title == "Disable Capture"
        })
    }

    func testGrantedPermissionActionOpensInputMonitoringSettings() {
        let settingsStore = SettingsStore(defaults: defaults)
        let permissionManager = TrackingPermissionManager(state: .granted)
        var openedURL: URL?
        let coordinator = AppCoordinator(
            launchConfiguration: LaunchConfiguration(
                isUITestMode: true,
                shouldOpenSettingsOnLaunch: false,
                shouldResetDefaults: false,
                defaultsSuiteName: "KeyGlassHostedUITests"
            ),
            settingsStore: settingsStore,
            permissionManager: permissionManager,
            eventTapService: NoOpEventTapService(),
            launchAtLoginManager: StubLaunchAtLoginManager(),
            formatter: KeystrokeFormatter(),
            overlayWindowController: RecordingOverlayPresenter(),
            openExternalURL: { url in
                openedURL = url
                return true
            }
        )

        XCTAssertEqual(coordinator.permissionActionTitle, "Open Input Monitoring Settings")
        coordinator.performPermissionAction()

        XCTAssertEqual(permissionManager.requestCount, 0)
        XCTAssertEqual(openedURL?.absoluteString, "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    func testMissingPermissionActionRequestsAccessInsteadOfOpeningSettings() {
        let settingsStore = SettingsStore(defaults: defaults)
        let permissionManager = TrackingPermissionManager(state: .requiresApproval)
        var didOpenURL = false
        let coordinator = AppCoordinator(
            launchConfiguration: LaunchConfiguration(
                isUITestMode: true,
                shouldOpenSettingsOnLaunch: false,
                shouldResetDefaults: false,
                defaultsSuiteName: "KeyGlassHostedUITests"
            ),
            settingsStore: settingsStore,
            permissionManager: permissionManager,
            eventTapService: NoOpEventTapService(),
            launchAtLoginManager: StubLaunchAtLoginManager(),
            formatter: KeystrokeFormatter(),
            overlayWindowController: RecordingOverlayPresenter(),
            openExternalURL: { _ in
                didOpenURL = true
                return true
            }
        )

        XCTAssertEqual(coordinator.permissionActionTitle, "Request Permission")
        coordinator.performPermissionAction()

        XCTAssertEqual(permissionManager.requestCount, 1)
        XCTAssertFalse(didOpenURL)
    }

    func testLaunchAtLoginToggleUsesManagerState() {
        let settingsStore = SettingsStore(defaults: defaults)
        let launchAtLoginManager = StubLaunchAtLoginManager(initialState: .disabled)
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
            launchAtLoginManager: launchAtLoginManager,
            formatter: KeystrokeFormatter(),
            overlayWindowController: RecordingOverlayPresenter()
        )

        XCTAssertEqual(coordinator.launchAtLoginDescription, "Off")
        XCTAssertFalse(coordinator.isLaunchAtLoginEnabled)

        coordinator.toggleLaunchAtLogin(true)

        XCTAssertEqual(launchAtLoginManager.setCalls, [true])
        XCTAssertEqual(coordinator.launchAtLoginDescription, "On")
        XCTAssertTrue(coordinator.isLaunchAtLoginEnabled)
    }

    func testLaunchAtLoginRequiresApprovalHintIsExposed() {
        let settingsStore = SettingsStore(defaults: defaults)
        let launchAtLoginManager = StubLaunchAtLoginManager(initialState: .requiresApproval)
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
            launchAtLoginManager: launchAtLoginManager,
            formatter: KeystrokeFormatter(),
            overlayWindowController: RecordingOverlayPresenter()
        )

        XCTAssertTrue(coordinator.isLaunchAtLoginEnabled)
        XCTAssertEqual(coordinator.launchAtLoginDescription, "Needs approval in Login Items")
        XCTAssertNotNil(coordinator.launchAtLoginHint)
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
            launchAtLoginManager: StubLaunchAtLoginManager(),
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
        settingsStore.overlayMergeWindow = 0.42
        settingsStore.overlayStackMaxCount = 7
        settingsStore.overlayStackDirection = .newestOnBottom
        settingsStore.showMouseClicks = true

        let reloadedStore = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloadedStore.displayMode, .modifierOnly)
        XCTAssertEqual(reloadedStore.overlayAnchor, .bottomRight)
        XCTAssertEqual(reloadedStore.overlayFontSize, 33, accuracy: 0.001)
        XCTAssertEqual(reloadedStore.overlayOpacity, 0.75, accuracy: 0.001)
        XCTAssertEqual(reloadedStore.fadeDelay, 1.8, accuracy: 0.001)
        XCTAssertEqual(reloadedStore.fadeDuration, 0.35, accuracy: 0.001)
        XCTAssertEqual(reloadedStore.overlayMergeWindow, 0.42, accuracy: 0.001)
        XCTAssertEqual(reloadedStore.overlayStackMaxCount, 7)
        XCTAssertEqual(reloadedStore.overlayStackDirection, .newestOnBottom)
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
        settingsStore.overlayStackDirection = .newestOnBottom

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
            launchAtLoginManager: StubLaunchAtLoginManager(),
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
        XCTAssertEqual(lastSettings.stackDirection, .newestOnBottom)
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
            launchAtLoginManager: StubLaunchAtLoginManager(),
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
            launchAtLoginManager: StubLaunchAtLoginManager(),
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
            launchAtLoginManager: StubLaunchAtLoginManager(),
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
            launchAtLoginManager: StubLaunchAtLoginManager(),
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

    func testOffscreenCustomOverlayOriginIsClampedBackIntoVisibleFrame() throws {
        let settingsStore = SettingsStore(defaults: defaults)
        settingsStore.customOverlayOrigin = CGPoint(x: -10000, y: 10000)
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
            launchAtLoginManager: StubLaunchAtLoginManager(),
            formatter: KeystrokeFormatter(),
            overlayWindowController: overlayWindowController
        )

        coordinator.previewCommandK()

        let window = try XCTUnwrap(overlayWindowController.testingWindow)
        let visibleFrame = try XCTUnwrap(window.screen ?? NSScreen.screens.first).visibleFrame

        XCTAssertGreaterThanOrEqual(window.frame.minX, visibleFrame.minX - 0.001)
        XCTAssertLessThanOrEqual(window.frame.maxX, visibleFrame.maxX + 0.001)
        XCTAssertGreaterThanOrEqual(window.frame.minY, visibleFrame.minY - 0.001)
        XCTAssertLessThanOrEqual(window.frame.maxY, visibleFrame.maxY + 0.001)
        XCTAssertEqual(settingsStore.customOverlayOrigin, window.frame.origin)
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
            launchAtLoginManager: StubLaunchAtLoginManager(),
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
        XCTAssertEqual(overlayPresenter.lastEntries.map(\.text), ["L Click"])
    }

    func testRapidPlainInputMergesIntoSingleHistoryEntry() {
        let settingsStore = SettingsStore(defaults: defaults)
        settingsStore.overlayMergeWindow = 0.6
        let overlayPresenter = RecordingOverlayPresenter()
        let coordinator = AppCoordinator(
            launchConfiguration: LaunchConfiguration(
                isUITestMode: true,
                shouldOpenSettingsOnLaunch: false,
                shouldResetDefaults: false,
                defaultsSuiteName: "KeyGlassHostedUITests"
            ),
            settingsStore: settingsStore,
            permissionManager: StubInputPermissionManager(state: .granted),
            eventTapService: ScriptedEventTapService(script: "keyDown:0:none;keyDown:1:none;keyDown:2:none"),
            launchAtLoginManager: StubLaunchAtLoginManager(),
            formatter: KeystrokeFormatter(),
            overlayWindowController: overlayPresenter
        )

        coordinator.toggleCaptureEnabled(true)
        waitUntil {
            coordinator.lastPresentedText == "asd"
                && overlayPresenter.lastEntries.map(\.text) == ["asd"]
        }

        XCTAssertEqual(coordinator.lastPresentedText, "asd")
        XCTAssertEqual(overlayPresenter.lastEntries.map(\.text), ["asd"])
    }

    func testSmallMergeWindowSplitsRapidInputIntoStackEntries() {
        let settingsStore = SettingsStore(defaults: defaults)
        settingsStore.overlayMergeWindow = 0.01
        settingsStore.fadeDelay = 10
        settingsStore.fadeDuration = 1
        let overlayPresenter = RecordingOverlayPresenter()
        let coordinator = AppCoordinator(
            launchConfiguration: LaunchConfiguration(
                isUITestMode: true,
                shouldOpenSettingsOnLaunch: false,
                shouldResetDefaults: false,
                defaultsSuiteName: "KeyGlassHostedUITests"
            ),
            settingsStore: settingsStore,
            permissionManager: StubInputPermissionManager(state: .granted),
            eventTapService: ScriptedEventTapService(
                script: "keyDown:0:none:0.12;keyDown:1:none:1.12;keyDown:2:none:2.12"
            ),
            launchAtLoginManager: StubLaunchAtLoginManager(),
            formatter: KeystrokeFormatter(),
            overlayWindowController: overlayPresenter
        )

        coordinator.toggleCaptureEnabled(true)
        waitUntil(timeout: 6.0) {
            coordinator.lastPresentedText == "d"
                && overlayPresenter.lastEntries.map(\.text) == ["d", "s", "a"]
        }

        XCTAssertEqual(coordinator.lastPresentedText, "d")
        XCTAssertEqual(overlayPresenter.lastEntries.map(\.text), ["d", "s", "a"])
    }

    func testStackMaxCountDropsOldestEntries() {
        let settingsStore = SettingsStore(defaults: defaults)
        settingsStore.overlayMergeWindow = 0.01
        settingsStore.overlayStackMaxCount = 2
        let overlayPresenter = RecordingOverlayPresenter()
        let coordinator = AppCoordinator(
            launchConfiguration: LaunchConfiguration(
                isUITestMode: true,
                shouldOpenSettingsOnLaunch: false,
                shouldResetDefaults: false,
                defaultsSuiteName: "KeyGlassHostedUITests"
            ),
            settingsStore: settingsStore,
            permissionManager: StubInputPermissionManager(state: .granted),
            eventTapService: ScriptedEventTapService(
                script: "keyDown:0:none:0.12;keyDown:1:none:1.12;keyDown:2:none:2.12;keyDown:3:none:3.12"
            ),
            launchAtLoginManager: StubLaunchAtLoginManager(),
            formatter: KeystrokeFormatter(),
            overlayWindowController: overlayPresenter
        )

        coordinator.toggleCaptureEnabled(true)
        waitUntil(timeout: 6.0) {
            overlayPresenter.lastEntries.map(\.text) == ["f", "d"]
        }

        XCTAssertEqual(overlayPresenter.lastEntries.map(\.text), ["f", "d"])
    }

    func testDragPausesOverlayExpiryUntilDropFinishes() {
        let settingsStore = SettingsStore(defaults: defaults)
        settingsStore.fadeDelay = 0.2
        settingsStore.fadeDuration = 0.1
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
            launchAtLoginManager: StubLaunchAtLoginManager(),
            formatter: KeystrokeFormatter(),
            overlayWindowController: overlayWindowController
        )

        coordinator.previewCommandK()
        XCTAssertEqual(overlayWindowController.testingDisplayedTexts, ["⌘K"])

        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        overlayWindowController.onDraggingStateChange?(true)
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        XCTAssertEqual(overlayWindowController.testingDisplayedTexts, ["⌘K"])

        overlayWindowController.onDraggingStateChange?(false)
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        XCTAssertTrue(overlayWindowController.testingDisplayedTexts.isEmpty)
    }

    func testDragSuppressesNewOverlayEntriesUntilDrop() {
        let settingsStore = SettingsStore(defaults: defaults)
        settingsStore.fadeDelay = 10.0
        settingsStore.fadeDuration = 1.0
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
            launchAtLoginManager: StubLaunchAtLoginManager(),
            formatter: KeystrokeFormatter(),
            overlayWindowController: overlayWindowController
        )

        coordinator.previewCommandK()
        XCTAssertEqual(overlayWindowController.testingDisplayedTexts, ["⌘K"])

        overlayWindowController.onDraggingStateChange?(true)

        coordinator.previewShiftTab()
        XCTAssertEqual(overlayWindowController.testingDisplayedTexts, ["⌘K"], "Overlay should not update during drag")

        overlayWindowController.onDraggingStateChange?(false)
        XCTAssertEqual(overlayWindowController.testingDisplayedTexts, ["⇧⇥", "⌘K"], "Overlay should reflect all entries after drag ends")
    }

    func testDragPreservesEntryAlphaMidFade() {
        let settingsStore = SettingsStore(defaults: defaults)
        settingsStore.fadeDelay = 0.05
        settingsStore.fadeDuration = 10.0
        let overlayWindowController = OverlayWindowController()
        _ = AppCoordinator(
            launchConfiguration: LaunchConfiguration(
                isUITestMode: true,
                shouldOpenSettingsOnLaunch: false,
                shouldResetDefaults: false,
                defaultsSuiteName: "KeyGlassHostedUITests"
            ),
            settingsStore: settingsStore,
            permissionManager: StubInputPermissionManager(state: .granted),
            eventTapService: NoOpEventTapService(),
            launchAtLoginManager: StubLaunchAtLoginManager(),
            formatter: KeystrokeFormatter(),
            overlayWindowController: overlayWindowController
        )

        overlayWindowController.show(
            entries: [OverlayHistoryEntry(id: UUID(), text: "⌘K", updatedAt: Date(), mergeMode: .isolated)],
            settings: OverlayPresentationSettings(from: settingsStore)
        )

        RunLoop.current.run(until: Date().addingTimeInterval(0.15))

        overlayWindowController.testingSimulateDragStateChange(true)

        let alphas = overlayWindowController.testingEntryAlphas
        XCTAssertFalse(alphas.isEmpty)
        XCTAssertGreaterThan(alphas[0], 0, "Entry alpha should not snap to 0 when drag pauses mid-fade")
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
            launchAtLoginManager: StubLaunchAtLoginManager(),
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
        waitUntil {
            coordinator.captureStatusDescription == "Running"
                && coordinator.liveCaptureDiagnostics.keyDownCount == 1
                && coordinator.liveCaptureDiagnostics.lastEventSummary == "keyDown keyCode=48 flags=shift"
                && coordinator.lastPresentedText == "⇧⇥"
        }

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
        waitUntil {
            coordinator.liveCaptureDiagnostics.modifierEventCount == 1
                && coordinator.liveCaptureDiagnostics.lastEventSummary == "flagsChanged keyCode=56 flags=shift"
                && coordinator.lastPresentedText == "⇧"
                && coordinator.liveCaptureHint
                == "Only modifier events have been seen so far. Check Input Monitoring approval and whether the active app is using Secure Input."
        }

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
            launchAtLoginManager: StubLaunchAtLoginManager(),
            formatter: KeystrokeFormatter(),
            overlayWindowController: RecordingOverlayPresenter()
        )

        coordinator.toggleCaptureEnabled(true)
        waitUntil {
            coordinator.liveCaptureDiagnostics.keyDownCount == 1
                && coordinator.liveCaptureDiagnostics.lastEventSummary == "keyDown keyCode=0 flags=none"
        }

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
            launchAtLoginManager: StubLaunchAtLoginManager(),
            formatter: formatter ?? KeystrokeFormatter(),
            overlayWindowController: overlayPresenter
        )
    }

    private func visibleSettingsWindow() -> NSWindow? {
        NSApp.windows.reversed().first { window in
            window.title == "KeyGlass" && window.isVisible
        }
    }

    private func waitUntil(
        timeout: TimeInterval = 1.5,
        pollInterval: TimeInterval = 0.02,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: () -> Bool
    ) {
        let deadline = Date().addingTimeInterval(timeout)

        while !condition(), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }

        XCTAssertTrue(condition(), file: file, line: line)
    }
}

private final class RecordingOverlayPresenter: OverlayPresenting {
    private(set) var lastEntries: [OverlayHistoryEntry] = []
    private(set) var lastSettings: OverlayPresentationSettings?

    var lastText: String? {
        lastEntries.first?.text
    }

    func show(entries: [OverlayHistoryEntry], settings: OverlayPresentationSettings) {
        lastEntries = entries
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

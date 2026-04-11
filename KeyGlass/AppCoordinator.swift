import AppKit
import Foundation
import OSLog

@MainActor
final class AppCoordinator: NSObject, ObservableObject {
    @Published private(set) var permissionState: InputPermissionState
    @Published private(set) var captureRuntimeState: CaptureRuntimeState = .stopped
    @Published private(set) var lastPresentedText = "No input yet"
    @Published private(set) var liveCaptureDiagnostics = LiveCaptureDiagnostics()

    let launchConfiguration: LaunchConfiguration
    let settingsStore: SettingsStore

    private let permissionManager: InputPermissionManaging
    private let eventTapService: EventTapServicing
    private let formatter: KeystrokeFormatter
    private let overlayWindowController: OverlayPresenting
    private lazy var settingsWindowController = SettingsWindowController(
        coordinator: self,
        settingsStore: settingsStore
    )
    private var statusItem: NSStatusItem?
    private let logger = Logger(subsystem: "com.mkusaka.KeyGlass", category: "AppCoordinator")

    init(
        launchConfiguration: LaunchConfiguration,
        settingsStore: SettingsStore,
        permissionManager: InputPermissionManaging,
        eventTapService: EventTapServicing,
        formatter: KeystrokeFormatter,
        overlayWindowController: OverlayPresenting
    ) {
        self.launchConfiguration = launchConfiguration
        self.settingsStore = settingsStore
        self.permissionManager = permissionManager
        self.eventTapService = eventTapService
        self.formatter = formatter
        self.overlayWindowController = overlayWindowController
        self.permissionState = permissionManager.currentState()
        super.init()

        if let overlayWindowController = overlayWindowController as? OverlayWindowController {
            overlayWindowController.onPositionChange = { [weak settingsStore] origin in
                settingsStore?.customOverlayOrigin = origin
            }
        }
    }

    var isCaptureEnabled: Bool {
        settingsStore.captureEnabled
    }

    var permissionDescription: String {
        permissionState.description
    }

    var captureStatusDescription: String {
        captureRuntimeState.description
    }

    var shouldShowUITestBanner: Bool {
        launchConfiguration.isUITestMode
    }

    var liveCaptureHint: String? {
        guard captureRuntimeState == .running else { return nil }
        guard liveCaptureDiagnostics.keyDownCount == 0 else { return nil }
        guard liveCaptureDiagnostics.modifierEventCount > 0 else { return nil }

        return "Only modifier events have been seen so far. Check Input Monitoring approval and whether the active app is using Secure Input."
    }

    func applicationDidFinishLaunching() {
        logger.notice(
            "applicationDidFinishLaunching uiTestMode=\(self.launchConfiguration.isUITestMode, privacy: .public) captureEnabled=\(self.settingsStore.captureEnabled, privacy: .public) hasPrompted=\(self.settingsStore.hasPromptedForInputMonitoring, privacy: .public)"
        )

        if launchConfiguration.isUITestMode {
            NSApp.setActivationPolicy(.regular)
        }

        configureStatusItemIfNeeded()
        refreshPermissionState()
        syncCaptureState()

        if !launchConfiguration.isUITestMode,
           !permissionState.isGranted,
           !settingsStore.hasPromptedForInputMonitoring {
            settingsStore.hasPromptedForInputMonitoring = true
            settingsStore.captureEnabled = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.openSettings()
                self?.requestPermission()
            }
        }

        if launchConfiguration.shouldOpenSettingsOnLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.openSettings()
            }
        }
    }

    func openSettings() {
        settingsWindowController.show()
    }

    func requestPermission() {
        let preflightState = permissionManager.currentState()
        logger.notice(
            "requestPermission started captureEnabled=\(self.settingsStore.captureEnabled, privacy: .public) currentPermission=\(preflightState.description, privacy: .public)"
        )
        settingsStore.hasPromptedForInputMonitoring = true
        permissionState = permissionManager.requestAccess()
        logger.notice("requestPermission finished permission=\(self.permissionState.description, privacy: .public)")
        syncCaptureState(reason: "requestPermission")
    }

    func toggleCaptureEnabled(_ enabled: Bool) {
        logger.notice("toggleCaptureEnabled enabled=\(enabled, privacy: .public)")
        settingsStore.captureEnabled = enabled

        let preflightState = permissionManager.currentState()
        logger.notice("toggleCaptureEnabled preflightPermission=\(preflightState.description, privacy: .public)")

        if enabled, !preflightState.isGranted {
            logger.notice("toggleCaptureEnabled requesting permission because capture was enabled without approval")
            requestPermission()
            return
        }

        syncCaptureState(reason: "toggleCaptureEnabled")
    }

    func previewCommandK() {
        presentCapturedInput(
            CapturedInput(
                kind: .keyDown,
                keyCode: 40,
                modifierFlags: [.command]
            )
        )
    }

    func previewShiftTab() {
        presentCapturedInput(
            CapturedInput(
                kind: .keyDown,
                keyCode: 48,
                modifierFlags: [.shift]
            )
        )
    }

    func previewPlainA() {
        presentCapturedInput(
            CapturedInput(
                kind: .keyDown,
                keyCode: 0,
                modifierFlags: []
            )
        )
    }

    func previewModifierOnly() {
        presentCapturedInput(
            CapturedInput(
                kind: .flagsChanged,
                keyCode: 56,
                modifierFlags: [.shift]
            )
        )
    }

    func previewLeftClick() {
        presentCapturedInput(
            CapturedInput(
                kind: .leftMouseDown,
                keyCode: 0,
                modifierFlags: []
            )
        )
    }

    @objc
    func handleOpenSettingsMenuAction(_ sender: Any?) {
        openSettings()
    }

    @objc
    func handleRequestPermissionMenuAction(_ sender: Any?) {
        requestPermission()
    }

    @objc
    func handlePreviewMenuAction(_ sender: Any?) {
        previewCommandK()
    }

    @objc
    func handleToggleCaptureMenuAction(_ sender: Any?) {
        toggleCaptureEnabled(!settingsStore.captureEnabled)
    }

    @objc
    func handleQuitMenuAction(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func configureStatusItemIfNeeded() {
        guard statusItem == nil else { return }

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⌨︎"
        statusItem.button?.toolTip = "KeyGlass"
        self.statusItem = statusItem
        rebuildStatusMenu()
    }

    private func refreshPermissionState() {
        permissionState = permissionManager.currentState()
        rebuildStatusMenu()
    }

    private func syncCaptureState(reason: String = "unspecified") {
        logger.notice(
            "syncCaptureState reason=\(reason, privacy: .public) captureEnabled=\(self.settingsStore.captureEnabled, privacy: .public) lastKnownPermission=\(self.permissionState.description, privacy: .public) eventTapRunning=\(self.eventTapService.isRunning, privacy: .public)"
        )
        refreshPermissionState()
        logger.notice("syncCaptureState refreshedPermission=\(self.permissionState.description, privacy: .public)")

        guard settingsStore.captureEnabled else {
            logger.notice("syncCaptureState stopping capture because captureEnabled is false")
            eventTapService.stop()
            resetLiveCaptureDiagnostics()
            captureRuntimeState = .stopped
            rebuildStatusMenu()
            return
        }

        guard permissionState.isGranted else {
            logger.notice("syncCaptureState cannot start capture because permission is required")
            eventTapService.stop()
            resetLiveCaptureDiagnostics()
            captureRuntimeState = .permissionRequired
            rebuildStatusMenu()
            return
        }

        resetLiveCaptureDiagnostics()

        do {
            logger.notice("syncCaptureState starting event tap")
            try eventTapService.start { [weak self] capturedInput in
                self?.handleLiveCapturedInput(capturedInput)
            }
            captureRuntimeState = .running
            logger.notice("syncCaptureState event tap is running")
        } catch {
            logger.error("syncCaptureState failed to start event tap error=\(String(describing: error), privacy: .public)")
            captureRuntimeState = .failed("Failed to start event capture")
        }

        rebuildStatusMenu()
    }

    private func presentCapturedInput(_ capturedInput: CapturedInput) {
        guard let text = formatter.string(for: capturedInput, displayMode: settingsStore.displayMode) else {
            return
        }

        switch capturedInput.kind {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            guard settingsStore.showMouseClicks else { return }
        case .keyDown, .flagsChanged:
            break
        }

        lastPresentedText = text
        overlayWindowController.show(
            text: text,
            settings: OverlayPresentationSettings(from: settingsStore)
        )
        rebuildStatusMenu()
    }

    private func handleLiveCapturedInput(_ capturedInput: CapturedInput) {
        liveCaptureDiagnostics.record(capturedInput)
        presentCapturedInput(capturedInput)
    }

    private func resetLiveCaptureDiagnostics() {
        liveCaptureDiagnostics = LiveCaptureDiagnostics()
    }

    private func rebuildStatusMenu() {
        guard let statusItem else { return }

        let menu = NSMenu()

        let statusLine = NSMenuItem(title: "Status: \(captureStatusDescription)", action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)

        let permissionLine = NSMenuItem(title: "Permission: \(permissionDescription)", action: nil, keyEquivalent: "")
        permissionLine.isEnabled = false
        menu.addItem(permissionLine)

        menu.addItem(.separator())

        let toggleItem = NSMenuItem(
            title: settingsStore.captureEnabled ? "Disable Capture" : "Enable Capture",
            action: #selector(handleToggleCaptureMenuAction(_:)),
            keyEquivalent: ""
        )
        toggleItem.state = settingsStore.captureEnabled ? .on : .off
        toggleItem.target = self
        menu.addItem(toggleItem)

        let settingsItem = NSMenuItem(
            title: "Open Settings",
            action: #selector(handleOpenSettingsMenuAction(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let permissionItem = NSMenuItem(
            title: "Request Permission",
            action: #selector(handleRequestPermissionMenuAction(_:)),
            keyEquivalent: ""
        )
        permissionItem.target = self
        menu.addItem(permissionItem)

        let previewItem = NSMenuItem(
            title: "Preview Command-K",
            action: #selector(handlePreviewMenuAction(_:)),
            keyEquivalent: ""
        )
        previewItem.target = self
        menu.addItem(previewItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit KeyGlass",
            action: #selector(handleQuitMenuAction(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.image = NSImage(
            systemSymbolName: settingsStore.captureEnabled ? "keyboard.fill" : "keyboard",
            accessibilityDescription: "KeyGlass"
        )
        statusItem.button?.title = ""
    }
}

enum CaptureRuntimeState: Equatable {
    case stopped
    case running
    case permissionRequired
    case failed(String)

    var description: String {
        switch self {
        case .stopped:
            return "Stopped"
        case .running:
            return "Running"
        case .permissionRequired:
            return "Permission required"
        case let .failed(message):
            return message
        }
    }
}

struct LiveCaptureDiagnostics: Equatable {
    private(set) var lastEventSummary = "No live input yet"
    private(set) var keyDownCount = 0
    private(set) var modifierEventCount = 0
    private(set) var mouseClickCount = 0

    mutating func record(_ capturedInput: CapturedInput) {
        switch capturedInput.kind {
        case .keyDown:
            keyDownCount += 1
        case .flagsChanged:
            modifierEventCount += 1
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            mouseClickCount += 1
        }

        lastEventSummary = capturedInput.debugSummary
    }
}

private extension CapturedInput {
    var debugSummary: String {
        "\(kind.debugName) keyCode=\(keyCode) flags=\(modifierFlags.debugSummary)"
    }
}

private extension CapturedInputKind {
    var debugName: String {
        switch self {
        case .keyDown:
            return "keyDown"
        case .flagsChanged:
            return "flagsChanged"
        case .leftMouseDown:
            return "leftMouseDown"
        case .rightMouseDown:
            return "rightMouseDown"
        case .otherMouseDown:
            return "otherMouseDown"
        }
    }
}

private extension NSEvent.ModifierFlags {
    var debugSummary: String {
        let filteredFlags = intersection(.deviceIndependentFlagsMask)
        var tokens: [String] = []

        if filteredFlags.contains(.capsLock) { tokens.append("capsLock") }
        if filteredFlags.contains(.shift) { tokens.append("shift") }
        if filteredFlags.contains(.control) { tokens.append("control") }
        if filteredFlags.contains(.option) { tokens.append("option") }
        if filteredFlags.contains(.command) { tokens.append("command") }
        if filteredFlags.contains(.function) { tokens.append("function") }

        return tokens.isEmpty ? "none" : tokens.joined(separator: ",")
    }
}

import AppKit
import Foundation
import OSLog

@MainActor
final class AppCoordinator: NSObject, ObservableObject {
    @Published private(set) var permissionState: InputPermissionState
    @Published private(set) var launchAtLoginState: LaunchAtLoginState
    @Published private(set) var captureRuntimeState: CaptureRuntimeState = .stopped
    @Published private(set) var lastPresentedText = "No input yet"
    @Published private(set) var liveCaptureDiagnostics = LiveCaptureDiagnostics()

    let launchConfiguration: LaunchConfiguration
    let settingsStore: SettingsStore

    private let permissionManager: InputPermissionManaging
    private let eventTapService: EventTapServicing
    private let launchAtLoginManager: LaunchAtLoginManaging
    private let formatter: KeystrokeFormatter
    private let overlayWindowController: OverlayPresenting
    private let openExternalURL: (URL) -> Bool
    private lazy var settingsWindowController = SettingsWindowController(
        coordinator: self,
        settingsStore: settingsStore
    )
    private var statusItem: NSStatusItem?
    private var overlayHistory: [OverlayHistoryEntry] = []
    private var pendingOverlayExpiryWorkItems: [UUID: DispatchWorkItem] = [:]
    private var overlayDragStartedAt: Date?
    private let logger = Logger(subsystem: "com.mkusaka.KeyGlass", category: "AppCoordinator")

    init(
        launchConfiguration: LaunchConfiguration,
        settingsStore: SettingsStore,
        permissionManager: InputPermissionManaging,
        eventTapService: EventTapServicing,
        launchAtLoginManager: LaunchAtLoginManaging,
        formatter: KeystrokeFormatter,
        overlayWindowController: OverlayPresenting,
        openExternalURL: @escaping (URL) -> Bool = { url in
            NSWorkspace.shared.open(url)
        }
    ) {
        self.launchConfiguration = launchConfiguration
        self.settingsStore = settingsStore
        self.permissionManager = permissionManager
        self.eventTapService = eventTapService
        self.launchAtLoginManager = launchAtLoginManager
        self.formatter = formatter
        self.overlayWindowController = overlayWindowController
        self.openExternalURL = openExternalURL
        permissionState = permissionManager.currentState()
        launchAtLoginState = launchAtLoginManager.currentState()
        super.init()

        if let overlayWindowController = overlayWindowController as? OverlayWindowController {
            overlayWindowController.onPositionChange = { [weak settingsStore] origin in
                settingsStore?.customOverlayOrigin = origin
            }
            overlayWindowController.onDraggingStateChange = { [weak self] isDragging in
                self?.setOverlayDragging(isDragging)
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

    var launchAtLoginDescription: String {
        launchAtLoginState.description
    }

    var isLaunchAtLoginEnabled: Bool {
        launchAtLoginState.isEnabled
    }

    var launchAtLoginHint: String? {
        launchAtLoginState.hint
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

    var permissionActionTitle: String {
        permissionState.isGranted ? "Open Input Monitoring Settings" : "Request Permission"
    }

    var testingStatusMenuItems: [NSMenuItem] {
        statusItem?.menu?.items ?? []
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
        refreshLaunchAtLoginState()
        syncCaptureState()

        if !launchConfiguration.isUITestMode,
           !permissionState.isGranted,
           !settingsStore.hasPromptedForInputMonitoring
        {
            settingsStore.hasPromptedForInputMonitoring = true
            settingsStore.captureEnabled = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.openSettings()
                self?.requestPermission()
            }
        }

        if launchConfiguration.shouldOpenSettingsOnLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self else { return }

                if self.launchConfiguration.isUITestMode {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } else {
                    self.openSettings()
                }
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

    func performPermissionAction() {
        if permissionState.isGranted {
            openInputMonitoringSettings()
        } else {
            requestPermission()
        }
    }

    func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            launchAtLoginState = try launchAtLoginManager.setEnabled(enabled)
        } catch {
            logger.error("toggleLaunchAtLogin failed error=\(String(describing: error), privacy: .public)")
            refreshLaunchAtLoginState()
        }
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
    func handleOpenSettingsMenuAction(_: Any?) {
        openSettings()
    }

    @objc
    func handleRequestPermissionMenuAction(_: Any?) {
        performPermissionAction()
    }

    @objc
    func handleToggleCaptureMenuAction(_: Any?) {
        toggleCaptureEnabled(!settingsStore.captureEnabled)
    }

    @objc
    func handleQuitMenuAction(_: Any?) {
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

    private func refreshLaunchAtLoginState() {
        launchAtLoginState = launchAtLoginManager.currentState()
    }

    private func openInputMonitoringSettings() {
        let candidateURLs = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.preference.security?Privacy",
            "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension",
        ]

        for urlString in candidateURLs {
            guard let url = URL(string: urlString) else { continue }
            if openExternalURL(url) {
                return
            }
        }
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
            clearOverlayHistory()
            captureRuntimeState = .stopped
            rebuildStatusMenu()
            return
        }

        guard permissionState.isGranted else {
            logger.notice("syncCaptureState cannot start capture because permission is required")
            eventTapService.stop()
            resetLiveCaptureDiagnostics()
            clearOverlayHistory()
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

        let now = Date()
        if shouldAppendToLatestEntry(for: capturedInput, at: now), !overlayHistory.isEmpty {
            overlayHistory[0].text += text
            overlayHistory[0].updatedAt = now
        } else {
            overlayHistory.insert(
                OverlayHistoryEntry(
                    id: UUID(),
                    text: text,
                    updatedAt: now,
                    mergeMode: mergeMode(for: capturedInput)
                ),
                at: 0
            )
        }

        trimOverlayHistoryIfNeeded()
        lastPresentedText = overlayHistory.first?.text ?? text
        renderOverlayHistory()
        rebuildStatusMenu()
    }

    private func handleLiveCapturedInput(_ capturedInput: CapturedInput) {
        liveCaptureDiagnostics.record(capturedInput)
        presentCapturedInput(capturedInput)
    }

    private func resetLiveCaptureDiagnostics() {
        liveCaptureDiagnostics = LiveCaptureDiagnostics()
    }

    private func mergeMode(for capturedInput: CapturedInput) -> OverlayEntryMergeMode {
        if isSequenceEligible(capturedInput) {
            return .sequence
        }

        return .isolated
    }

    private func shouldAppendToLatestEntry(for capturedInput: CapturedInput, at now: Date) -> Bool {
        guard isSequenceEligible(capturedInput) else { return false }
        guard let latestEntry = overlayHistory.first else { return false }
        guard latestEntry.mergeMode == .sequence else { return false }
        return now.timeIntervalSince(latestEntry.updatedAt) <= settingsStore.overlayMergeWindow
    }

    private func isSequenceEligible(_ capturedInput: CapturedInput) -> Bool {
        guard capturedInput.kind == .keyDown else { return false }
        return capturedInput.modifierFlags.isDisjoint(with: [.command, .control])
    }

    private func trimOverlayHistoryIfNeeded() {
        guard overlayHistory.count > settingsStore.overlayStackMaxCount else { return }

        let removedIDs = overlayHistory[settingsStore.overlayStackMaxCount...].map(\.id)
        overlayHistory = Array(overlayHistory.prefix(settingsStore.overlayStackMaxCount))

        for removedID in removedIDs {
            pendingOverlayExpiryWorkItems[removedID]?.cancel()
            pendingOverlayExpiryWorkItems.removeValue(forKey: removedID)
        }
    }

    private func renderOverlayHistory() {
        rescheduleOverlayExpiryWorkItems()
        overlayWindowController.show(
            entries: overlayHistory,
            settings: OverlayPresentationSettings(from: settingsStore)
        )
    }

    private func rescheduleOverlayExpiryWorkItems() {
        pendingOverlayExpiryWorkItems.values.forEach { $0.cancel() }
        pendingOverlayExpiryWorkItems.removeAll()

        guard overlayDragStartedAt == nil else { return }

        let totalLifetime = settingsStore.fadeDelay + settingsStore.fadeDuration
        for entry in overlayHistory {
            let remainingLifetime = max(0, entry.updatedAt.addingTimeInterval(totalLifetime).timeIntervalSinceNow)
            let workItem = DispatchWorkItem { [weak self] in
                self?.removeOverlayEntry(id: entry.id)
            }

            pendingOverlayExpiryWorkItems[entry.id] = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + remainingLifetime, execute: workItem)
        }
    }

    private func removeOverlayEntry(id: UUID) {
        pendingOverlayExpiryWorkItems.removeValue(forKey: id)
        overlayHistory.removeAll { entry in
            entry.id == id
        }
        overlayWindowController.show(
            entries: overlayHistory,
            settings: OverlayPresentationSettings(from: settingsStore)
        )
    }

    private func clearOverlayHistory() {
        pendingOverlayExpiryWorkItems.values.forEach { $0.cancel() }
        pendingOverlayExpiryWorkItems.removeAll()
        overlayHistory.removeAll()
        overlayDragStartedAt = nil
        overlayWindowController.show(
            entries: [],
            settings: OverlayPresentationSettings(from: settingsStore)
        )
    }

    private func setOverlayDragging(_ isDragging: Bool) {
        if isDragging {
            guard overlayDragStartedAt == nil else { return }
            overlayDragStartedAt = Date()
            pendingOverlayExpiryWorkItems.values.forEach { $0.cancel() }
            pendingOverlayExpiryWorkItems.removeAll()
            return
        }

        guard let overlayDragStartedAt else { return }
        let pausedDuration = Date().timeIntervalSince(overlayDragStartedAt)
        self.overlayDragStartedAt = nil

        if pausedDuration > 0 {
            for index in overlayHistory.indices {
                overlayHistory[index].updatedAt = overlayHistory[index].updatedAt.addingTimeInterval(pausedDuration)
            }
        }

        renderOverlayHistory()
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
            title: "Enable Capture",
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
            title: permissionActionTitle,
            action: #selector(handleRequestPermissionMenuAction(_:)),
            keyEquivalent: ""
        )
        permissionItem.target = self
        menu.addItem(permissionItem)

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
            "Stopped"
        case .running:
            "Running"
        case .permissionRequired:
            "Permission required"
        case let .failed(message):
            message
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
            "keyDown"
        case .flagsChanged:
            "flagsChanged"
        case .leftMouseDown:
            "leftMouseDown"
        case .rightMouseDown:
            "rightMouseDown"
        case .otherMouseDown:
            "otherMouseDown"
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

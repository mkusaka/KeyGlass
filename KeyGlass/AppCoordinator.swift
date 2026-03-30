import AppKit
import Foundation

@MainActor
final class AppCoordinator: NSObject, ObservableObject {
    @Published private(set) var permissionState: InputPermissionState
    @Published private(set) var captureRuntimeState: CaptureRuntimeState = .stopped
    @Published private(set) var lastPresentedText = "No input yet"

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

    func applicationDidFinishLaunching() {
        if launchConfiguration.isUITestMode {
            NSApp.setActivationPolicy(.regular)
        }

        configureStatusItemIfNeeded()
        refreshPermissionState()
        syncCaptureState()

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
        permissionState = permissionManager.requestAccess()
        syncCaptureState()
    }

    func toggleCaptureEnabled(_ enabled: Bool) {
        settingsStore.captureEnabled = enabled
        syncCaptureState()
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

    func previewModifierOnly() {
        presentCapturedInput(
            CapturedInput(
                kind: .flagsChanged,
                keyCode: 56,
                modifierFlags: [.shift]
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

    private func syncCaptureState() {
        refreshPermissionState()

        guard settingsStore.captureEnabled else {
            eventTapService.stop()
            captureRuntimeState = .stopped
            rebuildStatusMenu()
            return
        }

        guard permissionState.isGranted else {
            eventTapService.stop()
            captureRuntimeState = .permissionRequired
            rebuildStatusMenu()
            return
        }

        do {
            try eventTapService.start { [weak self] capturedInput in
                self?.presentCapturedInput(capturedInput)
            }
            captureRuntimeState = .running
        } catch {
            captureRuntimeState = .failed("Failed to start event capture")
        }

        rebuildStatusMenu()
    }

    private func presentCapturedInput(_ capturedInput: CapturedInput) {
        guard let text = formatter.string(for: capturedInput, displayMode: settingsStore.displayMode) else {
            return
        }

        lastPresentedText = text
        overlayWindowController.show(
            text: text,
            settings: OverlayPresentationSettings(from: settingsStore)
        )
        rebuildStatusMenu()
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

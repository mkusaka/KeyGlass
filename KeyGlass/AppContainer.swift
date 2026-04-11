import AppKit
import Foundation

@MainActor
final class AppContainer {
    static let shared = AppContainer(processInfo: .processInfo)

    let settingsStore: SettingsStore
    let coordinator: AppCoordinator

    private init(processInfo: ProcessInfo) {
        let launchConfiguration = LaunchConfiguration(processInfo: processInfo)
        let defaults = launchConfiguration.makeUserDefaults()
        let settingsStore = SettingsStore(defaults: defaults)
        let permissionManager: InputPermissionManaging
        let eventTapService: EventTapServicing

        if launchConfiguration.isUITestMode {
            permissionManager = StubInputPermissionManager(state: .granted)
            eventTapService = ScriptedEventTapService(script: launchConfiguration.uiTestCaptureScript)
        } else {
            permissionManager = SystemInputPermissionManager()
            eventTapService = SystemEventTapService()
        }

        if let initialDisplayMode = launchConfiguration.initialDisplayModeOverride {
            settingsStore.displayMode = initialDisplayMode
        }

        if let initialCaptureEnabled = launchConfiguration.initialCaptureEnabledOverride {
            settingsStore.captureEnabled = initialCaptureEnabled
        }

        let formatter = KeystrokeFormatter()
        let overlayWindowController = OverlayWindowController()

        self.settingsStore = settingsStore
        self.coordinator = AppCoordinator(
            launchConfiguration: launchConfiguration,
            settingsStore: settingsStore,
            permissionManager: permissionManager,
            eventTapService: eventTapService,
            formatter: formatter,
            overlayWindowController: overlayWindowController
        )
    }
}

struct LaunchConfiguration {
    let isUITestMode: Bool
    let shouldOpenSettingsOnLaunch: Bool
    let shouldResetDefaults: Bool
    let defaultsSuiteName: String
    let uiTestCaptureScript: String?
    let initialCaptureEnabledOverride: Bool?
    let initialDisplayModeOverride: DisplayMode?

    init(
        isUITestMode: Bool,
        shouldOpenSettingsOnLaunch: Bool,
        shouldResetDefaults: Bool,
        defaultsSuiteName: String,
        uiTestCaptureScript: String? = nil,
        initialCaptureEnabledOverride: Bool? = nil,
        initialDisplayModeOverride: DisplayMode? = nil
    ) {
        self.isUITestMode = isUITestMode
        self.shouldOpenSettingsOnLaunch = shouldOpenSettingsOnLaunch
        self.shouldResetDefaults = shouldResetDefaults
        self.defaultsSuiteName = defaultsSuiteName
        self.uiTestCaptureScript = uiTestCaptureScript
        self.initialCaptureEnabledOverride = initialCaptureEnabledOverride
        self.initialDisplayModeOverride = initialDisplayModeOverride
    }

    init(processInfo: ProcessInfo) {
        let arguments = Set(processInfo.arguments)
        let environment = processInfo.environment

        self.isUITestMode = arguments.contains("--ui-testing") || environment["KEYGLASS_UI_TEST_MODE"] == "1"
        self.shouldOpenSettingsOnLaunch = isUITestMode || arguments.contains("--open-settings-on-launch")
        self.shouldResetDefaults = isUITestMode || arguments.contains("--reset-defaults")
        self.defaultsSuiteName = environment["KEYGLASS_DEFAULTS_SUITE"] ?? "com.mkusaka.KeyGlass"
        self.uiTestCaptureScript = environment["KEYGLASS_UI_TEST_CAPTURE_SCRIPT"]
        self.initialCaptureEnabledOverride = Self.boolOverride(from: environment["KEYGLASS_UI_TEST_CAPTURE_ENABLED"])
        self.initialDisplayModeOverride = environment["KEYGLASS_UI_TEST_DISPLAY_MODE"].flatMap(DisplayMode.init(rawValue:))
    }

    func makeUserDefaults() -> UserDefaults {
        let defaults = isUITestMode ? (UserDefaults(suiteName: defaultsSuiteName) ?? .standard) : .standard

        if shouldResetDefaults {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
            defaults.synchronize()
        }

        return defaults
    }

    private static func boolOverride(from rawValue: String?) -> Bool? {
        switch rawValue {
        case "1", "true", "TRUE", "yes", "YES":
            true
        case "0", "false", "FALSE", "no", "NO":
            false
        default:
            nil
        }
    }
}

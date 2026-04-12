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
        let launchAtLoginManager: LaunchAtLoginManaging

        if launchConfiguration.isUITestMode {
            permissionManager = StubInputPermissionManager(state: .granted)
            eventTapService = ScriptedEventTapService(script: launchConfiguration.uiTestCaptureScript)
            launchAtLoginManager = StubLaunchAtLoginManager()
        } else {
            permissionManager = SystemInputPermissionManager()
            eventTapService = SystemEventTapService()
            launchAtLoginManager = SystemLaunchAtLoginManager()
        }

        if let initialDisplayMode = launchConfiguration.initialDisplayModeOverride {
            settingsStore.displayMode = initialDisplayMode
        }

        if let initialOverlayMergeWindow = launchConfiguration.initialOverlayMergeWindowOverride {
            settingsStore.overlayMergeWindow = initialOverlayMergeWindow
        }

        if let initialOverlayStackMaxCount = launchConfiguration.initialOverlayStackMaxCountOverride {
            settingsStore.overlayStackMaxCount = initialOverlayStackMaxCount
        }

        if let initialOverlayStackDirection = launchConfiguration.initialOverlayStackDirectionOverride {
            settingsStore.overlayStackDirection = initialOverlayStackDirection
        }

        if let initialCaptureEnabled = launchConfiguration.initialCaptureEnabledOverride {
            settingsStore.captureEnabled = initialCaptureEnabled
        }

        let formatter = KeystrokeFormatter()
        let overlayWindowController = OverlayWindowController()

        self.settingsStore = settingsStore
        coordinator = AppCoordinator(
            launchConfiguration: launchConfiguration,
            settingsStore: settingsStore,
            permissionManager: permissionManager,
            eventTapService: eventTapService,
            launchAtLoginManager: launchAtLoginManager,
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
    let initialOverlayMergeWindowOverride: Double?
    let initialOverlayStackMaxCountOverride: Int?
    let initialOverlayStackDirectionOverride: OverlayStackDirection?

    init(
        isUITestMode: Bool,
        shouldOpenSettingsOnLaunch: Bool,
        shouldResetDefaults: Bool,
        defaultsSuiteName: String,
        uiTestCaptureScript: String? = nil,
        initialCaptureEnabledOverride: Bool? = nil,
        initialDisplayModeOverride: DisplayMode? = nil,
        initialOverlayMergeWindowOverride: Double? = nil,
        initialOverlayStackMaxCountOverride: Int? = nil,
        initialOverlayStackDirectionOverride: OverlayStackDirection? = nil
    ) {
        self.isUITestMode = isUITestMode
        self.shouldOpenSettingsOnLaunch = shouldOpenSettingsOnLaunch
        self.shouldResetDefaults = shouldResetDefaults
        self.defaultsSuiteName = defaultsSuiteName
        self.uiTestCaptureScript = uiTestCaptureScript
        self.initialCaptureEnabledOverride = initialCaptureEnabledOverride
        self.initialDisplayModeOverride = initialDisplayModeOverride
        self.initialOverlayMergeWindowOverride = initialOverlayMergeWindowOverride
        self.initialOverlayStackMaxCountOverride = initialOverlayStackMaxCountOverride
        self.initialOverlayStackDirectionOverride = initialOverlayStackDirectionOverride
    }

    init(processInfo: ProcessInfo) {
        let arguments = Set(processInfo.arguments)
        let environment = processInfo.environment

        isUITestMode = arguments.contains("--ui-testing") || environment["KEYGLASS_UI_TEST_MODE"] == "1"
        shouldOpenSettingsOnLaunch = isUITestMode || arguments.contains("--open-settings-on-launch")
        shouldResetDefaults = isUITestMode || arguments.contains("--reset-defaults")
        defaultsSuiteName = environment["KEYGLASS_DEFAULTS_SUITE"] ?? "com.mkusaka.KeyGlass"
        uiTestCaptureScript = environment["KEYGLASS_UI_TEST_CAPTURE_SCRIPT"]
        initialCaptureEnabledOverride = Self.boolOverride(from: environment["KEYGLASS_UI_TEST_CAPTURE_ENABLED"])
        initialDisplayModeOverride = environment["KEYGLASS_UI_TEST_DISPLAY_MODE"].flatMap(DisplayMode.init(rawValue:))
        initialOverlayMergeWindowOverride = Self.doubleOverride(from: environment["KEYGLASS_UI_TEST_MERGE_WINDOW"])
        initialOverlayStackMaxCountOverride = Self.intOverride(from: environment["KEYGLASS_UI_TEST_STACK_MAX_COUNT"])
        initialOverlayStackDirectionOverride = environment["KEYGLASS_UI_TEST_STACK_DIRECTION"].flatMap(OverlayStackDirection.init(rawValue:))
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

    private static func doubleOverride(from rawValue: String?) -> Double? {
        guard let rawValue else { return nil }
        return Double(rawValue)
    }

    private static func intOverride(from rawValue: String?) -> Int? {
        guard let rawValue else { return nil }
        return Int(rawValue)
    }
}

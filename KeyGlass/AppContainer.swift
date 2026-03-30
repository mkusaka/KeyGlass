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
            eventTapService = NoOpEventTapService()
        } else {
            permissionManager = SystemInputPermissionManager()
            eventTapService = SystemEventTapService()
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

    init(
        isUITestMode: Bool,
        shouldOpenSettingsOnLaunch: Bool,
        shouldResetDefaults: Bool,
        defaultsSuiteName: String
    ) {
        self.isUITestMode = isUITestMode
        self.shouldOpenSettingsOnLaunch = shouldOpenSettingsOnLaunch
        self.shouldResetDefaults = shouldResetDefaults
        self.defaultsSuiteName = defaultsSuiteName
    }

    init(processInfo: ProcessInfo) {
        let arguments = Set(processInfo.arguments)
        let environment = processInfo.environment

        self.isUITestMode = arguments.contains("--ui-testing") || environment["KEYGLASS_UI_TEST_MODE"] == "1"
        self.shouldOpenSettingsOnLaunch = isUITestMode || arguments.contains("--open-settings-on-launch")
        self.shouldResetDefaults = isUITestMode || arguments.contains("--reset-defaults")
        self.defaultsSuiteName = environment["KEYGLASS_DEFAULTS_SUITE"] ?? "com.mkusaka.KeyGlass"
    }

    func makeUserDefaults() -> UserDefaults {
        let defaults = isUITestMode ? (UserDefaults(suiteName: defaultsSuiteName) ?? .standard) : .standard

        if shouldResetDefaults {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
            defaults.synchronize()
        }

        return defaults
    }
}

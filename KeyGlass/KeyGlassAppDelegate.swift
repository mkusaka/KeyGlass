import AppKit

@MainActor
final class KeyGlassAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_: Notification) {
        let launchConfiguration = LaunchConfiguration(processInfo: .processInfo)
        if launchConfiguration.isUITestMode {
            NSApp.setActivationPolicy(.regular)
        }
    }

    func applicationDidFinishLaunching(_: Notification) {
        AppContainer.shared.coordinator.applicationDidFinishLaunching()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }
}

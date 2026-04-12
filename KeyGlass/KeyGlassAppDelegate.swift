import AppKit

@MainActor
final class KeyGlassAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        let launchConfiguration = LaunchConfiguration(processInfo: .processInfo)
        if launchConfiguration.isUITestMode {
            NSApp.setActivationPolicy(.regular)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppContainer.shared.coordinator.applicationDidFinishLaunching()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

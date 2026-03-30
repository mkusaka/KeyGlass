import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private weak var coordinator: AppCoordinator?
    private let settingsStore: SettingsStore
    private var windowController: NSWindowController?

    init(coordinator: AppCoordinator, settingsStore: SettingsStore) {
        self.coordinator = coordinator
        self.settingsStore = settingsStore
    }

    func show() {
        if let windowController {
            showExistingWindow(windowController.window)
            return
        }

        guard let coordinator else { return }

        let rootView = SettingsView()
            .environmentObject(coordinator)
            .environmentObject(settingsStore)

        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 120, y: 120, width: 540, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = "KeyGlass"
        window.setFrameAutosaveName("KeyGlassSettingsWindow")
        window.isReleasedWhenClosed = false

        let windowController = NSWindowController(window: window)
        self.windowController = windowController
        showExistingWindow(window)
    }

    private func showExistingWindow(_ window: NSWindow?) {
        guard let window else { return }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

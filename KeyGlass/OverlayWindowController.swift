import AppKit
import Foundation

struct OverlayPresentationSettings {
    let overlayAnchor: OverlayAnchor
    let overlayOpacity: Double
    let overlayFontSize: Double
    let fadeDelay: Double
    let fadeDuration: Double
    let customOrigin: CGPoint?

    @MainActor
    init(from settingsStore: SettingsStore) {
        self.overlayAnchor = settingsStore.overlayAnchor
        self.overlayOpacity = settingsStore.overlayOpacity
        self.overlayFontSize = settingsStore.overlayFontSize
        self.fadeDelay = settingsStore.fadeDelay
        self.fadeDuration = settingsStore.fadeDuration
        self.customOrigin = settingsStore.customOverlayOrigin
    }
}

protocol OverlayPresenting: AnyObject {
    func show(text: String, settings: OverlayPresentationSettings)
}

struct OverlayScreenSnapshot: Equatable {
    let frame: CGRect
    let visibleFrame: CGRect
}

enum OverlayPlacementCalculator {
    static func targetVisibleFrame(mouseLocation: CGPoint, screens: [OverlayScreenSnapshot]) -> CGRect? {
        screens.first(where: { $0.frame.contains(mouseLocation) })?.visibleFrame ?? screens.first?.visibleFrame
    }

    static func origin(for anchor: OverlayAnchor, size: CGSize, visibleFrame: CGRect) -> CGPoint {
        switch anchor {
        case .topCenter:
            return CGPoint(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.maxY - size.height - 24
            )
        case .bottomCenter:
            return CGPoint(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.minY + 24
            )
        case .topLeft:
            return CGPoint(
                x: visibleFrame.minX + 24,
                y: visibleFrame.maxY - size.height - 24
            )
        case .topRight:
            return CGPoint(
                x: visibleFrame.maxX - size.width - 24,
                y: visibleFrame.maxY - size.height - 24
            )
        case .bottomLeft:
            return CGPoint(
                x: visibleFrame.minX + 24,
                y: visibleFrame.minY + 24
            )
        case .bottomRight:
            return CGPoint(
                x: visibleFrame.maxX - size.width - 24,
                y: visibleFrame.minY + 24
            )
        }
    }
}

final class OverlayWindowController: OverlayPresenting {
    var onPositionChange: ((CGPoint) -> Void)?

    private var window: NSPanel?
    private var visualEffectView: NSVisualEffectView?
    private var label: NSTextField?
    private var pendingFadeWorkItem: DispatchWorkItem?

    var testingWindow: NSWindow? {
        window
    }

    func show(text: String, settings: OverlayPresentationSettings) {
        let window = makeWindowIfNeeded()
        let label = makeLabelIfNeeded()

        label.stringValue = text
        label.font = .monospacedSystemFont(ofSize: settings.overlayFontSize, weight: .semibold)
        label.sizeToFit()
        let contentSize = label.fittingSize
        let windowSize = CGSize(
            width: min(max(contentSize.width + 40, 140), 320),
            height: max(contentSize.height + 28, 60)
        )
        window.setContentSize(windowSize)
        label.frame = CGRect(
            x: 20,
            y: (windowSize.height - contentSize.height) / 2,
            width: windowSize.width - 40,
            height: contentSize.height
        )
        visualEffectView?.alphaValue = settings.overlayOpacity
        updateWindowFrame(window: window, settings: settings)
        pendingFadeWorkItem?.cancel()
        window.alphaValue = 1
        window.orderFrontRegardless()

        let fadeWorkItem = DispatchWorkItem { [weak window] in
            guard let window else { return }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = settings.fadeDuration
                window.animator().alphaValue = 0
            } completionHandler: {
                window.orderOut(nil)
                window.alphaValue = 1
            }
        }

        pendingFadeWorkItem = fadeWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.fadeDelay, execute: fadeWorkItem)
    }

    private func makeWindowIfNeeded() -> NSPanel {
        if let window {
            return window
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 80, y: 80, width: 360, height: 92),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false

        let visualEffectView = NSVisualEffectView(frame: panel.contentView?.bounds ?? .zero)
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 16

        panel.contentView = visualEffectView
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidMove(_:)),
            name: NSWindow.didMoveNotification,
            object: panel
        )
        self.window = panel
        self.visualEffectView = visualEffectView
        return panel
    }

    private func makeLabelIfNeeded() -> NSTextField {
        if let label {
            return label
        }

        let label = NSTextField(labelWithString: "")
        label.alignment = .center
        label.textColor = .white
        label.lineBreakMode = .byTruncatingMiddle
        label.frame = CGRect(x: 20, y: 22, width: 320, height: 48)
        label.autoresizingMask = [.width, .height]
        visualEffectView?.addSubview(label)
        self.label = label
        return label
    }

    private func updateWindowFrame(window: NSPanel, settings: OverlayPresentationSettings) {
        if let customOrigin = settings.customOrigin {
            window.setFrameOrigin(customOrigin)
            return
        }

        let size = window.frame.size
        let screens = NSScreen.screens.map { screen in
            OverlayScreenSnapshot(frame: screen.frame, visibleFrame: screen.visibleFrame)
        }
        guard let visibleFrame = OverlayPlacementCalculator.targetVisibleFrame(
            mouseLocation: NSEvent.mouseLocation,
            screens: screens
        ) else { return }
        let origin = OverlayPlacementCalculator.origin(
            for: settings.overlayAnchor,
            size: size,
            visibleFrame: visibleFrame
        )

        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    @objc
    private func handleWindowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        onPositionChange?(window.frame.origin)
    }
}

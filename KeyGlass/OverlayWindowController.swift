import AppKit
import Foundation

struct OverlayPresentationSettings {
    let overlayAnchor: OverlayAnchor
    let overlayOpacity: Double
    let overlayFontSize: Double
    let fadeDelay: Double
    let fadeDuration: Double

    @MainActor
    init(from settingsStore: SettingsStore) {
        self.overlayAnchor = settingsStore.overlayAnchor
        self.overlayOpacity = settingsStore.overlayOpacity
        self.overlayFontSize = settingsStore.overlayFontSize
        self.fadeDelay = settingsStore.fadeDelay
        self.fadeDuration = settingsStore.fadeDuration
    }
}

protocol OverlayPresenting: AnyObject {
    func show(text: String, settings: OverlayPresentationSettings)
}

final class OverlayWindowController: OverlayPresenting {
    private var window: NSPanel?
    private var visualEffectView: NSVisualEffectView?
    private var label: NSTextField?
    private var pendingFadeWorkItem: DispatchWorkItem?

    func show(text: String, settings: OverlayPresentationSettings) {
        let window = makeWindowIfNeeded()
        let label = makeLabelIfNeeded()

        label.stringValue = text
        label.font = .monospacedSystemFont(ofSize: settings.overlayFontSize, weight: .semibold)
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
        panel.ignoresMouseEvents = true

        let visualEffectView = NSVisualEffectView(frame: panel.contentView?.bounds ?? .zero)
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 16

        panel.contentView = visualEffectView
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
        guard let screen = NSScreen.main else { return }

        let size = NSSize(width: 360, height: 92)
        let visibleFrame = screen.visibleFrame
        let origin: CGPoint

        switch settings.overlayAnchor {
        case .topCenter:
            origin = CGPoint(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.maxY - size.height - 24
            )
        case .bottomCenter:
            origin = CGPoint(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.minY + 24
            )
        case .topLeft:
            origin = CGPoint(
                x: visibleFrame.minX + 24,
                y: visibleFrame.maxY - size.height - 24
            )
        case .topRight:
            origin = CGPoint(
                x: visibleFrame.maxX - size.width - 24,
                y: visibleFrame.maxY - size.height - 24
            )
        case .bottomLeft:
            origin = CGPoint(
                x: visibleFrame.minX + 24,
                y: visibleFrame.minY + 24
            )
        case .bottomRight:
            origin = CGPoint(
                x: visibleFrame.maxX - size.width - 24,
                y: visibleFrame.minY + 24
            )
        }

        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}

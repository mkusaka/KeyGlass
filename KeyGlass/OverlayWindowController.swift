import AppKit
import Foundation

enum OverlayEntryMergeMode: Equatable {
    case sequence
    case isolated
}

struct OverlayHistoryEntry: Equatable, Identifiable {
    let id: UUID
    var text: String
    var updatedAt: Date
    let mergeMode: OverlayEntryMergeMode
}

struct OverlayPresentationSettings {
    let overlayAnchor: OverlayAnchor
    let overlayOpacity: Double
    let overlayFontSize: Double
    let fadeDelay: Double
    let fadeDuration: Double
    let stackDirection: OverlayStackDirection
    let customOrigin: CGPoint?

    @MainActor
    init(from settingsStore: SettingsStore) {
        overlayAnchor = settingsStore.overlayAnchor
        overlayOpacity = settingsStore.overlayOpacity
        overlayFontSize = settingsStore.overlayFontSize
        fadeDelay = settingsStore.fadeDelay
        fadeDuration = settingsStore.fadeDuration
        stackDirection = settingsStore.overlayStackDirection
        customOrigin = settingsStore.customOverlayOrigin
    }
}

protocol OverlayPresenting: AnyObject {
    func show(entries: [OverlayHistoryEntry], settings: OverlayPresentationSettings)
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
            CGPoint(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.maxY - size.height - 24
            )
        case .bottomCenter:
            CGPoint(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.minY + 24
            )
        case .topLeft:
            CGPoint(
                x: visibleFrame.minX + 24,
                y: visibleFrame.maxY - size.height - 24
            )
        case .topRight:
            CGPoint(
                x: visibleFrame.maxX - size.width - 24,
                y: visibleFrame.maxY - size.height - 24
            )
        case .bottomLeft:
            CGPoint(
                x: visibleFrame.minX + 24,
                y: visibleFrame.minY + 24
            )
        case .bottomRight:
            CGPoint(
                x: visibleFrame.maxX - size.width - 24,
                y: visibleFrame.minY + 24
            )
        }
    }
}

final class OverlayWindowController: OverlayPresenting {
    var onPositionChange: ((CGPoint) -> Void)?
    var onDraggingStateChange: ((Bool) -> Void)?

    private var window: OverlayPanel?
    private var contentView: FlippedContentView?
    private var entryViews: [OverlayEntryView] = []
    private var isDraggingWindow = false

    var testingWindow: NSWindow? {
        window
    }

    var testingDisplayedTexts: [String] {
        entryViews.map(\.displayedText)
    }

    var testingEntryAlphas: [CGFloat] {
        entryViews.map(\.alphaValue)
    }

    func testingSimulateDragStateChange(_ isDragging: Bool) {
        handleDraggingStateChange(isDragging)
    }

    func show(entries: [OverlayHistoryEntry], settings: OverlayPresentationSettings) {
        guard !entries.isEmpty else {
            clearEntries()
            window?.orderOut(nil)
            return
        }

        let window = makeWindowIfNeeded()
        let contentView = makeContentViewIfNeeded(window: window)
        let orderedEntries = orderedEntries(from: entries, direction: settings.stackDirection)
        let latestEntryID = entries.first?.id

        clearEntries()

        let newEntryViews = orderedEntries.map { entry in
            let entryView = OverlayEntryView()
            entryView.configure(
                entry: entry,
                isLatest: entry.id == latestEntryID,
                settings: settings,
                paused: isDraggingWindow
            )
            return entryView
        }

        let width = newEntryViews
            .map(\.preferredSize.width)
            .max() ?? 140
        let gap: CGFloat = 10
        var y: CGFloat = 0

        for entryView in newEntryViews {
            let height = entryView.preferredSize.height
            entryView.frame = CGRect(x: 0, y: y, width: width, height: height)
            entryView.applyLayout(width: width)
            contentView.addSubview(entryView)
            y += height + gap
        }

        entryViews = newEntryViews

        let contentHeight = max(0, y - gap)
        let windowSize = CGSize(width: width, height: contentHeight)
        contentView.frame = CGRect(origin: .zero, size: windowSize)
        window.setContentSize(windowSize)
        updateWindowFrame(window: window, settings: settings)
        window.orderFrontRegardless()
    }

    private func orderedEntries(from entries: [OverlayHistoryEntry], direction: OverlayStackDirection) -> [OverlayHistoryEntry] {
        switch direction {
        case .newestOnTop:
            entries
        case .newestOnBottom:
            entries.reversed()
        }
    }

    private func clearEntries() {
        for entryView in entryViews {
            entryView.removeFromSuperview()
        }
        entryViews.removeAll()
    }

    private func makeWindowIfNeeded() -> OverlayPanel {
        if let window {
            return window
        }

        let panel = OverlayPanel(
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
        panel.onDraggingStateChange = { [weak self] isDragging in
            self?.handleDraggingStateChange(isDragging)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidMove(_:)),
            name: NSWindow.didMoveNotification,
            object: panel
        )

        window = panel
        return panel
    }

    private func makeContentViewIfNeeded(window: NSPanel) -> FlippedContentView {
        if let contentView {
            return contentView
        }

        let contentView = FlippedContentView(frame: window.contentView?.bounds ?? .zero)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView = contentView
        self.contentView = contentView
        return contentView
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

    private func handleDraggingStateChange(_ isDragging: Bool) {
        isDraggingWindow = isDragging

        for entryView in entryViews {
            entryView.setPaused(isDragging)
        }

        onDraggingStateChange?(isDragging)
    }

    @objc
    private func handleWindowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        onPositionChange?(window.frame.origin)
    }
}

private final class OverlayEntryView: NSVisualEffectView {
    private let label = NSTextField(labelWithString: "")
    private var pendingFadeWorkItem: DispatchWorkItem?
    private var currentEntry: OverlayHistoryEntry?
    private var currentSettings: OverlayPresentationSettings?
    private var currentBaseAlpha: CGFloat = 1
    private(set) var preferredSize = CGSize(width: 140, height: 60)

    var displayedText: String {
        label.stringValue
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        pendingFadeWorkItem?.cancel()
    }

    override var mouseDownCanMoveWindow: Bool {
        true
    }

    func configure(
        entry: OverlayHistoryEntry,
        isLatest: Bool,
        settings: OverlayPresentationSettings,
        paused: Bool
    ) {
        currentEntry = entry
        currentSettings = settings
        currentBaseAlpha = CGFloat(settings.overlayOpacity) * (isLatest ? 1.0 : 0.78)

        material = .hudWindow
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 16

        label.stringValue = entry.text
        label.font = .monospacedSystemFont(
            ofSize: max(14, settings.overlayFontSize - (isLatest ? 0 : 1)),
            weight: isLatest ? .semibold : .medium
        )
        label.textColor = .white.withAlphaComponent(isLatest ? 1.0 : 0.92)
        label.sizeToFit()

        let contentSize = label.fittingSize
        preferredSize = CGSize(
            width: min(max(contentSize.width + 40, 140), 420),
            height: max(contentSize.height + 28, 54)
        )

        if paused {
            pendingFadeWorkItem?.cancel()
            layer?.removeAllAnimations()
        } else {
            applyFadeSchedule()
        }
    }

    func applyLayout(width: CGFloat) {
        frame.size = CGSize(width: width, height: preferredSize.height)
        label.frame = CGRect(
            x: 20,
            y: (preferredSize.height - label.fittingSize.height) / 2,
            width: width - 40,
            height: label.fittingSize.height
        )
    }

    func setPaused(_ paused: Bool) {
        guard currentEntry != nil, currentSettings != nil else { return }

        if paused {
            pendingFadeWorkItem?.cancel()
            let snapshotAlpha = (layer?.presentation()?.opacity).map { CGFloat($0) } ?? alphaValue
            layer?.removeAllAnimations()
            alphaValue = snapshotAlpha
            return
        }

        applyFadeSchedule()
    }

    private func setup() {
        label.alignment = .center
        label.lineBreakMode = .byTruncatingMiddle
        addSubview(label)
    }

    private func applyFadeSchedule() {
        guard let currentEntry, let currentSettings else { return }

        pendingFadeWorkItem?.cancel()
        layer?.removeAllAnimations()

        let elapsed = Date().timeIntervalSince(currentEntry.updatedAt)
        let fadeDelay = currentSettings.fadeDelay
        let fadeDuration = currentSettings.fadeDuration
        let fadeElapsed = elapsed - fadeDelay

        if fadeElapsed >= fadeDuration {
            alphaValue = 0
            return
        }

        if fadeElapsed <= 0 {
            alphaValue = currentBaseAlpha
            let workItem = DispatchWorkItem { [weak self] in
                self?.beginFade(duration: fadeDuration)
            }
            pendingFadeWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + (fadeDelay - elapsed), execute: workItem)
            return
        }

        let progress = max(0, min(1, fadeElapsed / fadeDuration))
        alphaValue = currentBaseAlpha * (1 - progress)
        beginFade(duration: fadeDuration - fadeElapsed)
    }

    private func beginFade(duration: TimeInterval) {
        guard duration > 0 else {
            alphaValue = 0
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            animator().alphaValue = 0
        }
    }
}

private final class FlippedContentView: NSView {
    override var isFlipped: Bool {
        true
    }
}

private final class OverlayPanel: NSPanel {
    var onDraggingStateChange: ((Bool) -> Void)?

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    override func mouseDown(with event: NSEvent) {
        onDraggingStateChange?(true)
        super.mouseDown(with: event)
        onDraggingStateChange?(false)
    }
}

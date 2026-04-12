import Combine
import Foundation

enum DisplayMode: String, CaseIterable, Identifiable {
    case modifierOnly
    case modifiedKeys
    case allKeys

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .modifierOnly:
            "Modifier Only"
        case .modifiedKeys:
            "Modified Keys"
        case .allKeys:
            "All Keys"
        }
    }
}

enum OverlayStackDirection: String, CaseIterable, Identifiable {
    case newestOnTop
    case newestOnBottom

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .newestOnTop:
            "Newest On Top"
        case .newestOnBottom:
            "Newest On Bottom"
        }
    }
}

enum OverlayAnchor: String, CaseIterable, Identifiable {
    case topCenter
    case bottomCenter
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .topCenter:
            "Top Center"
        case .bottomCenter:
            "Bottom Center"
        case .topLeft:
            "Top Left"
        case .topRight:
            "Top Right"
        case .bottomLeft:
            "Bottom Left"
        case .bottomRight:
            "Bottom Right"
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var captureEnabled: Bool {
        didSet { defaults.set(captureEnabled, forKey: Keys.captureEnabled) }
    }

    @Published var overlayAnchor: OverlayAnchor {
        didSet {
            defaults.set(overlayAnchor.rawValue, forKey: Keys.overlayAnchor)
            if customOverlayOrigin != nil {
                customOverlayOrigin = nil
            }
        }
    }

    @Published var overlayOpacity: Double {
        didSet { defaults.set(overlayOpacity, forKey: Keys.overlayOpacity) }
    }

    @Published var overlayFontSize: Double {
        didSet { defaults.set(overlayFontSize, forKey: Keys.overlayFontSize) }
    }

    @Published var fadeDelay: Double {
        didSet { defaults.set(fadeDelay, forKey: Keys.fadeDelay) }
    }

    @Published var fadeDuration: Double {
        didSet { defaults.set(fadeDuration, forKey: Keys.fadeDuration) }
    }

    @Published var overlayMergeWindow: Double {
        didSet { defaults.set(overlayMergeWindow, forKey: Keys.overlayMergeWindow) }
    }

    @Published var overlayStackMaxCount: Int {
        didSet { defaults.set(overlayStackMaxCount, forKey: Keys.overlayStackMaxCount) }
    }

    @Published var overlayStackDirection: OverlayStackDirection {
        didSet { defaults.set(overlayStackDirection.rawValue, forKey: Keys.overlayStackDirection) }
    }

    @Published var displayMode: DisplayMode {
        didSet { defaults.set(displayMode.rawValue, forKey: Keys.displayMode) }
    }

    @Published var showMouseClicks: Bool {
        didSet { defaults.set(showMouseClicks, forKey: Keys.showMouseClicks) }
    }

    @Published var hasPromptedForInputMonitoring: Bool {
        didSet { defaults.set(hasPromptedForInputMonitoring, forKey: Keys.hasPromptedForInputMonitoring) }
    }

    @Published var customOverlayOrigin: CGPoint? {
        didSet { persistCustomOverlayOrigin(customOverlayOrigin) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        captureEnabled = defaults.object(forKey: Keys.captureEnabled) as? Bool ?? false
        overlayAnchor = OverlayAnchor(rawValue: defaults.string(forKey: Keys.overlayAnchor) ?? "") ?? .topCenter
        overlayOpacity = defaults.object(forKey: Keys.overlayOpacity) as? Double ?? 0.94
        overlayFontSize = defaults.object(forKey: Keys.overlayFontSize) as? Double ?? 22
        fadeDelay = defaults.object(forKey: Keys.fadeDelay) as? Double ?? 1.2
        fadeDuration = defaults.object(forKey: Keys.fadeDuration) as? Double ?? 0.22
        overlayMergeWindow = defaults.object(forKey: Keys.overlayMergeWindow) as? Double ?? 0.6
        overlayStackMaxCount = defaults.object(forKey: Keys.overlayStackMaxCount) as? Int ?? 5
        overlayStackDirection = OverlayStackDirection(rawValue: defaults.string(forKey: Keys.overlayStackDirection) ?? "") ?? .newestOnTop
        displayMode = DisplayMode(rawValue: defaults.string(forKey: Keys.displayMode) ?? "") ?? .allKeys
        showMouseClicks = defaults.object(forKey: Keys.showMouseClicks) as? Bool ?? false
        hasPromptedForInputMonitoring = defaults.object(forKey: Keys.hasPromptedForInputMonitoring) as? Bool ?? false
        customOverlayOrigin = Self.loadCustomOverlayOrigin(defaults: defaults)
    }

    private enum Keys {
        static let captureEnabled = "captureEnabled"
        static let overlayAnchor = "overlayAnchor"
        static let overlayOpacity = "overlayOpacity"
        static let overlayFontSize = "overlayFontSize"
        static let fadeDelay = "fadeDelay"
        static let fadeDuration = "fadeDuration"
        static let overlayMergeWindow = "overlayMergeWindow"
        static let overlayStackMaxCount = "overlayStackMaxCount"
        static let overlayStackDirection = "overlayStackDirection"
        static let displayMode = "displayMode"
        static let showMouseClicks = "showMouseClicks"
        static let hasPromptedForInputMonitoring = "hasPromptedForInputMonitoring"
        static let customOverlayOriginX = "customOverlayOriginX"
        static let customOverlayOriginY = "customOverlayOriginY"
    }

    private func persistCustomOverlayOrigin(_ point: CGPoint?) {
        if let point {
            defaults.set(point.x, forKey: Keys.customOverlayOriginX)
            defaults.set(point.y, forKey: Keys.customOverlayOriginY)
        } else {
            defaults.removeObject(forKey: Keys.customOverlayOriginX)
            defaults.removeObject(forKey: Keys.customOverlayOriginY)
        }
    }

    private static func loadCustomOverlayOrigin(defaults: UserDefaults) -> CGPoint? {
        guard
            defaults.object(forKey: Keys.customOverlayOriginX) != nil,
            defaults.object(forKey: Keys.customOverlayOriginY) != nil
        else {
            return nil
        }

        return CGPoint(
            x: defaults.double(forKey: Keys.customOverlayOriginX),
            y: defaults.double(forKey: Keys.customOverlayOriginY)
        )
    }

    func resetCustomOverlayOrigin() {
        customOverlayOrigin = nil
    }
}

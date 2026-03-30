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
            return "Modifier Only"
        case .modifiedKeys:
            return "Modified Keys"
        case .allKeys:
            return "All Keys"
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
            return "Top Center"
        case .bottomCenter:
            return "Bottom Center"
        case .topLeft:
            return "Top Left"
        case .topRight:
            return "Top Right"
        case .bottomLeft:
            return "Bottom Left"
        case .bottomRight:
            return "Bottom Right"
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var captureEnabled: Bool {
        didSet { defaults.set(captureEnabled, forKey: Keys.captureEnabled) }
    }

    @Published var overlayAnchor: OverlayAnchor {
        didSet { defaults.set(overlayAnchor.rawValue, forKey: Keys.overlayAnchor) }
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

    @Published var displayMode: DisplayMode {
        didSet { defaults.set(displayMode.rawValue, forKey: Keys.displayMode) }
    }

    @Published var showMouseClicks: Bool {
        didSet { defaults.set(showMouseClicks, forKey: Keys.showMouseClicks) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        self.captureEnabled = defaults.object(forKey: Keys.captureEnabled) as? Bool ?? false
        self.overlayAnchor = OverlayAnchor(rawValue: defaults.string(forKey: Keys.overlayAnchor) ?? "") ?? .topCenter
        self.overlayOpacity = defaults.object(forKey: Keys.overlayOpacity) as? Double ?? 0.94
        self.overlayFontSize = defaults.object(forKey: Keys.overlayFontSize) as? Double ?? 28
        self.fadeDelay = defaults.object(forKey: Keys.fadeDelay) as? Double ?? 1.2
        self.fadeDuration = defaults.object(forKey: Keys.fadeDuration) as? Double ?? 0.22
        self.displayMode = DisplayMode(rawValue: defaults.string(forKey: Keys.displayMode) ?? "") ?? .allKeys
        self.showMouseClicks = defaults.object(forKey: Keys.showMouseClicks) as? Bool ?? false
    }

    private enum Keys {
        static let captureEnabled = "captureEnabled"
        static let overlayAnchor = "overlayAnchor"
        static let overlayOpacity = "overlayOpacity"
        static let overlayFontSize = "overlayFontSize"
        static let fadeDelay = "fadeDelay"
        static let fadeDuration = "fadeDuration"
        static let displayMode = "displayMode"
        static let showMouseClicks = "showMouseClicks"
    }
}

import Foundation
import OSLog
import ServiceManagement

enum LaunchAtLoginState: Equatable {
    case unavailable
    case disabled
    case enabled
    case requiresApproval
    case notFound

    var isEnabled: Bool {
        switch self {
        case .enabled, .requiresApproval:
            true
        case .unavailable, .disabled, .notFound:
            false
        }
    }

    var description: String {
        switch self {
        case .unavailable:
            "Unavailable"
        case .disabled:
            "Off"
        case .enabled:
            "On"
        case .requiresApproval:
            "Needs approval in Login Items"
        case .notFound:
            "Login item not found"
        }
    }

    var hint: String? {
        switch self {
        case .requiresApproval:
            "Approve KeyGlass in System Settings > General > Login Items to finish enabling start at login."
        case .notFound:
            "The app could not find its login item registration. Reinstalling or rebuilding the app may be required."
        case .unavailable, .disabled, .enabled:
            nil
        }
    }
}

@MainActor
protocol LaunchAtLoginManaging {
    func currentState() -> LaunchAtLoginState
    func setEnabled(_ enabled: Bool) throws -> LaunchAtLoginState
}

@MainActor
final class StubLaunchAtLoginManager: LaunchAtLoginManaging {
    private(set) var currentValue: LaunchAtLoginState
    private(set) var setCalls: [Bool] = []
    var nextError: Error?

    init(initialState: LaunchAtLoginState = .disabled) {
        currentValue = initialState
    }

    func currentState() -> LaunchAtLoginState {
        currentValue
    }

    func setEnabled(_ enabled: Bool) throws -> LaunchAtLoginState {
        setCalls.append(enabled)

        if let nextError {
            self.nextError = nil
            throw nextError
        }

        currentValue = enabled ? .enabled : .disabled
        return currentValue
    }
}

@MainActor
struct SystemLaunchAtLoginManager: LaunchAtLoginManaging {
    private let logger = Logger(subsystem: "com.mkusaka.KeyGlass", category: "LaunchAtLogin")

    func currentState() -> LaunchAtLoginState {
        guard #available(macOS 13.0, *) else {
            return .unavailable
        }

        let service = SMAppService.mainApp
        let state = Self.state(for: service.status)
        logger.notice("currentState -> \(state.description, privacy: .public)")
        return state
    }

    func setEnabled(_ enabled: Bool) throws -> LaunchAtLoginState {
        guard #available(macOS 13.0, *) else {
            return .unavailable
        }

        let service = SMAppService.mainApp
        logger.notice("setEnabled enabled=\(enabled, privacy: .public)")

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            logger.error("setEnabled failed error=\(String(describing: error), privacy: .public)")
            throw error
        }

        let state = Self.state(for: service.status)
        logger.notice("setEnabled finished state=\(state.description, privacy: .public)")
        return state
    }

    @available(macOS 13.0, *)
    private static func state(for status: SMAppService.Status) -> LaunchAtLoginState {
        switch status {
        case .notRegistered:
            return .disabled
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        @unknown default:
            return .notFound
        }
    }
}

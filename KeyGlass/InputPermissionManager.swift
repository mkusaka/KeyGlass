import ApplicationServices
import Foundation

enum InputPermissionState: Equatable {
    case granted
    case requiresApproval

    var isGranted: Bool {
        if case .granted = self {
            return true
        }

        return false
    }

    var description: String {
        switch self {
        case .granted:
            return "Granted"
        case .requiresApproval:
            return "Input Monitoring required"
        }
    }
}

protocol InputPermissionManaging {
    func currentState() -> InputPermissionState
    @discardableResult
    func requestAccess() -> InputPermissionState
}

struct StubInputPermissionManager: InputPermissionManaging {
    let state: InputPermissionState

    func currentState() -> InputPermissionState {
        state
    }

    func requestAccess() -> InputPermissionState {
        state
    }
}

struct SystemInputPermissionManager: InputPermissionManaging {
    func currentState() -> InputPermissionState {
        if #available(macOS 10.15, *) {
            return CGPreflightListenEventAccess() ? .granted : .requiresApproval
        }

        return AXIsProcessTrusted() ? .granted : .requiresApproval
    }

    func requestAccess() -> InputPermissionState {
        if #available(macOS 10.15, *) {
            _ = CGRequestListenEventAccess()
        } else {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }

        return currentState()
    }
}

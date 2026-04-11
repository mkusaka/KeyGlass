import ApplicationServices
import Foundation
import OSLog

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
    private let logger = Logger(subsystem: "com.mkusaka.KeyGlass", category: "InputPermission")

    func currentState() -> InputPermissionState {
        let state: InputPermissionState

        if #available(macOS 10.15, *) {
            state = CGPreflightListenEventAccess() ? .granted : .requiresApproval
        } else {
            state = AXIsProcessTrusted() ? .granted : .requiresApproval
        }

        logger.notice("currentState -> \(state.description, privacy: .public)")
        return state
    }

    func requestAccess() -> InputPermissionState {
        logger.notice("requestAccess started")

        if #available(macOS 10.15, *) {
            let requestResult = CGRequestListenEventAccess()
            logger.notice("CGRequestListenEventAccess returned \(requestResult, privacy: .public)")
        } else {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            let requestResult = AXIsProcessTrustedWithOptions(options)
            logger.notice("AXIsProcessTrustedWithOptions returned \(requestResult, privacy: .public)")
        }

        let state = currentState()
        logger.notice("requestAccess finished state=\(state.description, privacy: .public)")
        return state
    }
}

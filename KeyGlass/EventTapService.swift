import AppKit
import CoreGraphics
import Foundation
import OSLog

struct CapturedInput: Equatable {
    let kind: CapturedInputKind
    let keyCode: UInt16
    let modifierFlags: NSEvent.ModifierFlags
}

enum CapturedInputKind: Equatable {
    case keyDown
    case flagsChanged
    case leftMouseDown
    case rightMouseDown
    case otherMouseDown
}

enum EventTapError: Error, LocalizedError {
    case tapCreationFailed

    var errorDescription: String? {
        switch self {
        case .tapCreationFailed:
            "Failed to create the event tap."
        }
    }
}

protocol EventTapServicing: AnyObject {
    var isRunning: Bool { get }
    func start(handler: @escaping (CapturedInput) -> Void) throws
    func stop()
}

final class NoOpEventTapService: EventTapServicing {
    private(set) var isRunning = false

    func start(handler _: @escaping (CapturedInput) -> Void) throws {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }
}

final class SystemEventTapService: EventTapServicing {
    private(set) var isRunning = false

    private let logger = Logger(subsystem: "com.mkusaka.KeyGlass", category: "EventTap")
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var handler: ((CapturedInput) -> Void)?

    func start(handler: @escaping (CapturedInput) -> Void) throws {
        guard !isRunning else {
            logger.notice("start ignored because event tap is already running")
            return
        }

        logger.notice("start requested")
        self.handler = handler
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let callback: CGEventTapCallBack = { _, eventType, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let service = Unmanaged<SystemEventTapService>.fromOpaque(userInfo).takeUnretainedValue()
            service.handle(eventType: eventType, event: event)
            return Unmanaged.passUnretained(event)
        }

        let eventMask =
            CGEventMask(1 << CGEventType.keyDown.rawValue) |
            CGEventMask(1 << CGEventType.flagsChanged.rawValue) |
            CGEventMask(1 << CGEventType.leftMouseDown.rawValue) |
            CGEventMask(1 << CGEventType.rightMouseDown.rawValue) |
            CGEventMask(1 << CGEventType.otherMouseDown.rawValue)

        let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: context
        )

        guard let eventTap else {
            logger.error("tapCreate failed")
            self.handler = nil
            throw EventTapError.tapCreationFailed
        }

        self.eventTap = eventTap
        eventTapSource = CFMachPortCreateRunLoopSource(nil, eventTap, 0)

        if let eventTapSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
        }

        CGEvent.tapEnable(tap: eventTap, enable: true)
        isRunning = true
        logger.notice("start succeeded")
    }

    func stop() {
        logger.notice("stop requested")
        if let eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
            CFRunLoopSourceInvalidate(eventTapSource)
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }

        eventTap = nil
        eventTapSource = nil
        handler = nil
        isRunning = false
        logger.notice("stop finished")
    }

    private func handle(eventType: CGEventType, event: CGEvent) {
        switch eventType {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            logger.notice("tap disabled by system eventType=\(String(describing: eventType), privacy: .public); re-enabling")
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }

        case .keyDown:
            handler?(
                CapturedInput(
                    kind: .keyDown,
                    keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
                    modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
                )
            )

        case .flagsChanged:
            handler?(
                CapturedInput(
                    kind: .flagsChanged,
                    keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
                    modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
                )
            )

        case .leftMouseDown:
            handler?(
                CapturedInput(
                    kind: .leftMouseDown,
                    keyCode: 0,
                    modifierFlags: []
                )
            )

        case .rightMouseDown:
            handler?(
                CapturedInput(
                    kind: .rightMouseDown,
                    keyCode: 0,
                    modifierFlags: []
                )
            )

        case .otherMouseDown:
            handler?(
                CapturedInput(
                    kind: .otherMouseDown,
                    keyCode: 0,
                    modifierFlags: []
                )
            )

        default:
            break
        }
    }
}

final class ScriptedEventTapService: EventTapServicing {
    private(set) var isRunning = false

    private let script: [CapturedInput]
    private var handler: ((CapturedInput) -> Void)?
    private var pendingWorkItems: [DispatchWorkItem] = []

    init(script: String?) {
        self.script = Self.parse(script: script)
    }

    func start(handler: @escaping (CapturedInput) -> Void) throws {
        guard !isRunning else { return }

        isRunning = true
        self.handler = handler
        pendingWorkItems.removeAll()

        for (index, input) in script.enumerated() {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, isRunning else { return }
                self.handler?(input)
            }

            pendingWorkItems.append(workItem)
            let delay = 0.12 + (Double(index) * 0.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    func stop() {
        pendingWorkItems.forEach { $0.cancel() }
        pendingWorkItems.removeAll()
        handler = nil
        isRunning = false
    }

    private static func parse(script: String?) -> [CapturedInput] {
        guard let script, !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        return script
            .split(separator: ";")
            .compactMap { entry in
                let parts = entry.split(separator: ":", omittingEmptySubsequences: false)
                guard parts.count == 3,
                      let kind = CapturedInputKind(scriptToken: String(parts[0])),
                      let keyCode = UInt16(parts[1])
                else {
                    return nil
                }

                return CapturedInput(
                    kind: kind,
                    keyCode: keyCode,
                    modifierFlags: NSEvent.ModifierFlags(scriptToken: String(parts[2]))
                )
            }
    }
}

private extension CapturedInputKind {
    init?(scriptToken: String) {
        switch scriptToken {
        case "keyDown":
            self = .keyDown
        case "flagsChanged":
            self = .flagsChanged
        case "leftMouseDown":
            self = .leftMouseDown
        case "rightMouseDown":
            self = .rightMouseDown
        case "otherMouseDown":
            self = .otherMouseDown
        default:
            return nil
        }
    }
}

private extension NSEvent.ModifierFlags {
    init(scriptToken: String) {
        if scriptToken.isEmpty || scriptToken == "none" {
            self = []
            return
        }

        self = scriptToken
            .split(separator: ",")
            .reduce(into: NSEvent.ModifierFlags()) { result, token in
                switch token {
                case "capsLock":
                    result.insert(.capsLock)
                case "shift":
                    result.insert(.shift)
                case "control":
                    result.insert(.control)
                case "option":
                    result.insert(.option)
                case "command":
                    result.insert(.command)
                case "function":
                    result.insert(.function)
                default:
                    break
                }
            }
    }
}

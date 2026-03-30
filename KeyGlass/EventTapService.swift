import AppKit
import CoreGraphics
import Foundation

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
            return "Failed to create the event tap."
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

    func start(handler: @escaping (CapturedInput) -> Void) throws {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }
}

final class SystemEventTapService: EventTapServicing {
    private(set) var isRunning = false

    private var keyTap: CFMachPort?
    private var keyTapSource: CFRunLoopSource?
    private var flagsTap: CFMachPort?
    private var flagsTapSource: CFRunLoopSource?
    private var handler: ((CapturedInput) -> Void)?

    func start(handler: @escaping (CapturedInput) -> Void) throws {
        guard !isRunning else { return }

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

        let keyMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let flagsMask =
            CGEventMask(1 << CGEventType.flagsChanged.rawValue) |
            CGEventMask(1 << CGEventType.leftMouseDown.rawValue) |
            CGEventMask(1 << CGEventType.rightMouseDown.rawValue) |
            CGEventMask(1 << CGEventType.otherMouseDown.rawValue)

        let keyTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: keyMask,
            callback: callback,
            userInfo: context
        )

        let flagsTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: flagsMask,
            callback: callback,
            userInfo: context
        )

        guard let keyTap, let flagsTap else {
            self.handler = nil
            throw EventTapError.tapCreationFailed
        }

        self.keyTap = keyTap
        self.flagsTap = flagsTap

        keyTapSource = CFMachPortCreateRunLoopSource(nil, keyTap, 0)
        flagsTapSource = CFMachPortCreateRunLoopSource(nil, flagsTap, 0)

        if let keyTapSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), keyTapSource, .commonModes)
        }

        if let flagsTapSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), flagsTapSource, .commonModes)
        }

        CGEvent.tapEnable(tap: keyTap, enable: true)
        CGEvent.tapEnable(tap: flagsTap, enable: true)
        isRunning = true
    }

    func stop() {
        if let keyTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), keyTapSource, .commonModes)
            CFRunLoopSourceInvalidate(keyTapSource)
        }

        if let flagsTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), flagsTapSource, .commonModes)
            CFRunLoopSourceInvalidate(flagsTapSource)
        }

        if let keyTap {
            CFMachPortInvalidate(keyTap)
        }

        if let flagsTap {
            CFMachPortInvalidate(flagsTap)
        }

        keyTap = nil
        keyTapSource = nil
        flagsTap = nil
        flagsTapSource = nil
        handler = nil
        isRunning = false
    }

    private func handle(eventType: CGEventType, event: CGEvent) {
        switch eventType {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let keyTap {
                CGEvent.tapEnable(tap: keyTap, enable: true)
            }

            if let flagsTap {
                CGEvent.tapEnable(tap: flagsTap, enable: true)
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

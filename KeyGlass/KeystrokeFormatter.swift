import AppKit
import Carbon.HIToolbox
import Foundation

@MainActor
protocol KeyTranslating {
    func string(for keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> String?
}

@MainActor
final class SystemKeyTranslator: KeyTranslating {
    private var layoutData: Data?
    private var selectedInputSourceObserver: NSObjectProtocol?

    init(notificationCenter: DistributedNotificationCenter = .default()) {
        refreshLayoutData()
        selectedInputSourceObserver = notificationCenter.addObserver(
            forName: Notification.Name(rawValue: kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshLayoutData()
            }
        }
    }

    deinit {
        if let selectedInputSourceObserver {
            DistributedNotificationCenter.default().removeObserver(selectedInputSourceObserver)
        }
    }

    func string(for keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> String? {
        refreshLayoutData()

        guard let layoutData else {
            return nil
        }

        let translationFlags = modifierFlags.intersection([.shift, .option, .capsLock])
        let modifierKeyState = UInt32((translationFlags.rawValue >> 16) & 0xFF)
        let keyboardType = UInt32(LMGetKbdType())
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 8)

        let status = layoutData.withUnsafeBytes { rawBufferPointer -> OSStatus in
            guard let baseAddress = rawBufferPointer.baseAddress else {
                return OSStatus(paramErr)
            }

            let keyboardLayout = baseAddress.assumingMemoryBound(to: UCKeyboardLayout.self)
            return UCKeyTranslate(
                keyboardLayout,
                keyCode,
                UInt16(kUCKeyActionDisplay),
                modifierKeyState,
                keyboardType,
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
        }

        guard status == noErr, length > 0 else {
            return nil
        }

        return String(utf16CodeUnits: characters, count: length)
    }

    private func refreshLayoutData() {
        let currentInputSource =
            TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() ??
            TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue()

        guard let currentInputSource else {
            layoutData = nil
            return
        }

        guard let rawLayoutData = TISGetInputSourceProperty(currentInputSource, kTISPropertyUnicodeKeyLayoutData) else {
            layoutData = nil
            return
        }

        let unicodeLayoutData = unsafeBitCast(rawLayoutData, to: CFData.self)
        layoutData = unicodeLayoutData as Data
    }
}

@MainActor
struct StubKeyTranslator: KeyTranslating {
    let values: [UInt16: String]

    func string(for keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> String? {
        values[keyCode]
    }
}

@MainActor
final class KeystrokeFormatter {
    private let translator: KeyTranslating

    private let specialKeys: [UInt16: String] = [
        36: "↩",
        48: "⇥",
        49: "␣",
        51: "⌫",
        53: "⎋",
        64: "F17",
        71: "⌧",
        76: "↩",
        79: "F18",
        80: "F19",
        90: "F20",
        96: "F5",
        97: "F6",
        98: "F7",
        99: "F3",
        100: "F8",
        101: "F9",
        102: "英数",
        103: "F11",
        104: "かな",
        105: "F13",
        106: "F16",
        107: "F14",
        109: "F10",
        111: "F12",
        113: "F15",
        114: "Help",
        115: "↖",
        116: "⇞",
        117: "⌦",
        118: "F4",
        119: "↘",
        120: "F2",
        121: "⇟",
        122: "F1",
        123: "←",
        124: "→",
        125: "↓",
        126: "↑",
    ]

    init(translator: (any KeyTranslating)? = nil) {
        self.translator = translator ?? SystemKeyTranslator()
    }

    func string(for capturedInput: CapturedInput, displayMode: DisplayMode) -> String? {
        switch capturedInput.kind {
        case .leftMouseDown:
            return "L Click"

        case .rightMouseDown:
            return "R Click"

        case .otherMouseDown:
            return "Click"

        case .flagsChanged:
            let modifiers = modifierGlyphs(from: capturedInput.modifierFlags)
            return modifiers.isEmpty ? nil : modifiers

        case .keyDown:
            let modifiers = modifierGlyphs(from: capturedInput.modifierFlags)
            let key = specialKeys[capturedInput.keyCode] ?? translatedKey(for: capturedInput.keyCode, flags: capturedInput.modifierFlags)

            switch displayMode {
            case .modifierOnly:
                return nil
            case .modifiedKeys:
                guard !modifiers.isEmpty else { return nil }
                return modifiers + key
            case .allKeys:
                return modifiers + key
            }
        }
    }

    private func translatedKey(for keyCode: UInt16, flags: NSEvent.ModifierFlags) -> String {
        let translated = translator.string(for: keyCode, modifierFlags: flags) ?? "Key \(keyCode)"

        guard translated.count == 1 else {
            return translated
        }

        if flags.contains(.shift) || flags.contains(.command) || flags.contains(.control) {
            return translated.uppercased()
        }

        return translated
    }

    private func modifierGlyphs(from flags: NSEvent.ModifierFlags) -> String {
        let filteredFlags = flags.intersection(.deviceIndependentFlagsMask)
        var output = ""

        if filteredFlags.contains(.control) {
            output += "⌃"
        }

        if filteredFlags.contains(.option) {
            output += "⌥"
        }

        if filteredFlags.contains(.shift) {
            output += "⇧"
        }

        if filteredFlags.contains(.command) {
            output += "⌘"
        }

        return output
    }
}

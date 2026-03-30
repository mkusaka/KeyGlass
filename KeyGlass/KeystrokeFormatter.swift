import AppKit
import Foundation

final class KeystrokeFormatter {
    private let specialKeys: [UInt16: String] = [
        36: "↩",
        48: "⇥",
        49: "␣",
        51: "⌫",
        53: "⎋",
        76: "↩",
        117: "⌦",
        123: "←",
        124: "→",
        125: "↓",
        126: "↑",
    ]

    private let plainKeys: [UInt16: String] = [
        0: "a",
        1: "s",
        2: "d",
        3: "f",
        4: "h",
        5: "g",
        6: "z",
        7: "x",
        8: "c",
        9: "v",
        11: "b",
        12: "q",
        13: "w",
        14: "e",
        15: "r",
        16: "y",
        17: "t",
        18: "1",
        19: "2",
        20: "3",
        21: "4",
        22: "6",
        23: "5",
        24: "=",
        25: "9",
        26: "7",
        27: "-",
        28: "8",
        29: "0",
        30: "]",
        31: "o",
        32: "u",
        33: "[",
        34: "i",
        35: "p",
        37: "l",
        38: "j",
        39: "'",
        40: "k",
        41: ";",
        42: "\\",
        43: ",",
        44: "/",
        45: "n",
        46: "m",
        47: ".",
        50: "`",
    ]

    func string(for capturedInput: CapturedInput, displayMode: DisplayMode) -> String? {
        switch capturedInput.kind {
        case .flagsChanged:
            let modifiers = modifierGlyphs(from: capturedInput.modifierFlags)
            return modifiers.isEmpty ? nil : modifiers

        case .keyDown:
            let modifiers = modifierGlyphs(from: capturedInput.modifierFlags)
            let key = specialKeys[capturedInput.keyCode] ?? plainKey(for: capturedInput.keyCode, flags: capturedInput.modifierFlags)

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

    private func plainKey(for keyCode: UInt16, flags: NSEvent.ModifierFlags) -> String {
        let base = plainKeys[keyCode] ?? "Key \(keyCode)"
        let shouldUppercase = flags.contains(.shift) || flags.contains(.command) || flags.contains(.control)

        guard shouldUppercase, base.count == 1 else {
            return base
        }

        return base.uppercased()
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

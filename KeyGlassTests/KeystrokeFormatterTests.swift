import AppKit
@testable import KeyGlass
import XCTest

@MainActor
final class KeystrokeFormatterTests: XCTestCase {
    func testTranslatorOutputIsUsedForPlainKeyRendering() {
        let formatter = KeystrokeFormatter(translator: StubKeyTranslator(values: [0: "a"]))

        let result = formatter.string(
            for: CapturedInput(kind: .keyDown, keyCode: 0, modifierFlags: []),
            displayMode: .allKeys
        )

        XCTAssertEqual(result, "a")
    }

    func testModifiedKeysModeFiltersPlainKeys() {
        let formatter = KeystrokeFormatter(translator: StubKeyTranslator(values: [0: "a"]))

        let result = formatter.string(
            for: CapturedInput(kind: .keyDown, keyCode: 0, modifierFlags: []),
            displayMode: .modifiedKeys
        )

        XCTAssertNil(result)
    }

    func testModifierOnlyFlagsChangedShowsModifierGlyphs() {
        let formatter = KeystrokeFormatter(translator: StubKeyTranslator(values: [:]))

        let result = formatter.string(
            for: CapturedInput(kind: .flagsChanged, keyCode: 56, modifierFlags: [.shift, .command]),
            displayMode: .modifierOnly
        )

        XCTAssertEqual(result, "⇧⌘")
    }

    func testSpecialKeysBypassTranslator() {
        let formatter = KeystrokeFormatter(translator: StubKeyTranslator(values: [123: "x", 102: "x"]))

        let leftArrow = formatter.string(
            for: CapturedInput(kind: .keyDown, keyCode: 123, modifierFlags: []),
            displayMode: .allKeys
        )
        let eisu = formatter.string(
            for: CapturedInput(kind: .keyDown, keyCode: 102, modifierFlags: []),
            displayMode: .allKeys
        )

        XCTAssertEqual(leftArrow, "←")
        XCTAssertEqual(eisu, "英数")
    }

    func testFunctionKeysAreRenderedExplicitly() {
        let formatter = KeystrokeFormatter(translator: StubKeyTranslator(values: [:]))

        let result = formatter.string(
            for: CapturedInput(kind: .keyDown, keyCode: 122, modifierFlags: []),
            displayMode: .allKeys
        )

        XCTAssertEqual(result, "F1")
    }

    func testModifierPrefixesRemainVisibleForTranslatedCharacters() {
        let formatter = KeystrokeFormatter(translator: StubKeyTranslator(values: [40: "k"]))

        let result = formatter.string(
            for: CapturedInput(kind: .keyDown, keyCode: 40, modifierFlags: [.command]),
            displayMode: .allKeys
        )

        XCTAssertEqual(result, "⌘K")
    }

    func testFallbackMapKeepsShortcutReadableWhenTranslatorReturnsNil() {
        let formatter = KeystrokeFormatter(translator: StubKeyTranslator(values: [:]))

        let result = formatter.string(
            for: CapturedInput(kind: .keyDown, keyCode: 40, modifierFlags: [.command]),
            displayMode: .allKeys
        )

        XCTAssertEqual(result, "⌘K")
    }

    func testMouseClicksAreRenderedExplicitly() {
        let formatter = KeystrokeFormatter(translator: StubKeyTranslator(values: [:]))

        let result = formatter.string(
            for: CapturedInput(kind: .leftMouseDown, keyCode: 0, modifierFlags: []),
            displayMode: .allKeys
        )

        XCTAssertEqual(result, "L Click")
    }
}

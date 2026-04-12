import XCTest

final class KeyGlassUITests: XCTestCase {
    private var app: XCUIApplication!

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testLiveKeyDownUpdatesOutputAndDiagnostics() throws {
        app = configuredApp(
            captureScript: "keyDown:48:shift",
            captureEnabled: true
        )

        app.launch()

        let outputValue = app.staticTexts["last-output-value"]
        XCTAssertTrue(outputValue.waitForExistence(timeout: 5))
        XCTAssertEqual(try label(of: outputValue, becomes: "⇧⇥"), "⇧⇥")

        let keyDownCountValue = app.staticTexts["live-keydown-count-value"]
        XCTAssertEqual(try label(of: keyDownCountValue, becomes: "1"), "1")

        let lastLiveEventValue = app.staticTexts["live-last-event-value"]
        XCTAssertEqual(
            try label(of: lastLiveEventValue, becomes: "keyDown keyCode=48 flags=shift"),
            "keyDown keyCode=48 flags=shift"
        )
    }

    func testModifierOnlyCaptureShowsDiagnosticHint() throws {
        app = configuredApp(
            captureScript: "flagsChanged:56:shift",
            captureEnabled: true
        )

        app.launch()

        let outputValue = app.staticTexts["last-output-value"]
        XCTAssertTrue(outputValue.waitForExistence(timeout: 5))
        XCTAssertEqual(try label(of: outputValue, becomes: "⇧"), "⇧")

        let modifierCountValue = app.staticTexts["live-modifier-count-value"]
        XCTAssertEqual(try label(of: modifierCountValue, becomes: "1"), "1")

        let keyDownCountValue = app.staticTexts["live-keydown-count-value"]
        XCTAssertEqual(keyDownCountValue.label, "0")

        let hint = app.staticTexts["live-capture-hint"]
        XCTAssertTrue(hint.waitForExistence(timeout: 5))
        XCTAssertTrue(hint.label.contains("Only modifier events have been seen so far"))
    }

    func testDiagnosticsDistinguishFilteredPlainKeyFromMissingKeyDown() throws {
        app = configuredApp(
            captureScript: "keyDown:0:none",
            captureEnabled: true,
            displayMode: "modifiedKeys"
        )

        app.launch()

        let outputValue = app.staticTexts["last-output-value"]
        XCTAssertTrue(outputValue.waitForExistence(timeout: 5))
        XCTAssertEqual(outputValue.label, "No input yet")

        let keyDownCountValue = app.staticTexts["live-keydown-count-value"]
        XCTAssertEqual(try label(of: keyDownCountValue, becomes: "1"), "1")

        let lastLiveEventValue = app.staticTexts["live-last-event-value"]
        XCTAssertEqual(
            try label(of: lastLiveEventValue, becomes: "keyDown keyCode=0 flags=none"),
            "keyDown keyCode=0 flags=none"
        )
    }

    func testRapidPlainInputMergesIntoSingleVisibleEntry() throws {
        app = configuredApp(
            captureScript: "keyDown:0:none;keyDown:1:none;keyDown:2:none",
            captureEnabled: true
        )

        app.launch()

        let outputValue = app.staticTexts["last-output-value"]
        XCTAssertTrue(outputValue.waitForExistence(timeout: 5))
        XCTAssertEqual(try label(of: outputValue, becomes: "asd"), "asd")
    }

    func testMergeWindowOverrideCanPreventRapidInputConcatenation() throws {
        app = configuredApp(
            captureScript: "keyDown:0:none;keyDown:1:none;keyDown:2:none",
            captureEnabled: true,
            mergeWindow: "0.01"
        )

        app.launch()

        let outputValue = app.staticTexts["last-output-value"]
        XCTAssertTrue(outputValue.waitForExistence(timeout: 5))
        XCTAssertEqual(try label(of: outputValue, becomes: "d"), "d")
    }

    func testDisplaySectionExposesHistoryControls() {
        app = configuredApp(
            captureScript: "",
            captureEnabled: false
        )

        app.launch()

        XCTAssertTrue(app.sliders["merge-window-slider"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.steppers["stack-max-count-stepper"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls["stack-direction-picker"].waitForExistence(timeout: 5))
    }

    private func configuredApp(
        captureScript: String,
        captureEnabled: Bool,
        displayMode: String? = nil,
        mergeWindow: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["KEYGLASS_UI_TEST_MODE"] = "1"
        app.launchEnvironment["KEYGLASS_DEFAULTS_SUITE"] = "KeyGlassUITests.\(UUID().uuidString)"
        app.launchEnvironment["KEYGLASS_UI_TEST_CAPTURE_SCRIPT"] = captureScript
        app.launchEnvironment["KEYGLASS_UI_TEST_CAPTURE_ENABLED"] = captureEnabled ? "1" : "0"

        if let displayMode {
            app.launchEnvironment["KEYGLASS_UI_TEST_DISPLAY_MODE"] = displayMode
        }

        if let mergeWindow {
            app.launchEnvironment["KEYGLASS_UI_TEST_MERGE_WINDOW"] = mergeWindow
        }

        return app
    }

    private func label(of element: XCUIElement, becomes expected: String, timeout: TimeInterval = 5) throws -> String {
        let predicate = NSPredicate(format: "label == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed)
        return element.label
    }
}

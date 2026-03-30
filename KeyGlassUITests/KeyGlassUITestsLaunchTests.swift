//
//  KeyGlassUITestsLaunchTests.swift
//  KeyGlassUITests
//
//  Created by Masatomo Kusaka on 2026/03/31.
//

import XCTest

final class KeyGlassUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        throw XCTSkip("XCUI runner hangs in this CLI environment. UI behavior is covered by hosted AppKit tests in KeyGlassTests.")
    }
}

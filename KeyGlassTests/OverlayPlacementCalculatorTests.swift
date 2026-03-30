import CoreGraphics
import XCTest
@testable import KeyGlass

final class OverlayPlacementCalculatorTests: XCTestCase {
    func testTargetVisibleFrameUsesScreenContainingMouse() {
        let leftScreen = OverlayScreenSnapshot(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 860)
        )
        let rightScreen = OverlayScreenSnapshot(
            frame: CGRect(x: 1440, y: 0, width: 1728, height: 1117),
            visibleFrame: CGRect(x: 1440, y: 0, width: 1728, height: 1077)
        )

        let visibleFrame = OverlayPlacementCalculator.targetVisibleFrame(
            mouseLocation: CGPoint(x: 1700, y: 400),
            screens: [leftScreen, rightScreen]
        )

        XCTAssertEqual(visibleFrame, rightScreen.visibleFrame)
    }

    func testTargetVisibleFrameFallsBackToFirstScreen() {
        let screen = OverlayScreenSnapshot(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 860)
        )

        let visibleFrame = OverlayPlacementCalculator.targetVisibleFrame(
            mouseLocation: CGPoint(x: -500, y: -500),
            screens: [screen]
        )

        XCTAssertEqual(visibleFrame, screen.visibleFrame)
    }

    func testOriginUsesRequestedAnchor() {
        let visibleFrame = CGRect(x: 100, y: 200, width: 1200, height: 800)
        let size = CGSize(width: 360, height: 92)

        let topRight = OverlayPlacementCalculator.origin(
            for: .topRight,
            size: size,
            visibleFrame: visibleFrame
        )
        let bottomLeft = OverlayPlacementCalculator.origin(
            for: .bottomLeft,
            size: size,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(topRight.x, visibleFrame.maxX - size.width - 24, accuracy: 0.001)
        XCTAssertEqual(topRight.y, visibleFrame.maxY - size.height - 24, accuracy: 0.001)
        XCTAssertEqual(bottomLeft.x, visibleFrame.minX + 24, accuracy: 0.001)
        XCTAssertEqual(bottomLeft.y, visibleFrame.minY + 24, accuracy: 0.001)
    }
}

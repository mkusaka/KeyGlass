import CoreGraphics
@testable import KeyGlass
import XCTest

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

    func testTargetVisibleFrameUsesLargestIntersectionForCustomOrigin() {
        let leftScreen = OverlayScreenSnapshot(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 860)
        )
        let rightScreen = OverlayScreenSnapshot(
            frame: CGRect(x: 1440, y: 0, width: 1728, height: 1117),
            visibleFrame: CGRect(x: 1440, y: 0, width: 1728, height: 1077)
        )
        let overlayFrame = CGRect(x: 1400, y: 120, width: 360, height: 92)

        let visibleFrame = OverlayPlacementCalculator.targetVisibleFrame(
            for: overlayFrame,
            screens: [leftScreen, rightScreen]
        )

        XCTAssertEqual(visibleFrame, rightScreen.visibleFrame)
    }

    func testClampedOriginKeepsCustomOriginInsideVisibleFrame() {
        let visibleFrame = CGRect(x: 100, y: 200, width: 1200, height: 800)
        let size = CGSize(width: 360, height: 92)

        let clampedOrigin = OverlayPlacementCalculator.clampedOrigin(
            CGPoint(x: -500, y: 5000),
            size: size,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(clampedOrigin.x, visibleFrame.minX + 24, accuracy: 0.001)
        XCTAssertEqual(clampedOrigin.y, visibleFrame.maxY - size.height - 24, accuracy: 0.001)
    }

    func testOriginClampsAnchoredPlacementWhenOverlayWouldBleedOffscreen() {
        let visibleFrame = CGRect(x: 100, y: 200, width: 320, height: 220)
        let size = CGSize(width: 280, height: 140)

        let origin = OverlayPlacementCalculator.origin(
            for: .topCenter,
            size: size,
            visibleFrame: visibleFrame
        )
        let overlayFrame = CGRect(origin: origin, size: size)

        XCTAssertGreaterThanOrEqual(overlayFrame.minX, visibleFrame.minX - 0.001)
        XCTAssertLessThanOrEqual(overlayFrame.maxX, visibleFrame.maxX + 0.001)
        XCTAssertGreaterThanOrEqual(overlayFrame.minY, visibleFrame.minY - 0.001)
        XCTAssertLessThanOrEqual(overlayFrame.maxY, visibleFrame.maxY + 0.001)
    }
}

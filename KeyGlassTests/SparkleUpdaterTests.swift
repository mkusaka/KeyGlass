import AppKit
@testable import KeyGlass
import XCTest

@MainActor
final class SparkleUpdaterTests: XCTestCase {
    func testUpdaterNotStartedBeforeLaunch() {
        let coordinator = makeCoordinator()

        XCTAssertFalse(coordinator.testingCanCheckForUpdates)
    }

    func testStatusMenuContainsCheckForUpdatesItem() {
        let coordinator = makeCoordinator()

        coordinator.applicationDidFinishLaunching()

        XCTAssertTrue(coordinator.testingStatusMenuItems.contains { item in
            item.title == "Check for Updates…"
        })
        XCTAssertTrue(coordinator.testingStatusMenuItems.contains { item in
            item.title == "About KeyGlass"
        })
        XCTAssertFalse(coordinator.testingCanCheckForUpdates)
    }

    func testBuildInfoValuesAreAvailable() {
        XCTAssertFalse(BuildInfo.version.isEmpty)
        XCTAssertFalse(BuildInfo.gitCommitHash.isEmpty)
        XCTAssertFalse(BuildInfo.gitCommitHashFull.isEmpty)
    }

    func testSparkleBuildVersionUsesPackedNumericRule() throws {
        XCTAssertEqual(try makeBuildVersion(from: "0.0.1"), "1")
        XCTAssertEqual(try makeBuildVersion(from: "0.0.2"), "2")
        XCTAssertEqual(try makeBuildVersion(from: "0.0.9"), "9")
        XCTAssertEqual(try makeBuildVersion(from: "0.1.0"), "100")
        XCTAssertEqual(try makeBuildVersion(from: "1.2.3"), "10203")
    }

    func testSparkleBuildVersionRejectsInvalidVersionFormat() {
        XCTAssertThrowsError(try makeBuildVersion(from: "1.0"))
        XCTAssertThrowsError(try makeBuildVersion(from: "1.0.0.0"))
        XCTAssertThrowsError(try makeBuildVersion(from: "a.b.c"))
    }

    private func makeCoordinator() -> AppCoordinator {
        AppCoordinator(
            launchConfiguration: LaunchConfiguration(
                isUITestMode: true,
                shouldOpenSettingsOnLaunch: false,
                shouldResetDefaults: false,
                defaultsSuiteName: "KeyGlassSparkleUpdaterTests"
            ),
            settingsStore: SettingsStore(defaults: UserDefaults(suiteName: "KeyGlassSparkleUpdaterTests")!),
            permissionManager: StubInputPermissionManager(state: .granted),
            eventTapService: NoOpEventTapService(),
            launchAtLoginManager: StubLaunchAtLoginManager(),
            formatter: KeystrokeFormatter(),
            overlayWindowController: NullOverlayPresenter()
        )
    }
}

private final class NullOverlayPresenter: OverlayPresenting {
    func show(entries _: [OverlayHistoryEntry], settings _: OverlayPresentationSettings) {}
}

private enum BuildVersionError: Error {
    case invalidFormat
    case invalidNumber
}

private func makeBuildVersion(from version: String) throws -> String {
    let components = version.split(separator: ".", omittingEmptySubsequences: false)
    guard components.count == 3 else {
        throw BuildVersionError.invalidFormat
    }

    guard
        let major = Int(components[0]),
        let minor = Int(components[1]),
        let patch = Int(components[2])
    else {
        throw BuildVersionError.invalidNumber
    }

    return String(major * 10000 + minor * 100 + patch)
}

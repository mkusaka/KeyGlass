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

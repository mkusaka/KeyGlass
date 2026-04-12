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
        XCTAssertFalse(coordinator.testingCanCheckForUpdates)
    }

    func testInfoPlistContainsFeedURL() throws {
        let bundle = try XCTUnwrap(hostAppBundle())
        XCTAssertEqual(
            bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            "https://mkusaka.github.io/KeyGlass/appcast.xml"
        )
    }

    func testInfoPlistContainsSharedPublicEDKey() throws {
        let bundle = try XCTUnwrap(hostAppBundle())
        XCTAssertEqual(
            bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
            "k3iDdoME7CuJwteINJWaU/qt/O9OF6AENSloZfmlhdo="
        )
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

    private func hostAppBundle() -> Bundle? {
        Bundle.allBundles.first { bundle in
            bundle.bundleIdentifier == "com.mkusaka.KeyGlass"
        }
    }
}

private final class NullOverlayPresenter: OverlayPresenting {
    func show(entries _: [OverlayHistoryEntry], settings _: OverlayPresentationSettings) {}
}

import XCTest
@testable import BetterCallSaul

final class AppLaunchScenarioTests: XCTestCase {
    func testSignaturePreviewStartsAtSignatureWithoutLiveServices() {
        let scenario = AppLaunchScenario(
            arguments: ["BetterCallSaul", "-signature-preview"]
        )

        XCTAssertEqual(scenario, .signaturePreview)
        XCTAssertEqual(scenario.initialPath, [.signature])
        XCTAssertFalse(scenario.usesBundledServices)
    }

    func testNormalLaunchUsesBundledServicesAndHome() {
        let scenario = AppLaunchScenario(arguments: ["BetterCallSaul"])

        XCTAssertEqual(scenario, .live)
        XCTAssertTrue(scenario.initialPath.isEmpty)
        XCTAssertTrue(scenario.usesBundledServices)
    }
}

import XCTest
@testable import BetterCallSaul

@MainActor
final class AppRouterTests: XCTestCase {
    func testSelectingToolsChangesActiveTab() {
        let router = AppRouter()

        router.select(.tools)

        XCTAssertEqual(router.selectedTab, .tools)
    }

    func testOpeningEvidenceAddsEvidenceRoute() {
        let router = AppRouter()

        router.open(.evidence)

        XCTAssertEqual(router.path, [.evidence])
    }

    func testResetClearsNavigationPath() {
        let router = AppRouter()
        router.open(.evidence)
        router.open(.document)

        router.reset()

        XCTAssertTrue(router.path.isEmpty)
    }

    func testSignatureRouteCanPrecedeReadyDocument() {
        let router = AppRouter()

        router.open(.signature)
        router.open(.document)

        XCTAssertEqual(router.path, [.signature, .document])
    }
}

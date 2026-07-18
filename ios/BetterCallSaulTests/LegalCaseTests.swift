import XCTest
@testable import BetterCallSaul

final class LegalCaseTests: XCTestCase {
    func testActiveFixtureMatchesApprovedConcept() {
        let legalCase = DemoFixtures.activeCase

        XCTAssertEqual(legalCase.amount, 24_900)
        XCTAssertEqual(legalCase.counterparty, "MegaPlus Kazakhstan")
        XCTAssertEqual(legalCase.status, .waitingForResponse)
        XCTAssertEqual(legalCase.evidence.count, 1)
    }

    func testToolsContainOnlySupportedProductionActions() {
        let tools = DemoFixtures.tools

        XCTAssertEqual(tools.count, 5)
        XCTAssertTrue(tools.allSatisfy { !$0.title.isEmpty })
        XCTAssertFalse(tools.contains { $0.title == "Временный номер" })
        XCTAssertFalse(tools.contains { $0.title == "Trial Card" })
    }
}

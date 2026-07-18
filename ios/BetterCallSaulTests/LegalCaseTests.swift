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

    func testWorkingToolsAreNotMarkedAsConcepts() {
        let working = DemoFixtures.tools.filter { $0.capability == .working }

        XCTAssertEqual(working.count, 5)
        XCTAssertTrue(working.allSatisfy { !$0.title.isEmpty })
    }
}

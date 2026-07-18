import XCTest
@testable import BetterCallSaul

final class DocumentDraftGeneratorTests: XCTestCase {
    func testConfirmedCaseFactsAppearInDraft() {
        let draft = DocumentDraftGenerator().makeDraft(
            from: DemoFixtures.activeCase,
            senderName: "Алим",
            createdAt: Date(timeIntervalSince1970: 1_774_000_000)
        )

        XCTAssertEqual(draft.caseNumber, DemoFixtures.activeCase.number)
        XCTAssertEqual(draft.recipient, "MegaPlus Kazakhstan")
        XCTAssertTrue(draft.title.contains("24 900 ₸"))
        XCTAssertTrue(draft.body.contains("24 900 ₸"))
        XCTAssertTrue(draft.body.contains("подписк"))
        XCTAssertEqual(draft.senderName, "Алим")
        XCTAssertEqual(draft.attachmentCount, 1)
    }

    func testMissingFactsAreMarkedForReviewInsteadOfInvented() {
        let legalCase = LegalCase(
            number: "BCS-TEST",
            type: .charge,
            title: "Возврат списания",
            counterparty: "",
            amount: nil,
            status: .draft,
            responseDeadline: nil,
            evidence: [],
            extractedFields: []
        )

        let draft = DocumentDraftGenerator().makeDraft(
            from: legalCase,
            senderName: "Алим",
            createdAt: Date(timeIntervalSince1970: 1_774_000_000)
        )

        XCTAssertEqual(draft.recipient, "[укажите получателя]")
        XCTAssertFalse(draft.title.contains("0 ₸"))
        XCTAssertFalse(draft.body.contains("MegaPlus"))
        XCTAssertTrue(draft.requiresReview)
    }
}

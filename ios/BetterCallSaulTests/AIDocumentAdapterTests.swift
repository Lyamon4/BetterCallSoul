import XCTest
@testable import BetterCallSaul

final class AIDocumentAdapterTests: XCTestCase {
    func testAdapterBuildsDraftFromTypedSectionsAndMarksUnresolvedIssues() {
        let sections = AIDocumentSections(
            recipient: "ТОО MegaPlus",
            subject: "Требование о возврате",
            facts: ["17 июля 2026 года списано 24 900 ₸"],
            demands: ["Вернуть 24 900 ₸", "Отменить продление"],
            responseDays: nil,
            attachmentDescription: "Копия чека",
            unresolvedIssues: ["Уточнить адрес получателя"]
        )

        let draft = AIDocumentAdapter().makeDraft(
            sections: sections,
            legalCase: DemoFixtures.activeCase,
            senderName: "Алим",
            createdAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(draft.title, "Требование о возврате")
        XCTAssertTrue(draft.body.contains("17 июля 2026 года"))
        XCTAssertTrue(draft.body.contains("Вернуть 24 900 ₸"))
        XCTAssertTrue(draft.reviewNotice.contains("Уточнить адрес получателя"))
        XCTAssertTrue(draft.requiresReview)
    }
}

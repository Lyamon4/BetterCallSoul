import XCTest
@testable import BetterCallSaul

final class AIDocumentAdapterTests: XCTestCase {
    func testAdapterBuildsDraftFromTypedSectionsAndMarksUnresolvedIssues() {
        let sections = AIDocumentSections(
            recipient: "ТОО MegaPlus",
            subject: "Требование о возврате",
            facts: ["17 июля 2026 года списано 24 900 ₸"],
            legalGrounds: [
                "Согласно пунктам 1 и 2 статьи 42-4 Закона Республики Казахстан «О защите прав потребителей» получатель обязан рассмотреть претензию и при несогласии предоставить мотивированный письменный ответ."
            ],
            demands: ["Вернуть 24 900 ₸", "Отменить продление"],
            responseDays: 10,
            nonComplianceActions: [
                "При отказе или отсутствии ответа обратиться в уполномоченный орган в сфере защиты прав потребителей."
            ],
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
        XCTAssertTrue(draft.body.contains("Правовые основания:"))
        XCTAssertTrue(draft.body.contains("статьи 42-4"))
        XCTAssertTrue(draft.body.contains("Вернуть 24 900 ₸"))
        XCTAssertTrue(draft.body.contains("10 календарных дней"))
        XCTAssertTrue(draft.body.contains("При отказе или отсутствии ответа"))
        XCTAssertTrue(draft.body.contains("Приложения:"))
        XCTAssertTrue(draft.body.contains("Копия чека"))
        XCTAssertTrue(draft.reviewNotice.contains("Уточнить адрес получателя"))
        XCTAssertTrue(draft.requiresReview)
    }

    func testAdapterMarksMissingLegalSectionsForReview() {
        let sections = AIDocumentSections(
            recipient: "ТОО MegaPlus",
            subject: "Требование о возврате",
            facts: ["Списано 24 900 ₸"],
            legalGrounds: [],
            demands: ["Вернуть 24 900 ₸"],
            responseDays: nil,
            nonComplianceActions: [],
            attachmentDescription: "Копия чека",
            unresolvedIssues: []
        )

        let draft = AIDocumentAdapter().makeDraft(
            sections: sections,
            legalCase: DemoFixtures.activeCase,
            senderName: "Алим",
            createdAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertTrue(draft.requiresReview)
        XCTAssertTrue(draft.reviewNotice.contains("правовые основания"))
        XCTAssertTrue(draft.reviewNotice.contains("срок ответа"))
        XCTAssertTrue(draft.reviewNotice.contains("дальнейшие действия"))
    }
}

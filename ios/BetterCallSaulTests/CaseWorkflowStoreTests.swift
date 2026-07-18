import XCTest
@testable import BetterCallSaul

@MainActor
final class CaseWorkflowStoreTests: XCTestCase {
    func testStartingCaseUsesSelectedTypeAndDraftStatus() {
        let store = CaseWorkflowStore()

        store.start(type: .fine)

        XCTAssertEqual(store.currentCase.type, .fine)
        XCTAssertEqual(store.currentCase.status, .draft)
        XCTAssertTrue(store.currentCase.evidence.isEmpty)
        XCTAssertTrue(store.currentCase.number.hasPrefix("BCS-"))
    }

    func testApplyingExtractionUpdatesEvidenceFactsAndAmount() {
        let store = CaseWorkflowStore()
        store.start(type: .subscription)
        let fields = [
            ExtractedField(label: "Компания", value: "MegaPlus"),
            ExtractedField(label: "Сумма", value: "24 900 ₸"),
            ExtractedField(label: "Дата", value: "17 июля 2026"),
            ExtractedField(label: "Тип", value: "Подписка")
        ]

        store.applyExtraction(
            evidence: EvidenceItem(fileName: "receipt.png", fileSize: "48 КБ"),
            fields: fields
        )

        XCTAssertEqual(store.currentCase.evidence.first?.fileName, "receipt.png")
        XCTAssertEqual(store.currentCase.counterparty, "MegaPlus")
        XCTAssertEqual(store.currentCase.amount, 24_900)
        XCTAssertEqual(store.currentCase.extractedFields, fields)
    }

    func testEditingFieldKeepsCaseFactsInSync() {
        let store = CaseWorkflowStore(seed: DemoFixtures.activeCase)

        store.updateField(label: "Компания", value: "MegaPlus KZ")
        store.updateField(label: "Сумма", value: "31 500 ₸")

        XCTAssertEqual(store.currentCase.counterparty, "MegaPlus KZ")
        XCTAssertEqual(store.currentCase.amount, 31_500)
        XCTAssertEqual(
            store.currentCase.extractedFields.first(where: { $0.label == "Компания" })?.value,
            "MegaPlus KZ"
        )
    }

    func testPreparingAndSendingDocumentChangesStatus() {
        let store = CaseWorkflowStore(seed: DemoFixtures.activeCase)

        store.prepareDocument()
        XCTAssertEqual(store.currentCase.status, .documentReady)

        store.markSent()
        XCTAssertEqual(store.currentCase.status, .sent)
    }
}

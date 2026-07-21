import XCTest
@testable import BetterCallSaul

final class LocalLegalTextGeneratorTests: XCTestCase {
    func testFineAnalysisAsksForFineSpecificMissingFields() async throws {
        let request = CaseAIRequest(
            caseType: .fine,
            narrative: "Штраф выписан ошибочно",
            reviewedFields: [
                "Орган": "",
                "Номер постановления": "",
                "Сумма": "12 000 ₸",
                "Дата": ""
            ],
            evidenceSummary: nil,
            answers: []
        )

        let analysis = try await LocalLegalTextGenerator().analyzeCase(request)

        XCTAssertEqual(
            analysis.questions.map(\.prompt),
            ["Укажите: орган", "Укажите: номер постановления", "Укажите: дата"]
        )
        XCTAssertEqual(analysis.questions.map(\.kind), [.text, .text, .date])
    }

    func testBillDocumentUsesSupplierAndReportsMissingFields() async throws {
        let context = CaseAIRequest(
            caseType: .bill,
            narrative: "Начисление не соответствует тарифу",
            reviewedFields: [
                "Поставщик": "KazNet",
                "Период": "Июнь 2026",
                "Сумма": "",
                "Номер счёта": ""
            ],
            evidenceSummary: nil,
            answers: []
        )
        let analysis = try await LocalLegalTextGenerator().analyzeCase(context)

        let document = try await LocalLegalTextGenerator().generateDocument(
            AIDocumentRequest(caseContext: context, analysis: analysis)
        )

        XCTAssertEqual(document.recipient, "KazNet")
        XCTAssertEqual(
            document.unresolvedIssues,
            [
                "Уточнить поле «Сумма»",
                "Уточнить поле «Номер счёта»",
                "Проверить применимые правовые основания и срок ответа"
            ]
        )
        XCTAssertTrue(document.legalGrounds.isEmpty)
        XCTAssertNil(document.responseDays)
    }
}

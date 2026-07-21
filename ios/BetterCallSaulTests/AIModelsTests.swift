import XCTest
@testable import BetterCallSaul

final class AIModelsTests: XCTestCase {
    func testEvidenceAnalysisAllowsUnknownFacts() throws {
        let json = #"{"documentKind":"receipt","rawText":"Оплата","counterparty":null,"amount":null,"currency":"KZT","transactionDate":null,"evidenceSummary":"Чек","importantDetails":[],"warnings":[],"confidence":{}}"#.data(using: .utf8)!

        let result = try JSONDecoder().decode(EvidenceAnalysis.self, from: json)

        XCTAssertNil(result.counterparty)
        XCTAssertNil(result.amount)
        XCTAssertEqual(result.currency, "KZT")
    }

    func testCaseRequestEncodesReviewedTextWithoutEvidencePayload() throws {
        let request = CaseAIRequest(
            caseType: .subscription,
            narrative: "Списали деньги после отмены",
            reviewedFields: ["Сумма": "24 900 ₸"],
            evidenceSummary: "Чек подтверждает списание",
            answers: [AIAnswer(questionID: "cancelled", value: "Да")]
        )

        let json = String(decoding: try JSONEncoder().encode(request), as: UTF8.self)

        XCTAssertTrue(json.contains("24 900"))
        XCTAssertFalse(json.contains("mimeType"))
        XCTAssertFalse(json.contains("base64"))
        XCTAssertFalse(json.contains("fileName"))
    }
}

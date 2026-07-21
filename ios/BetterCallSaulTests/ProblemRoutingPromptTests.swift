import XCTest
@testable import BetterCallSaul

final class ProblemRoutingPromptTests: XCTestCase {
    func testPromptContainsBoundedRoutingContractAndOriginalProblem() {
        let request = ProblemRoutingRequest(
            problem: "Списали 4990 тенге",
            clarificationQuestion: nil,
            clarificationAnswer: nil,
            clarificationAllowed: true
        )

        let prompt = ProblemRoutingPrompt.make(request: request)

        for identifier in ["charge", "fine", "subscription", "product", "bill"] {
            XCTAssertTrue(prompt.contains(identifier))
        }
        XCTAssertTrue(prompt.contains("Списали 4990 тенге"))
        XCTAssertTrue(prompt.contains("120"))
        XCTAssertTrue(prompt.contains("JSON"))
        XCTAssertTrue(prompt.contains("не давай юридических советов"))
    }

    func testSecondPromptIncludesClarificationAndForcesRoute() {
        let request = ProblemRoutingRequest(
            problem: "Списали деньги",
            clarificationQuestion: "Это продление подписки?",
            clarificationAnswer: "Да, ежемесячное",
            clarificationAllowed: false
        )

        let prompt = ProblemRoutingPrompt.make(request: request)

        XCTAssertTrue(prompt.contains("Это продление подписки?"))
        XCTAssertTrue(prompt.contains("Да, ежемесячное"))
        XCTAssertTrue(prompt.contains("clarify запрещён"))
    }

    func testPromptNeverRequestsEvidenceOrBinaryPayloads() {
        let request = ProblemRoutingRequest(
            problem: "Не понимаю счёт",
            clarificationQuestion: nil,
            clarificationAnswer: nil,
            clarificationAllowed: true
        )
        let prompt = ProblemRoutingPrompt.make(request: request).lowercased()

        for forbidden in ["base64", "mime_type", "ocr", "pdf", "изображение", "фотограф"] {
            XCTAssertFalse(prompt.contains(forbidden), "Prompt unexpectedly contains \(forbidden)")
        }
    }
}

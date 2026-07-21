import XCTest
@testable import BetterCallSaul

final class ProblemRoutingModelsTests: XCTestCase {
    func testDecodesEverySupportedRouteIdentifier() throws {
        let routes: [(String, CaseType)] = [
            ("charge", .charge),
            ("fine", .fine),
            ("subscription", .subscription),
            ("product", .product),
            ("bill", .bill)
        ]

        for (identifier, expectedType) in routes {
            let json = #"{"action":"route","case_type":"\#(identifier)","question":null}"#

            XCTAssertEqual(
                try ProblemRoutingResponseDecoder.decode(json, clarificationAllowed: true),
                .route(caseType: expectedType)
            )
        }
    }

    func testDecodesValidClarificationQuestion() throws {
        let json = #"{"action":"clarify","case_type":null,"question":"Это продление подписки?"}"#

        XCTAssertEqual(
            try ProblemRoutingResponseDecoder.decode(json, clarificationAllowed: true),
            .clarify(question: "Это продление подписки?")
        )
    }

    func testDecodesJSONInsideMarkdownFence() throws {
        let response = """
        ```json
        {"action":"route","case_type":"fine","question":null}
        ```
        """

        XCTAssertEqual(
            try ProblemRoutingResponseDecoder.decode(response, clarificationAllowed: true),
            .route(caseType: .fine)
        )
    }

    func testRejectsInvalidSchemaCombinations() {
        let invalidResponses = [
            #"{"action":"unknown","case_type":"fine","question":null}"#,
            #"{"action":"route","case_type":null,"question":null}"#,
            #"{"action":"route","case_type":"unknown","question":null}"#,
            #"{"action":"route","case_type":"fine","question":"Лишнее поле"}"#,
            #"{"action":"clarify","case_type":"fine","question":"Что случилось?"}"#,
            #"{"action":"clarify","case_type":null,"question":"   "}"#,
            #"{"action":"clarify","case_type":null,"question":null}"#,
            #"{"case_type":"fine","question":null}"#,
            #"{"action":"route","case_type":"fine"}"#,
            #"{"action":"clarify","question":"Это подписка?"}"#,
            #"{"action":"route","case_type":"fine","question":null,"extra":true}"#
        ]

        for response in invalidResponses {
            XCTAssertThrowsError(
                try ProblemRoutingResponseDecoder.decode(response, clarificationAllowed: true),
                "Expected invalid response for: \(response)"
            ) { error in
                XCTAssertEqual(error as? ProblemRoutingError, .invalidResponse)
            }
        }
    }

    func testRejectsClarificationWhenItIsNotAllowed() {
        let json = #"{"action":"clarify","case_type":null,"question":"Это подписка?"}"#

        XCTAssertThrowsError(
            try ProblemRoutingResponseDecoder.decode(json, clarificationAllowed: false)
        ) { error in
            XCTAssertEqual(error as? ProblemRoutingError, .invalidResponse)
        }
    }
}

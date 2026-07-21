import XCTest
@testable import BetterCallSaul

private actor GeminiRoutingTransport: HTTPTransport {
    private let responseData: Data
    private let statusCode: Int
    private var request: URLRequest?

    init(content: String?, status: String = "completed", statusCode: Int = 200) throws {
        let contentArray: [[String: Any]] = content.map {
            [["type": "text", "text": $0]]
        } ?? []
        responseData = try JSONSerialization.data(withJSONObject: [
            "status": status,
            "steps": [["type": "model_output", "content": contentArray]]
        ])
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        self.request = request
        return (
            responseData,
            HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
        )
    }

    func recordedRequest() -> URLRequest? { request }
}

final class GeminiProblemClassifierTests: XCTestCase {
    func testSendsOneTextInputWithConstrainedSchemaAndDecodesRoute() async throws {
        let response = #"{"action":"route","case_type":"bill","question":null}"#
        let transport = try GeminiRoutingTransport(content: response)
        let classifier = GeminiProblemClassifier(
            apiKey: "gemini-test-key",
            model: "gemini-test-model",
            transport: transport
        )

        let result = try await classifier.classify(Self.request)
        let recordedRequest = await transport.recordedRequest()
        let urlRequest = try XCTUnwrap(recordedRequest)
        let bodyData = try XCTUnwrap(urlRequest.httpBody)
        let body = String(decoding: bodyData, as: UTF8.self)
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        )
        let input = try XCTUnwrap(object["input"] as? [[String: Any]])
        let format = try XCTUnwrap(object["response_format"] as? [String: Any])
        let schema = try XCTUnwrap(format["schema"] as? [String: Any])

        XCTAssertEqual(result, .route(caseType: .bill))
        XCTAssertEqual(urlRequest.url?.absoluteString, "https://generativelanguage.googleapis.com/v1beta/interactions")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "x-goog-api-key"), "gemini-test-key")
        XCTAssertEqual(input.count, 1)
        XCTAssertEqual(input.first?["type"] as? String, "text")
        XCTAssertNil(input.first?["data"])
        XCTAssertNil(input.first?["mime_type"])
        XCTAssertNotNil(schema["properties"])
        for forbidden in ["base64", "mime_type\":\"image", "document\""] {
            XCTAssertFalse(body.contains(forbidden))
        }
    }

    func testRejectsMissingIncompleteOrInvalidTextResponse() async throws {
        let cases: [(String?, String)] = [
            (nil, "completed"),
            (#"{"action":"route","case_type":"bill","question":null}"#, "running"),
            ("not-json", "completed"),
            (#"{"action":"clarify","case_type":null,"question":"Ещё вопрос?"}"#, "completed")
        ]

        for (content, status) in cases {
            let transport = try GeminiRoutingTransport(content: content, status: status)
            let classifier = GeminiProblemClassifier(apiKey: "key", model: "model", transport: transport)

            await assertThrowsRoutingError {
                _ = try await classifier.classify(Self.secondRequest)
            }
        }
    }

    func testMapsNonSuccessStatusToProviderError() async throws {
        let transport = try GeminiRoutingTransport(content: "{}", statusCode: 429)
        let classifier = GeminiProblemClassifier(apiKey: "key", model: "model", transport: transport)

        do {
            _ = try await classifier.classify(Self.request)
            XCTFail("Expected quota failure")
        } catch {
            XCTAssertEqual(error as? AIProviderError, .quotaExceeded(.gemini))
        }
    }

    private static let request = ProblemRoutingRequest(
        problem: "Мне выставили странный счёт",
        clarificationQuestion: nil,
        clarificationAnswer: nil,
        clarificationAllowed: true
    )

    private static let secondRequest = ProblemRoutingRequest(
        problem: "Списали деньги",
        clarificationQuestion: "Это подписка?",
        clarificationAnswer: "Не знаю",
        clarificationAllowed: false
    )
}

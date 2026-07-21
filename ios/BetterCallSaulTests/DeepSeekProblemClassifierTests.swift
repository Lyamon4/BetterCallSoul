import XCTest
@testable import BetterCallSaul

private actor DeepSeekRoutingTransport: HTTPTransport {
    private let responseData: Data
    private let statusCode: Int
    private var request: URLRequest?

    init(content: String, finishReason: String = "stop", statusCode: Int = 200) throws {
        responseData = try JSONSerialization.data(withJSONObject: [
            "choices": [[
                "finish_reason": finishReason,
                "message": ["role": "assistant", "content": content]
            ]]
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

final class DeepSeekProblemClassifierTests: XCTestCase {
    func testSendsTextOnlyJSONRoutingRequestAndDecodesRoute() async throws {
        let response = #"{"action":"route","case_type":"fine","question":null}"#
        let transport = try DeepSeekRoutingTransport(content: response)
        let classifier = DeepSeekProblemClassifier(
            apiKey: "deepseek-test-key",
            model: "deepseek-test-model",
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
        let format = try XCTUnwrap(object["response_format"] as? [String: Any])

        XCTAssertEqual(result, .route(caseType: .fine))
        XCTAssertEqual(urlRequest.url?.absoluteString, "https://api.deepseek.com/chat/completions")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer deepseek-test-key")
        XCTAssertEqual(format["type"] as? String, "json_object")
        XCTAssertTrue(body.contains("Мне выписали штраф"))
        for forbidden in ["base64", "mime_type", "fileName", "EvidencePayload"] {
            XCTAssertFalse(body.contains(forbidden))
        }
    }

    func testRejectsIncompleteOrInvalidProviderResponse() async throws {
        let responses: [(String, String)] = [
            ("length", #"{"action":"route","case_type":"fine","question":null}"#),
            ("stop", "not-json"),
            ("stop", #"{"action":"route","case_type":"unsupported","question":null}"#)
        ]

        for (finishReason, content) in responses {
            let transport = try DeepSeekRoutingTransport(
                content: content,
                finishReason: finishReason
            )
            let classifier = DeepSeekProblemClassifier(apiKey: "key", model: "model", transport: transport)

            await assertThrowsRoutingError {
                _ = try await classifier.classify(Self.request)
            }
        }
    }

    func testMapsNonSuccessStatusToProviderError() async throws {
        let transport = try DeepSeekRoutingTransport(content: "{}", statusCode: 401)
        let classifier = DeepSeekProblemClassifier(apiKey: "bad", model: "model", transport: transport)

        do {
            _ = try await classifier.classify(Self.request)
            XCTFail("Expected authentication failure")
        } catch {
            XCTAssertEqual(error as? AIProviderError, .authenticationFailed(.deepSeek))
        }
    }

    private static let request = ProblemRoutingRequest(
        problem: "Мне выписали штраф",
        clarificationQuestion: nil,
        clarificationAnswer: nil,
        clarificationAllowed: true
    )
}

func assertThrowsRoutingError(
    _ expression: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {
        // Expected.
    }
}

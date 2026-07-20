import XCTest
@testable import BetterCallSaul

private actor DeepSeekRecordingTransport: HTTPTransport {
    private let data: Data
    private let statusCode: Int
    private var request: URLRequest?

    init(content: String, finishReason: String = "stop", statusCode: Int = 200) throws {
        data = try JSONSerialization.data(withJSONObject: [
            "choices": [[
                "finish_reason": finishReason,
                "message": ["role": "assistant", "content": content]
            ]]
        ])
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        self.request = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }

    func recordedRequest() -> URLRequest? { request }
}

final class DeepSeekTextClientTests: XCTestCase {
    func testAnalysisRequestContainsReviewedTextButNoBinaryEvidenceFields() async throws {
        let analysis = #"{"summary":"Нежелательное продление","recommendedAction":"Запросить отмену и возврат","warnings":[],"questions":[]}"#
        let transport = try DeepSeekRecordingTransport(content: analysis)
        let client = DeepSeekTextClient(
            apiKey: "test-key",
            model: "deepseek-v4-pro",
            transport: transport
        )
        let caseRequest = CaseAIRequest(
            caseType: .subscription,
            narrative: "Списали деньги",
            reviewedFields: ["Сумма": "24 900 ₸"],
            evidenceSummary: "Чек подтверждает списание",
            answers: []
        )

        let result = try await client.analyzeCase(caseRequest)
        let recordedRequest = await transport.recordedRequest()
        let request = try XCTUnwrap(recordedRequest)
        let bodyData = try XCTUnwrap(request.httpBody)
        let body = String(decoding: bodyData, as: UTF8.self)
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        )
        let responseFormat = try XCTUnwrap(object["response_format"] as? [String: Any])

        XCTAssertEqual(result.summary, "Нежелательное продление")
        XCTAssertTrue(body.contains("24 900"))
        XCTAssertFalse(body.contains("base64"))
        XCTAssertFalse(body.contains("mime_type"))
        XCTAssertFalse(body.contains("fileName"))
        XCTAssertFalse(body.contains("EvidencePayload"))
        XCTAssertEqual(responseFormat["type"] as? String, "json_object")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        XCTAssertEqual(request.url?.absoluteString, "https://api.deepseek.com/chat/completions")
        XCTAssertEqual(request.timeoutInterval, 15)
    }

    func testRejectsMoreThanFiveQuestions() async throws {
        let questions = (1...6).map {
            [
                "id": "q\($0)",
                "kind": "text",
                "prompt": "Вопрос \($0)",
                "whyNeeded": "Нужно для документа",
                "options": [],
                "required": true
            ] as [String: Any]
        }
        let analysisData = try JSONSerialization.data(withJSONObject: [
            "summary": "Итог",
            "recommendedAction": "Подать претензию",
            "warnings": [],
            "questions": questions
        ])
        let transport = try DeepSeekRecordingTransport(
            content: String(decoding: analysisData, as: UTF8.self)
        )
        let client = DeepSeekTextClient(apiKey: "key", model: "deepseek-v4-pro", transport: transport)

        do {
            _ = try await client.analyzeCase(Self.caseRequest)
            XCTFail("Expected question limit error")
        } catch {
            XCTAssertEqual(error as? AIProviderError, .invalidResponse(.deepSeek))
        }
    }

    func testGeneratesTypedDocumentSections() async throws {
        let document = #"{"recipient":"ТОО MegaPlus","subject":"Требование о возврате","facts":["17 июля списано 24 900 ₸"],"demands":["Вернуть 24 900 ₸"],"responseDays":10,"attachmentDescription":"Копия чека","unresolvedIssues":[]}"#
        let transport = try DeepSeekRecordingTransport(content: document)
        let client = DeepSeekTextClient(apiKey: "key", model: "deepseek-v4-pro", transport: transport)
        let analysis = CaseAIAnalysis(
            summary: "Нежелательное продление",
            recommendedAction: "Претензия",
            warnings: [],
            questions: []
        )

        let result = try await client.generateDocument(
            AIDocumentRequest(caseContext: Self.caseRequest, analysis: analysis)
        )
        let recordedRequest = await transport.recordedRequest()
        let request = try XCTUnwrap(recordedRequest)

        XCTAssertEqual(result.responseDays, 10)
        XCTAssertEqual(result.demands, ["Вернуть 24 900 ₸"])
        XCTAssertEqual(request.timeoutInterval, 15)
    }

    private static let caseRequest = CaseAIRequest(
        caseType: .subscription,
        narrative: "Списали деньги",
        reviewedFields: ["Сумма": "24 900 ₸"],
        evidenceSummary: "Чек",
        answers: []
    )
}

import UIKit
import XCTest
@testable import BetterCallSaul

private actor GeminiRecordingTransport: HTTPTransport {
    private let responseData: Data
    private let statusCode: Int
    private var request: URLRequest?

    init(responseData: Data, statusCode: Int = 200) {
        self.responseData = responseData
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
        return (responseData, response)
    }

    func recordedRequest() -> URLRequest? {
        request
    }
}

final class GeminiVisionClientTests: XCTestCase {
    func testImageRequestContainsInlineVisualDataSchemaAndKeyHeader() async throws {
        let transport = GeminiRecordingTransport(responseData: try completedResponse())
        let client = GeminiVisionClient(
            apiKey: "test-key",
            model: "gemini-2.5-flash",
            transport: transport
        )
        let payload = EvidencePayload(
            fileName: "receipt.jpg",
            mimeType: "image/jpeg",
            data: Data([1, 2, 3]),
            previewImage: Self.pixelImage()
        )

        let result = try await client.analyze(
            payload: payload,
            caseType: .subscription,
            narrative: "Верните списание"
        )
        let recordedRequest = await transport.recordedRequest()
        let request = try XCTUnwrap(recordedRequest)
        let bodyData = try XCTUnwrap(request.httpBody)
        let body = String(decoding: bodyData, as: UTF8.self)
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        )
        let input = try XCTUnwrap(object["input"] as? [[String: Any]])
        let responseFormat = try XCTUnwrap(object["response_format"] as? [String: Any])
        let schema = try XCTUnwrap(responseFormat["schema"] as? [String: Any])
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
        let amountSchema = try XCTUnwrap(properties["amount"] as? [String: Any])

        XCTAssertEqual(result.amount, Decimal(24_900))
        XCTAssertEqual(object["model"] as? String, "gemini-2.5-flash")
        XCTAssertTrue(body.contains(payload.data.base64EncodedString()))
        XCTAssertNotNil(responseFormat["schema"])
        XCTAssertEqual(responseFormat["mime_type"] as? String, "application/json")
        XCTAssertEqual(amountSchema["type"] as? String, "string")
        XCTAssertNil(properties["confidence"])
        XCTAssertEqual(input.last?["type"] as? String, "image")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-goog-api-key"), "test-key")
        XCTAssertEqual(request.url?.absoluteString, "https://generativelanguage.googleapis.com/v1beta/interactions")
    }

    func testPDFUsesDocumentInputType() async throws {
        let transport = GeminiRecordingTransport(responseData: try completedResponse())
        let client = GeminiVisionClient(apiKey: "key", model: "gemini-2.5-flash", transport: transport)
        let payload = EvidencePayload(
            fileName: "bill.pdf",
            mimeType: "application/pdf",
            data: Data([37, 80, 68, 70]),
            previewImage: Self.pixelImage()
        )

        _ = try await client.analyze(payload: payload, caseType: .bill, narrative: "Завышенный счёт")
        let recordedRequest = await transport.recordedRequest()
        let request = try XCTUnwrap(recordedRequest)
        let bodyData = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        )
        let input = try XCTUnwrap(object["input"] as? [[String: Any]])

        XCTAssertEqual(input.last?["type"] as? String, "document")
        XCTAssertEqual(input.last?["mime_type"] as? String, "application/pdf")
    }

    func testFencedSchemaDivergentResponseIsNormalized() async throws {
        let modelText = #"""
        ```json
        {
          "documentType": {"value": "Счёт за коммунальные услуги"},
          "serviceProvider": {
            "value": "ТОО ГородКом Сервис",
            "rawText": "ТОО ГородКом Сервис"
          },
          "totalAmount": {"value": "14 850 ₸", "rawText": "Итого: 14 850 ₸"},
          "invoiceDate": {"value": "2026-07-18"},
          "billingPeriod": {"value": "июнь 2026"}
        }
        ```
        """#
        let transport = GeminiRecordingTransport(
            responseData: try completedResponse(modelText: modelText)
        )
        let client = GeminiVisionClient(
            apiKey: "test-key",
            model: "gemini-2.5-flash",
            transport: transport
        )
        let payload = EvidencePayload(
            fileName: "bill.png",
            mimeType: "image/png",
            data: Data([1, 2, 3]),
            previewImage: Self.pixelImage()
        )

        let result = try await client.analyze(
            payload: payload,
            caseType: .bill,
            narrative: "Сумма в счёте завышена"
        )

        XCTAssertEqual(result.documentKind, "Счёт за коммунальные услуги")
        XCTAssertEqual(result.counterparty, "ТОО ГородКом Сервис")
        XCTAssertEqual(result.amount, Decimal(14_850))
        XCTAssertEqual(result.currency, "KZT")
        XCTAssertEqual(result.transactionDate, "2026-07-18")
        XCTAssertTrue(result.rawText.contains("ТОО ГородКом Сервис"))
        XCTAssertTrue(result.rawText.contains("14 850 ₸"))
    }

    func testAuthenticationStatusMapsToGeminiError() async throws {
        let transport = GeminiRecordingTransport(responseData: Data(), statusCode: 401)
        let client = GeminiVisionClient(apiKey: "bad-key", model: "gemini-2.5-flash", transport: transport)
        let payload = EvidencePayload(
            fileName: "receipt.jpg",
            mimeType: "image/jpeg",
            data: Data([1]),
            previewImage: Self.pixelImage()
        )

        do {
            _ = try await client.analyze(payload: payload, caseType: .charge, narrative: "")
            XCTFail("Expected authentication error")
        } catch {
            XCTAssertEqual(error as? AIProviderError, .authenticationFailed(.gemini))
        }
    }

    private func completedResponse() throws -> Data {
        let analysis = #"{"documentKind":"receipt","rawText":"MEGAPLUS","counterparty":"MegaPlus","amount":24900,"currency":"KZT","transactionDate":"2026-07-17","evidenceSummary":"Списание","importantDetails":[],"warnings":[],"confidence":{"amount":0.99}}"#
        return try completedResponse(modelText: analysis)
    }

    private func completedResponse(modelText: String) throws -> Data {
        return try JSONSerialization.data(withJSONObject: [
            "status": "completed",
            "steps": [[
                "type": "model_output",
                "content": [["type": "text", "text": modelText]]
            ]]
        ])
    }

    private static func pixelImage() -> CGImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }.cgImage!
    }
}

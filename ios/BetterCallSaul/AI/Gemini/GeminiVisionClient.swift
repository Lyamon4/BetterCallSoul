import Foundation

struct GeminiVisionClient: EvidenceAnalyzing {
    private static let endpoint = URL(
        string: "https://generativelanguage.googleapis.com/v1beta/interactions"
    )!
    private static let maximumPayloadBytes = 10 * 1_024 * 1_024

    let apiKey: String
    let model: String
    let transport: any HTTPTransport

    func analyze(
        payload: EvidencePayload,
        caseType: CaseType,
        narrative: String
    ) async throws -> EvidenceAnalysis {
        guard payload.data.count <= Self.maximumPayloadBytes else {
            throw AIProviderError.payloadTooLarge(maximumMB: 10)
        }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(
            GeminiInteractionRequest(
                model: model,
                input: [
                    GeminiInput(
                        type: "text",
                        text: GeminiEvidencePrompt.make(caseType: caseType, narrative: narrative),
                        data: nil,
                        mimeType: nil
                    ),
                    GeminiInput(
                        type: payload.mimeType == "application/pdf" ? "document" : "image",
                        text: nil,
                        data: payload.data.base64EncodedString(),
                        mimeType: payload.mimeType
                    )
                ],
                responseFormat: GeminiResponseFormat(schema: Self.evidenceSchema)
            )
        )

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch let error as AIProviderError {
            throw error
        } catch {
            throw AIProviderError.transport(error.localizedDescription)
        }

        guard (200..<300).contains(response.statusCode) else {
            throw AIProviderError.httpStatus(response.statusCode, provider: .gemini)
        }

        do {
            let interaction = try JSONDecoder().decode(GeminiInteractionResponse.self, from: data)
            guard interaction.status == "completed",
                  let text = interaction.steps.reversed()
                    .first(where: { $0.type == "model_output" })?
                    .content
                    .last(where: { $0.type == "text" })?
                    .text else {
                throw AIProviderError.invalidResponse(.gemini)
            }
            return try JSONDecoder().decode(EvidenceAnalysis.self, from: Data(text.utf8))
        } catch let error as AIProviderError {
            throw error
        } catch {
            throw AIProviderError.invalidResponse(.gemini)
        }
    }

    private static let evidenceSchema: GeminiJSONValue = {
        let string = GeminiJSONValue.object(["type": .string("string")])
        let nullableString = GeminiJSONValue.object([
            "type": .array([.string("string"), .string("null")])
        ])
        let nullableNumber = GeminiJSONValue.object([
            "type": .array([.string("number"), .string("null")])
        ])
        let stringArray = GeminiJSONValue.object([
            "type": .string("array"),
            "items": string
        ])
        let confidence = GeminiJSONValue.object([
            "type": .string("object"),
            "additionalProperties": .object(["type": .string("number")])
        ])
        let required = [
            "documentKind", "rawText", "counterparty", "amount", "currency",
            "transactionDate", "evidenceSummary", "importantDetails", "warnings", "confidence"
        ].map(GeminiJSONValue.string)

        return .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "properties": .object([
                "documentKind": string,
                "rawText": string,
                "counterparty": nullableString,
                "amount": nullableNumber,
                "currency": nullableString,
                "transactionDate": nullableString,
                "evidenceSummary": string,
                "importantDetails": stringArray,
                "warnings": stringArray,
                "confidence": confidence
            ]),
            "required": .array(required)
        ])
    }()
}

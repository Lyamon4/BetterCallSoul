import Foundation

struct GeminiProblemClassifier: ProblemClassifying {
    private static let endpoint = URL(
        string: "https://generativelanguage.googleapis.com/v1beta/interactions"
    )!

    let apiKey: String
    let model: String
    let transport: any HTTPTransport

    func classify(_ routingRequest: ProblemRoutingRequest) async throws -> ProblemRoutingDecision {
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
                        text: ProblemRoutingPrompt.make(request: routingRequest),
                        data: nil,
                        mimeType: nil
                    )
                ],
                responseFormat: GeminiResponseFormat(schema: Self.routingSchema)
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
                    .text,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIProviderError.invalidResponse(.gemini)
            }
            return try ProblemRoutingResponseDecoder.decode(
                text,
                clarificationAllowed: routingRequest.clarificationAllowed
            )
        } catch let error as AIProviderError {
            throw error
        } catch {
            throw AIProviderError.invalidResponse(.gemini)
        }
    }

    private static let routingSchema: GeminiJSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "properties": .object([
            "action": .object([
                "type": .string("string"),
                "enum": .array([.string("route"), .string("clarify")])
            ]),
            "case_type": .object([
                "type": .array([.string("string"), .string("null")]),
                "enum": .array([
                    .string("charge"), .string("fine"), .string("subscription"),
                    .string("product"), .string("bill"), .null
                ])
            ]),
            "question": .object([
                "type": .array([.string("string"), .string("null")])
            ])
        ]),
        "required": .array([
            .string("action"), .string("case_type"), .string("question")
        ])
    ])
}

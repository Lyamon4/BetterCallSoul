import Foundation

struct DeepSeekProblemClassifier: ProblemClassifying {
    private static let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!

    let apiKey: String
    let model: String
    let transport: any HTTPTransport

    func classify(_ routingRequest: ProblemRoutingRequest) async throws -> ProblemRoutingDecision {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            DeepSeekChatRequest(
                model: model,
                messages: [
                    DeepSeekMessage(
                        role: "system",
                        content: "Ты маршрутизатор обращений. Выполняй только JSON-контракт пользователя."
                    ),
                    DeepSeekMessage(
                        role: "user",
                        content: ProblemRoutingPrompt.make(request: routingRequest)
                    )
                ]
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
            throw AIProviderError.httpStatus(response.statusCode, provider: .deepSeek)
        }

        do {
            let chat = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)
            guard let choice = chat.choices.first,
                  choice.finishReason == "stop",
                  !choice.message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIProviderError.invalidResponse(.deepSeek)
            }
            return try ProblemRoutingResponseDecoder.decode(
                choice.message.content,
                clarificationAllowed: routingRequest.clarificationAllowed
            )
        } catch let error as AIProviderError {
            throw error
        } catch {
            throw AIProviderError.invalidResponse(.deepSeek)
        }
    }
}

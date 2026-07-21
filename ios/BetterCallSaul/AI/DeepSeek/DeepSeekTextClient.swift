import Foundation

struct DeepSeekTextClient: LegalTextGenerating {
    private static let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!
    private static let timeoutInterval: TimeInterval = 15

    let apiKey: String
    let model: String
    let transport: any HTTPTransport

    func analyzeCase(_ request: CaseAIRequest) async throws -> CaseAIAnalysis {
        let content = try await complete(messages: [
            DeepSeekMessage(role: "system", content: DeepSeekPrompts.analysisSystem(for: request.caseType)),
            DeepSeekMessage(role: "user", content: try DeepSeekPrompts.analysis(request: request))
        ])
        let analysis: CaseAIAnalysis = try decode(content)
        guard analysis.questions.count <= 5 else {
            throw AIProviderError.invalidResponse(.deepSeek)
        }
        return analysis
    }

    func generateDocument(_ request: AIDocumentRequest) async throws -> AIDocumentSections {
        let content = try await complete(messages: [
            DeepSeekMessage(
                role: "system",
                content: DeepSeekPrompts.documentSystem(for: request.caseContext.caseType)
            ),
            DeepSeekMessage(role: "user", content: try DeepSeekPrompts.document(request: request))
        ])
        return try decode(content)
    }

    private func complete(messages: [DeepSeekMessage]) async throws -> String {
        var request = URLRequest(url: Self.endpoint)
        request.timeoutInterval = Self.timeoutInterval
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            DeepSeekChatRequest(model: model, messages: messages)
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
            return choice.message.content
        } catch let error as AIProviderError {
            throw error
        } catch {
            throw AIProviderError.invalidResponse(.deepSeek)
        }
    }

    private func decode<T: Decodable>(_ content: String) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: Data(content.utf8))
        } catch {
            throw AIProviderError.invalidResponse(.deepSeek)
        }
    }
}

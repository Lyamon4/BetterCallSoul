import XCTest
@testable import BetterCallSaul

private actor RuntimeRoutingTransport: HTTPTransport {
    private var urls: [URL] = []

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        urls.append(request.url!)
        let routing = #"{"action":"route","case_type":"bill","question":null}"#
        let data = try JSONSerialization.data(withJSONObject: [
            "status": "completed",
            "steps": [[
                "type": "model_output",
                "content": [["type": "text", "text": routing]]
            ]]
        ])
        return (
            data,
            HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )
    }

    func recordedURLs() -> [URL] { urls }
}

final class AIConfigurationTests: XCTestCase {
    func testHostAppBundleContainsProviderConfiguration() throws {
        let configuration = try AIConfiguration.bundled()

        XCTAssertEqual(configuration.geminiModel, "gemini-2.5-flash")
        XCTAssertEqual(configuration.deepSeekModel, "deepseek-v4-pro")
        XCTAssertFalse(configuration.geminiAPIKey.isEmpty)
        XCTAssertFalse(configuration.deepSeekAPIKey.isEmpty)
    }

    func testConfigurationReportsBothBundledProviders() throws {
        let configuration = try AIConfiguration(values: [
            "GeminiAPIKey": "gemini-test-key",
            "GeminiModel": "gemini-2.5-flash",
            "DeepSeekAPIKey": "deepseek-test-key",
            "DeepSeekModel": "deepseek-v4-pro"
        ])

        XCTAssertEqual(configuration.geminiModel, "gemini-2.5-flash")
        XCTAssertEqual(configuration.deepSeekModel, "deepseek-v4-pro")
        XCTAssertEqual(configuration.geminiAPIKey, "gemini-test-key")
        XCTAssertEqual(configuration.deepSeekAPIKey, "deepseek-test-key")
    }

    func testMissingGeminiKeyProducesConfigurationError() {
        XCTAssertThrowsError(try AIConfiguration(values: [:])) { error in
            XCTAssertEqual(error as? AIProviderError, .missingKey(.gemini))
        }
    }

    func testMissingDeepSeekKeyProducesConfigurationError() {
        XCTAssertThrowsError(try AIConfiguration(values: [
            "GeminiAPIKey": "gemini-test-key",
            "GeminiModel": "gemini-2.5-flash"
        ])) { error in
            XCTAssertEqual(error as? AIProviderError, .missingKey(.deepSeek))
        }
    }

    func testUITestingClassifierRoutesWithoutNetwork() async throws {
        let result = try await AIServiceContainer.uiTesting.problemClassifier.classify(
            ProblemRoutingRequest(
                problem: "Любое тестовое описание",
                clarificationQuestion: nil,
                clarificationAnswer: nil,
                clarificationAllowed: true
            )
        )

        XCTAssertEqual(result, .route(caseType: .fine))
    }

    func testUITestingClarificationClassifierAsksOnceThenRoutes() async throws {
        let classifier = AIServiceContainer.uiTestingWithClarification.problemClassifier
        let first = try await classifier.classify(
            ProblemRoutingRequest(
                problem: "Неясная ситуация",
                clarificationQuestion: nil,
                clarificationAnswer: nil,
                clarificationAllowed: true
            )
        )
        let second = try await classifier.classify(
            ProblemRoutingRequest(
                problem: "Неясная ситуация",
                clarificationQuestion: "Это штраф от госоргана?",
                clarificationAnswer: "Да",
                clarificationAllowed: false
            )
        )

        XCTAssertEqual(first, .clarify(question: "Это штраф от госоргана?"))
        XCTAssertEqual(second, .route(caseType: .fine))
    }

    func testLocalOnlyClassifierDoesNotGuessCategory() async {
        do {
            _ = try await AIServiceContainer.localOnly.problemClassifier.classify(
                ProblemRoutingRequest(
                    problem: "Пришёл штраф",
                    clarificationQuestion: nil,
                    clarificationAnswer: nil,
                    clarificationAllowed: true
                )
            )
            XCTFail("Expected unavailable classifier")
        } catch {
            XCTAssertEqual(error as? ProblemRoutingError, .unavailable)
        }
    }

    func testRuntimeConfigurationFallsBackToGeminiWhenDeepSeekKeyIsMissing() async throws {
        let transport = RuntimeRoutingTransport()
        let services = AIServiceContainer.runtime(
            values: [
                "GeminiAPIKey": "gemini-key",
                "GeminiModel": "gemini-model",
                "DeepSeekModel": "deepseek-model"
            ],
            transport: transport
        )

        let decision = try await services.problemClassifier.classify(
            ProblemRoutingRequest(
                problem: "Мне выставили завышенный счёт",
                clarificationQuestion: nil,
                clarificationAnswer: nil,
                clarificationAllowed: true
            )
        )
        let urls = await transport.recordedURLs()

        XCTAssertEqual(decision, .route(caseType: .bill))
        XCTAssertEqual(
            urls.map(\.absoluteString),
            ["https://generativelanguage.googleapis.com/v1beta/interactions"]
        )
    }
}

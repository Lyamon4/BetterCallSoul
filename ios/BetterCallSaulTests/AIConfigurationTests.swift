import XCTest
@testable import BetterCallSaul

final class AIConfigurationTests: XCTestCase {
    func testConfigurationReportsBothBundledProviders() throws {
        let configuration = try AIConfiguration(values: [
            "GeminiAPIKey": "gemini-test-key",
            "GeminiModel": "gemini-3.5-flash",
            "DeepSeekAPIKey": "deepseek-test-key",
            "DeepSeekModel": "deepseek-v4-pro"
        ])

        XCTAssertEqual(configuration.geminiModel, "gemini-3.5-flash")
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
            "GeminiModel": "gemini-3.5-flash"
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
}

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
}

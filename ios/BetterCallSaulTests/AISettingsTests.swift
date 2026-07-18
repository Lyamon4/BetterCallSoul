import XCTest
@testable import BetterCallSaul

final class AISettingsTests: XCTestCase {
    func testProviderStatusesExposeOnlyMaskedCredentialSuffixes() throws {
        let configuration = try AIConfiguration(values: [
            "GeminiAPIKey": "full-private-gemini-key",
            "GeminiModel": "gemini-3.5-flash",
            "DeepSeekAPIKey": "full-private-deepseek-key",
            "DeepSeekModel": "deepseek-v4-pro"
        ])

        let statuses = AIProviderStatus.make(from: configuration)

        XCTAssertEqual(statuses.map(\.provider), [.gemini, .deepSeek])
        XCTAssertTrue(statuses.allSatisfy(\.isConfigured))
        XCTAssertTrue(statuses.allSatisfy { $0.maskedKey.hasPrefix("••••") })
        XCTAssertFalse(statuses.contains { $0.maskedKey.contains("full-private") })
        XCTAssertEqual(statuses.map(\.model), ["gemini-3.5-flash", "deepseek-v4-pro"])
    }

    func testConfigurationMasksShortKeyWithoutExposingIt() throws {
        let configuration = try AIConfiguration(values: [
            "GeminiAPIKey": "abc",
            "GeminiModel": "gemini-3.5-flash",
            "DeepSeekAPIKey": "xyz",
            "DeepSeekModel": "deepseek-v4-pro"
        ])

        XCTAssertEqual(configuration.maskedGeminiKey, "••••abc")
        XCTAssertEqual(configuration.maskedDeepSeekKey, "••••xyz")
    }
}

import XCTest
@testable import BetterCallSaul

final class HTTPTransportTests: XCTestCase {
    func testStatusMappingPreservesProviderSpecificFailure() {
        XCTAssertEqual(
            AIProviderError.httpStatus(429, provider: .deepSeek),
            .quotaExceeded(.deepSeek)
        )
        XCTAssertEqual(
            AIProviderError.httpStatus(401, provider: .gemini),
            .authenticationFailed(.gemini)
        )
    }

    func testUnknownStatusMapsToInvalidResponse() {
        XCTAssertEqual(
            AIProviderError.httpStatus(503, provider: .gemini),
            .invalidResponse(.gemini)
        )
    }
}

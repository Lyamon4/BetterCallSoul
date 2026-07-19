import XCTest
@testable import BetterCallSaul

private actor RoutingCallLog {
    private var entries: [String] = []

    func append(_ entry: String) {
        entries.append(entry)
    }

    func snapshot() -> [String] { entries }
}

private enum RoutingSpyBehavior: Sendable {
    case route(CaseType)
    case clarify(String)
    case fail
    case cancel
}

private struct RoutingClassifierSpy: ProblemClassifying {
    let name: String
    let behavior: RoutingSpyBehavior
    let log: RoutingCallLog

    func classify(_ request: ProblemRoutingRequest) async throws -> ProblemRoutingDecision {
        await log.append(name)
        switch behavior {
        case .route(let type): return .route(caseType: type)
        case .clarify(let question): return .clarify(question: question)
        case .fail: throw ProblemRoutingError.invalidResponse
        case .cancel: throw CancellationError()
        }
    }
}

final class FallbackProblemClassifierTests: XCTestCase {
    func testPrimarySuccessReturnsWithoutCallingFallback() async throws {
        let log = RoutingCallLog()
        let classifier = makeClassifier(
            primary: .route(.subscription),
            fallback: .route(.fine),
            log: log
        )

        let result = try await classifier.classify(Self.request)
        let calls = await log.snapshot()

        XCTAssertEqual(result, .route(caseType: .subscription))
        XCTAssertEqual(calls, ["deepseek"])
    }

    func testPrimaryFailureCallsFallbackSecondAndReturnsItsDecision() async throws {
        let log = RoutingCallLog()
        let classifier = makeClassifier(
            primary: .fail,
            fallback: .clarify("Это подписка?"),
            log: log
        )

        let result = try await classifier.classify(Self.request)
        let calls = await log.snapshot()

        XCTAssertEqual(result, .clarify(question: "Это подписка?"))
        XCTAssertEqual(calls, ["deepseek", "gemini"])
    }

    func testDoubleFailureReturnsNeutralUnavailableError() async {
        let log = RoutingCallLog()
        let classifier = makeClassifier(primary: .fail, fallback: .fail, log: log)

        do {
            _ = try await classifier.classify(Self.request)
            XCTFail("Expected unavailable error")
        } catch {
            XCTAssertEqual(error as? ProblemRoutingError, .unavailable)
        }
        let calls = await log.snapshot()
        XCTAssertEqual(calls, ["deepseek", "gemini"])
    }

    func testCancellationNeverStartsFallback() async {
        let log = RoutingCallLog()
        let classifier = makeClassifier(primary: .cancel, fallback: .route(.fine), log: log)

        do {
            _ = try await classifier.classify(Self.request)
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        let calls = await log.snapshot()
        XCTAssertEqual(calls, ["deepseek"])
    }

    private func makeClassifier(
        primary: RoutingSpyBehavior,
        fallback: RoutingSpyBehavior,
        log: RoutingCallLog
    ) -> FallbackProblemClassifier {
        FallbackProblemClassifier(
            primary: RoutingClassifierSpy(name: "deepseek", behavior: primary, log: log),
            fallback: RoutingClassifierSpy(name: "gemini", behavior: fallback, log: log)
        )
    }

    private static let request = ProblemRoutingRequest(
        problem: "Произошло списание",
        clarificationQuestion: nil,
        clarificationAnswer: nil,
        clarificationAllowed: true
    )
}

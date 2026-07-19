import XCTest
@testable import BetterCallSaul

private enum ClassifierOutcome: Sendable {
    case decision(ProblemRoutingDecision)
    case failure
}

private actor QueuedProblemClassifier: ProblemClassifying {
    private var outcomes: [ClassifierOutcome]
    private var requests: [ProblemRoutingRequest] = []

    init(_ outcomes: [ClassifierOutcome]) {
        self.outcomes = outcomes
    }

    func classify(_ request: ProblemRoutingRequest) async throws -> ProblemRoutingDecision {
        requests.append(request)
        guard !outcomes.isEmpty else { throw ProblemRoutingError.unavailable }
        switch outcomes.removeFirst() {
        case .decision(let decision): return decision
        case .failure: throw ProblemRoutingError.unavailable
        }
    }

    func recordedRequests() -> [ProblemRoutingRequest] { requests }
}

private actor SuspendedProblemClassifier: ProblemClassifying {
    private var continuation: CheckedContinuation<ProblemRoutingDecision, Never>?
    private var pendingDecision: ProblemRoutingDecision?

    func classify(_ request: ProblemRoutingRequest) async throws -> ProblemRoutingDecision {
        await withCheckedContinuation { continuation in
            if let pendingDecision {
                self.pendingDecision = nil
                continuation.resume(returning: pendingDecision)
            } else {
                self.continuation = continuation
            }
        }
    }

    func resolve(_ decision: ProblemRoutingDecision) {
        if let continuation {
            self.continuation = nil
            continuation.resume(returning: decision)
        } else {
            pendingDecision = decision
        }
    }
}

@MainActor
final class SaulAssistantViewModelTests: XCTestCase {
    func testBlankProblemCannotBeSubmitted() {
        let classifier = QueuedProblemClassifier([.decision(.route(caseType: .fine))])
        let viewModel = SaulAssistantViewModel(classifier: classifier)

        viewModel.problemText = "  \n "

        XCTAssertFalse(viewModel.canSubmit)
        viewModel.submit()
        XCTAssertEqual(viewModel.state, .askingProblem)
    }

    func testDirectDecisionMovesToRoutingState() async {
        let classifier = QueuedProblemClassifier([.decision(.route(caseType: .fine))])
        let viewModel = SaulAssistantViewModel(classifier: classifier)
        viewModel.problemText = "Мне выписали штраф"

        viewModel.submit()
        await waitUntil { viewModel.state == .routing(.fine) }

        XCTAssertEqual(viewModel.state, .routing(.fine))
        XCTAssertEqual(viewModel.composedNarrative, "Мне выписали штраф")
    }

    func testClarificationIsLimitedToOneAndIncludedInSecondRequest() async {
        let classifier = QueuedProblemClassifier([
            .decision(.clarify(question: "Это продление подписки?")),
            .decision(.route(caseType: .subscription))
        ])
        let viewModel = SaulAssistantViewModel(classifier: classifier)
        viewModel.problemText = "Списали деньги"

        viewModel.submit()
        await waitUntil {
            viewModel.state == .askingClarification(question: "Это продление подписки?")
        }
        viewModel.clarificationText = "Да, ежемесячное"
        viewModel.submit()
        await waitUntil { viewModel.state == .routing(.subscription) }

        let requests = await classifier.recordedRequests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests[0].clarificationAllowed)
        XCTAssertEqual(requests[1].problem, "Списали деньги")
        XCTAssertEqual(requests[1].clarificationQuestion, "Это продление подписки?")
        XCTAssertEqual(requests[1].clarificationAnswer, "Да, ежемесячное")
        XCTAssertFalse(requests[1].clarificationAllowed)
        XCTAssertEqual(
            viewModel.composedNarrative,
            "Списали деньги\nУточнение: Да, ежемесячное"
        )
    }

    func testSecondClarificationResponseBecomesFailure() async {
        let classifier = QueuedProblemClassifier([
            .decision(.clarify(question: "Первый вопрос?")),
            .decision(.clarify(question: "Второй вопрос?"))
        ])
        let viewModel = SaulAssistantViewModel(classifier: classifier)
        viewModel.problemText = "Неясная ситуация"

        viewModel.submit()
        await waitUntil { viewModel.state == .askingClarification(question: "Первый вопрос?") }
        viewModel.clarificationText = "Ответ"
        viewModel.submit()
        await waitUntil { viewModel.state == .failed }

        XCTAssertEqual(viewModel.state, .failed)
    }

    func testRetryPreservesInputsAndRepeatsRequest() async {
        let classifier = QueuedProblemClassifier([
            .failure,
            .decision(.route(caseType: .charge))
        ])
        let viewModel = SaulAssistantViewModel(classifier: classifier)
        viewModel.problemText = "Неизвестное списание"

        viewModel.submit()
        await waitUntil { viewModel.state == .failed }
        viewModel.retry()
        await waitUntil { viewModel.state == .routing(.charge) }

        let requests = await classifier.recordedRequests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[0], requests[1])
        XCTAssertEqual(viewModel.problemText, "Неизвестное списание")
    }

    func testCancellationIgnoresLateClassifierResult() async {
        let classifier = SuspendedProblemClassifier()
        let viewModel = SaulAssistantViewModel(classifier: classifier)
        viewModel.problemText = "Поздний ответ"

        viewModel.submit()
        await waitUntil { viewModel.state == .classifying }
        viewModel.cancel()
        await classifier.resolve(.route(caseType: .bill))
        try? await Task.sleep(for: .milliseconds(30))

        XCTAssertNotEqual(viewModel.state, .routing(.bill))
    }

    private func waitUntil(
        timeoutIterations: Int = 100,
        condition: @escaping @MainActor () -> Bool
    ) async {
        for _ in 0..<timeoutIterations {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Condition was not reached")
    }
}

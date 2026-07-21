import Foundation

struct FallbackProblemClassifier: ProblemClassifying {
    let primary: any ProblemClassifying
    let fallback: any ProblemClassifying

    func classify(_ request: ProblemRoutingRequest) async throws -> ProblemRoutingDecision {
        do {
            return try await primary.classify(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            do {
                return try await fallback.classify(request)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw ProblemRoutingError.unavailable
            }
        }
    }
}

struct UnavailableProblemClassifier: ProblemClassifying {
    func classify(_ request: ProblemRoutingRequest) async throws -> ProblemRoutingDecision {
        throw ProblemRoutingError.unavailable
    }
}

struct UITestingProblemClassifier: ProblemClassifying {
    let asksForClarification: Bool

    func classify(_ request: ProblemRoutingRequest) async throws -> ProblemRoutingDecision {
        if asksForClarification && request.clarificationAllowed {
            return .clarify(question: "Это штраф от госоргана?")
        }
        return .route(caseType: .fine)
    }
}

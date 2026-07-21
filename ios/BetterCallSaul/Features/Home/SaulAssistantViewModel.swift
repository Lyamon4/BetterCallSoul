import Foundation
import Observation

enum SaulAssistantState: Equatable {
    case askingProblem
    case classifying
    case askingClarification(question: String)
    case routing(CaseType)
    case failed
}

@MainActor
@Observable
final class SaulAssistantViewModel {
    var problemText = ""
    var clarificationText = ""
    private(set) var state: SaulAssistantState = .askingProblem
    private(set) var clarificationQuestion: String?

    private let classifier: any ProblemClassifying
    private var classificationTask: Task<Void, Never>?
    private var requestGeneration = 0

    init(classifier: any ProblemClassifying) {
        self.classifier = classifier
    }

    var canSubmit: Bool {
        switch state {
        case .askingProblem:
            !trimmed(problemText).isEmpty
        case .askingClarification:
            !trimmed(clarificationText).isEmpty
        case .classifying, .routing, .failed:
            false
        }
    }

    var visibleMessage: String {
        switch state {
        case .askingProblem:
            "Что случилось? Опишите своими словами."
        case .classifying:
            "Разбираюсь в ситуации…"
        case .askingClarification(let question):
            question
        case .routing(let type):
            Self.routingMessage(for: type)
        case .failed:
            "Не удалось разобраться в ситуации. Попробуйте ещё раз."
        }
    }

    var mascotState: SaulMascotState {
        state == .classifying ? .thinking : .talking
    }

    var composedNarrative: String {
        let problem = trimmed(problemText)
        let answer = trimmed(clarificationText)
        guard clarificationQuestion != nil, !answer.isEmpty else { return problem }
        return "\(problem)\nУточнение: \(answer)"
    }

    func submit() {
        let request: ProblemRoutingRequest

        switch state {
        case .askingProblem:
            let problem = trimmed(problemText)
            guard !problem.isEmpty else { return }
            problemText = problem
            request = ProblemRoutingRequest(
                problem: problem,
                clarificationQuestion: nil,
                clarificationAnswer: nil,
                clarificationAllowed: true
            )

        case .askingClarification(let question):
            let answer = trimmed(clarificationText)
            guard !answer.isEmpty else { return }
            clarificationText = answer
            clarificationQuestion = question
            request = ProblemRoutingRequest(
                problem: trimmed(problemText),
                clarificationQuestion: question,
                clarificationAnswer: answer,
                clarificationAllowed: false
            )

        case .classifying, .routing, .failed:
            return
        }

        startClassification(request)
    }

    func retry() {
        guard state == .failed else { return }
        let question = clarificationQuestion
        let answer = trimmed(clarificationText)
        let request = ProblemRoutingRequest(
            problem: trimmed(problemText),
            clarificationQuestion: question,
            clarificationAnswer: question == nil ? nil : answer,
            clarificationAllowed: question == nil
        )
        startClassification(request)
    }

    func cancel() {
        requestGeneration += 1
        classificationTask?.cancel()
        classificationTask = nil
    }

    func reset() {
        cancel()
        problemText = ""
        clarificationText = ""
        clarificationQuestion = nil
        state = .askingProblem
    }

    private func startClassification(_ request: ProblemRoutingRequest) {
        classificationTask?.cancel()
        requestGeneration += 1
        let generation = requestGeneration
        let classifier = classifier
        state = .classifying

        classificationTask = Task { [weak self] in
            do {
                let decision = try await classifier.classify(request)
                guard !Task.isCancelled else { return }
                self?.apply(decision, request: request, generation: generation)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.applyFailure(generation: generation)
            }
        }
    }

    private func apply(
        _ decision: ProblemRoutingDecision,
        request: ProblemRoutingRequest,
        generation: Int
    ) {
        guard generation == requestGeneration else { return }
        classificationTask = nil

        switch decision {
        case .route(let caseType):
            state = .routing(caseType)
        case .clarify(let question):
            guard request.clarificationAllowed else {
                state = .failed
                return
            }
            clarificationQuestion = question
            clarificationText = ""
            state = .askingClarification(question: question)
        }
    }

    private func applyFailure(generation: Int) {
        guard generation == requestGeneration else { return }
        classificationTask = nil
        state = .failed
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func routingMessage(for type: CaseType) -> String {
        switch type {
        case .charge:
            "Похоже, нужно разобраться со списанием. Открываю обращение."
        case .fine:
            "Похоже, нужно обжаловать штраф. Открываю обращение."
        case .subscription:
            "Помогу отменить подписку. Открываю обращение."
        case .product:
            "Похоже, проблема связана с товаром. Открываю обращение."
        case .bill:
            "Похоже, нужно проверить счёт. Открываю обращение."
        }
    }
}

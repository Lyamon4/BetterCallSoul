import Foundation

struct ProblemRoutingRequest: Equatable, Sendable {
    let problem: String
    let clarificationQuestion: String?
    let clarificationAnswer: String?
    let clarificationAllowed: Bool
}

enum ProblemRoutingDecision: Equatable, Sendable {
    case route(caseType: CaseType)
    case clarify(question: String)
}

enum ProblemRoutingError: Error, Equatable {
    case invalidResponse
    case unavailable
}

extension CaseType {
    var routingIdentifier: String {
        switch self {
        case .charge: "charge"
        case .fine: "fine"
        case .subscription: "subscription"
        case .product: "product"
        case .bill: "bill"
        }
    }

    init?(routingIdentifier: String) {
        switch routingIdentifier {
        case "charge": self = .charge
        case "fine": self = .fine
        case "subscription": self = .subscription
        case "product": self = .product
        case "bill": self = .bill
        default: return nil
        }
    }
}

enum ProblemRoutingResponseDecoder {
    private struct WireResponse: Decodable {
        let action: String
        let caseType: String?
        let question: String?

        enum CodingKeys: String, CodingKey {
            case action
            case caseType = "case_type"
            case question
        }
    }

    static func decode(
        _ response: String,
        clarificationAllowed: Bool
    ) throws -> ProblemRoutingDecision {
        let json = stripMarkdownFence(from: response)
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == Set(["action", "case_type", "question"]),
              let wire = try? JSONDecoder().decode(WireResponse.self, from: data) else {
            throw ProblemRoutingError.invalidResponse
        }

        switch wire.action {
        case "route":
            guard wire.question == nil,
                  let identifier = wire.caseType,
                  let caseType = CaseType(routingIdentifier: identifier) else {
                throw ProblemRoutingError.invalidResponse
            }
            return .route(caseType: caseType)

        case "clarify":
            guard clarificationAllowed,
                  wire.caseType == nil,
                  let rawQuestion = wire.question else {
                throw ProblemRoutingError.invalidResponse
            }
            let question = rawQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !question.isEmpty else {
                throw ProblemRoutingError.invalidResponse
            }
            return .clarify(question: question)

        default:
            throw ProblemRoutingError.invalidResponse
        }
    }

    private static func stripMarkdownFence(from response: String) -> String {
        var text = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("```") else { return text }

        if let firstLineEnd = text.firstIndex(of: "\n") {
            text = String(text[text.index(after: firstLineEnd)...])
        }
        if text.hasSuffix("```") {
            text.removeLast(3)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

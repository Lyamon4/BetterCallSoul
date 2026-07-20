import CoreGraphics
import Foundation

struct EvidencePayload: @unchecked Sendable {
    let fileName: String
    let mimeType: String
    let data: Data
    let previewImage: CGImage
}

struct EvidenceAnalysis: Codable, Equatable, Sendable {
    let documentKind: String
    let rawText: String
    let counterparty: String?
    let amount: Decimal?
    let currency: String?
    let transactionDate: String?
    let evidenceSummary: String
    let importantDetails: [String]
    let warnings: [String]
    let confidence: [String: Double]
}

enum AIQuestionKind: String, Codable, Sendable {
    case text
    case choice
    case date
    case amount
    case boolean
}

struct AIQuestion: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let kind: AIQuestionKind
    let prompt: String
    let whyNeeded: String
    let options: [String]
    let required: Bool
}

struct AIAnswer: Codable, Equatable, Sendable {
    let questionID: String
    let value: String
}

struct CaseAIRequest: Codable, Equatable, Sendable {
    let caseType: CaseType
    let narrative: String
    let reviewedFields: [String: String]
    let evidenceSummary: String?
    let answers: [AIAnswer]
}

struct CaseAIAnalysis: Codable, Equatable, Sendable {
    let summary: String
    let recommendedAction: String
    let warnings: [String]
    let questions: [AIQuestion]
}

struct AIDocumentRequest: Codable, Equatable, Sendable {
    let caseContext: CaseAIRequest
    let analysis: CaseAIAnalysis
}

struct AIDocumentSections: Codable, Equatable, Sendable {
    let recipient: String?
    let subject: String
    let facts: [String]
    let legalGrounds: [String]
    let demands: [String]
    let responseDays: Int?
    let nonComplianceActions: [String]
    let attachmentDescription: String
    let unresolvedIssues: [String]
}

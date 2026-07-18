import Foundation

protocol EvidenceAnalyzing: Sendable {
    func analyze(
        payload: EvidencePayload,
        caseType: CaseType,
        narrative: String
    ) async throws -> EvidenceAnalysis
}

protocol LegalTextGenerating: Sendable {
    func analyzeCase(_ request: CaseAIRequest) async throws -> CaseAIAnalysis
    func generateDocument(_ request: AIDocumentRequest) async throws -> AIDocumentSections
}

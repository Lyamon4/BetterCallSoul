import Foundation
import Observation

@MainActor
@Observable
final class CaseWorkflowStore {
    private(set) var currentCase: LegalCase
    private let services: AIServiceContainer

    private(set) var narrative = ""
    private(set) var evidencePayload: EvidencePayload?
    private(set) var evidenceAnalysis: EvidenceAnalysis?
    private(set) var caseAnalysis: CaseAIAnalysis?
    private(set) var answers: [String: String] = [:]
    private(set) var aiDocumentSections: AIDocumentSections?
    private(set) var aiState: AIWorkflowState = .idle
    private(set) var activeProvider: AIProvider = .local

    init(seed: LegalCase? = nil, services: AIServiceContainer = .localOnly) {
        currentCase = seed ?? Self.makeDraft(type: .subscription)
        self.services = services
    }

    func start(type: CaseType) {
        currentCase = Self.makeDraft(type: type)
        narrative = ""
        evidencePayload = nil
        evidenceAnalysis = nil
        caseAnalysis = nil
        answers = [:]
        aiDocumentSections = nil
        aiState = .idle
        activeProvider = .local
    }

    func updateNarrative(_ value: String) {
        narrative = value
    }

    func attachEvidence(_ imported: ImportedEvidence) {
        evidencePayload = imported.payload
        currentCase.evidence = [imported.item]
        evidenceAnalysis = nil
        caseAnalysis = nil
        aiDocumentSections = nil
        aiState = .idle
    }

    func applyExtraction(evidence: EvidenceItem, fields: [ExtractedField]) {
        currentCase.evidence = [evidence]
        currentCase.extractedFields = fields
        synchronizeCaseFacts()
    }

    func removeEvidence() {
        currentCase.evidence = []
        currentCase.extractedFields = Self.emptyFields(for: currentCase.type)
        evidencePayload = nil
        evidenceAnalysis = nil
        caseAnalysis = nil
        aiDocumentSections = nil
        aiState = .idle
        synchronizeCaseFacts()
    }

    func updateField(label: String, value: String) {
        guard let index = currentCase.extractedFields.firstIndex(where: { $0.label == label }) else {
            return
        }

        currentCase.extractedFields[index].value = value
        currentCase.extractedFields[index].requiresReview = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        synchronizeCaseFacts()
    }

    func prepareDocument() {
        currentCase.status = .documentReady
    }

    func setAnswer(questionID: String, value: String) {
        answers[questionID] = value
    }

    func runAIAnalysis() async {
        var evidenceError: Error?

        if let evidencePayload {
            aiState = .analyzingEvidence
            do {
                let analysis = try await retryOnce {
                    try await services.evidenceAnalyzer.analyze(
                        payload: evidencePayload,
                        caseType: currentCase.type,
                        narrative: narrative
                    )
                }
                evidenceAnalysis = analysis
                applyEvidenceAnalysis(analysis)
                activeProvider = .gemini
            } catch {
                evidenceError = error
            }
        }

        aiState = .analyzingText
        do {
            caseAnalysis = try await retryOnce {
                try await services.legalTextGenerator.analyzeCase(makeCaseRequest())
            }
            activeProvider = .deepSeek
            if let evidenceError {
                aiState = .fallback(evidenceError.localizedDescription)
            } else {
                aiState = .questions
            }
        } catch {
            do {
                caseAnalysis = try await services.localTextGenerator.analyzeCase(makeCaseRequest())
            } catch {
                caseAnalysis = Self.emergencyAnalysis(for: currentCase.type)
            }
            activeProvider = .local
            aiState = .fallback(error.localizedDescription)
        }
    }

    func generateAIDocument() async {
        if caseAnalysis == nil {
            do {
                caseAnalysis = try await services.localTextGenerator.analyzeCase(makeCaseRequest())
            } catch {
                caseAnalysis = Self.emergencyAnalysis(for: currentCase.type)
            }
        }
        guard let caseAnalysis else { return }
        let request = AIDocumentRequest(caseContext: makeCaseRequest(), analysis: caseAnalysis)
        aiState = .generatingDocument

        do {
            aiDocumentSections = try await retryOnce {
                try await services.legalTextGenerator.generateDocument(request)
            }
            activeProvider = .deepSeek
            aiState = .ready
        } catch {
            do {
                aiDocumentSections = try await services.localTextGenerator.generateDocument(request)
            } catch {
                aiDocumentSections = nil
            }
            activeProvider = .local
            aiState = .fallback(error.localizedDescription)
        }
    }

    func resolvedDocumentDraft(senderName: String, createdAt: Date) -> DocumentDraft {
        guard let aiDocumentSections else {
            return DocumentDraftGenerator().makeDraft(
                from: currentCase,
                senderName: senderName,
                createdAt: createdAt
            )
        }
        return AIDocumentAdapter().makeDraft(
            sections: aiDocumentSections,
            legalCase: currentCase,
            senderName: senderName,
            createdAt: createdAt
        )
    }

    func markSent() {
        currentCase.status = .sent
    }

    private func synchronizeCaseFacts() {
        currentCase.counterparty = value(for: "Компания")
        currentCase.amount = Self.integerAmount(from: value(for: "Сумма"))
        currentCase.title = Self.title(for: currentCase.type, amount: currentCase.amount)
    }

    private func applyEvidenceAnalysis(_ analysis: EvidenceAnalysis) {
        let existingCompany = value(for: "Компания")
        let existingAmount = value(for: "Сумма")
        let existingDate = value(for: "Дата")
        let company = analysis.counterparty ?? existingCompany
        let amount = analysis.amount.map(Self.formatDecimalAmount) ?? existingAmount
        let date = analysis.transactionDate ?? existingDate
        currentCase.extractedFields = [
            ExtractedField(label: "Компания", value: company, requiresReview: company.isEmpty),
            ExtractedField(label: "Сумма", value: amount, requiresReview: amount.isEmpty),
            ExtractedField(label: "Дата", value: date, requiresReview: date.isEmpty),
            ExtractedField(label: "Тип", value: ReceiptFieldParser.displayName(for: currentCase.type))
        ]
        synchronizeCaseFacts()
    }

    private func makeCaseRequest() -> CaseAIRequest {
        CaseAIRequest(
            caseType: currentCase.type,
            narrative: narrative,
            reviewedFields: Dictionary(
                uniqueKeysWithValues: currentCase.extractedFields.map { ($0.label, $0.value) }
            ),
            evidenceSummary: evidenceAnalysis?.evidenceSummary,
            answers: answers.keys.sorted().map {
                AIAnswer(questionID: $0, value: answers[$0] ?? "")
            }
        )
    }

    private func retryOnce<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch {
            return try await operation()
        }
    }

    private func value(for label: String) -> String {
        currentCase.extractedFields
            .first(where: { $0.label == label })?
            .value
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func makeDraft(type: CaseType) -> LegalCase {
        LegalCase(
            number: makeCaseNumber(),
            type: type,
            title: title(for: type, amount: nil),
            counterparty: "",
            amount: nil,
            status: .draft,
            responseDeadline: nil,
            evidence: [],
            extractedFields: emptyFields(for: type)
        )
    }

    private static func emptyFields(for type: CaseType) -> [ExtractedField] {
        [
            ExtractedField(label: "Компания", value: "", requiresReview: true),
            ExtractedField(label: "Сумма", value: "", requiresReview: true),
            ExtractedField(label: "Дата", value: "", requiresReview: true),
            ExtractedField(label: "Тип", value: ReceiptFieldParser.displayName(for: type))
        ]
    }

    private static func makeCaseNumber(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "BCS-\(formatter.string(from: now))"
    }

    private static func integerAmount(from value: String) -> Int? {
        let digits = value.filter(\.isNumber)
        return digits.isEmpty ? nil : Int(digits)
    }

    private static func formatDecimalAmount(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = " "
        return "\(formatter.string(from: number) ?? number.stringValue) ₸"
    }

    private static func emergencyAnalysis(for type: CaseType) -> CaseAIAnalysis {
        CaseAIAnalysis(
            summary: "Обращение категории «\(type.rawValue)».",
            recommendedAction: "Проверьте заполненные поля и подготовьте обращение.",
            warnings: ["Автоматический анализ недоступен."],
            questions: []
        )
    }

    private static func title(for type: CaseType, amount: Int?) -> String {
        let formattedAmount = amount.map { " \(formatAmount($0)) ₸" } ?? ""
        switch type {
        case .charge:
            return "Возврат списания\(formattedAmount)"
        case .fine:
            return "Обжалование штрафа\(formattedAmount)"
        case .subscription:
            return "Возврат за подписку\(formattedAmount)"
        case .product:
            return "Претензия по товару\(formattedAmount)"
        case .bill:
            return "Перерасчёт счёта\(formattedAmount)"
        }
    }

    private static func formatAmount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

enum AIWorkflowState: Equatable, Sendable {
    case idle
    case analyzingEvidence
    case analyzingText
    case questions
    case generatingDocument
    case ready
    case fallback(String)
}

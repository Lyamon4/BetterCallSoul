import Foundation
import Observation

@MainActor
@Observable
final class CaseWorkflowStore {
    private(set) var currentCase: LegalCase

    init(seed: LegalCase? = nil) {
        currentCase = seed ?? Self.makeDraft(type: .subscription)
    }

    func start(type: CaseType) {
        currentCase = Self.makeDraft(type: type)
    }

    func applyExtraction(evidence: EvidenceItem, fields: [ExtractedField]) {
        currentCase.evidence = [evidence]
        currentCase.extractedFields = fields
        synchronizeCaseFacts()
    }

    func removeEvidence() {
        currentCase.evidence = []
        currentCase.extractedFields = Self.emptyFields(for: currentCase.type)
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

    func markSent() {
        currentCase.status = .sent
    }

    private func synchronizeCaseFacts() {
        currentCase.counterparty = value(for: "Компания")
        currentCase.amount = Self.integerAmount(from: value(for: "Сумма"))
        currentCase.title = Self.title(for: currentCase.type, amount: currentCase.amount)
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

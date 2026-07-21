import Foundation

enum CaseType: String, CaseIterable, Identifiable, Codable, Sendable {
    case charge = "Списали деньги"
    case fine = "Пришёл штраф"
    case subscription = "Отменить подписку"
    case product = "Проблема с товаром"
    case bill = "Завышенный счёт"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .charge: "creditcard.fill"
        case .fine: "doc.text.fill"
        case .subscription: "arrow.triangle.2.circlepath"
        case .product: "shippingbox.fill"
        case .bill: "list.bullet.rectangle.fill"
        }
    }
}

enum CaseStatus: String, Codable {
    case draft = "Черновик"
    case documentReady = "Документ готов"
    case sent = "Отправлено"
    case waitingForResponse = "Ожидается ответ"
    case actionRequired = "Требуется действие"
    case completed = "Завершено"
}

struct EvidenceItem: Identifiable, Equatable, Codable {
    let id: UUID
    let fileName: String
    let fileSize: String

    init(id: UUID = UUID(), fileName: String, fileSize: String) {
        self.id = id
        self.fileName = fileName
        self.fileSize = fileSize
    }
}

struct ExtractedField: Identifiable, Equatable, Codable {
    let id: UUID
    let kind: CaseFieldKind
    let label: String
    var value: String
    var requiresReview: Bool

    init(
        id: UUID = UUID(),
        kind: CaseFieldKind,
        label: String,
        value: String,
        requiresReview: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.value = value
        self.requiresReview = requiresReview
    }
}

struct LegalCase: Identifiable, Equatable, Codable {
    let id: UUID
    let number: String
    var type: CaseType
    var title: String
    var counterparty: String
    var amount: Int?
    var status: CaseStatus
    var responseDeadline: Date?
    var evidence: [EvidenceItem]
    var extractedFields: [ExtractedField]

    init(
        id: UUID = UUID(),
        number: String,
        type: CaseType,
        title: String,
        counterparty: String,
        amount: Int?,
        status: CaseStatus,
        responseDeadline: Date?,
        evidence: [EvidenceItem],
        extractedFields: [ExtractedField]
    ) {
        self.id = id
        self.number = number
        self.type = type
        self.title = title
        self.counterparty = counterparty
        self.amount = amount
        self.status = status
        self.responseDeadline = responseDeadline
        self.evidence = evidence
        self.extractedFields = extractedFields
    }
}

struct ToolItem: Identifiable, Equatable {
    let id: Int
    let title: String
}

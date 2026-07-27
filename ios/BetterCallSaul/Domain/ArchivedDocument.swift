import Foundation

struct ArchivedDocument: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let caseID: UUID
    let caseNumber: String
    let title: String
    let recipient: String
    let senderName: String
    let createdAt: Date
    let savedAt: Date
    let pdfFileName: String
}

enum DocumentArchiveError: LocalizedError, Equatable {
    case missingSignature
    case documentNotFound

    var errorDescription: String? {
        switch self {
        case .missingSignature:
            "Документ нельзя сохранить без подписи."
        case .documentNotFound:
            "Сохранённый PDF не найден."
        }
    }
}

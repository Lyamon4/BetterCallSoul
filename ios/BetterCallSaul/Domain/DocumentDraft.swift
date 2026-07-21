import Foundation

struct DocumentDraft: Equatable {
    let caseNumber: String
    let createdAt: Date
    let recipient: String
    let title: String
    let body: String
    let reviewNotice: String
    let attachmentCount: Int
    let senderName: String
    let requiresReview: Bool
}

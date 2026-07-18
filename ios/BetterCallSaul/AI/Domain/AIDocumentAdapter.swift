import Foundation

struct AIDocumentAdapter {
    func makeDraft(
        sections: AIDocumentSections,
        legalCase: LegalCase,
        senderName: String,
        createdAt: Date
    ) -> DocumentDraft {
        let recipient = sections.recipient?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedRecipient = recipient?.isEmpty == false
            ? recipient!
            : legalCase.counterparty.isEmpty ? "[укажите получателя]" : legalCase.counterparty
        let factLines = numbered(sections.facts)
        let demandLines = numbered(sections.demands)
        let body = """
        Фактические обстоятельства:
        \(factLines)

        Требования:
        \(demandLines)
        """
        let unresolved = sections.unresolvedIssues
        let requiresReview = resolvedRecipient == "[укажите получателя]"
            || !unresolved.isEmpty
            || legalCase.extractedFields.contains(where: \.requiresReview)
        let reviewNotice = unresolved.isEmpty
            ? "Перед отправкой проверьте факты, получателя и применимые основания."
            : "Требует проверки: \(unresolved.joined(separator: "; "))."

        return DocumentDraft(
            caseNumber: legalCase.number,
            createdAt: createdAt,
            recipient: resolvedRecipient,
            title: sections.subject,
            body: body,
            reviewNotice: reviewNotice,
            attachmentCount: legalCase.evidence.count,
            senderName: senderName,
            requiresReview: requiresReview
        )
    }

    private func numbered(_ values: [String]) -> String {
        guard !values.isEmpty else { return "[требуется уточнение]" }
        return values.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
    }
}

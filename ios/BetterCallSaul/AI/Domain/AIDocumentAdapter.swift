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
        let legalGroundLines = numbered(sections.legalGrounds)
        let demandLines = numbered(sections.demands)
        let responseDeadline = sections.responseDays.map {
            "Прошу рассмотреть изложенные требования и удовлетворить их добровольно. В случае несогласия прошу предоставить мотивированный письменный ответ в течение \($0) календарных дней со дня получения настоящего обращения."
        } ?? "[требуется уточнить применимый срок ответа]"
        let nonComplianceLines = numbered(sections.nonComplianceActions)
        let attachmentDescription = sections.attachmentDescription
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let body = """
        Фактические обстоятельства:
        \(factLines)

        Правовые основания:
        \(legalGroundLines)

        На основании изложенного требую:
        \(demandLines)

        Срок исполнения и ответа:
        \(responseDeadline)

        В случае отказа или отсутствия ответа:
        \(nonComplianceLines)

        Приложения:
        1. \(attachmentDescription.isEmpty ? "[подтверждающие материалы требуют уточнения]" : attachmentDescription)
        """
        var unresolved = sections.unresolvedIssues
        if sections.legalGrounds.isEmpty {
            unresolved.append("Уточнить применимые правовые основания")
        }
        if sections.responseDays == nil {
            unresolved.append("Уточнить применимый срок ответа")
        }
        if sections.nonComplianceActions.isEmpty {
            unresolved.append("Уточнить дальнейшие действия при отказе или отсутствии ответа")
        }
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

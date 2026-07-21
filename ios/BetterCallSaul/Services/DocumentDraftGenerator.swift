import Foundation

struct DocumentDraftGenerator {
    func makeDraft(
        from legalCase: LegalCase,
        senderName: String = "Алим",
        createdAt: Date = Date()
    ) -> DocumentDraft {
        let recipient = legalCase.counterparty.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = legalCase.amount.map(Self.formatAmount)
        let missingRecipient = recipient.isEmpty
        let missingAmount = amount == nil
        let requiresReview = missingRecipient || missingAmount || legalCase.extractedFields.contains(where: \.requiresReview)

        return DocumentDraft(
            caseNumber: legalCase.number,
            createdAt: createdAt,
            recipient: missingRecipient ? "[укажите получателя]" : recipient,
            title: title(for: legalCase.type, amount: amount),
            body: body(for: legalCase.type, amount: amount),
            reviewNotice: requiresReview
                ? "Перед отправкой заполните отмеченные поля и проверьте факты, получателя и применимые основания."
                : "Перед отправкой проверьте факты, получателя и применимые основания.",
            attachmentCount: legalCase.evidence.count,
            senderName: senderName,
            requiresReview: requiresReview
        )
    }

    private func title(for type: CaseType, amount: String?) -> String {
        let amountSuffix = amount.map { " \($0)" } ?? ""
        switch type {
        case .charge, .subscription:
            return "Требование о возврате\(amountSuffix)"
        case .fine:
            return "Заявление об обжаловании штрафа\(amountSuffix)"
        case .product:
            return "Претензия по качеству товара\(amountSuffix)"
        case .bill:
            return "Требование о перерасчёте счёта\(amountSuffix)"
        }
    }

    private func body(for type: CaseType, amount: String?) -> String {
        let amountPhrase = amount.map { " в размере \($0)" } ?? ""
        switch type {
        case .charge:
            return "С моего счёта было произведено списание\(amountPhrase). Прошу проверить основания операции и вернуть денежные средства при отсутствии законных оснований для удержания."
        case .fine:
            return "Прошу пересмотреть постановление о штрафе\(amountPhrase), проверить обстоятельства и приложенные доказательства, а также сообщить мотивированное решение."
        case .subscription:
            return "С моего счёта была списана сумма\(amountPhrase) за продление подписки. Прошу проверить обстоятельства списания, отменить дальнейшее продление и рассмотреть возврат денежных средств."
        case .product:
            return "Прошу рассмотреть претензию по приобретённому товару\(amountPhrase), проверить приложенные доказательства и предоставить предусмотренный законом способ урегулирования."
        case .bill:
            return "Прошу проверить начисления по выставленному счёту\(amountPhrase), предоставить расчёт и выполнить перерасчёт при выявлении ошибки."
        }
    }

    private static func formatAmount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = " "
        return "\(formatter.string(from: NSNumber(value: value)) ?? String(value)) ₸"
    }
}

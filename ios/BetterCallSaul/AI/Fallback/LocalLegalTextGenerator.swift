import Foundation

struct LocalLegalTextGenerator: LegalTextGenerating {
    func analyzeCase(_ request: CaseAIRequest) async throws -> CaseAIAnalysis {
        let missingFields = request.caseType.presentation.fields.filter { descriptor in
            request.reviewedFields[descriptor.label]?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty ?? true
        }
        let questions = Array(missingFields.prefix(5)).map { descriptor in
            AIQuestion(
                id: "local.\(descriptor.kind.rawValue).\(descriptor.label)",
                kind: questionKind(for: descriptor.kind),
                prompt: "Укажите: \(descriptor.label.lowercased())",
                whyNeeded: "Поле нужно для точного обращения",
                options: [],
                required: true
            )
        }
        return CaseAIAnalysis(
            summary: request.narrative.isEmpty
                ? "Нужно уточнить обстоятельства обращения."
                : request.narrative,
            recommendedAction: recommendation(for: request.caseType),
            warnings: ["Проверьте формулировки и факты перед отправкой."],
            questions: questions
        )
    }

    func generateDocument(_ request: AIDocumentRequest) async throws -> AIDocumentSections {
        let context = request.caseContext
        let facts = [context.narrative, context.evidenceSummary]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let descriptors = context.caseType.presentation.fields
        let missing = descriptors.filter { descriptor in
            context.reviewedFields[descriptor.label]?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty ?? true
        }
        let recipientLabel = descriptors.first(where: { $0.kind == .counterparty })?.label
        let recipient = recipientLabel.flatMap { nonEmpty(context.reviewedFields[$0]) }
        return AIDocumentSections(
            recipient: recipient,
            subject: subject(for: context.caseType),
            facts: facts.isEmpty ? ["Обстоятельства указаны пользователем в обращении."] : facts,
            legalGrounds: [],
            demands: demands(for: context.caseType),
            responseDays: nil,
            nonComplianceActions: [],
            attachmentDescription: context.evidenceSummary == nil
                ? "Подтверждающие материалы не приложены"
                : "Приложенные подтверждающие материалы",
            unresolvedIssues: missing.map { "Уточнить поле «\($0.label)»" }
                + ["Проверить применимые правовые основания и срок ответа"]
        )
    }

    private func questionKind(for fieldKind: CaseFieldKind) -> AIQuestionKind {
        switch fieldKind {
        case .amount: .amount
        case .date: .date
        case .counterparty, .reference, .detail: .text
        }
    }

    private func recommendation(for type: CaseType) -> String {
        switch type {
        case .charge: "Запросить основание операции и возврат средств."
        case .fine: "Подготовить заявление об обжаловании штрафа."
        case .subscription: "Запросить отмену подписки и возврат списания."
        case .product: "Направить продавцу претензию по товару."
        case .bill: "Запросить расчёт начислений и перерасчёт счёта."
        }
    }

    private func subject(for type: CaseType) -> String {
        switch type {
        case .charge: "Требование о возврате списанных средств"
        case .fine: "Заявление об обжаловании штрафа"
        case .subscription: "Требование об отмене подписки и возврате средств"
        case .product: "Претензия по качеству товара"
        case .bill: "Требование о перерасчёте счёта"
        }
    }

    private func demands(for type: CaseType) -> [String] {
        switch type {
        case .charge: ["Проверить основание списания", "Вернуть средства при отсутствии основания"]
        case .fine: ["Пересмотреть обстоятельства штрафа", "Сообщить мотивированное решение"]
        case .subscription: ["Отменить дальнейшее продление", "Рассмотреть возврат списанных средств"]
        case .product: ["Проверить недостаток товара", "Предложить возврат, замену или иной способ урегулирования"]
        case .bill: ["Предоставить расчёт начислений", "Выполнить перерасчёт при выявлении ошибки"]
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

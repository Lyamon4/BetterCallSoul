import Foundation

struct LocalLegalTextGenerator: LegalTextGenerating {
    func analyzeCase(_ request: CaseAIRequest) async throws -> CaseAIAnalysis {
        let missingFields = ["Компания", "Сумма", "Дата"].filter {
            request.reviewedFields[$0]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        }
        let questions = Array(missingFields.prefix(5)).map { field in
            AIQuestion(
                id: "local.\(field)",
                kind: field == "Сумма" ? .amount : field == "Дата" ? .date : .text,
                prompt: "Укажите: \(field.lowercased())",
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
            warnings: ["Использован локальный шаблон — проверьте формулировки перед отправкой."],
            questions: questions
        )
    }

    func generateDocument(_ request: AIDocumentRequest) async throws -> AIDocumentSections {
        let context = request.caseContext
        let facts = [context.narrative, context.evidenceSummary]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let missing = ["Компания", "Сумма", "Дата"].filter {
            context.reviewedFields[$0]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        }
        return AIDocumentSections(
            recipient: nonEmpty(context.reviewedFields["Компания"]),
            subject: subject(for: context.caseType),
            facts: facts.isEmpty ? ["Обстоятельства указаны пользователем в обращении."] : facts,
            demands: demands(for: context.caseType),
            responseDays: nil,
            attachmentDescription: context.evidenceSummary == nil
                ? "Подтверждающие материалы не приложены"
                : "Приложенные подтверждающие материалы",
            unresolvedIssues: missing.map { "Уточнить поле «\($0)»" }
        )
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

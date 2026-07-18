import Foundation

enum DeepSeekPrompts {
    static func requiredFacts(for type: CaseType) -> [String] {
        switch type {
        case .charge:
            ["кто списал деньги", "сумма и дата", "основание списания", "обращение в банк или компанию"]
        case .fine:
            ["орган и номер постановления", "дата и сумма штрафа", "причина несогласия", "срок обжалования"]
        case .subscription:
            ["название сервиса", "сумма и дата продления", "когда отменили или пытались отменить", "условия возврата"]
        case .product:
            ["продавец и товар", "дата покупки", "недостаток товара", "желаемый возврат или замена"]
        case .bill:
            ["поставщик услуги", "период и сумма счёта", "почему сумма завышена", "предыдущие показания или тариф"]
        }
    }

    static func analysisSystem(for type: CaseType) -> String {
        """
        Ты — AI-помощник BetterCallSaul по защите прав потребителей и гражданским обращениям.
        Категория: \(type.rawValue).
        Определи практичный следующий шаг и задай не больше пяти коротких уточняющих вопросов.
        Используй только переданный текст: не выдумывай факты, даты, суммы, адресатов и нормы права.
        Не цитируй законы и статьи, если точная юрисдикция и источник не предоставлены.
        Каждый неизвестный важный факт преврати в вопрос или warning.
        Верни только JSON object строго такой формы:
        {"summary":"string","recommendedAction":"string","warnings":["string"],"questions":[{"id":"string","kind":"text|choice|date|amount|boolean","prompt":"string","whyNeeded":"string","options":["string"],"required":true}]}
        Обязательные факты для проверки: \(requiredFacts(for: type).joined(separator: "; ")).
        """
    }

    static func analysis(request: CaseAIRequest) throws -> String {
        let data = try JSONEncoder().encode(request)
        return "Проанализируй следующий подтверждённый пользователем JSON:\n\(String(decoding: data, as: UTF8.self))"
    }

    static func documentSystem() -> String {
        """
        Составь деловое обращение на русском языке. Используй только факты из входного JSON и ответы пользователя.
        Не добавляй статьи закона, адреса, даты, суммы или обещания, которых нет во входных данных.
        Неизвестное не угадывай — добавь его в unresolvedIssues.
        Верни только JSON object строго такой формы:
        {"recipient":"string|null","subject":"string","facts":["string"],"demands":["string"],"responseDays":10,"attachmentDescription":"string","unresolvedIssues":["string"]}
        responseDays может быть null, если срок не подтверждён.
        """
    }

    static func document(request: AIDocumentRequest) throws -> String {
        let data = try JSONEncoder().encode(request)
        return "Подготовь документ, используя только факты из этого JSON:\n\(String(decoding: data, as: UTF8.self))"
    }
}

import Foundation

enum GeminiEvidencePrompt {
    static func make(caseType: CaseType, narrative: String) -> String {
        """
        Ты анализируешь визуальное доказательство для юридического помощника BetterCallSaul.
        Категория обращения: \(caseType.rawValue).
        Описание пользователя: \(narrative.isEmpty ? "не указано" : narrative).

        Извлекай только факты, которые реально видны в приложенном изображении или PDF.
        Не додумывай компанию, сумму, валюту, дату или содержание документа.
        Используй строго эти поля верхнего уровня: documentKind, rawText, counterparty,
        amount, currency, transactionDate, evidenceSummary, importantDetails, warnings.
        Не создавай вложенные объекты и дополнительные поля. amount верни строкой только с
        числом. Если факт не виден или неоднозначен, верни пустую строку и добавь пояснение
        в warnings.
        rawText должен быть максимально точной транскрипцией видимого текста.

        Analyze only information visibly present in the attached evidence.
        Never infer missing facts. Use an empty string for every unknown string field.
        Return data matching the supplied JSON schema, without markdown.
        """
    }
}

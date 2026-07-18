import Foundation

enum GeminiEvidencePrompt {
    static func make(caseType: CaseType, narrative: String) -> String {
        """
        Ты анализируешь визуальное доказательство для юридического помощника BetterCallSaul.
        Категория обращения: \(caseType.rawValue).
        Описание пользователя: \(narrative.isEmpty ? "не указано" : narrative).

        Извлекай только факты, которые реально видны в приложенном изображении или PDF.
        Не додумывай компанию, сумму, валюту, дату или содержание документа.
        Если факт не виден или неоднозначен, верни JSON null и добавь пояснение в warnings.
        rawText должен быть максимально точной транскрипцией видимого текста.

        Analyze only information visibly present in the attached evidence.
        Never infer missing facts. Use JSON null for every unknown nullable field.
        Return data matching the supplied JSON schema, without markdown.
        """
    }
}

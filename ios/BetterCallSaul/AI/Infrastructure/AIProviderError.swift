import Foundation

enum AIProvider: String, Codable, Sendable {
    case gemini
    case deepSeek
    case local
}

enum AIProviderError: Error, Equatable, LocalizedError, Sendable {
    case missingKey(AIProvider)
    case invalidConfiguration(String)
    case authenticationFailed(AIProvider)
    case quotaExceeded(AIProvider)
    case invalidResponse(AIProvider)
    case payloadTooLarge(maximumMB: Int)
    case transport(String)

    static func httpStatus(_ status: Int, provider: AIProvider) -> Self {
        switch status {
        case 401, 403:
            .authenticationFailed(provider)
        case 429:
            .quotaExceeded(provider)
        default:
            .invalidResponse(provider)
        }
    }

    var errorDescription: String? {
        switch self {
        case .missingKey(let provider):
            "Не добавлен API-ключ для \(provider.displayName)."
        case .invalidConfiguration(let message):
            "Ошибка конфигурации: \(message)"
        case .authenticationFailed(let provider):
            "\(provider.displayName) отклонил API-ключ."
        case .quotaExceeded(let provider):
            "У \(provider.displayName) закончился доступный лимит."
        case .invalidResponse(let provider):
            "\(provider.displayName) вернул некорректный ответ."
        case .payloadTooLarge(let maximumMB):
            "Файл слишком большой. Максимум — \(maximumMB) МБ."
        case .transport:
            "Не удалось связаться с AI-сервисом."
        }
    }
}

extension AIProvider {
    var displayName: String {
        switch self {
        case .gemini: "Gemini"
        case .deepSeek: "DeepSeek"
        case .local: "Локальный режим"
        }
    }
}

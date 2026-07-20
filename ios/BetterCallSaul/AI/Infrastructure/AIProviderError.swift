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
    case timedOut
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
        case .missingKey:
            "Сервис обработки временно недоступен."
        case .invalidConfiguration:
            "Сервис обработки настроен некорректно."
        case .authenticationFailed:
            "Не удалось подключиться к сервису обработки."
        case .quotaExceeded:
            "Сервис обработки временно перегружен."
        case .invalidResponse:
            "Не удалось обработать данные. Попробуйте ещё раз."
        case .payloadTooLarge(let maximumMB):
            "Файл слишком большой. Максимум — \(maximumMB) МБ."
        case .timedOut:
            "Сервис обработки отвечает слишком долго."
        case .transport:
            "Не удалось связаться с сервисом обработки."
        }
    }
}

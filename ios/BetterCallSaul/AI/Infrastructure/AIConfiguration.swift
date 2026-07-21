import Foundation

struct AIConfiguration: Equatable, Sendable {
    let geminiAPIKey: String
    let geminiModel: String
    let deepSeekAPIKey: String
    let deepSeekModel: String

    init(values: [String: String]) throws {
        geminiAPIKey = try Self.required("GeminiAPIKey", provider: .gemini, in: values)
        geminiModel = try Self.requiredModel("GeminiModel", in: values)
        deepSeekAPIKey = try Self.required("DeepSeekAPIKey", provider: .deepSeek, in: values)
        deepSeekModel = try Self.requiredModel("DeepSeekModel", in: values)
    }

    static func bundled(bundle: Bundle = .main) throws -> Self {
        let info = bundle.infoDictionary ?? [:]
        let values = ["GeminiAPIKey", "GeminiModel", "DeepSeekAPIKey", "DeepSeekModel"]
            .reduce(into: [String: String]()) { result, key in
                if let value = info[key] as? String {
                    result[key] = value
                }
            }
        return try AIConfiguration(values: values)
    }

    private static func required(
        _ key: String,
        provider: AIProvider,
        in values: [String: String]
    ) throws -> String {
        guard let value = values[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            throw AIProviderError.missingKey(provider)
        }
        return value
    }

    private static func requiredModel(_ key: String, in values: [String: String]) throws -> String {
        guard let value = values[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            throw AIProviderError.invalidConfiguration("Не указана модель \(key).")
        }
        return value
    }
}

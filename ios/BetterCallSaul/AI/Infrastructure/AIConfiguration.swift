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

    static func bundled(
        bundle: Bundle = .main,
        secrets: KeychainSecretStore = .init()
    ) throws -> Self {
        let info = bundle.infoDictionary ?? [:]
        var values = ["GeminiAPIKey", "GeminiModel", "DeepSeekAPIKey", "DeepSeekModel"]
            .reduce(into: [String: String]()) { result, key in
                if let value = info[key] as? String {
                    result[key] = value
                }
            }

        if let override = secrets.read(account: KeychainSecretStore.geminiAccount), !override.isEmpty {
            values["GeminiAPIKey"] = override
        }
        if let override = secrets.read(account: KeychainSecretStore.deepSeekAccount), !override.isEmpty {
            values["DeepSeekAPIKey"] = override
        }
        return try AIConfiguration(values: values)
    }

    var maskedGeminiKey: String { Self.mask(geminiAPIKey) }
    var maskedDeepSeekKey: String { Self.mask(deepSeekAPIKey) }

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

    private static func mask(_ value: String) -> String {
        "••••" + value.suffix(4)
    }
}

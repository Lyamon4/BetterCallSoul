import Foundation

struct GeminiInteractionRequest: Encodable {
    let model: String
    let input: [GeminiInput]
    let responseFormat: GeminiResponseFormat

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case responseFormat = "response_format"
    }
}

struct GeminiInput: Encodable {
    let type: String
    let text: String?
    let data: String?
    let mimeType: String?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case data
        case mimeType = "mime_type"
    }
}

struct GeminiResponseFormat: Encodable {
    let type = "text"
    let mimeType = "application/json"
    let schema: GeminiJSONValue

    enum CodingKeys: String, CodingKey {
        case type
        case mimeType = "mime_type"
        case schema
    }
}

indirect enum GeminiJSONValue: Encodable {
    case string(String)
    case bool(Bool)
    case object([String: GeminiJSONValue])
    case array([GeminiJSONValue])
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

struct GeminiInteractionResponse: Decodable {
    let status: String
    let steps: [GeminiInteractionStep]
}

struct GeminiInteractionStep: Decodable {
    let type: String
    let content: [GeminiInteractionContent]
}

struct GeminiInteractionContent: Decodable {
    let type: String
    let text: String?
}

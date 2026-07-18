import Foundation

struct DeepSeekChatRequest: Encodable {
    let model: String
    let messages: [DeepSeekMessage]
    let responseFormat = DeepSeekResponseFormat()
    let stream = false

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case responseFormat = "response_format"
        case stream
    }
}

struct DeepSeekMessage: Codable {
    let role: String
    let content: String
}

struct DeepSeekResponseFormat: Codable {
    let type = "json_object"
}

struct DeepSeekChatResponse: Decodable {
    let choices: [DeepSeekChoice]
}

struct DeepSeekChoice: Decodable {
    let finishReason: String
    let message: DeepSeekMessage

    enum CodingKeys: String, CodingKey {
        case finishReason = "finish_reason"
        case message
    }
}

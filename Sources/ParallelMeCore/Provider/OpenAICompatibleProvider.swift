import Foundation

public struct OpenAICompatibleConfiguration: Codable, Equatable, Sendable {
    public var baseURL: URL
    public var apiKey: String
    public var model: String
    public var temperature: Double
    public var timeout: TimeInterval

    public init(
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        apiKey: String,
        model: String,
        temperature: Double = 0.45,
        timeout: TimeInterval = 60
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
        self.timeout = timeout
    }
}

public enum OpenAICompatibleProviderError: Error, Equatable, Sendable {
    case invalidURL
    case transport(statusCode: Int, body: String)
    case missingMessageContent
    case invalidJSON(String)
}

public actor OpenAICompatibleProvider: LLMProvider {
    private let configuration: OpenAICompatibleConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        configuration: OpenAICompatibleConfiguration,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
        self.encoder = ParallelMeCoding.makeEncoder()
        self.decoder = ParallelMeCoding.makeDecoder()
    }

    public func generate<RequestPayload, ResponsePayload>(
        request: LLMRequest<RequestPayload>,
        responseType: ResponsePayload.Type
    ) async throws -> LLMEnvelope<ResponsePayload>
    where RequestPayload: Codable & Sendable, ResponsePayload: Codable & Sendable {
        let chatRequest = try ChatCompletionRequest(
            model: configuration.model,
            temperature: configuration.temperature,
            messages: PromptFactory.messages(for: request, encoder: encoder),
            responseFormat: ChatResponseFormat(type: "json_object")
        )
        let data = try encoder.encode(chatRequest)
        var urlRequest = URLRequest(url: configuration.baseURL.appendingPathComponent("chat/completions"))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.timeout
        urlRequest.httpBody = data
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (responseData, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAICompatibleProviderError.transport(statusCode: -1, body: "Missing HTTP response")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OpenAICompatibleProviderError.transport(
                statusCode: httpResponse.statusCode,
                body: String(data: responseData, encoding: .utf8) ?? ""
            )
        }

        let chatResponse = try decoder.decode(ChatCompletionResponse.self, from: responseData)
        guard let content = chatResponse.choices.first?.message.content else {
            throw OpenAICompatibleProviderError.missingMessageContent
        }
        let payload = try decodeModelJSON(content, as: responseType)
        return LLMEnvelope(payload: payload, trace: ["openai-compatible:\(request.kind.rawValue)"])
    }

    private func decodeModelJSON<ResponsePayload: Codable & Sendable>(
        _ content: String,
        as responseType: ResponsePayload.Type
    ) throws -> ResponsePayload {
        let trimmed = extractJSONObject(from: content)
        guard let data = trimmed.data(using: .utf8) else {
            throw OpenAICompatibleProviderError.invalidJSON(content)
        }
        do {
            return try decoder.decode(responseType, from: data)
        } catch {
            throw OpenAICompatibleProviderError.invalidJSON(trimmed)
        }
    }

    private func extractJSONObject(from content: String) -> String {
        var text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}"),
           start <= end {
            return String(text[start...end])
        }
        return text
    }
}

private struct ChatCompletionRequest: Encodable {
    var model: String
    var temperature: Double
    var messages: [ChatMessage]
    var responseFormat: ChatResponseFormat

    enum CodingKeys: String, CodingKey {
        case model
        case temperature
        case messages
        case responseFormat = "response_format"
    }
}

private struct ChatMessage: Codable {
    var role: String
    var content: String
}

private struct ChatResponseFormat: Codable {
    var type: String
}

private struct ChatCompletionResponse: Decodable {
    var choices: [Choice]

    struct Choice: Decodable {
        var message: Message
    }

    struct Message: Decodable {
        var content: String?
    }
}

private enum PromptFactory {
    static func messages<Payload: Codable & Sendable>(
        for request: LLMRequest<Payload>,
        encoder: JSONEncoder
    ) throws -> [ChatMessage] {
        let payloadData = try encoder.encode(request.payload)
        let payloadJSON = String(data: payloadData, encoding: .utf8) ?? "{}"
        return [
            ChatMessage(role: "system", content: ProviderPromptSpec.spec(for: request.kind).systemPrompt),
            ChatMessage(role: "user", content: "任务输入 JSON：\n\(payloadJSON)")
        ]
    }
}

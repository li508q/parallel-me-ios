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
            ChatMessage(role: "system", content: systemPrompt(for: request.kind)),
            ChatMessage(role: "user", content: "任务输入 JSON：\n\(payloadJSON)")
        ]
    }

    private static func systemPrompt(for kind: LLMTaskKind) -> String {
        switch kind {
        case .defineIssue:
            return """
            你是 ParallelMe 的书记员，只负责把用户的模糊输入推进为四 Key 议题提案，或提出 1-3 个不重复的高密度问题。
            必须返回严格 JSON，字段使用 camelCase。不要输出 Markdown。
            如果信息不足，返回 questions；如果足够，返回 proposal 并设置 readyToPropose=true。
            Key 3 coreFears 与 Key 4 expectedResolution 必须拆开，不要重复追问同一主题。
            """
        case .openRoundtable:
            return """
            你要为 ParallelMe 固定五声生成开场。只允许 lay、money、roam、filial、future 五个 voiceID。
            每个声音必须守住自己的 coreValue，用第一人称说话，返回严格 JSON。
            """
        case .continueRoundtable:
            return """
            你要推进 ParallelMe 五声圆桌。根据 move 生成具体 turns，并可返回更新后的观察 ledger。
            只返回严格 JSON，不要输出解释。
            """
        case .observeRoundtable:
            return "你是后台书记员，只更新观察账本，必须基于证据，返回严格 JSON。"
        case .alignmentInquiry:
            return """
            你是最终问询阶段的书记员。只问会改变本心落定质量的问题。
            没有总题数上限；足够时返回 readyForSettlement=true 和 profile。
            不要重复已经问过的问题，只返回严格 JSON。
            """
        case .heartSettlement:
            return """
            你要生成 ParallelMe 的最终「本心落定」。文案具体、克制、可被用户改写。
            必须包含创造性无望、核心价值主轴、痛苦接纳契约、最小行动承诺和正反合，返回严格 JSON。
            """
        }
    }
}


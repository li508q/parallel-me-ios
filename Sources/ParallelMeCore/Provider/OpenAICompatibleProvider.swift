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

public protocol OpenAICompatibleTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public actor URLSessionOpenAICompatibleTransport: OpenAICompatibleTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAICompatibleProviderError.transport(statusCode: -1, body: "Missing HTTP response")
        }
        return (data, httpResponse)
    }
}

public actor OpenAICompatibleProvider: LLMProvider {
    private let configuration: OpenAICompatibleConfiguration
    private let transport: any OpenAICompatibleTransport
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        configuration: OpenAICompatibleConfiguration,
        transport: any OpenAICompatibleTransport = URLSessionOpenAICompatibleTransport()
    ) {
        self.configuration = configuration
        self.transport = transport
        self.encoder = ParallelMeCoding.makeEncoder()
        self.decoder = ParallelMeCoding.makeDecoder()
    }

    public func generate<RequestPayload, ResponsePayload>(
        request: LLMRequest<RequestPayload>,
        responseType: ResponsePayload.Type
    ) async throws -> LLMEnvelope<ResponsePayload>
    where RequestPayload: Codable & Sendable, ResponsePayload: Codable & Sendable {
        let content = try await chatContent(
            messages: PromptFactory.messages(for: request, encoder: encoder)
        )
        let baseTrace = "openai-compatible:\(request.kind.rawValue)"
        do {
            let payload = try decodeModelJSON(content, as: responseType)
            return LLMEnvelope(payload: payload, trace: [baseTrace])
        } catch {
            let repairedContent = try await chatContent(
                messages: PromptFactory.repairMessages(
                    for: request.kind,
                    originalContent: content,
                    error: error
                )
            )
            let payload = try decodeModelJSON(repairedContent, as: responseType)
            return LLMEnvelope(payload: payload, trace: [baseTrace, "json-repair"])
        }
    }

    private func chatContent(messages: [ChatMessage]) async throws -> String {
        let chatRequest = ChatCompletionRequest(
            model: configuration.model,
            temperature: configuration.temperature,
            messages: messages,
            responseFormat: ChatResponseFormat(type: "json_object")
        )
        let data = try encoder.encode(chatRequest)
        var urlRequest = URLRequest(url: configuration.baseURL.appendingPathComponent("chat/completions"))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.timeout
        urlRequest.httpBody = data
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (responseData, httpResponse) = try await transport.data(for: urlRequest)
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
        return content
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
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        var searchIndex = text.startIndex
        while searchIndex < text.endIndex,
              let start = text[searchIndex...].firstIndex(of: "{") {
            if let candidate = balancedJSONObject(in: text, startingAt: start),
               let data = candidate.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data)) != nil {
                return candidate
            }
            searchIndex = text.index(after: start)
        }
        return text
    }

    private func balancedJSONObject(in text: String, startingAt start: String.Index) -> String? {
        var depth = 0
        var isInsideString = false
        var isEscaped = false
        var index = start

        while index < text.endIndex {
            let character = text[index]
            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
            } else if character == "\"" {
                isInsideString = true
            } else if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(text[start...index])
                }
                if depth < 0 {
                    return nil
                }
            }
            index = text.index(after: index)
        }
        return nil
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

    static func repairMessages(
        for kind: LLMTaskKind,
        originalContent: String,
        error: Error
    ) -> [ChatMessage] {
        let spec = ProviderPromptSpec.spec(for: kind)
        return [
            ChatMessage(
                role: "system",
                content: """
                你是 ParallelMe 的 JSON 修复器。把上一轮模型输出修复为当前任务要求的严格 JSON object。

                返回契约：
                \(spec.responseContract)

                只返回一个 JSON object。不要输出 Markdown、代码块、解释或额外文本。
                """
            ),
            ChatMessage(
                role: "user",
                content: """
                解码失败：
                \(String(describing: error))

                上一轮输出：
                \(originalContent)
                """
            )
        ]
    }
}

import Foundation

public enum LLMTaskKind: String, Codable, Sendable {
    case defineIssue
    case openRoundtable
    case continueRoundtable
    case observeRoundtable
    case alignmentInquiry
    case heartSettlement
}

public struct LLMRequest<Payload: Codable & Sendable>: Codable, Sendable {
    public var id: String
    public var kind: LLMTaskKind
    public var payload: Payload

    public init(id: String = UUID().uuidString, kind: LLMTaskKind, payload: Payload) {
        self.id = id
        self.kind = kind
        self.payload = payload
    }
}

public struct LLMEnvelope<Payload: Codable & Sendable>: Codable, Sendable {
    public var payload: Payload
    public var trace: [String]

    public init(payload: Payload, trace: [String] = []) {
        self.payload = payload
        self.trace = trace
    }
}

public protocol LLMProvider: Sendable {
    func generate<RequestPayload, ResponsePayload>(
        request: LLMRequest<RequestPayload>,
        responseType: ResponsePayload.Type
    ) async throws -> LLMEnvelope<ResponsePayload>
    where RequestPayload: Codable & Sendable, ResponsePayload: Codable & Sendable
}

public actor MockLLMProvider: LLMProvider {
    private var responses: [LLMTaskKind: Any] = [:]

    public init() {}

    public func register<ResponsePayload: Codable & Sendable>(
        _ payload: ResponsePayload,
        for kind: LLMTaskKind
    ) {
        responses[kind] = payload
    }

    public func generate<RequestPayload, ResponsePayload>(
        request: LLMRequest<RequestPayload>,
        responseType: ResponsePayload.Type
    ) async throws -> LLMEnvelope<ResponsePayload>
    where RequestPayload: Codable & Sendable, ResponsePayload: Codable & Sendable {
        guard let payload = responses[request.kind] as? ResponsePayload else {
            throw MockLLMProviderError.missingResponse(kind: request.kind)
        }
        return LLMEnvelope(payload: payload, trace: ["mock:\(request.kind.rawValue)"])
    }
}

public enum MockLLMProviderError: Error, Equatable, Sendable {
    case missingResponse(kind: LLMTaskKind)
}


import Foundation

public enum ProviderRuntimeMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case demo
    case openAICompatible

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .demo: "Demo"
        case .openAICompatible: "OpenAI"
        }
    }
}

public struct ProviderRuntimeSettings: Codable, Equatable, Sendable {
    public var mode: ProviderRuntimeMode
    public var baseURLString: String
    public var model: String
    public var apiKey: String

    public init(
        mode: ProviderRuntimeMode = .demo,
        baseURLString: String = "https://api.openai.com/v1",
        model: String = "gpt-4o-mini",
        apiKey: String = ""
    ) {
        self.mode = mode
        self.baseURLString = baseURLString
        self.model = model
        self.apiKey = apiKey
    }

    public var isUsable: Bool {
        switch mode {
        case .demo:
            true
        case .openAICompatible:
            resolvedBaseURL != nil &&
            !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public var resolvedBaseURL: URL? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host?.isEmpty == false else {
            return nil
        }
        return url
    }
}

public enum ProviderRuntimeFactory {
    public static func makeProvider(settings: ProviderRuntimeSettings) throws -> AnyLLMProvider {
        switch settings.mode {
        case .demo:
            return AnyLLMProvider(DemoLLMProvider())
        case .openAICompatible:
            guard let baseURL = settings.resolvedBaseURL, settings.isUsable else {
                throw ProviderRuntimeFactoryError.invalidOpenAICompatibleSettings
            }
            return AnyLLMProvider(
                OpenAICompatibleProvider(
                    configuration: OpenAICompatibleConfiguration(
                        baseURL: baseURL,
                        apiKey: settings.apiKey,
                        model: settings.model
                    )
                )
            )
        }
    }
}

public enum ProviderRuntimeFactoryError: Error, Equatable, Sendable {
    case invalidOpenAICompatibleSettings
}

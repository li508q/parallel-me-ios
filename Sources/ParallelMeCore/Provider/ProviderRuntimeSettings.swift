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
            normalized.resolvedBaseURL != nil &&
            !normalized.model.isEmpty &&
            !normalized.apiKey.isEmpty
        }
    }

    public var normalized: ProviderRuntimeSettings {
        ProviderRuntimeSettings(
            mode: mode,
            baseURLString: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    public var resolvedBaseURL: URL? {
        guard let url = URL(string: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)),
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
        try makeProvider(
            settings: settings,
            openAITransport: URLSessionOpenAICompatibleTransport()
        )
    }

    public static func makeProvider(
        settings: ProviderRuntimeSettings,
        openAITransport: any OpenAICompatibleTransport
    ) throws -> AnyLLMProvider {
        let settings = settings.normalized
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
                    ),
                    transport: openAITransport
                )
            )
        }
    }
}

public enum ProviderRuntimeFactoryError: Error, Equatable, Sendable {
    case invalidOpenAICompatibleSettings
}

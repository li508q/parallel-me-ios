import Foundation
#if canImport(Security)
import Security
#endif

public struct ProviderRuntimeMetadata: Codable, Equatable, Sendable {
    public var mode: ProviderRuntimeMode
    public var baseURLString: String
    public var model: String

    public init(
        mode: ProviderRuntimeMode = .demo,
        baseURLString: String = "https://api.openai.com/v1",
        model: String = "gpt-4o-mini"
    ) {
        self.mode = mode
        self.baseURLString = baseURLString
        self.model = model
    }

    public init(settings: ProviderRuntimeSettings) {
        self.init(
            mode: settings.mode,
            baseURLString: settings.baseURLString,
            model: settings.model
        )
    }

    public func runtimeSettings(apiKey: String) -> ProviderRuntimeSettings {
        ProviderRuntimeSettings(
            mode: mode,
            baseURLString: baseURLString,
            model: model,
            apiKey: apiKey
        )
    }
}

public protocol ProviderRuntimeMetadataStore: Sendable {
    func loadMetadata() async throws -> ProviderRuntimeMetadata
    func saveMetadata(_ metadata: ProviderRuntimeMetadata) async throws
    func clearMetadata() async throws
}

public protocol SecretStore: Sendable {
    func loadSecret(key: String) async throws -> String?
    func saveSecret(_ secret: String, key: String) async throws
    func deleteSecret(key: String) async throws
}

public protocol ProviderSettingsStoring: Sendable {
    func loadSettings() async throws -> ProviderRuntimeSettings
    func saveSettings(_ settings: ProviderRuntimeSettings) async throws
    func clearSettings() async throws
}

public actor ProviderSettingsRepository: ProviderSettingsStoring {
    private let metadataStore: any ProviderRuntimeMetadataStore
    private let secretStore: any SecretStore
    private let apiKeySecretName: String

    public init(
        metadataStore: any ProviderRuntimeMetadataStore,
        secretStore: any SecretStore,
        apiKeySecretName: String = "openai-compatible-api-key"
    ) {
        self.metadataStore = metadataStore
        self.secretStore = secretStore
        self.apiKeySecretName = apiKeySecretName
    }

    public static func defaultRepository() -> ProviderSettingsRepository {
        ProviderSettingsRepository(
            metadataStore: FileProviderRuntimeMetadataStore.defaultStore(),
            secretStore: KeychainSecretStore(service: "com.parallelme.provider")
        )
    }

    public func loadSettings() async throws -> ProviderRuntimeSettings {
        let metadata = try await metadataStore.loadMetadata()
        let apiKey = try await secretStore.loadSecret(key: apiKeySecretName) ?? ""
        return metadata.runtimeSettings(apiKey: apiKey)
    }

    public func saveSettings(_ settings: ProviderRuntimeSettings) async throws {
        try await metadataStore.saveMetadata(ProviderRuntimeMetadata(settings: settings))
        let trimmedKey = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKey.isEmpty {
            try await secretStore.deleteSecret(key: apiKeySecretName)
        } else {
            try await secretStore.saveSecret(trimmedKey, key: apiKeySecretName)
        }
    }

    public func clearSettings() async throws {
        try await metadataStore.clearMetadata()
        try await secretStore.deleteSecret(key: apiKeySecretName)
    }
}

public actor FileProviderRuntimeMetadataStore: ProviderRuntimeMetadataStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.encoder = ParallelMeCoding.makeEncoder()
        self.decoder = ParallelMeCoding.makeDecoder()
    }

    public static func defaultStore() -> FileProviderRuntimeMetadataStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return FileProviderRuntimeMetadataStore(
            fileURL: base
                .appendingPathComponent("ParallelMe", isDirectory: true)
                .appendingPathComponent("provider-settings.json")
        )
    }

    public func loadMetadata() async throws -> ProviderRuntimeMetadata {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return ProviderRuntimeMetadata()
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(ProviderRuntimeMetadata.self, from: data)
    }

    public func saveMetadata(_ metadata: ProviderRuntimeMetadata) async throws {
        try ensureDirectory()
        let data = try encoder.encode(metadata)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func clearMetadata() async throws {
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    private func ensureDirectory() throws {
        let directory = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}

public actor InMemoryProviderRuntimeMetadataStore: ProviderRuntimeMetadataStore {
    private var metadata: ProviderRuntimeMetadata?

    public init(metadata: ProviderRuntimeMetadata? = nil) {
        self.metadata = metadata
    }

    public func loadMetadata() async throws -> ProviderRuntimeMetadata {
        metadata ?? ProviderRuntimeMetadata()
    }

    public func saveMetadata(_ metadata: ProviderRuntimeMetadata) async throws {
        self.metadata = metadata
    }

    public func clearMetadata() async throws {
        metadata = nil
    }
}

public actor InMemorySecretStore: SecretStore {
    private var secrets: [String: String] = [:]

    public init() {}

    public func loadSecret(key: String) async throws -> String? {
        secrets[key]
    }

    public func saveSecret(_ secret: String, key: String) async throws {
        secrets[key] = secret
    }

    public func deleteSecret(key: String) async throws {
        secrets[key] = nil
    }
}

public enum KeychainSecretStoreError: Error, Equatable, Sendable {
    case unavailable
    case invalidData
    case unexpectedStatus(Int32)
}

public actor KeychainSecretStore: SecretStore {
    private let service: String

    public init(service: String) {
        self.service = service
    }

    public func loadSecret(key: String) async throws -> String? {
        #if canImport(Security)
        var query = baseQuery(key: key)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw KeychainSecretStoreError.unexpectedStatus(status)
        }
        guard let data = item as? Data,
              let secret = String(data: data, encoding: .utf8) else {
            throw KeychainSecretStoreError.invalidData
        }
        return secret
        #else
        throw KeychainSecretStoreError.unavailable
        #endif
    }

    public func saveSecret(_ secret: String, key: String) async throws {
        #if canImport(Security)
        let data = Data(secret.utf8)
        let query = baseQuery(key: key)
        let update = [kSecValueData as String: data] as CFDictionary
        let status = SecItemUpdate(query as CFDictionary, update)
        if status == errSecSuccess { return }
        if status != errSecItemNotFound {
            throw KeychainSecretStoreError.unexpectedStatus(status)
        }
        var add = query
        add[kSecValueData as String] = data
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainSecretStoreError.unexpectedStatus(addStatus)
        }
        #else
        throw KeychainSecretStoreError.unavailable
        #endif
    }

    public func deleteSecret(key: String) async throws {
        #if canImport(Security)
        let status = SecItemDelete(baseQuery(key: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainSecretStoreError.unexpectedStatus(status)
        }
        #else
        throw KeychainSecretStoreError.unavailable
        #endif
    }

    #if canImport(Security)
    private func baseQuery(key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
    #endif
}


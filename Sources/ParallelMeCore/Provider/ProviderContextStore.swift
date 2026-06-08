import Foundation

public protocol ProviderContextStoring: Sendable {
    func loadContext() async throws -> ProviderContext
    func saveContext(_ context: ProviderContext) async throws
    func clearContext() async throws
}

public actor FileProviderContextStore: ProviderContextStoring {
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

    public static func defaultStore() -> FileProviderContextStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return FileProviderContextStore(
            fileURL: base
                .appendingPathComponent("ParallelMe", isDirectory: true)
                .appendingPathComponent("provider-context.json")
        )
    }

    public func loadContext() async throws -> ProviderContext {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return ProviderContext()
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(ProviderContext.self, from: data).normalized
    }

    public func saveContext(_ context: ProviderContext) async throws {
        try ensureDirectory()
        let data = try encoder.encode(context.normalized)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func clearContext() async throws {
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

public actor InMemoryProviderContextStore: ProviderContextStoring {
    private var context: ProviderContext

    public init(context: ProviderContext = ProviderContext()) {
        self.context = context.normalized
    }

    public func loadContext() async throws -> ProviderContext {
        context
    }

    public func saveContext(_ context: ProviderContext) async throws {
        self.context = context.normalized
    }

    public func clearContext() async throws {
        context = ProviderContext()
    }
}

import Foundation

public actor FileMeetingRepository: MeetingRepository {
    private let directoryURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager

    public init(
        directoryURL: URL,
        fileManager: FileManager = .default
    ) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
        self.encoder = ParallelMeCoding.makeEncoder()
        self.decoder = ParallelMeCoding.makeDecoder()
    }

    public static func defaultRepository() -> FileMeetingRepository {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return FileMeetingRepository(directoryURL: base.appendingPathComponent("ParallelMeMeetings", isDirectory: true))
    }

    public func save(_ state: MeetingFlowState) async throws {
        try ensureDirectory()
        let data = try encoder.encode(state)
        try data.write(to: fileURL(for: state.id), options: [.atomic])
    }

    public func load(id: String) async throws -> MeetingFlowState? {
        let url = fileURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(MeetingFlowState.self, from: data)
    }

    public func list() async throws -> [MeetingFlowState] {
        try ensureDirectory()
        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return try urls
            .filter { $0.pathExtension == "json" }
            .map { url in
                let data = try Data(contentsOf: url)
                return try decoder.decode(MeetingFlowState.self, from: data)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func delete(id: String) async throws {
        let url = fileURL(for: id)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func ensureDirectory() throws {
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }

    private func fileURL(for id: String) -> URL {
        directoryURL.appendingPathComponent("\(id).json")
    }
}


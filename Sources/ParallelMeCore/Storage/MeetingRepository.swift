import Foundation

public protocol MeetingRepository: Sendable {
    func save(_ state: MeetingFlowState) async throws
    func load(id: String) async throws -> MeetingFlowState?
    func list() async throws -> [MeetingFlowState]
    func delete(id: String) async throws
}

public actor AnyMeetingRepository: MeetingRepository {
    private let base: any MeetingRepository

    public init(_ base: any MeetingRepository) {
        self.base = base
    }

    public func save(_ state: MeetingFlowState) async throws {
        try await base.save(state)
    }

    public func load(id: String) async throws -> MeetingFlowState? {
        try await base.load(id: id)
    }

    public func list() async throws -> [MeetingFlowState] {
        try await base.list()
    }

    public func delete(id: String) async throws {
        try await base.delete(id: id)
    }
}

public actor InMemoryMeetingRepository: MeetingRepository {
    private var states: [String: MeetingFlowState] = [:]

    public init() {}

    public func save(_ state: MeetingFlowState) async throws {
        states[state.id] = state
    }

    public func load(id: String) async throws -> MeetingFlowState? {
        states[id]
    }

    public func list() async throws -> [MeetingFlowState] {
        states.values.sorted { $0.createdAt > $1.createdAt }
    }

    public func delete(id: String) async throws {
        states[id] = nil
    }
}

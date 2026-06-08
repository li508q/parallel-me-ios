import Foundation

public enum MeetingSessionEventKind: String, Codable, Sendable {
    case started
    case providerRequest
    case providerResponse
    case persisted
    case failed
}

public struct MeetingSessionEvent: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var meetingID: String?
    public var kind: MeetingSessionEventKind
    public var message: String
    public var trace: [String]
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        meetingID: String? = nil,
        kind: MeetingSessionEventKind,
        message: String,
        trace: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.meetingID = meetingID
        self.kind = kind
        self.message = message
        self.trace = trace
        self.createdAt = createdAt
    }
}

public protocol MeetingSessionEventSink: Sendable {
    func record(_ event: MeetingSessionEvent) async
}

public actor NoopMeetingSessionEventSink: MeetingSessionEventSink {
    public init() {}
    public func record(_ event: MeetingSessionEvent) async {}
}

public actor InMemoryMeetingSessionEventSink: MeetingSessionEventSink {
    private var events: [MeetingSessionEvent] = []

    public init() {}

    public func record(_ event: MeetingSessionEvent) async {
        events.append(event)
    }

    public func allEvents() async -> [MeetingSessionEvent] {
        events
    }
}

public protocol MeetingCoordinating: Sendable {
    func currentState() async -> MeetingFlowState?
    func restore(_ restored: MeetingFlowState) async throws -> MeetingFlowState
    func start(rawInput: String) async throws -> MeetingFlowState
    func requestDefinition() async throws -> MeetingFlowState
    func submitProbeAnswers(_ answers: [ScribeAnswer]) async throws -> MeetingFlowState
    func refineProposal(feedback: String) async throws -> MeetingFlowState
    func confirmProposalAndOpenRoundtable() async throws -> MeetingFlowState
    func submitRoundtableMove(_ move: RoundtableMove) async throws -> MeetingFlowState
    func startInquiry() async throws -> MeetingFlowState
    func submitInquiryAnswers(_ answers: [ScribeInquiryAnswer]) async throws -> MeetingFlowState
    func requestNextInquiry() async throws -> MeetingFlowState
    func requestSettlement() async throws -> MeetingFlowState
    func reviseSettlement(_ revisions: [SettlementModuleID: String]) async throws -> MeetingFlowState
    func archive() async throws -> MeetingFlowState
}

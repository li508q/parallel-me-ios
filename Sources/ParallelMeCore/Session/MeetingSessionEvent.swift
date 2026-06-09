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

public struct MeetingSessionDiagnosticsSnapshot: Equatable, Sendable {
    public var recentEvents: [MeetingSessionEvent]
    public var totalCount: Int
    public var providerRequestCount: Int
    public var providerResponseCount: Int
    public var persistedCount: Int
    public var failureCount: Int
    public var latestFailure: MeetingSessionEvent?

    public init(events: [MeetingSessionEvent] = [], limit: Int = 12) {
        let ordered = events.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id < rhs.id
            }
            return lhs.createdAt < rhs.createdAt
        }
        let visibleLimit = max(0, limit)
        self.recentEvents = Array(ordered.suffix(visibleLimit))
        self.totalCount = ordered.count
        self.providerRequestCount = ordered.filter { $0.kind == .providerRequest }.count
        self.providerResponseCount = ordered.filter { $0.kind == .providerResponse }.count
        self.persistedCount = ordered.filter { $0.kind == .persisted }.count
        self.failureCount = ordered.filter { $0.kind == .failed }.count
        self.latestFailure = ordered.last { $0.kind == .failed }
    }

    public var isEmpty: Bool {
        totalCount == 0
    }

    public var displayedCount: Int {
        recentEvents.count
    }

    public var hasFailures: Bool {
        failureCount > 0
    }

    public var pendingProviderResponseCount: Int {
        max(0, providerRequestCount - providerResponseCount)
    }

    public var title: String {
        if failureCount > 0 {
            return "运行轨迹 · \(failureCount) 次失败"
        }
        if pendingProviderResponseCount > 0 {
            return "运行轨迹 · 等待模型响应"
        }
        return "运行轨迹 · \(totalCount) 条事件"
    }

    public var detail: String {
        if let latestFailure {
            return latestFailure.message
        }
        if pendingProviderResponseCount > 0 {
            return "还有 \(pendingProviderResponseCount) 个模型请求没有对应响应。"
        }
        if totalCount > displayedCount {
            return "显示最近 \(displayedCount) 条，共 \(totalCount) 条。"
        }
        return "请求 \(providerRequestCount) · 响应 \(providerResponseCount) · 保存 \(persistedCount)"
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

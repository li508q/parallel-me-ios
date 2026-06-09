import Foundation

public struct MeetingArchiveSnapshot: Codable, Equatable, Sendable {
    public var summary: MeetingSummary
    public var issueRows: [MeetingArchiveRow]
    public var settlementRows: [MeetingArchiveRow]
    public var timelineItems: [MeetingTimelineItem]

    public init(
        summary: MeetingSummary,
        issueRows: [MeetingArchiveRow] = [],
        settlementRows: [MeetingArchiveRow] = [],
        timelineItems: [MeetingTimelineItem] = []
    ) {
        self.summary = summary
        self.issueRows = issueRows
        self.settlementRows = settlementRows
        self.timelineItems = timelineItems
    }

    public init(state: MeetingFlowState) {
        self.init(
            summary: MeetingSummary(state: state),
            issueRows: MeetingArchiveSnapshot.issueRows(for: state),
            settlementRows: MeetingArchiveSnapshot.settlementRows(for: state),
            timelineItems: MeetingTimeline.items(for: state)
        )
    }

    public var hasIssue: Bool {
        !issueRows.isEmpty
    }

    public var hasSettlement: Bool {
        !settlementRows.isEmpty
    }

    private static func issueRows(for state: MeetingFlowState) -> [MeetingArchiveRow] {
        if let proposal = state.issueProposal {
            return IssueProposalSnapshot(proposal: proposal).rows
                .map {
                    MeetingArchiveRow(
                        id: "issue:\($0.purpose.rawValue)",
                        title: $0.title,
                        body: $0.body,
                        details: $0.details
                    )
                }
                .filter(\.isMeaningful)
        }

        guard let taskFrame = state.taskFrame else { return [] }
        return [
            MeetingArchiveRow(id: "issue:problemDefinition", title: "问题定义", body: taskFrame.problemDefinition),
            MeetingArchiveRow(id: "issue:currentState", title: "当前处境", body: taskFrame.currentState, details: taskFrame.keyFacts),
            MeetingArchiveRow(id: "issue:coreConflict", title: "核心冲突", body: taskFrame.coreConflict, details: taskFrame.mainConcerns),
            MeetingArchiveRow(id: "issue:discussionFocus", title: "讨论焦点", body: taskFrame.centralQuestion, details: taskFrame.mainChoices + [taskFrame.discussionFocus])
        ].filter(\.isMeaningful)
    }

    private static func settlementRows(for state: MeetingFlowState) -> [MeetingArchiveRow] {
        guard let settlement = state.heartSettlement else { return [] }
        return HeartSettlementSnapshot(settlement: settlement).rows
            .map {
                MeetingArchiveRow(
                    id: "settlement:\($0.moduleID.rawValue)",
                    title: $0.title,
                    body: $0.body,
                    details: $0.details
                )
            }
            .filter(\.isMeaningful)
    }
}

public struct MeetingArchiveActionSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var systemImage: String

    public init(title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }
}

public struct MeetingArchiveSectionSnapshot: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var rows: [MeetingArchiveRow]

    public init(id: String, title: String, rows: [MeetingArchiveRow]) {
        self.id = id
        self.title = title
        self.rows = rows
    }

    public var isVisible: Bool {
        !rows.isEmpty
    }
}

public struct MeetingArchiveTimelinePresentationSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var items: [MeetingTimelineItem]

    public init(items: [MeetingTimelineItem]) {
        self.items = items
        self.title = "完整脉络 · \(items.count) 步"
    }

    public var isVisible: Bool {
        !items.isEmpty
    }
}

public struct MeetingArchivePresentationSnapshot: Codable, Equatable, Sendable {
    public var eyebrow: String
    public var title: String
    public var detail: String
    public var sections: [MeetingArchiveSectionSnapshot]
    public var timeline: MeetingArchiveTimelinePresentationSnapshot?
    public var resetAction: MeetingArchiveActionSnapshot

    public init(snapshot: MeetingArchiveSnapshot) {
        let settlementSection = MeetingArchiveSectionSnapshot(
            id: "settlement",
            title: "本心落定",
            rows: snapshot.settlementRows
        )
        let issueSection = MeetingArchiveSectionSnapshot(
            id: "issue",
            title: "本次议题",
            rows: snapshot.issueRows
        )
        let timeline = MeetingArchiveTimelinePresentationSnapshot(items: snapshot.timelineItems)

        self.eyebrow = "归档纸页"
        self.title = snapshot.summary.title
        self.detail = "已保存为本地纸页，可以随时回到首页从纸页库打开。"
        self.sections = [settlementSection, issueSection].filter(\.isVisible)
        self.timeline = timeline.isVisible ? timeline : nil
        self.resetAction = MeetingArchiveActionSnapshot(
            title: "开始新的圆桌",
            systemImage: "plus.circle.fill"
        )
    }

    public init(state: MeetingFlowState) {
        self.init(snapshot: MeetingArchiveSnapshot(state: state))
    }
}

public struct MeetingArchiveRow: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var body: String
    public var details: [String]

    public init(
        id: String? = nil,
        title: String,
        body: String,
        details: [String] = []
    ) {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDetails = details.compactMap(\.nonEmptyArchiveText)
        self.id = id ?? "\(normalizedTitle)|\(normalizedBody.prefix(28))"
        self.title = normalizedTitle
        self.body = normalizedBody
        self.details = normalizedDetails
    }

    public var isMeaningful: Bool {
        !title.isEmpty && !body.isEmpty
    }
}

private extension String {
    var nonEmptyArchiveText: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

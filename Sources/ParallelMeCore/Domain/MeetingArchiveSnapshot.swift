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
            return [
                MeetingArchiveRow(id: "issue:surfaceDilemma", title: "选择岔路", body: proposal.surfaceDilemma.content, details: proposal.surfaceDilemma.details),
                MeetingArchiveRow(id: "issue:currentConstraints", title: "现实边界", body: proposal.currentConstraints.content, details: proposal.currentConstraints.details),
                MeetingArchiveRow(id: "issue:coreFears", title: "隐秘关切", body: proposal.coreFears.content, details: proposal.coreFears.details),
                MeetingArchiveRow(id: "issue:expectedResolution", title: "圆桌任务", body: proposal.expectedResolution.content, details: proposal.expectedResolution.details)
            ].filter(\.isMeaningful)
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
        return [
            MeetingArchiveRow(
                id: "settlement:creativeHopelessness",
                title: settlement.creativeHopelessness.title.nonEmptyArchiveText ?? "创造性无望",
                body: settlement.resolvedText(for: .creativeHopelessness),
                details: settlement.creativeHopelessness.evidence
            ),
            MeetingArchiveRow(
                id: "settlement:coreValues",
                title: settlement.coreValueAxis.title.nonEmptyArchiveText ?? "核心价值主轴",
                body: settlement.resolvedText(for: .coreValues),
                details: settlement.coreValueAxis.evidence
            ),
            MeetingArchiveRow(
                id: "settlement:costAcceptance",
                title: settlement.costAcceptanceContract.title.nonEmptyArchiveText ?? "痛苦接纳契约",
                body: settlement.resolvedText(for: .costAcceptance),
                details: settlement.costAcceptanceContract.evidence
            ),
            MeetingArchiveRow(
                id: "settlement:minimumAction",
                title: settlement.minimumViableCommitment.title.nonEmptyArchiveText ?? "最小行动承诺",
                body: settlement.resolvedText(for: .minimumAction),
                details: settlement.minimumViableCommitment.evidence
            ),
            MeetingArchiveRow(
                id: "settlement:dialecticSynthesis",
                title: "正反合",
                body: settlement.resolvedText(for: .dialecticSynthesis),
                details: [settlement.dialecticSynthesis.thesis, settlement.dialecticSynthesis.antithesis]
            )
        ].filter(\.isMeaningful)
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

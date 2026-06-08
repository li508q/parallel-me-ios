import Foundation

public struct MeetingSummary: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var stage: MeetingStage
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        title: String,
        subtitle: String,
        stage: MeetingStage,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.stage = stage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(state: MeetingFlowState) {
        self.init(
            id: state.id,
            title: MeetingSummary.title(for: state),
            subtitle: MeetingSummary.subtitle(for: state),
            stage: state.stage,
            createdAt: state.createdAt,
            updatedAt: MeetingSummary.updatedAt(for: state)
        )
    }

    private static func title(for state: MeetingFlowState) -> String {
        if let settlement = state.heartSettlement?.headline.nonEmptySummaryText {
            return settlement
        }
        if let issue = state.issueProposal?.issueSentence.nonEmptySummaryText {
            return issue
        }
        return state.rawInput.nonEmptySummaryText ?? "未命名圆桌"
    }

    private static func subtitle(for state: MeetingFlowState) -> String {
        switch state.stage {
        case .defining:
            return "议题定义中"
        case .roundtable:
            return "五声圆桌 · \(state.roundtable.openingTurns.count) 个开场"
        case .inquiry:
            return "书记员问询 · \(state.inquiryAnswers.count) 个回答"
        case .settlement:
            return "本心落定待归档"
        case .archived:
            return "已归档"
        }
    }

    private static func updatedAt(for state: MeetingFlowState) -> Date {
        ([state.createdAt] + [
            state.roundtable.moves.map(\.createdAt).max(),
            state.roundtable.turns.map(\.createdAt).max(),
            state.inquiryAnswers.map(\.answeredAt).max(),
            state.roundtable.openingTurns.map(\.createdAt).max()
        ]
        .compactMap { $0 })
        .max() ?? state.createdAt
    }
}

private extension String {
    var nonEmptySummaryText: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

import Foundation

public enum MeetingTimelineKind: String, Codable, Sendable {
    case started
    case definingAnswer
    case proposal
    case roundtableOpened
    case roundtableMove
    case inquiryAnswer
    case settlement
    case archived
}

public struct MeetingTimelineItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: MeetingTimelineKind
    public var stage: MeetingStage
    public var title: String
    public var detail: String
    public var createdAt: Date

    public init(
        id: String,
        kind: MeetingTimelineKind,
        stage: MeetingStage,
        title: String,
        detail: String,
        createdAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.stage = stage
        self.title = title
        self.detail = detail
        self.createdAt = createdAt
    }
}

public enum MeetingTimeline {
    public static func items(for state: MeetingFlowState) -> [MeetingTimelineItem] {
        var items: [MeetingTimelineItem] = [
            MeetingTimelineItem(
                id: "\(state.id):started",
                kind: .started,
                stage: .defining,
                title: "写下原始困惑",
                detail: state.rawInput.timelineDetail,
                createdAt: state.createdAt
            )
        ]

        for (index, entry) in state.definingDialogue.enumerated() {
            guard let answer = entry.answer else { continue }
            items.append(
                MeetingTimelineItem(
                    id: "\(state.id):defining-answer:\(answer.id):\(index)",
                    kind: .definingAnswer,
                    stage: .defining,
                    title: "回应书记员",
                    detail: answer.timelineDetail,
                    createdAt: answer.answeredAt
                )
            )
        }

        if let proposal = state.issueProposal {
            items.append(
                MeetingTimelineItem(
                    id: "\(state.id):proposal",
                    kind: .proposal,
                    stage: .defining,
                    title: "议题提案完成",
                    detail: proposal.issueSentence.timelineDetail,
                    createdAt: items.last?.createdAt ?? state.createdAt
                )
            )
        }

        if !state.roundtable.openingTurns.isEmpty {
            items.append(
                MeetingTimelineItem(
                    id: "\(state.id):roundtable-opened",
                    kind: .roundtableOpened,
                    stage: .roundtable,
                    title: "五声开场",
                    detail: "\(state.roundtable.openingTurns.count) 个声音已入座",
                    createdAt: state.roundtable.openingTurns.map(\.createdAt).max() ?? items.last?.createdAt ?? state.createdAt
                )
            )
        }

        for move in state.roundtable.moves {
            items.append(
                MeetingTimelineItem(
                    id: "\(state.id):roundtable-move:\(move.id)",
                    kind: .roundtableMove,
                    stage: .roundtable,
                    title: move.timelineTitle,
                    detail: move.timelineDetail,
                    createdAt: move.createdAt
                )
            )
        }

        for answer in state.inquiryAnswers {
            items.append(
                MeetingTimelineItem(
                    id: "\(state.id):inquiry-answer:\(answer.id)",
                    kind: .inquiryAnswer,
                    stage: .inquiry,
                    title: "问询回答",
                    detail: answer.timelineDetail,
                    createdAt: answer.answeredAt
                )
            )
        }

        if let settlement = state.heartSettlement {
            items.append(
                MeetingTimelineItem(
                    id: "\(state.id):settlement",
                    kind: .settlement,
                    stage: .settlement,
                    title: "本心落定生成",
                    detail: settlement.headline.timelineDetail,
                    createdAt: state.settledAt ?? items.last?.createdAt ?? state.createdAt
                )
            )
        }

        if state.stage == .archived {
            items.append(
                MeetingTimelineItem(
                    id: "\(state.id):archived",
                    kind: .archived,
                    stage: .archived,
                    title: "纸页归档",
                    detail: "已保存为本地纸页",
                    createdAt: state.archivedAt ?? items.last?.createdAt ?? state.createdAt
                )
            )
        }

        return items
    }
}

private extension ScribeAnswer {
    var timelineDetail: String {
        freeText.timelineFallback ?? selectedOptionLabel.timelineFallback ?? "已回答"
    }
}

private extension ScribeInquiryAnswer {
    var timelineDetail: String {
        customText.timelineFallback ?? selectedLabel.timelineDetail
    }
}

private extension RoundtableMove {
    var timelineTitle: String {
        switch type {
        case .continueAll:
            return "圆桌继续一轮"
        case .duel:
            return "两声对话"
        case .userToVoice:
            return "追问一声"
        case .userToTable:
            return "追问全桌"
        }
    }

    var timelineDetail: String {
        switch type {
        case .continueAll:
            return "五声继续补充立场"
        case .duel:
            let from = fromVoiceID?.displayName ?? "一声"
            let to = toVoiceID?.displayName ?? "另一声"
            return "\(from) 向 \(to) 发问"
        case .userToVoice:
            let target = targetVoiceID?.displayName ?? "一声"
            return "\(target)：\(userText.timelineFallback ?? "继续追问")"
        case .userToTable:
            return userText.timelineFallback ?? "继续追问"
        }
    }
}

private extension Optional where Wrapped == String {
    var timelineFallback: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value.timelineDetail
    }
}

private extension String {
    var timelineDetail: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 64 else { return trimmed }
        return "\(trimmed.prefix(61))..."
    }
}

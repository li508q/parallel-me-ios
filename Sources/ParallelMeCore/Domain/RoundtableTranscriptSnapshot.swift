import Foundation

public enum RoundtableTranscriptSectionKind: String, Codable, Sendable {
    case opening
    case move
    case ungrouped
}

public struct RoundtableTranscriptSection: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: RoundtableTranscriptSectionKind
    public var title: String
    public var detail: String
    public var createdAt: Date?
    public var move: RoundtableMove?
    public var openingTurns: [VoiceOpeningTurn]
    public var turns: [RoundtableTurn]

    public init(
        id: String,
        kind: RoundtableTranscriptSectionKind,
        title: String,
        detail: String,
        createdAt: Date? = nil,
        move: RoundtableMove? = nil,
        openingTurns: [VoiceOpeningTurn] = [],
        turns: [RoundtableTurn] = []
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.createdAt = createdAt
        self.move = move
        self.openingTurns = openingTurns
        self.turns = turns
    }
}

public struct RoundtableTranscriptSnapshot: Codable, Equatable, Sendable {
    public var sections: [RoundtableTranscriptSection]

    public init(sections: [RoundtableTranscriptSection]) {
        self.sections = sections
    }

    public init(record: RoundtableRecord) {
        var sections: [RoundtableTranscriptSection] = []

        if !record.openingTurns.isEmpty {
            sections.append(
                RoundtableTranscriptSection(
                    id: "roundtable:opening",
                    kind: .opening,
                    title: "五声开场",
                    detail: "\(record.openingTurns.count) 个声音已入座",
                    createdAt: record.openingTurns.map(\.createdAt).min(),
                    openingTurns: record.openingTurns
                )
            )
        }

        let turnsByMoveID = Dictionary(grouping: record.turns.compactMap { turn -> (String, RoundtableTurn)? in
            guard let moveID = turn.moveID else { return nil }
            return (moveID, turn)
        }, by: \.0)
            .mapValues { pairs in pairs.map(\.1) }
        let knownMoveIDs = Set(record.moves.map(\.id))

        for move in record.moves {
            let turns = turnsByMoveID[move.id] ?? []
            sections.append(
                RoundtableTranscriptSection(
                    id: "roundtable:move:\(move.id)",
                    kind: .move,
                    title: move.transcriptTitle,
                    detail: move.transcriptDetail,
                    createdAt: move.createdAt,
                    move: move,
                    turns: turns
                )
            )
        }

        let ungroupedTurns = record.turns.filter { turn in
            guard let moveID = turn.moveID else { return true }
            return !knownMoveIDs.contains(moveID)
        }
        if !ungroupedTurns.isEmpty {
            sections.append(
                RoundtableTranscriptSection(
                    id: "roundtable:ungrouped",
                    kind: .ungrouped,
                    title: "圆桌补充",
                    detail: "\(ungroupedTurns.count) 个未绑定动作的发言",
                    createdAt: ungroupedTurns.map(\.createdAt).min(),
                    turns: ungroupedTurns
                )
            )
        }

        self.sections = sections
    }

    public var isEmpty: Bool {
        sections.isEmpty
    }
}

private extension RoundtableMove {
    var transcriptTitle: String {
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

    var transcriptDetail: String {
        switch type {
        case .continueAll:
            return "五声继续补充立场"
        case .duel:
            let from = fromVoiceID?.displayName ?? "一声"
            let to = toVoiceID?.displayName ?? "另一声"
            return "\(from) 向 \(to) 发问"
        case .userToVoice:
            let target = targetVoiceID?.displayName ?? "一声"
            return "\(target)：\(userText.transcriptFallback ?? "继续追问")"
        case .userToTable:
            return userText.transcriptFallback ?? "继续追问"
        }
    }
}

private extension Optional where Wrapped == String {
    var transcriptFallback: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

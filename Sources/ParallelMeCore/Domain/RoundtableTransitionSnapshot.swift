import Foundation

public struct RoundtableTransitionSnapshot: Codable, Equatable, Sendable {
    public var openingCount: Int
    public var expectedOpeningCount: Int
    public var missingOpeningIDs: [VoiceID]
    public var moveCount: Int
    public var answeredMoveCount: Int

    public init(record: RoundtableRecord) {
        self.openingCount = record.openingTurns.count
        self.expectedOpeningCount = VoiceID.allCases.count
        let receivedOpeningIDs = Set(record.openingTurns.map(\.voiceID))
        self.missingOpeningIDs = VoiceID.allCases.filter { !receivedOpeningIDs.contains($0) }
        self.moveCount = record.moves.count

        let moveIDsWithTurns = Set(record.turns.compactMap(\.moveID))
        self.answeredMoveCount = record.moves.filter { moveIDsWithTurns.contains($0.id) }.count
    }

    public var hasCompleteOpenings: Bool {
        missingOpeningIDs.isEmpty
    }

    public var hasSubstantiveExchange: Bool {
        answeredMoveCount > 0
    }

    public var canStartInquiry: Bool {
        hasCompleteOpenings && hasSubstantiveExchange
    }

    public var statusTitle: String {
        if !hasCompleteOpenings {
            return "五声正在入座"
        }
        if !hasSubstantiveExchange {
            return "先让圆桌真正说一轮"
        }
        return "可以进入书记员问询"
    }

    public var statusDetail: String {
        if !hasCompleteOpenings {
            let missing = missingOpeningIDs.map(\.displayName).joined(separator: "、")
            return "需要固定五声完整开场后，才能继续推进。还缺：\(missing)。"
        }
        if !hasSubstantiveExchange {
            return "问询没有最高轮次上限，但进入前至少需要一轮具体圆桌交换，避免突然变成固定题目。"
        }
        return "你可以继续追问，也可以让书记员只围绕已有证据补齐落定所需的问题。"
    }

    public var inquiryActionTitle: String {
        canStartInquiry ? "进入问询" : "材料还不够"
    }
}

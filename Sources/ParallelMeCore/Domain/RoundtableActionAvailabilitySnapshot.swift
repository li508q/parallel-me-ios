public enum RoundtableActionBlocker: String, Codable, Equatable, Sendable, CaseIterable {
    case busy
    case notRoundtable
    case missingProposal
    case incompleteProposal
    case missingTaskFrame
    case incompleteOpenings
}

public enum RoundtableActionMessageTone: String, Codable, Sendable {
    case muted
    case warning
}

public struct RoundtableActionAvailabilitySnapshot: Codable, Equatable, Sendable {
    public var blockers: [RoundtableActionBlocker]
    public var missingOpeningIDs: [VoiceID]
    public var missingProposalPurposes: [ProbePurpose]
    public var transition: RoundtableTransitionSnapshot

    public init(state: MeetingFlowState, isBusy: Bool = false) {
        self.transition = RoundtableTransitionSnapshot(record: state.roundtable)
        self.missingOpeningIDs = transition.missingOpeningIDs

        var blockers: [RoundtableActionBlocker] = []
        var missingProposalPurposes: [ProbePurpose] = []

        if isBusy {
            blockers.append(.busy)
        }
        if state.stage != .roundtable {
            blockers.append(.notRoundtable)
        }
        if let proposal = state.issueProposal {
            if !proposal.isComplete {
                blockers.append(.incompleteProposal)
                missingProposalPurposes = proposal.missingPurposes
            }
        } else {
            blockers.append(.missingProposal)
            missingProposalPurposes = ProbePurpose.allCases
        }
        if state.taskFrame == nil {
            blockers.append(.missingTaskFrame)
        }
        if !transition.hasCompleteOpenings {
            blockers.append(.incompleteOpenings)
        }

        self.blockers = blockers
        self.missingProposalPurposes = missingProposalPurposes
    }

    public var canSubmitRoundtableMove: Bool {
        blockers.isEmpty
    }

    public var canContinueRoundtable: Bool {
        canSubmitRoundtableMove
    }

    public var canAskTable: Bool {
        canSubmitRoundtableMove
    }

    public var canAskVoice: Bool {
        canSubmitRoundtableMove
    }

    public var canStartDuel: Bool {
        canSubmitRoundtableMove
    }

    public var canStartInquiry: Bool {
        canSubmitRoundtableMove && transition.canStartInquiry
    }

    public var statusTitle: String {
        if blockers.contains(.busy) {
            return "圆桌正在整理"
        }
        if !canSubmitRoundtableMove {
            return "圆桌状态需要修复"
        }
        return transition.statusTitle
    }

    public var statusDetail: String {
        if blockers.contains(.busy) {
            return "这一步完成前先别重复提交，纸页会自动保存。"
        }
        if blockers.contains(.notRoundtable) {
            return "当前纸页不在圆桌阶段，不能提交圆桌动作。"
        }
        if blockers.contains(.missingProposal) {
            return "当前纸页缺少已确认的议题提案，不能安全生成圆桌回应。"
        }
        if blockers.contains(.incompleteProposal) {
            let missing = missingProposalPurposes.map(\.label).joined(separator: "、")
            return "议题提案还缺 \(missing)，不能安全生成圆桌回应。"
        }
        if blockers.contains(.missingTaskFrame) {
            return "当前纸页缺少圆桌任务框架，请回到定义阶段重新整理议题。"
        }
        if blockers.contains(.incompleteOpenings) {
            let missing = missingOpeningIDs.map(\.displayName).joined(separator: "、")
            return "固定五声还没有完整开场，暂时不能继续圆桌动作。还缺：\(missing)。"
        }
        return transition.statusDetail
    }

    public var inquiryActionTitle: String {
        if canStartInquiry {
            return "进入问询"
        }
        if !canSubmitRoundtableMove {
            return "圆桌需修复"
        }
        return transition.inquiryActionTitle
    }

    public var messageTone: RoundtableActionMessageTone {
        canSubmitRoundtableMove || blockers.contains(.busy) ? .muted : .warning
    }
}

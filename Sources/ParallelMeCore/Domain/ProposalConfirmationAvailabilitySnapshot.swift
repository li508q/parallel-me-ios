public enum ProposalConfirmationBlocker: String, Codable, Equatable, Sendable, CaseIterable {
    case busy
    case missingProposal
    case incompleteProposal
    case missingTaskFrame
}

public enum ProposalConfirmationMessageTone: String, Codable, Sendable {
    case muted
    case warning
}

public struct ProposalConfirmationAvailabilitySnapshot: Codable, Equatable, Sendable {
    public var blockers: [ProposalConfirmationBlocker]
    public var missingPurposes: [ProbePurpose]

    public init(state: MeetingFlowState, isBusy: Bool = false) {
        var blockers: [ProposalConfirmationBlocker] = []
        var missingPurposes: [ProbePurpose] = []

        if isBusy {
            blockers.append(.busy)
        }

        if let proposal = state.issueProposal {
            if !proposal.isComplete {
                blockers.append(.incompleteProposal)
                missingPurposes = proposal.missingPurposes
            }
        } else {
            blockers.append(.missingProposal)
            missingPurposes = ProbePurpose.allCases
        }

        if state.taskFrame == nil {
            blockers.append(.missingTaskFrame)
        }

        self.blockers = blockers
        self.missingPurposes = missingPurposes
    }

    public var canConfirm: Bool {
        blockers.isEmpty
    }

    public var actionTitle: String {
        if blockers.contains(.busy) {
            return "书记员整理中"
        }
        if canConfirm {
            return "确认议题，进入圆桌"
        }
        if blockers.contains(.missingProposal) || blockers.contains(.incompleteProposal) {
            return "还不能进入圆桌"
        }
        return "需要重新整理议题"
    }

    public var message: String {
        if blockers.contains(.busy) {
            return "书记员正在处理这一步，先不要重复提交。"
        }
        if blockers.contains(.missingProposal) {
            return "还没有可确认的议题提案。"
        }
        if blockers.contains(.incompleteProposal) {
            let labels = missingPurposes.map(\.label).joined(separator: "、")
            return "这版议题还缺 \(labels)，先让书记员补齐。"
        }
        if blockers.contains(.missingTaskFrame) {
            return "这版议题缺少圆桌任务框架，请让书记员重新整理后再确认。"
        }
        return "确认后，五声会基于这版议题开场。"
    }

    public var messageTone: ProposalConfirmationMessageTone {
        canConfirm || blockers.contains(.busy) ? .muted : .warning
    }
}

public enum SettlementRequestBlocker: String, Codable, Equatable, Sendable, CaseIterable {
    case busy
    case notInquiry
    case activeQuestionsUnanswered
    case missingProposal
    case incompleteProposal
    case missingTaskFrame
    case missingAlignmentProfile
    case settlementEvidenceMissing
}

public enum SettlementRequestMessageTone: String, Codable, Sendable {
    case muted
    case warning
}

public struct SettlementRequestAvailabilitySnapshot: Codable, Equatable, Sendable {
    public var blockers: [SettlementRequestBlocker]
    public var activeQuestionCount: Int
    public var missingProposalPurposes: [ProbePurpose]
    public var missingSettlementModules: [SettlementModuleID]

    public init(
        state: MeetingFlowState,
        isBusy: Bool = false,
        readinessEvaluator: SettlementReadinessEvaluator = SettlementReadinessEvaluator()
    ) {
        let answeredIDs = Set(state.inquiryAnswers.map(\.questionID))
        self.activeQuestionCount = state.inquiryQuestions.filter { !answeredIDs.contains($0.id) }.count

        var blockers: [SettlementRequestBlocker] = []
        var missingProposalPurposes: [ProbePurpose] = []
        var missingSettlementModules: [SettlementModuleID] = []

        if isBusy {
            blockers.append(.busy)
        }
        if state.stage != .inquiry {
            blockers.append(.notInquiry)
        }
        if activeQuestionCount > 0 {
            blockers.append(.activeQuestionsUnanswered)
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

        if let profile = state.alignmentProfile {
            let readiness = readinessEvaluator.evaluate(
                profile: profile,
                ledger: state.scribeObservationLedger,
                answers: state.inquiryAnswers
            )
            if !readiness.isReady {
                blockers.append(.settlementEvidenceMissing)
                missingSettlementModules = readiness.missingModules
            }
        } else {
            blockers.append(.missingAlignmentProfile)
        }

        self.blockers = blockers
        self.missingProposalPurposes = missingProposalPurposes
        self.missingSettlementModules = missingSettlementModules
    }

    public var canRequestSettlement: Bool {
        blockers.isEmpty
    }

    public var canContinueInquiry: Bool {
        !blockers.contains(.busy) &&
        !blockers.contains(.notInquiry) &&
        !blockers.contains(.activeQuestionsUnanswered) &&
        !blockers.contains(.missingProposal) &&
        !blockers.contains(.incompleteProposal) &&
        !blockers.contains(.missingTaskFrame) &&
        !canRequestSettlement
    }

    public var title: String {
        if canRequestSettlement {
            return "证据已经足够"
        }
        if blockers.contains(.busy) {
            return "书记员正在整理"
        }
        if blockers.contains(.activeQuestionsUnanswered) {
            return "先回答本轮问询"
        }
        if blockers.contains(.settlementEvidenceMissing) || blockers.contains(.missingAlignmentProfile) {
            return "证据还不够落定"
        }
        return "问询状态需要修复"
    }

    public var detail: String {
        if canRequestSettlement {
            return "可以生成本心落定；归档前你仍然可以修订最终文字。"
        }
        if blockers.contains(.busy) {
            return "这一步完成前先不要重复提交，纸页会自动保存。"
        }
        if blockers.contains(.notInquiry) {
            return "当前纸页不在问询阶段，不能生成本心落定。"
        }
        if blockers.contains(.activeQuestionsUnanswered) {
            return "还有 \(activeQuestionCount) 个书记员问题没有回答。"
        }
        if blockers.contains(.missingProposal) {
            return "当前纸页缺少已确认的议题提案，不能安全生成本心落定。"
        }
        if blockers.contains(.incompleteProposal) {
            let missing = missingProposalPurposes.map(\.label).joined(separator: "、")
            return "议题提案还缺 \(missing)，不能安全生成本心落定。"
        }
        if blockers.contains(.missingTaskFrame) {
            return "当前纸页缺少圆桌任务框架，请回到定义阶段重新整理议题。"
        }
        if blockers.contains(.missingAlignmentProfile) {
            return "书记员还没有形成足够的落定画像，可以继续问询。"
        }
        if blockers.contains(.settlementEvidenceMissing) {
            let missing = missingSettlementModules.map(\.label).joined(separator: "、")
            return "本心落定还缺 \(missing) 的证据，可以继续问询。"
        }
        return "这一步暂时不可用。"
    }

    public var requestActionTitle: String {
        canRequestSettlement ? "生成本心落定" : "还不能落定"
    }

    public var continueInquiryActionTitle: String {
        "继续书记员问询"
    }

    public var messageTone: SettlementRequestMessageTone {
        canRequestSettlement || blockers.contains(.busy) ? .muted : .warning
    }
}

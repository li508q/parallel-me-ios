import Foundation

public enum MeetingStateHealthTone: String, Codable, Sendable {
    case ok
    case warning
    case blocked
}

public struct MeetingStateHealthFinding: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var detail: String
    public var tone: MeetingStateHealthTone
    public var systemImage: String

    public init(
        id: String,
        title: String,
        detail: String,
        tone: MeetingStateHealthTone,
        systemImage: String
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.tone = tone
        self.systemImage = systemImage
    }
}

public struct MeetingStateHealthSnapshot: Codable, Equatable, Sendable {
    public var stage: MeetingStage
    public var tone: MeetingStateHealthTone
    public var title: String
    public var detail: String
    public var findings: [MeetingStateHealthFinding]

    public init(state: MeetingFlowState) {
        self.stage = state.stage

        var findings: [MeetingStateHealthFinding] = []
        if state.rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            findings.append(
                .blocked(
                    id: "petition.empty",
                    title: "原始困惑为空",
                    detail: "这张纸页缺少最初提交的困惑，后续摘要和导出会失去起点。",
                    systemImage: "doc.text.magnifyingglass"
                )
            )
        }

        switch state.stage {
        case .defining:
            if let proposal = state.issueProposal, !proposal.isComplete {
                let missing = proposal.missingPurposes.map(\.label).joined(separator: "、")
                findings.append(
                    .blocked(
                        id: "defining.incompleteProposal",
                        title: "议题提案不完整",
                        detail: "还缺 \(missing)，不能进入五声圆桌。",
                        systemImage: "list.bullet.clipboard"
                    )
                )
            }
        case .roundtable:
            Self.appendIssueReadinessFindings(for: state, to: &findings)
            let transition = RoundtableTransitionSnapshot(record: state.roundtable)
            if !transition.hasCompleteOpenings {
                let missing = transition.missingOpeningIDs.map(\.displayName).joined(separator: "、")
                findings.append(
                    .warning(
                        id: "roundtable.openings",
                        title: "五声开场未完整",
                        detail: "还缺 \(missing)，暂时不能进入书记员问询。",
                        systemImage: "person.3.sequence"
                    )
                )
            } else if !transition.hasSubstantiveExchange {
                findings.append(
                    .warning(
                        id: "roundtable.exchange",
                        title: "还没有真实交换",
                        detail: "至少完成一轮具体圆桌回应后，问询才会开放。",
                        systemImage: "arrow.left.and.right"
                    )
                )
            }
        case .inquiry:
            Self.appendIssueReadinessFindings(for: state, to: &findings)
            let answered = Set(state.inquiryAnswers.map(\.questionID))
            let activeQuestionCount = state.inquiryQuestions.filter { !answered.contains($0.id) }.count
            if activeQuestionCount > 0 {
                findings.append(
                    .warning(
                        id: "inquiry.answers",
                        title: "本轮问询未完成",
                        detail: "还有 \(activeQuestionCount) 个书记员问题需要回答。",
                        systemImage: "questionmark.bubble"
                    )
                )
            } else if state.alignmentProfile == nil {
                findings.append(
                    .warning(
                        id: "inquiry.awaitingQuestions",
                        title: "等待下一轮问询",
                        detail: "当前没有未答问题，也没有足够证据生成本心落定。",
                        systemImage: "arrow.clockwise"
                    )
                )
            }
        case .settlement:
            Self.appendSettlementFindings(for: state, stageIDPrefix: "settlement", to: &findings)
        case .archived:
            Self.appendSettlementFindings(for: state, stageIDPrefix: "archived", to: &findings)
            if state.archivedAt == nil {
                findings.append(
                    .warning(
                        id: "archived.timestamp",
                        title: "归档时间缺失",
                        detail: "这张纸页是归档状态，但没有归档时间；排序和时间线可能只能回退到创建时间。",
                        systemImage: "clock.badge.questionmark"
                    )
                )
            }
        }

        self.findings = findings
        self.tone = findings.contains { $0.tone == .blocked } ? .blocked : (findings.isEmpty ? .ok : .warning)
        switch tone {
        case .ok:
            self.title = "纸页状态完整"
            self.detail = "当前阶段的数据结构和操作门禁一致。"
        case .warning:
            self.title = "纸页状态有提示"
            self.detail = "\(findings.count) 个地方需要留意，但纸页仍可继续阅读或推进。"
        case .blocked:
            self.title = "纸页状态需要处理"
            self.detail = "\(Self.blockedCount(in: findings)) 个关键数据缺口会阻止当前阶段的主要动作。"
        }
    }

    public var isHealthy: Bool {
        tone == .ok
    }

    public var blockedCount: Int {
        Self.blockedCount(in: findings)
    }

    public var warningCount: Int {
        findings.filter { $0.tone == .warning }.count
    }

    private static func appendIssueReadinessFindings(
        for state: MeetingFlowState,
        to findings: inout [MeetingStateHealthFinding]
    ) {
        if state.taskFrame == nil {
            findings.append(
                .blocked(
                    id: "\(state.stage.rawValue).taskFrame",
                    title: "任务框架缺失",
                    detail: "当前阶段需要已确认的圆桌任务框架，模型请求无法安全继续。",
                    systemImage: "rectangle.and.text.magnifyingglass"
                )
            )
        }

        guard let proposal = state.issueProposal else {
            findings.append(
                .blocked(
                    id: "\(state.stage.rawValue).proposal",
                    title: "议题提案缺失",
                    detail: "当前阶段需要完整议题提案，才能稳定生成后续模型上下文。",
                    systemImage: "list.bullet.clipboard"
                )
            )
            return
        }

        if !proposal.isComplete {
            let missing = proposal.missingPurposes.map(\.label).joined(separator: "、")
            findings.append(
                .blocked(
                    id: "\(state.stage.rawValue).proposal",
                    title: "议题提案不完整",
                    detail: "还缺 \(missing)，后续模型上下文不完整。",
                    systemImage: "list.bullet.clipboard"
                )
            )
        }
    }

    private static func appendSettlementFindings(
        for state: MeetingFlowState,
        stageIDPrefix: String,
        to findings: inout [MeetingStateHealthFinding]
    ) {
        guard let settlement = state.heartSettlement else {
            findings.append(
                .blocked(
                    id: "\(stageIDPrefix).settlement",
                    title: "本心落定缺失",
                    detail: state.stage == .archived
                        ? "归档纸页缺少完整本心落定，因此不能导出为成品纸页。"
                        : "落定阶段需要五模块内容，才能修订或保存纸页。",
                    systemImage: "exclamationmark.triangle.fill"
                )
            )
            return
        }

        let missing = settlement.missingModules
        if !missing.isEmpty {
            findings.append(
                .blocked(
                    id: "\(stageIDPrefix).settlement",
                    title: "本心落定不完整",
                    detail: "还缺 \(missing.map(\.label).joined(separator: "、"))，不能保存或导出为成品纸页。",
                    systemImage: "exclamationmark.triangle.fill"
                )
            )
        }
    }

    private static func blockedCount(in findings: [MeetingStateHealthFinding]) -> Int {
        findings.filter { $0.tone == .blocked }.count
    }
}

private extension MeetingStateHealthFinding {
    static func warning(
        id: String,
        title: String,
        detail: String,
        systemImage: String
    ) -> MeetingStateHealthFinding {
        MeetingStateHealthFinding(
            id: id,
            title: title,
            detail: detail,
            tone: .warning,
            systemImage: systemImage
        )
    }

    static func blocked(
        id: String,
        title: String,
        detail: String,
        systemImage: String
    ) -> MeetingStateHealthFinding {
        MeetingStateHealthFinding(
            id: id,
            title: title,
            detail: detail,
            tone: .blocked,
            systemImage: systemImage
        )
    }
}

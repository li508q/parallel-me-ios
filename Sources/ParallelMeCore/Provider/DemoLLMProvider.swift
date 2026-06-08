import Foundation

public actor DemoLLMProvider: LLMProvider {
    public init() {}

    public func generate<RequestPayload, ResponsePayload>(
        request: LLMRequest<RequestPayload>,
        responseType: ResponsePayload.Type
    ) async throws -> LLMEnvelope<ResponsePayload>
    where RequestPayload: Codable & Sendable, ResponsePayload: Codable & Sendable {
        let payload: Any
        switch request.kind {
        case .defineIssue:
            let input = request.payload as? IssueDefinitionInput
            payload = IssueDefinitionResponse(
                proposal: Self.proposal(rawInput: input?.rawInput ?? "这件事还没有被说清楚"),
                readyToPropose: true,
                thinking: "演示模式：直接生成四 Key 议题提案。"
            )
        case .openRoundtable:
            payload = RoundtableOpeningResponse(openings: VoiceID.allCases.map(Self.opening))
        case .continueRoundtable:
            let move = (request.payload as? RoundtableMoveInput)?.move
            payload = RoundtableMoveResponse(
                turns: VoiceID.allCases.map { id in
                    RoundtableTurn(
                        moveID: move?.id,
                        voiceID: id,
                        text: "\(id.displayName)：我会把这件事里我守护的那部分先放到桌面上，但不替你做决定。"
                    )
                },
                ledger: ScribeObservationLedger(moduleSignals: [
                    .creativeHopelessness: ["用户开始看见无代价方案不存在。"],
                    .coreValues: ["自由与安全感同时出现。"]
                ])
            )
        case .observeRoundtable:
            payload = ScribeObservationLedger(moduleSignals: [
                .coreValues: ["演示观察：用户反复回到自由与退路。"]
            ])
        case .alignmentInquiry:
            let input = request.payload as? AlignmentInquiryInput
            if input?.answers.isEmpty == true {
                payload = AlignmentInquiryResponse(
                    questions: [
                        ScribeInquiryQuestion(
                            id: "demo_minimum_action",
                            question: "如果只做一个 24 小时内能完成的小动作，哪一个最能让你恢复判断力？",
                            options: [
                                ScribeInquiryOption(id: "budget", label: "今晚写出三个月现金流和观察期。"),
                                ScribeInquiryOption(id: "talk", label: "把真实担心告诉一个会支持我的人。"),
                                ScribeInquiryOption(id: "sleep", label: "先睡够一晚，明早再确认选择。"),
                                ScribeInquiryOption(id: "custom", label: "都不准，我自己说")
                            ],
                            module: .minimumAction
                        )
                    ],
                    readyForSettlement: false,
                    profile: nil,
                    ledger: ScribeObservationLedger(moduleSignals: [
                        .creativeHopelessness: ["没有无代价答案。"],
                        .coreValues: ["自由需要和现实退路一起被守住。"],
                        .costAcceptance: ["短期不确定性需要被承认。"]
                    ])
                )
            } else {
                payload = AlignmentInquiryResponse(
                    readyForSettlement: true,
                    profile: Self.profile,
                    ledger: ScribeObservationLedger(moduleSignals: [
                        .creativeHopelessness: ["没有无代价答案。"],
                        .coreValues: ["自由需要和现实退路一起被守住。"],
                        .costAcceptance: ["短期不确定性需要被承认。"],
                        .minimumAction: ["用户已选出 24 小时行动。"]
                    ])
                )
            }
        case .heartSettlement:
            payload = HeartSettlementResponse(settlement: Self.settlement)
        }

        guard let typedPayload = payload as? ResponsePayload else {
            throw MockLLMProviderError.missingResponse(kind: request.kind)
        }
        return LLMEnvelope(payload: typedPayload, trace: ["demo:\(request.kind.rawValue)"])
    }

    private static func proposal(rawInput: String) -> IssueProposal {
        IssueProposal(
            issueSentence: rawInput,
            surfaceDilemma: IssueProposalKey(
                title: "选择岔路",
                content: "一边是继续维持现状，一边是承认自己想换一种活法。",
                details: ["继续沿着旧轨道走", "设置一个观察期，测试新方向"]
            ),
            currentConstraints: IssueProposalKey(
                title: "现实边界",
                content: "选择会牵动现金流、关系期待和身体余量。",
                details: ["现金流不能断", "关系会被牵动", "身体已经在提醒"]
            ),
            coreFears: IssueProposalKey(
                title: "隐秘关切",
                content: "真正怕的是既失去安全感，也失去对自己的尊重。",
                details: ["安全感", "自我尊重", "不想被此刻吞掉"]
            ),
            expectedResolution: IssueProposalKey(
                title: "圆桌任务",
                content: "确认哪一种代价必须接受，哪一种底线不能碰。",
                details: ["排出代价优先级", "给出一个 24 小时行动"]
            )
        )
    }

    private static func opening(_ id: VoiceID) -> VoiceOpeningTurn {
        let persona = VoicePersonas.byID[id]
        return VoiceOpeningTurn(
            voiceID: id,
            payload: VoiceOpeningPayload(
                thesis: "我看见这件事卡住你，不是因为你不够努力，而是几个底线在互相拉扯。",
                protectedValue: persona?.coreValue ?? id.displayName,
                concern: persona?.cost ?? "这条路有代价。",
                taskEvidence: "来自刚刚确认的四 Key 议题。",
                pull: persona?.chairPrompt ?? "先把真实问题说清楚。"
            )
        )
    }

    private static var profile: AlignmentProfile {
        AlignmentProfile(
            falsifiedFantasy: "你无法同时拥有零风险、零痛苦和彻底自由。",
            coreValueAxis: "用可持续的方式守住自由。",
            offendedVoices: [.money, .lay],
            acceptedCosts: ["短期不确定性", "需要向重要的人解释"],
            refusedCosts: ["继续把身体耗空"],
            unresolvedTensions: ["自由和现金流仍需要一起被照看"],
            hegelianSynthesis: HegelianSynthesis(
                thesis: "我想要自由。",
                antithesis: "我也需要退路。",
                synthesis: "我先用一个观察期恢复判断力，而不是立刻赌上全部。"
            ),
            userSelfStatements: ["我可以接受慢一点，但不能继续耗空。"]
        )
    }

    private static var settlement: HeartSettlement {
        HeartSettlement(
            creativeHopelessness: SettlementModule(
                title: "创造性无望",
                report: "这件事没有无代价版本。你要放弃的幻想，是既不冒险、也不疼、还立刻自由。"
            ),
            coreValueAxis: SettlementModule(
                title: "核心价值主轴",
                report: "你真正想守住的是可持续的自由，不是一次冲动的逃离。"
            ),
            costAcceptanceContract: SettlementModule(
                title: "痛苦接纳契约",
                report: "如果选择这个方向，你需要承认短期不确定性，并认真照看现金流和关系解释。"
            ),
            minimumViableCommitment: SettlementModule(
                title: "最小行动承诺",
                report: "24 小时内写出三个月现金流、观察期长度和一个不可触碰的身体底线。"
            ),
            dialecticSynthesis: DialecticSynthesis(
                thesis: "我想离开旧轨道。",
                antithesis: "我需要现实退路。",
                synthesis: "我先设观察期，用具体账本和身体底线换回判断力。"
            )
        )
    }
}


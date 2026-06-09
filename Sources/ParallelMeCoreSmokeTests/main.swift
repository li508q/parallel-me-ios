import Foundation
import ParallelMeCore
import ParallelMeUI

@main
struct ParallelMeCoreSmokeTests {
    static func main() async throws {
        var runner = Runner()
        try runner.run("fixed five voices") {
            try expect(VoicePersonas.all.map(\.id) == VoiceID.allCases)
            try expect(VoicePersonas.all.map(\.name) == [
                "躺平的我",
                "搞钱的我",
                "出走的我",
                "被牵挂的我",
                "5 年后的我"
            ])
            try expect(Set(VoicePersonas.all.map(\.coreValue)).count == VoicePersonas.all.count)
        }

        try runner.run("starter prompts provide distinct petition seeds") {
            let prompts = PetitionStarterPrompts.all

            try expect(prompts.count >= 4)
            try expect(Set(prompts.map(\.id)).count == prompts.count)
            try expect(Set(prompts.map(\.seedText)).count == prompts.count)
            try expect(Set(prompts.map(\.accentVoiceID)).isSubset(of: Set(VoiceID.allCases)))
            try expect(prompts.allSatisfy { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            try expect(prompts.allSatisfy { $0.seedText.count >= 18 })
        }

        try runner.run("meeting flow requires complete proposal") {
            let engine = MeetingFlowEngine()
            do {
                _ = try engine.start(rawInput: "  ")
                throw TestFailure("Expected empty petition error")
            } catch MeetingFlowError.emptyPetition {
                // expected
            }

            let started = try engine.start(rawInput: "我想辞职又怕没钱")
            do {
                _ = try engine.confirmProposal(in: started)
                throw TestFailure("Expected incomplete proposal error")
            } catch MeetingFlowError.incompleteProposal {
                // expected
            }
        }

        try runner.run("complete proposal reaches roundtable") {
            let engine = MeetingFlowEngine()
            let started = try engine.start(rawInput: "我想辞职又怕没钱")
            let proposed = try engine.receiveIssueProposal(completeProposal, in: started)
            try expect(proposed.definingSubstage == .showingProposal)
            try expect(proposed.taskFrame?.problemDefinition == "要不要离开现在的工作")
            let roundtable = try engine.confirmProposal(in: proposed)
            try expect(roundtable.stage == .roundtable)
        }

        try runner.run("meeting stage progress exposes user-facing steps") {
            let snapshot = MeetingStageProgressSnapshot(stage: .inquiry)

            try expect(snapshot.totalCount == 5)
            try expect(snapshot.currentPosition == 3)
            try expect(snapshot.currentItem.title == "问询")
            try expect(snapshot.currentItem.detail == "补齐落定证据")
            try expect(snapshot.items.map(\.stage) == [.defining, .roundtable, .inquiry, .settlement, .archived])
            try expect(snapshot.items.map(\.title) == ["定义", "圆桌", "问询", "落定", "归档"])
            try expect(snapshot.items.map(\.isCompleted) == [true, true, false, false, false])
            try expect(snapshot.items.filter(\.isCurrent).map(\.stage) == [.inquiry])
        }

        try runner.run("roundtable requires openings before inquiry") {
            let engine = MeetingFlowEngine()
            let started = try engine.start(rawInput: "我想辞职又怕没钱")
            let proposed = try engine.receiveIssueProposal(completeProposal, in: started)
            let roundtable = try engine.confirmProposal(in: proposed)
            do {
                _ = try engine.startInquiry(in: roundtable)
                throw TestFailure("Expected missing openings error")
            } catch MeetingFlowError.missingRoundtableOpenings {
                // expected
            }

            let opened = try engine.receiveOpenings(VoiceID.allCases.map { opening($0) }, in: roundtable)
            do {
                _ = try engine.startInquiry(in: opened)
                throw TestFailure("Expected missing roundtable exchange error")
            } catch MeetingFlowError.missingRoundtableExchange {
                // expected
            }
        }

        try runner.run("openings normalize to fixed order") {
            let engine = MeetingFlowEngine()
            let started = try engine.start(rawInput: "我想辞职又怕没钱")
            let proposed = try engine.receiveIssueProposal(completeProposal, in: started)
            let roundtable = try engine.confirmProposal(in: proposed)
            let openings = [
                opening(.future),
                opening(.lay),
                opening(.money),
                opening(.filial),
                opening(.roam)
            ]
            let next = try engine.receiveOpenings(openings, in: roundtable)
            try expect(next.roundtable.openingTurns.map(\.voiceID) == VoiceID.allCases)
        }

        try runner.run("roundtable transition requires a substantive exchange") {
            let engine = MeetingFlowEngine()
            let started = try engine.start(rawInput: "我想辞职又怕没钱")
            let proposed = try engine.receiveIssueProposal(completeProposal, in: started)
            let roundtable = try engine.confirmProposal(in: proposed)
            let opened = try engine.receiveOpenings(VoiceID.allCases.map { opening($0) }, in: roundtable)
            let waiting = RoundtableTransitionSnapshot(record: opened.roundtable)

            try expect(waiting.hasCompleteOpenings)
            try expect(!waiting.hasSubstantiveExchange)
            try expect(!waiting.canStartInquiry)
            try expect(waiting.inquiryActionTitle == "材料还不够")

            let duplicatedOpenings = RoundtableRecord(
                openingTurns: Array(repeating: opening(.future), count: VoiceID.allCases.count)
            )
            let incomplete = RoundtableTransitionSnapshot(record: duplicatedOpenings)

            try expect(!incomplete.hasCompleteOpenings)
            try expect(incomplete.missingOpeningIDs.contains(.lay))

            let moved = try engine.appendRoundtableMove(
                RoundtableMove(id: "move_transition", type: .continueAll),
                turns: [RoundtableTurn(moveID: "move_transition", voiceID: .future, text: "先把长期后果说清楚。")],
                in: opened
            )
            let ready = RoundtableTransitionSnapshot(record: moved.roundtable)

            try expect(ready.moveCount == 1)
            try expect(ready.answeredMoveCount == 1)
            try expect(ready.canStartInquiry)
            try expect(ready.statusTitle == "可以进入书记员问询")
        }

        try runner.run("scribe drops duplicate purposes") {
            let deduplicator = ScribeQuestionDeduplicator()
            let normalized = deduplicator.normalize([
                question("q1", "你最怕失去什么？", .coreFears),
                question("q2", "这件事真正让你害怕失去的是什么？", .coreFears),
                question("q3", "哪个现实条件会立刻改变你的选择？", .currentConstraints)
            ])
            try expect(normalized.map(\.purpose) == [.coreFears, .currentConstraints])
        }

        try runner.run("scribe drops questions similar to history") {
            let deduplicator = ScribeQuestionDeduplicator()
            let previous = question("q1", "你希望这次圆桌最终帮你验证什么？", .expectedResolution)
            let history = [DefiningDialogueEntry(role: .scribe, question: previous)]
            let normalized = deduplicator.normalize([
                question("q2", "你希望这次圆桌讨论帮自己验证什么？", .expectedResolution),
                question("q3", "表面上最像哪一个选择岔路？", .surfaceDilemma)
            ], history: history)
            try expect(normalized.map(\.id) == ["q3"])
        }

        try runner.run("scribe adds custom option") {
            let deduplicator = ScribeQuestionDeduplicator()
            let normalized = deduplicator.normalize([
                ScribeQuestion(
                    id: "q1",
                    text: "哪个现实条件最硬？",
                    options: [
                        ScribeProbeOption(id: "money", label: "钱最硬"),
                        ScribeProbeOption(id: "time", label: "时间最硬")
                    ],
                    purpose: .currentConstraints
                )
            ])
            try expect(normalized.first?.options.contains { $0.id == "custom" } == true)
        }

        try runner.run("custom answers preserve user text") {
            let probeCustom = ScribeProbeOption(id: "free_text", label: "都不准，我自己说")
            let inquiryCustom = ScribeInquiryOption(id: "other", label: "都不对，我自己说")
            try expect(probeCustom.isCustomAnswer)
            try expect(inquiryCustom.isCustomAnswer)

            let engine = MeetingFlowEngine()
            let started = try engine.start(rawInput: "我想辞职又怕没钱")
            let probe = question("probe_custom", "这件事最不准的地方是什么？", .coreFears)
            let probing = try engine.receiveProbeQuestions([probe], in: started)
            let answeredProbe = try engine.answerProbe([
                ScribeAnswer(
                    questionID: probe.id,
                    selectedOptionID: probeCustom.id,
                    selectedOptionLabel: probeCustom.label,
                    questionText: probe.text,
                    freeText: "我不是怕没钱，我是怕身体撑不住。"
                )
            ], in: probing)
            let proposed = try engine.receiveIssueProposal(completeProposal, in: answeredProbe)
            let roundtable = try engine.confirmProposal(in: proposed)
            let opened = try engine.receiveOpenings(VoiceID.allCases.map { opening($0) }, in: roundtable)
            let moved = try engine.appendRoundtableMove(
                RoundtableMove(type: .continueAll),
                turns: [RoundtableTurn(voiceID: .future, text: "先把 24 小时内能做的事落下来。")],
                in: opened
            )
            let inquiry = try engine.startInquiry(in: moved)
            let answeredInquiry = try engine.answerInquiry([
                ScribeInquiryAnswer(
                    questionID: "inquiry_custom",
                    question: "24 小时内真正能做的行动是什么？",
                    selectedOptionID: inquiryCustom.id,
                    selectedLabel: inquiryCustom.label,
                    customText: "明早先请半天假，去医院做检查。"
                )
            ], in: inquiry)

            try expect(answeredProbe.definingDialogue.last?.answer?.freeText == "我不是怕没钱，我是怕身体撑不住。")
            try expect(answeredInquiry.inquiryAnswers.last?.customText == "明早先请半天假，去医院做检查。")
        }

        try runner.run("probe answer batch requires every current question") {
            let engine = MeetingFlowEngine()
            let started = try engine.start(rawInput: "我想辞职又怕没钱")
            let fear = question("batch_fear", "真正怕失去什么？", .coreFears)
            let constraint = question("batch_constraint", "哪个现实边界最硬？", .currentConstraints)
            let probing = try engine.receiveProbeQuestions([fear, constraint], in: started)

            var draft = ScribeProbeAnswerBatchDraft()
            let fearOption = try unwrap(fear.options.first(where: { $0.id == "a" }), "Expected regular option")
            let customOption = try unwrap(constraint.options.first(where: \.isCustomAnswer), "Expected custom option")
            draft.select(question: fear, option: fearOption)

            try expect(!draft.canSubmit(questions: [fear, constraint]))
            try expect(draft.missingQuestionIDs(in: [fear, constraint]) == [constraint.id])
            do {
                _ = try engine.answerProbe(draft.answers(for: [fear, constraint]), in: probing)
                throw TestFailure("Expected incomplete probe answers error")
            } catch MeetingFlowError.incompleteProbeAnswers(let missingQuestionIDs) {
                try expect(missingQuestionIDs == [constraint.id])
            }

            draft.select(question: constraint, option: customOption, customText: "  现金流最多只能撑三个月。  ")
            let answers = draft.answers(for: [fear, constraint])
            let answered = try engine.answerProbe(answers, in: probing)

            try expect(draft.canSubmit(questions: [fear, constraint]))
            try expect(answers.map(\.questionID) == [fear.id, constraint.id])
            try expect(answers.last?.freeText == "现金流最多只能撑三个月。")
            try expect(answered.definingDialogue.compactMap(\.question).map(\.id) == [fear.id, constraint.id])
            try expect(answered.definingDialogue.compactMap(\.answer).map(\.questionID) == [fear.id, constraint.id])
        }

        try runner.run("inquiry answer batch requires every active question") {
            let engine = MeetingFlowEngine()
            let started = try engine.start(rawInput: "我想辞职又怕没钱")
            let proposed = try engine.receiveIssueProposal(completeProposal, in: started)
            let roundtable = try engine.confirmProposal(in: proposed)
            let opened = try engine.receiveOpenings(VoiceID.allCases.map { opening($0) }, in: roundtable)
            let moved = try engine.appendRoundtableMove(
                RoundtableMove(type: .continueAll),
                turns: [RoundtableTurn(voiceID: .future, text: "先把 24 小时内能做的事落下来。")],
                in: opened
            )
            var inquiry = try engine.startInquiry(in: moved)
            let action = ScribeInquiryQuestion(
                id: "inquiry_action_batch",
                question: "24 小时内能完成的行动是什么？",
                options: [
                    ScribeInquiryOption(id: "budget", label: "今晚写预算。"),
                    ScribeInquiryOption(id: "custom", label: "都不准，我自己说")
                ],
                module: .minimumAction
            )
            let cost = ScribeInquiryQuestion(
                id: "inquiry_cost_batch",
                question: "你愿意承认哪一种代价？",
                options: [
                    ScribeInquiryOption(id: "money", label: "短期收入波动。"),
                    ScribeInquiryOption(id: "custom", label: "都不准，我自己说")
                ],
                module: .costAcceptance
            )
            inquiry = try engine.receiveInquiryQuestions(
                [action, cost],
                profile: nil,
                ledger: ScribeObservationLedger(),
                readyForSettlement: false,
                in: inquiry
            )

            var draft = ScribeInquiryAnswerBatchDraft()
            let actionOption = try unwrap(action.options.first(where: { $0.id == "budget" }), "Expected action option")
            let customOption = try unwrap(cost.options.first(where: \.isCustomAnswer), "Expected custom option")
            draft.select(question: action, option: actionOption)

            try expect(!draft.canSubmit(questions: [action, cost]))
            try expect(draft.missingQuestionIDs(in: [action, cost]) == [cost.id])
            do {
                _ = try engine.answerInquiry(draft.answers(for: [action, cost]), in: inquiry)
                throw TestFailure("Expected incomplete inquiry answers error")
            } catch MeetingFlowError.incompleteInquiryAnswers(let missingQuestionIDs) {
                try expect(missingQuestionIDs == [cost.id])
            }

            draft.select(question: cost, option: customOption, customText: "  我可以接受三个月收入下降。  ")
            let answers = draft.answers(for: [action, cost])
            let answered = try engine.answerInquiry(answers, in: inquiry)

            try expect(draft.canSubmit(questions: [action, cost]))
            try expect(answers.map(\.questionID) == [action.id, cost.id])
            try expect(answers.last?.customText == "我可以接受三个月收入下降。")
            try expect(answered.inquiryAnswers.map(\.questionID) == [action.id, cost.id])
        }

        try runner.run("many answers do not force settlement") {
            let evaluator = SettlementReadinessEvaluator()
            let answers = (0..<24).map { index in
                ScribeInquiryAnswer(
                    questionID: "q\(index)",
                    question: "第 \(index) 个问题",
                    selectedOptionID: "a",
                    selectedLabel: "回答"
                )
            }
            let readiness = evaluator.evaluate(
                profile: AlignmentProfile(),
                ledger: ScribeObservationLedger(),
                answers: answers
            )
            try expect(!readiness.isReady)
            try expect(readiness.missingModules.contains(.creativeHopelessness))
            try expect(readiness.missingModules.contains(.coreValues))
        }

        try runner.run("readiness is evidence driven") {
            let evaluator = SettlementReadinessEvaluator()
            let profile = AlignmentProfile(
                falsifiedFantasy: "没有无代价的自由。",
                coreValueAxis: "用可持续的方式守住自由。",
                acceptedCosts: ["短期收入波动"],
                hegelianSynthesis: HegelianSynthesis(
                    thesis: "我想离开高压工作。",
                    antithesis: "我也需要现实退路。",
                    synthesis: "先用一个月观察期换回判断力。"
                ),
                userSelfStatements: ["我可以接受慢一点，但不能继续耗空。"]
            )
            let readiness = evaluator.evaluate(
                profile: profile,
                ledger: ScribeObservationLedger(),
                answers: [
                    ScribeInquiryAnswer(
                        questionID: "action",
                        question: "24 小时内能完成的行动是什么？",
                        selectedOptionID: "a",
                        selectedLabel: "今晚写出预算和离职观察期"
                    )
                ]
            )
            try expect(readiness.isReady)
        }

        try runner.run("meeting flow stores normalized runtime snapshot") {
            let engine = MeetingFlowEngine()
            let state = try engine.start(
                rawInput: "我想辞职又怕没钱",
                runtimeSnapshot: MeetingRuntimeSnapshot(
                    providerMode: .openAICompatible,
                    providerModel: "  gpt-4.1  ",
                    providerBaseURLString: " https://api.example.com/v1 ",
                    context: ProviderContext(
                        meCard: "  我需要低噪音地想清楚  ",
                        tasteProfile: "   "
                    )
                )
            )

            try expect(state.runtimeSnapshot?.providerMode == .openAICompatible)
            try expect(state.runtimeSnapshot?.providerModel == "gpt-4.1")
            try expect(state.runtimeSnapshot?.providerBaseURLString == "https://api.example.com/v1")
            try expect(state.runtimeSnapshot?.context?.meCard == "我需要低噪音地想清楚")
            try expect(state.runtimeSnapshot?.context?.tasteProfile == nil)
            try expect(state.runtimeSnapshot?.contextSummary == "个人背景")
        }

        try runner.run("runtime snapshot omits secrets and legacy state decodes") {
            let encoder = ParallelMeCoding.makeEncoder()
            let decoder = ParallelMeCoding.makeDecoder()
            let snapshot = MeetingRuntimeSnapshot(
                settings: ProviderRuntimeSettings(
                    mode: .openAICompatible,
                    baseURLString: "https://api.openai.com/v1",
                    model: "gpt-4.1",
                    apiKey: "sk-test-secret"
                )
            )
            let snapshotText = try String(data: encoder.encode(snapshot), encoding: .utf8) ?? ""
            let legacyStateData = try encoder.encode(try MeetingFlowEngine().start(rawInput: "我想换工作"))
            let decodedLegacyState = try decoder.decode(MeetingFlowState.self, from: legacyStateData)

            try expect(!snapshotText.contains("sk-test-secret"))
            try expect(!snapshotText.contains("apiKey"))
            try expect(decodedLegacyState.runtimeSnapshot == nil)
        }

        try runner.run("provider settings validate demo and openai-compatible modes") {
            try expect(ProviderRuntimeSettings(mode: .demo).isUsable)
            try expect(!ProviderRuntimeSettings(mode: .openAICompatible).isUsable)
            let paddedSettings = ProviderRuntimeSettings(
                mode: .openAICompatible,
                baseURLString: " https://api.example.com/v1 ",
                model: " gpt-test ",
                apiKey: " sk-test "
            )
            try expect(paddedSettings.isUsable)
            try expect(
                paddedSettings.normalized == ProviderRuntimeSettings(
                    mode: .openAICompatible,
                    baseURLString: "https://api.example.com/v1",
                    model: "gpt-test",
                    apiKey: "sk-test"
                )
            )
            try expect(paddedSettings.resolvedBaseURL?.absoluteString == "https://api.example.com/v1")
            try expect(
                !ProviderRuntimeSettings(
                    mode: .openAICompatible,
                    baseURLString: "api.openai.com/v1",
                    model: "gpt-4o-mini",
                    apiKey: "test-key"
                ).isUsable
            )
            try expect(
                ProviderRuntimeSettings(
                    mode: .openAICompatible,
                    baseURLString: "https://api.openai.com/v1",
                    model: "gpt-4o-mini",
                    apiKey: "test-key"
                ).isUsable
            )
            do {
                _ = try ProviderRuntimeFactory.makeProvider(settings: ProviderRuntimeSettings(mode: .openAICompatible))
                throw TestFailure("Expected invalid provider settings")
            } catch ProviderRuntimeFactoryError.invalidOpenAICompatibleSettings {
                // expected
            }
        }

        try runner.run("meeting start readiness explains blocked starts") {
            let emptyDemo = MeetingStartReadinessSnapshot(
                petition: "   ",
                providerSettings: ProviderRuntimeSettings(mode: .demo)
            )
            try expect(!emptyDemo.canStart)
            try expect(emptyDemo.blockers == [.emptyPetition])
            try expect(emptyDemo.actionTitle == "还不能开始")

            let invalidProvider = MeetingStartReadinessSnapshot(
                petition: "我想换工作",
                providerSettings: ProviderRuntimeSettings(
                    mode: .openAICompatible,
                    baseURLString: "api.openai.com/v1",
                    model: " ",
                    apiKey: " "
                )
            )
            try expect(!invalidProvider.canStart)
            try expect(invalidProvider.blockers == [.invalidBaseURL, .missingModel, .missingAPIKey])
            try expect(invalidProvider.detail.contains("Base URL"))
            try expect(invalidProvider.detail.contains("模型名"))
            try expect(invalidProvider.detail.contains("API Key"))

            let ready = MeetingStartReadinessSnapshot(
                petition: "我想换工作",
                providerSettings: ProviderRuntimeSettings(mode: .demo)
            )
            try expect(ready.canStart)
            try expect(ready.actionTitle == "开始五声圆桌")

            let busy = MeetingStartReadinessSnapshot(
                petition: "我想换工作",
                providerSettings: ProviderRuntimeSettings(mode: .demo),
                isBusy: true
            )
            try expect(!busy.canStart)
            try expect(!busy.canEditPetition)
            try expect(!busy.canUseStarterPrompts)
            try expect(busy.actionTitle == "书记员整理中")
        }

        try runner.run("runtime preferences actions lock while busy") {
            let ready = RuntimePreferencesActionAvailabilitySnapshot()
            let busy = RuntimePreferencesActionAvailabilitySnapshot(isBusy: true)

            try expect(ready.canEdit)
            try expect(ready.canSave)
            try expect(ready.canClear)
            try expect(ready.message == nil)
            try expect(!busy.canEdit)
            try expect(!busy.canSave)
            try expect(!busy.canClear)
            try expect(busy.message?.contains("运行配置正在处理") == true)
        }

        try runner.run("meeting activity snapshots explain active work") {
            let inquiry = MeetingActivitySnapshot(kind: .startingInquiry)
            let localArchive = MeetingActivitySnapshot(kind: .archivingPaper)
            let definition = MeetingActivitySnapshot(kind: .submittingDefinitionAnswers)
            let retryInquiry = MeetingActivitySnapshot(kind: .retryingInquiry)

            try expect(inquiry.title == "书记员正在进入问询")
            try expect(inquiry.detail.contains("没有固定题数上限"))
            try expect(inquiry.usesProvider)
            try expect(retryInquiry.title == "书记员正在重新整理问询")
            try expect(retryInquiry.detail.contains("已有问询回答"))
            try expect(retryInquiry.usesProvider)
            try expect(localArchive.systemImage == "archivebox")
            try expect(!localArchive.usesProvider)
            try expect(definition.detail.contains("一起送回"))
            try expect(MeetingActivitySnapshot(kind: .retryingDefinition).usesProvider)
            try expect(MeetingActivitySnapshot(kind: .retryingDefinition).title.contains("重新整理"))
            try expect(MeetingActivityKind.allCases.count == 19)
        }

        try runner.run("provider prompt specs preserve product contracts") {
            let definitionPrompt = ProviderPromptSpec.spec(for: .defineIssue).systemPrompt
            try expect(definitionPrompt.contains("input.context"))
            try expect(definitionPrompt.contains("不得覆盖本轮"))
            try expect(definitionPrompt.contains("1-3"))
            try expect(definitionPrompt.contains("不得设置总轮数上限"))
            try expect(definitionPrompt.contains("coreFears"))
            try expect(definitionPrompt.contains("expectedResolution"))
            try expect(definitionPrompt.contains("userFeedback"))
            try expect(definitionPrompt.contains("custom"))

            let openingPrompt = ProviderPromptSpec.spec(for: .openRoundtable).systemPrompt
            for voiceID in VoiceID.allCases {
                try expect(openingPrompt.contains(voiceID.rawValue))
            }
            try expect(openingPrompt.contains("input.context"))
            try expect(openingPrompt.contains("不得创造临时角色"))

            let inquiryPrompt = ProviderPromptSpec.spec(for: .alignmentInquiry).systemPrompt
            try expect(inquiryPrompt.contains("input.context"))
            try expect(inquiryPrompt.contains("没有总题数上限"))
            try expect(inquiryPrompt.contains("readyForSettlement=true"))
            try expect(inquiryPrompt.contains("creativeHopelessness"))
            try expect(inquiryPrompt.contains("dialecticSynthesis"))
            try expect(inquiryPrompt.contains("custom"))

            let settlementPrompt = ProviderPromptSpec.spec(for: .heartSettlement).systemPrompt
            try expect(settlementPrompt.contains("24 小时"))
            try expect(settlementPrompt.contains("creativeHopelessness"))
            try expect(settlementPrompt.contains("minimumViableCommitment"))
            try expect(settlementPrompt.contains("dialecticSynthesis"))
        }

        try runner.run("meeting summary prefers settlement headline") {
            var state = try MeetingFlowEngine().start(rawInput: "我想换工作")
            state = try MeetingFlowEngine().receiveIssueProposal(completeProposal, in: state)
            state.heartSettlement = sampleSettlement
            state.stage = .archived
            let summary = MeetingSummary(state: state)

            try expect(summary.title == sampleSettlement.headline)
            try expect(summary.subtitle == "已归档")
            try expect(summary.stage == .archived)
        }

        try runner.run("resume policy picks latest unfinished meeting") {
            let engine = MeetingFlowEngine()
            var stale = try engine.start(rawInput: "旧纸页")
            stale.createdAt = Date(timeIntervalSince1970: 10)

            var archived = try engine.start(rawInput: "已经完成的纸页")
            archived.createdAt = Date(timeIntervalSince1970: 100)
            archived.stage = .archived

            var active = try engine.start(rawInput: "需要继续的纸页")
            active.createdAt = Date(timeIntervalSince1970: 20)
            active = try engine.receiveIssueProposal(completeProposal, in: active)
            active = try engine.confirmProposal(in: active)
            active = try engine.receiveOpenings(VoiceID.allCases.map { opening($0) }, in: active)
            active = try engine.appendRoundtableMove(
                RoundtableMove(
                    type: .userToTable,
                    userText: "继续讨论现金流底线",
                    createdAt: Date(timeIntervalSince1970: 120)
                ),
                turns: [],
                in: active
            )

            let candidate = MeetingResumePolicy.candidate(in: [stale, archived, active])
            let summary = MeetingResumePolicy.summary(in: [archived, active])

            try expect(candidate?.id == active.id)
            try expect(summary?.title == completeProposal.issueSentence)
            try expect(MeetingResumePolicy.candidate(in: [archived]) == nil)
        }

        try runner.run("meeting library groups and sorts local papers") {
            let engine = MeetingFlowEngine()
            var oldArchived = try engine.start(rawInput: "旧归档")
            oldArchived.createdAt = Date(timeIntervalSince1970: 10)
            oldArchived.stage = .archived
            oldArchived.heartSettlement = sampleSettlement

            var recentArchived = try engine.start(rawInput: "新归档")
            recentArchived.createdAt = Date(timeIntervalSince1970: 20)
            recentArchived.stage = .archived

            var active = try engine.start(rawInput: "最新未完成")
            active.createdAt = Date(timeIntervalSince1970: 30)
            active = try engine.receiveIssueProposal(completeProposal, in: active)
            active = try engine.confirmProposal(in: active)
            active = try engine.receiveOpenings(VoiceID.allCases.map { opening($0) }, in: active)
            active = try engine.appendRoundtableMove(
                RoundtableMove(
                    type: .userToTable,
                    userText: "继续排代价",
                    createdAt: Date(timeIntervalSince1970: 120)
                ),
                turns: [],
                in: active
            )

            let library = MeetingLibrarySnapshot(states: [oldArchived, active, recentArchived], recentLimit: 2)

            try expect(library.totalCount == 3)
            try expect(library.recent.map(\.id) == [active.id, recentArchived.id])
            try expect(library.resumable?.id == active.id)
            try expect(library.unfinished.map(\.id) == [active.id])
            try expect(library.archived.map(\.id) == [recentArchived.id, oldArchived.id])
            try expect(library.archivedCount == 2)
            try expect(library.unfinishedCount == 1)
            try expect(!library.isEmpty)
        }

        try runner.run("meeting library filters papers by status and search text") {
            let now = Date(timeIntervalSince1970: 100)
            let summaries = [
                MeetingSummary(
                    id: "money",
                    title: "现金流观察期",
                    subtitle: "五声圆桌 · 5 个开场",
                    stage: .roundtable,
                    createdAt: Date(timeIntervalSince1970: 10),
                    updatedAt: now
                ),
                MeetingSummary(
                    id: "health",
                    title: "身体底线",
                    subtitle: "已归档",
                    stage: .archived,
                    createdAt: Date(timeIntervalSince1970: 20),
                    updatedAt: Date(timeIntervalSince1970: 90)
                )
            ]
            let library = MeetingLibrarySnapshot(summaries: summaries)
            let money = library.filtered(searchText: "现金 圆桌")
            let archived = library.filtered(searchText: "归档")
            let unfinishedOnly = library.filtered(searchText: "", filter: .unfinished)
            let archivedOnly = library.filtered(searchText: "", filter: .archived)
            let archivedHealth = library.filtered(searchText: "身体", filter: .archived)
            let archivedMoney = library.filtered(searchText: "现金", filter: .archived)
            let none = library.filtered(searchText: "不存在")

            try expect(MeetingLibraryFilter.allCases.map(\.title) == ["全部", "未完成", "已归档"])
            try expect(money.recent.map(\.id) == ["money"], "Unexpected money recent: \(money.recent.map(\.id))")
            try expect(money.unfinished.map(\.id) == ["money"], "Unexpected money unfinished: \(money.unfinished.map(\.id))")
            try expect(archived.archived.map(\.id) == ["health"], "Unexpected archived results: \(archived.archived.map(\.id))")
            try expect(unfinishedOnly.unfinished.map(\.id) == ["money"])
            try expect(unfinishedOnly.archived.isEmpty)
            try expect(archivedOnly.archived.map(\.id) == ["health"])
            try expect(archivedOnly.unfinished.isEmpty)
            try expect(archivedHealth.archived.map(\.id) == ["health"])
            try expect(archivedMoney.isEmpty)
            try expect(none.isEmpty, "Unexpected no-match count: \(none.totalCount)")
            try expect(library.filtered(searchText: "   ") == library)
        }

        try runner.run("meeting library searches full paper content") {
            let engine = MeetingFlowEngine()
            var state = try engine.start(rawInput: "我想重新安排工作")
            state = try engine.receiveIssueProposal(completeProposal, in: state)
            state = try engine.confirmProposal(in: state)
            state = try engine.receiveOpenings(VoiceID.allCases.map { opening($0) }, in: state)
            state = try engine.appendRoundtableMove(
                RoundtableMove(type: .userToTable, userText: "下一步要看什么？"),
                turns: [
                    RoundtableTurn(
                        voiceID: .future,
                        text: "未来的我希望你把预约体检这件事排进明天。"
                    )
                ],
                in: state
            )
            state = try engine.startInquiry(in: state)
            state = try engine.answerInquiry([
                ScribeInquiryAnswer(
                    questionID: "full_text_action",
                    question: "24 小时内能完成的行动是什么？",
                    selectedOptionID: "custom",
                    selectedLabel: "都不准，我自己说",
                    customText: "明早 10 点前预约体检。"
                )
            ], in: state)
            var settlement = sampleSettlement
            settlement.revise(moduleID: .minimumAction, text: "明早 10 点前预约体检。")
            state = try engine.settle(settlement, profile: completeProfile, in: state)
            state = try engine.archive(state: state)

            let library = MeetingLibrarySnapshot(states: [state])

            try expect(library.filtered(searchText: "预约体检").archived.map(\.id) == [state.id])
            try expect(library.filtered(searchText: "未来的我").archived.map(\.id) == [state.id])
        }

        try runner.run("paper library actions lock while busy") {
            let ready = PaperLibraryActionAvailabilitySnapshot()
            let busy = PaperLibraryActionAvailabilitySnapshot(isBusy: true)

            try expect(ready.canRestore)
            try expect(ready.canDelete)
            try expect(ready.message == nil)
            try expect(!busy.canRestore)
            try expect(!busy.canDelete)
            try expect(busy.message?.contains("纸页库正在处理") == true)
        }

        try runner.run("meeting timeline summarizes current paper progress") {
            let engine = MeetingFlowEngine()
            let started = try engine.start(rawInput: "我想辞职又怕没钱")
            let probe = question("timeline_probe", "真正怕失去什么？", .coreFears)
            let probing = try engine.receiveProbeQuestions([probe], in: started)
            let answered = try engine.answerProbe([
                ScribeAnswer(
                    questionID: probe.id,
                    selectedOptionID: "custom",
                    selectedOptionLabel: "都不准，我自己说",
                    questionText: probe.text,
                    freeText: "我怕继续撑下去，身体会先垮。"
                )
            ], in: probing)
            let proposed = try engine.receiveIssueProposal(completeProposal, in: answered)
            let roundtable = try engine.confirmProposal(in: proposed)
            let opened = try engine.receiveOpenings(VoiceID.allCases.map { opening($0) }, in: roundtable)
            let moved = try engine.appendRoundtableMove(
                RoundtableMove(type: .userToTable, userText: "你们怎么看身体底线？"),
                turns: [RoundtableTurn(voiceID: .lay, text: "先承认身体不是无限资源。")],
                in: opened
            )
            let inquiry = try engine.startInquiry(in: moved)
            let inquiryAnswered = try engine.answerInquiry([
                ScribeInquiryAnswer(
                    questionID: "timeline_inquiry",
                    question: "24 小时内能完成的行动是什么？",
                    selectedOptionID: "custom",
                    selectedLabel: "都不准，我自己说",
                    customText: "今晚先约体检。"
                )
            ], in: inquiry)
            let settled = try engine.settle(sampleSettlement, profile: completeProfile, in: inquiryAnswered)
            let archived = try engine.archive(state: settled)
            let timeline = MeetingTimeline.items(for: archived)

            try expect(timeline.map(\.kind) == [
                .started,
                .definingAnswer,
                .proposal,
                .roundtableOpened,
                .roundtableMove,
                .inquiryAnswer,
                .settlement,
                .archived
            ])
            try expect(timeline.first?.detail == "我想辞职又怕没钱")
            try expect(timeline.contains { $0.detail.contains("身体会先垮") })
            try expect(timeline.contains { $0.title == "追问全桌" && $0.detail.contains("身体底线") })
            try expect(timeline.last?.stage == .archived)
            try expect(timeline.first { $0.kind == .settlement }?.createdAt == archived.settledAt)
            try expect(timeline.last?.createdAt == archived.archivedAt)
        }

        try runner.run("meeting timeline snapshot supports recent and full views") {
            let engine = MeetingFlowEngine()
            var state = try engine.start(rawInput: "我想辞职又怕没钱")
            let probe = question("timeline_snapshot_probe", "真正怕失去什么？", .coreFears)
            state = try engine.receiveProbeQuestions([probe], in: state)
            state = try engine.answerProbe([
                ScribeAnswer(
                    questionID: probe.id,
                    selectedOptionID: "custom",
                    selectedOptionLabel: "都不准，我自己说",
                    questionText: probe.text,
                    freeText: "我怕继续撑下去，身体会先垮。"
                )
            ], in: state)
            state = try engine.receiveIssueProposal(completeProposal, in: state)
            state = try engine.confirmProposal(in: state)
            state = try engine.receiveOpenings(VoiceID.allCases.map { opening($0) }, in: state)
            state = try engine.appendRoundtableMove(
                RoundtableMove(type: .userToTable, userText: "你们怎么看身体底线？"),
                turns: [RoundtableTurn(voiceID: .lay, text: "先承认身体不是无限资源。")],
                in: state
            )
            state = try engine.startInquiry(in: state)
            state = try engine.answerInquiry([
                ScribeInquiryAnswer(
                    questionID: "timeline_snapshot_inquiry",
                    question: "24 小时内能完成的行动是什么？",
                    selectedOptionID: "custom",
                    selectedLabel: "都不准，我自己说",
                    customText: "今晚先约体检。"
                )
            ], in: state)
            state = try engine.settle(sampleSettlement, profile: completeProfile, in: state)
            state = try engine.archive(state: state)

            let timeline = MeetingTimeline.items(for: state)
            let snapshot = MeetingTimelineSnapshot(items: timeline, collapsedLimit: 5)

            try expect(snapshot.totalCount == 8)
            try expect(snapshot.hiddenCount == 3)
            try expect(snapshot.hasHiddenHistory)
            try expect(snapshot.collapsedItems.map(\.kind) == [
                .roundtableOpened,
                .roundtableMove,
                .inquiryAnswer,
                .settlement,
                .archived
            ])
            try expect(snapshot.visibleItems(isExpanded: true) == timeline)
        }

        try runner.run("roundtable transcript groups openings moves and legacy turns") {
            let firstMove = RoundtableMove(
                id: "move_table",
                type: .userToTable,
                userText: "你们怎么看身体底线？",
                createdAt: Date(timeIntervalSince1970: 20)
            )
            let secondMove = RoundtableMove(
                id: "move_duel",
                type: .duel,
                fromVoiceID: .money,
                toVoiceID: .lay,
                createdAt: Date(timeIntervalSince1970: 30)
            )
            let record = RoundtableRecord(
                openingTurns: VoiceID.allCases.map { opening($0) },
                turns: [
                    RoundtableTurn(moveID: firstMove.id, voiceID: .lay, text: "身体不是无限资源。"),
                    RoundtableTurn(moveID: firstMove.id, voiceID: .future, text: "先把体检排进明天。"),
                    RoundtableTurn(moveID: secondMove.id, voiceID: .money, text: "预算要先看清。"),
                    RoundtableTurn(voiceID: .roam, text: "这是旧纸页里未绑定动作的发言。")
                ],
                moves: [firstMove, secondMove]
            )

            let transcript = RoundtableTranscriptSnapshot(record: record)

            try expect(transcript.sections.map(\.kind) == [.opening, .move, .move, .ungrouped])
            try expect(transcript.sections.first?.openingTurns.map(\.voiceID) == VoiceID.allCases)
            try expect(transcript.sections[1].title == "追问全桌")
            try expect(transcript.sections[1].detail == "你们怎么看身体底线？")
            try expect(transcript.sections[1].turns.map(\.voiceID) == [.lay, .future])
            try expect(transcript.sections[2].detail == "搞钱的我 向 躺平的我 发问")
            try expect(transcript.sections[3].title == "圆桌补充")
            try expect(transcript.sections[3].turns.map(\.voiceID) == [.roam])
            try expect(!RoundtableTranscriptSnapshot(record: RoundtableRecord(moves: [firstMove])).isEmpty)
        }

        try runner.run("meeting summaries use settlement and archive timestamps") {
            let engine = MeetingFlowEngine()
            var active = try engine.start(rawInput: "待落定纸页")
            active.createdAt = Date(timeIntervalSince1970: 10)
            active.stage = .settlement
            active.heartSettlement = sampleSettlement
            active.settledAt = Date(timeIntervalSince1970: 80)

            var olderArchived = try engine.start(rawInput: "较早归档")
            olderArchived.createdAt = Date(timeIntervalSince1970: 100)
            olderArchived.stage = .archived
            olderArchived.heartSettlement = sampleSettlement
            olderArchived.archivedAt = Date(timeIntervalSince1970: 120)

            var newerArchived = try engine.start(rawInput: "较新归档")
            newerArchived.createdAt = Date(timeIntervalSince1970: 20)
            newerArchived.stage = .archived
            newerArchived.heartSettlement = sampleSettlement
            newerArchived.archivedAt = Date(timeIntervalSince1970: 200)

            let summary = MeetingSummary(state: active)
            let library = MeetingLibrarySnapshot(states: [olderArchived, newerArchived, active], recentLimit: 3)

            try expect(summary.updatedAt == Date(timeIntervalSince1970: 80))
            try expect(library.recent.map(\.id) == [newerArchived.id, olderArchived.id, active.id])
            try expect(library.archived.map(\.id) == [newerArchived.id, olderArchived.id])
        }

        try runner.run("meeting archive snapshot renders archived paper detail") {
            let engine = MeetingFlowEngine()
            var state = try engine.start(rawInput: "我想辞职又怕没钱")
            let probe = question("archive_probe", "真正怕失去什么？", .coreFears)
            state = try engine.receiveProbeQuestions([probe], in: state)
            state = try engine.answerProbe([
                ScribeAnswer(
                    questionID: probe.id,
                    selectedOptionID: "custom",
                    selectedOptionLabel: "都不准，我自己说",
                    questionText: probe.text,
                    freeText: "我怕身体撑不住。"
                )
            ], in: state)
            state = try engine.receiveIssueProposal(completeProposal, in: state)
            state = try engine.confirmProposal(in: state)
            state = try engine.receiveOpenings(VoiceID.allCases.map { opening($0) }, in: state)
            state = try engine.appendRoundtableMove(
                RoundtableMove(type: .userToTable, userText: "身体底线在哪里？"),
                turns: [RoundtableTurn(voiceID: .lay, text: "先把身体当成真实边界。")],
                in: state
            )
            state = try engine.startInquiry(in: state)
            state = try engine.answerInquiry([
                ScribeInquiryAnswer(
                    questionID: "archive_action",
                    question: "24 小时内能完成的行动是什么？",
                    selectedOptionID: "custom",
                    selectedLabel: "都不准，我自己说",
                    customText: "明早预约体检。"
                )
            ], in: state)
            var settlement = sampleSettlement
            settlement.revise(moduleID: .minimumAction, text: "明早 10 点前预约体检。")
            settlement.revise(moduleID: .dialecticSynthesis, text: "先承认身体边界，再用观察期换回判断力。")
            state = try engine.settle(settlement, profile: completeProfile, in: state)
            state = try engine.archive(state: state)

            let archive = MeetingArchiveSnapshot(state: state)

            try expect(archive.summary.stage == .archived)
            try expect(archive.summary.title == "先承认身体边界，再用观察期换回判断力。")
            try expect(archive.hasIssue)
            try expect(archive.hasSettlement)
            try expect(archive.issueRows.map(\.title) == ["选择岔路", "现实边界", "隐秘关切", "圆桌任务"])
            try expect(archive.settlementRows.contains { $0.body == "明早 10 点前预约体检。" })
            try expect(archive.settlementRows.contains { $0.body == "先承认身体边界，再用观察期换回判断力。" })
            try expect(archive.timelineItems.map(\.kind).contains(.definingAnswer))
            try expect(archive.timelineItems.map(\.kind).contains(.roundtableMove))
            try expect(archive.timelineItems.last?.kind == .archived)
        }

        try runner.run("meeting export availability follows archive state") {
            for stage in [MeetingStage.defining, .roundtable, .inquiry, .settlement] {
                let snapshot = MeetingExportAvailabilitySnapshot(stage: stage)
                try expect(!snapshot.canExport)
                try expect(snapshot.actionTitle == "归档后导出")
            }

            let archived = MeetingExportAvailabilitySnapshot(stage: .archived)
            try expect(archived.canExport)
            try expect(archived.actionTitle == "导出纸页")
            try expect(archived.accessibilityHint.contains("已归档"))
        }

        try runner.run("meeting export document renders archived paper") {
            let engine = MeetingFlowEngine()
            var state = try engine.start(
                rawInput: "我想辞职又怕没钱",
                runtimeSnapshot: MeetingRuntimeSnapshot(
                    providerMode: .openAICompatible,
                    providerModel: "gpt-4.1",
                    providerBaseURLString: "https://api.openai.com/v1",
                    context: ProviderContext(
                        meCard: "我最近睡眠很差",
                        tasteProfile: "先问事实，再给判断"
                    )
                )
            )
            state = try engine.receiveIssueProposal(completeProposal, in: state)
            state = try engine.confirmProposal(in: state)
            state = try engine.receiveOpenings(VoiceID.allCases.map { opening($0) }, in: state)
            state = try engine.appendRoundtableMove(
                RoundtableMove(type: .userToTable, userText: "身体底线在哪里？"),
                turns: [RoundtableTurn(voiceID: .future, text: "未来的我希望你把体检排进 24 小时内。")],
                in: state
            )
            state = try engine.startInquiry(in: state)
            state = try engine.answerInquiry([
                ScribeInquiryAnswer(
                    questionID: "export_action",
                    question: "24 小时内能完成的行动是什么？",
                    selectedOptionID: "custom",
                    selectedLabel: "都不准，我自己说",
                    customText: "明早预约体检。"
                )
            ], in: state)
            var settlement = sampleSettlement
            settlement.revise(moduleID: .minimumAction, text: "明早 10 点前预约体检。")
            state = try engine.settle(settlement, profile: completeProfile, in: state)
            state = try engine.archive(state: state)

            let document = MeetingExportDocument(
                state: state,
                generatedAt: Date(timeIntervalSince1970: 0)
            )

            try expect(document.title == settlement.headline)
            try expect(document.fileName.hasSuffix(".md"))
            try expect(document.markdown.contains("# \(settlement.headline)"))
            try expect(document.markdown.contains("Provider：gpt-4.1"))
            try expect(document.markdown.contains("个人背景：我最近睡眠很差"))
            try expect(document.markdown.contains("明早 10 点前预约体检。"))
            try expect(document.markdown.contains("纸页脉络"))
            try expect(!document.markdown.contains("apiKey"))
            try expect(!document.markdown.contains("Optional"))
        }

        try runner.run("meeting export writer creates named Markdown file") {
            let engine = MeetingFlowEngine()
            var state = try engine.start(rawInput: "我想辞职又怕没钱")
            state = try engine.receiveIssueProposal(completeProposal, in: state)
            state = try engine.confirmProposal(in: state)
            state = try engine.receiveOpenings(VoiceID.allCases.map { opening($0) }, in: state)
            state = try engine.appendRoundtableMove(
                RoundtableMove(type: .continueAll),
                turns: [RoundtableTurn(voiceID: .future, text: "先把未来后果说清楚。")],
                in: state
            )
            state = try engine.startInquiry(in: state)
            state = try engine.settle(sampleSettlement, profile: completeProfile, in: state)
            state = try engine.archive(state: state)

            let document = MeetingExportDocument(state: state, generatedAt: Date(timeIntervalSince1970: 0))
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("ParallelMeExportSmoke-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: directory) }

            let file = try MeetingExportFileWriter(directoryURL: directory).write(document: document)
            let exportedText = try String(contentsOf: file.url, encoding: .utf8)

            try expect(file.url.deletingLastPathComponent() == directory)
            try expect(file.url.lastPathComponent == document.fileName)
            try expect(file.url.pathExtension == "md")
            try expect(exportedText == document.markdown)
        }

        try runner.run("settlement revisions override resolved text and headline") {
            var settlement = sampleSettlement
            settlement.revise(moduleID: .coreValues, text: "我要守住自己写下的主轴。")
            settlement.revise(moduleID: .dialecticSynthesis, text: "这是我自己认领的正反合。")

            try expect(settlement.resolvedText(for: .coreValues) == "我要守住自己写下的主轴。")
            try expect(settlement.headline == "这是我自己认领的正反合。")
        }

        try runner.run("settlement revision draft only emits meaningful changes") {
            var draft = SettlementRevisionDraft(settlement: sampleSettlement)
            try expect(!draft.hasChanges)
            try expect(!draft.hasDraftEdits)
            try expect(!draft.canApply)
            try expect(draft.canArchive)

            draft.minimumAction = "  今晚只写一行预算。  "
            draft.coreValues = "\n\(sampleSettlement.resolvedText(for: .coreValues))\n"

            try expect(draft.revisions == [.minimumAction: "今晚只写一行预算。"])
            try expect(draft.hasChanges)
            try expect(draft.hasDraftEdits)
            try expect(draft.canApply)
            try expect(!draft.canArchive)

            draft.dialecticSynthesis = "   "

            try expect(draft.hasEmptyRequiredText)
            try expect(!draft.canApply)
            try expect(!draft.canArchive)
        }

        try runner.run("settlement action availability locks while busy") {
            var draft = SettlementRevisionDraft(settlement: sampleSettlement)
            let ready = SettlementActionAvailabilitySnapshot(draft: draft)

            try expect(!ready.canApplyRevision)
            try expect(ready.canArchive)
            try expect(ready.message.contains("保存纸页"))
            try expect(ready.messageTone == .muted)

            draft.minimumAction = "今晚只写一行预算。"
            let edited = SettlementActionAvailabilitySnapshot(draft: draft)
            let busy = SettlementActionAvailabilitySnapshot(draft: draft, isBusy: true)

            try expect(edited.canApplyRevision)
            try expect(!edited.canArchive)
            try expect(edited.message.contains("应用修订"))
            try expect(!busy.canApplyRevision)
            try expect(!busy.canArchive)
            try expect(busy.message.contains("正在处理"))

            draft.minimumAction = "   "
            let incomplete = SettlementActionAvailabilitySnapshot(draft: draft)

            try expect(!incomplete.canApplyRevision)
            try expect(!incomplete.canArchive)
            try expect(incomplete.messageTone == .warning)
        }

        try runner.run("settlement stage snapshot exposes missing settlement recovery") {
            let engine = MeetingFlowEngine()
            var state = try engine.start(rawInput: "我想辞职又怕没钱")
            state.stage = .settlement

            let missing = SettlementStageSnapshot(state: state)
            try expect(!missing.hasSettlement)
            try expect(!missing.canShowSettlementEditor)
            try expect(missing.title == "本心落定缺失")
            try expect(missing.recoveryActionTitle == "回首页")

            state.heartSettlement = sampleSettlement
            let ready = SettlementStageSnapshot(state: state)
            try expect(ready.hasSettlement)
            try expect(ready.canShowSettlementEditor)
            try expect(ready.title == "本心落定")
        }

        try runner.run("archive requires complete heart settlement") {
            let engine = MeetingFlowEngine()
            var missingSettlement = try engine.start(rawInput: "我想辞职又怕没钱")
            missingSettlement.stage = .settlement

            do {
                _ = try engine.archive(state: missingSettlement)
                throw TestFailure("Expected missing heart settlement error")
            } catch MeetingFlowError.missingHeartSettlement {
                // expected
            }

            var incompleteSettlement = sampleSettlement
            incompleteSettlement.minimumViableCommitment.report = "   "
            var incomplete = missingSettlement
            incomplete.heartSettlement = incompleteSettlement

            try expect(!incompleteSettlement.isComplete)
            try expect(incompleteSettlement.missingModules == [.minimumAction])
            do {
                _ = try engine.archive(state: incomplete)
                throw TestFailure("Expected incomplete heart settlement error")
            } catch MeetingFlowError.incompleteHeartSettlement(let missing) {
                try expect(missing == [.minimumAction])
            }
        }

        try await runner.runAsync("provider factory creates demo provider") {
            let provider = try ProviderRuntimeFactory.makeProvider(settings: ProviderRuntimeSettings(mode: .demo))
            let envelope = try await provider.generate(
                request: LLMRequest(
                    kind: .defineIssue,
                    payload: IssueDefinitionInput(rawInput: "我想辞职又怕没钱", dialogue: [])
                ),
                responseType: IssueDefinitionResponse.self
            )
            let refined = try await provider.generate(
                request: LLMRequest(
                    kind: .defineIssue,
                    payload: IssueDefinitionInput(
                        rawInput: "我想辞职又怕没钱",
                        dialogue: [],
                        userFeedback: "请聚焦身体底线"
                    )
                ),
                responseType: IssueDefinitionResponse.self
            )
            try expect(envelope.payload.proposal?.isComplete == true)
            try expect(refined.payload.proposal?.expectedResolution.content.contains("身体底线") == true)
            try expect(envelope.trace == ["demo:defineIssue"])
        }

        try await runner.runAsync("provider factory normalizes openai-compatible settings") {
            let payload = IssueDefinitionResponse(
                proposal: completeProposal,
                readyToPropose: true,
                thinking: "proposal ready"
            )
            let payloadData = try ParallelMeCoding.makeEncoder().encode(payload)
            let payloadJSON = try unwrap(String(data: payloadData, encoding: .utf8), "Expected payload JSON")
            let transport = MockOpenAITransport(
                statusCode: 200,
                responseData: try chatCompletionResponseData(content: payloadJSON)
            )
            let provider = try ProviderRuntimeFactory.makeProvider(
                settings: ProviderRuntimeSettings(
                    mode: .openAICompatible,
                    baseURLString: " https://api.example.com/v1 ",
                    model: " gpt-4.1-mini ",
                    apiKey: " sk-test "
                ),
                openAITransport: transport
            )

            _ = try await provider.generate(
                request: LLMRequest(
                    kind: .defineIssue,
                    payload: IssueDefinitionInput(rawInput: "我想辞职又怕没钱", dialogue: [])
                ),
                responseType: IssueDefinitionResponse.self
            )
            let captured = try await unwrap(transport.latestRequest(), "Expected captured OpenAI request")
            let bodyData = try unwrap(captured.body, "Expected request body")
            let body = try unwrap(
                JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                "Expected JSON request body"
            )

            try expect(captured.urlString == "https://api.example.com/v1/chat/completions")
            try expect(captured.authorization == "Bearer sk-test")
            try expect(body["model"] as? String == "gpt-4.1-mini")
        }

        try await runner.runAsync("openai-compatible provider sends strict chat request and decodes response") {
            let payload = IssueDefinitionResponse(
                proposal: completeProposal,
                readyToPropose: true,
                thinking: "proposal ready"
            )
            let payloadData = try ParallelMeCoding.makeEncoder().encode(payload)
            let payloadJSON = try unwrap(String(data: payloadData, encoding: .utf8), "Expected payload JSON")
            let transport = MockOpenAITransport(
                statusCode: 200,
                responseData: try chatCompletionResponseData(content: "```json\n\(payloadJSON)\n```")
            )
            let provider = OpenAICompatibleProvider(
                configuration: OpenAICompatibleConfiguration(
                    baseURL: URL(string: "https://api.example.com/v1")!,
                    apiKey: "sk-test",
                    model: "gpt-4.1-mini",
                    temperature: 0.2,
                    timeout: 12
                ),
                transport: transport
            )

            let envelope = try await provider.generate(
                request: LLMRequest(
                    kind: .defineIssue,
                    payload: IssueDefinitionInput(rawInput: "我想辞职又怕没钱", dialogue: [])
                ),
                responseType: IssueDefinitionResponse.self
            )
            let captured = try await unwrap(transport.latestRequest(), "Expected captured OpenAI request")
            let bodyData = try unwrap(captured.body, "Expected request body")
            let body = try unwrap(
                JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                "Expected JSON request body"
            )
            let responseFormat = try unwrap(body["response_format"] as? [String: Any], "Expected response format")
            let messages = try unwrap(body["messages"] as? [[String: Any]], "Expected messages")
            let systemPrompt = try unwrap(messages.first?["content"] as? String, "Expected system prompt")
            let userPrompt = try unwrap(messages.last?["content"] as? String, "Expected user prompt")

            try expect(envelope.payload.proposal == completeProposal)
            try expect(envelope.trace == ["openai-compatible:defineIssue"])
            try expect(captured.urlString == "https://api.example.com/v1/chat/completions")
            try expect(captured.method == "POST")
            try expect(captured.timeout == 12)
            try expect(captured.authorization == "Bearer sk-test")
            try expect(captured.contentType == "application/json")
            try expect(body["model"] as? String == "gpt-4.1-mini")
            try expect(body["temperature"] as? Double == 0.2)
            try expect(responseFormat["type"] as? String == "json_object")
            try expect(messages.map { $0["role"] as? String } == ["system", "user"])
            try expect(systemPrompt.contains("只返回一个严格 JSON object"))
            try expect(userPrompt.contains("任务输入 JSON"))
            try expect(userPrompt.contains("我想辞职又怕没钱"))
        }

        try await runner.runAsync("openai-compatible provider reports HTTP error body") {
            let transport = MockOpenAITransport(
                statusCode: 429,
                responseData: Data(#"{"error":"rate limited"}"#.utf8)
            )
            let provider = OpenAICompatibleProvider(
                configuration: OpenAICompatibleConfiguration(
                    baseURL: URL(string: "https://api.example.com/v1")!,
                    apiKey: "sk-test",
                    model: "gpt-4.1-mini"
                ),
                transport: transport
            )

            do {
                _ = try await provider.generate(
                    request: LLMRequest(
                        kind: .defineIssue,
                        payload: IssueDefinitionInput(rawInput: "我想辞职又怕没钱", dialogue: [])
                    ),
                    responseType: IssueDefinitionResponse.self
                )
                throw TestFailure("Expected OpenAI-compatible transport error")
            } catch OpenAICompatibleProviderError.transport(let statusCode, let body) {
                try expect(statusCode == 429)
                try expect(body.contains("rate limited"))
            }
        }

        try await runner.runAsync("provider settings repository keeps api key out of metadata") {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("parallel-me-provider-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let fileURL = directory.appendingPathComponent("provider-settings.json")
            let metadataStore = FileProviderRuntimeMetadataStore(fileURL: fileURL)
            let secretStore = InMemorySecretStore()
            let repository = ProviderSettingsRepository(
                metadataStore: metadataStore,
                secretStore: secretStore
            )
            let settings = ProviderRuntimeSettings(
                mode: .openAICompatible,
                baseURLString: "https://api.openai.com/v1",
                model: "gpt-4o-mini",
                apiKey: "sk-test-secret"
            )

            try await repository.saveSettings(settings)
            let loaded = try await repository.loadSettings()
            let metadataText = try String(contentsOf: fileURL, encoding: .utf8)

            try expect(loaded == settings)
            try expect(!metadataText.contains("sk-test-secret"))
            try expect(metadataText.contains("gpt-4o-mini"))
        }

        try await runner.runAsync("provider context store normalizes and clears context") {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("parallel-me-context-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = FileProviderContextStore(
                fileURL: directory.appendingPathComponent("provider-context.json")
            )
            let context = ProviderContext(
                meCard: "  我长期在高压工作里消耗自己  ",
                tasteProfile: "\n直接一点，但不要替我决定\n"
            )

            try await store.saveContext(context)
            let loaded = try await store.loadContext()
            try await store.clearContext()
            let cleared = try await store.loadContext()

            try expect(loaded.meCard == "我长期在高压工作里消耗自己")
            try expect(loaded.tasteProfile == "直接一点，但不要替我决定")
            try expect(cleared.isEmpty)
        }

        try await runner.runAsync("meeting view model applies starter prompt") {
            let viewModel = MeetingViewModel(
                coordinator: MeetingSessionCoordinator(
                    provider: DemoLLMProvider(),
                    repository: InMemoryMeetingRepository()
                )
            )
            let prompt = try unwrap(PetitionStarterPrompts.all.first, "Expected starter prompt")

            try expect(viewModel.petition.isEmpty)
            try expect(!viewModel.canStart)
            try expect(viewModel.startReadiness.blockers == [.emptyPetition])

            viewModel.useStarterPrompt(prompt)

            try expect(viewModel.petition == prompt.seedText)
            try expect(viewModel.canStart)
            try expect(viewModel.startReadiness.canStart)
        }

        try await runner.runAsync("meeting view model saves and clears runtime preferences") {
            let metadataStore = InMemoryProviderRuntimeMetadataStore()
            let secretStore = InMemorySecretStore()
            let settingsStore = ProviderSettingsRepository(
                metadataStore: metadataStore,
                secretStore: secretStore
            )
            let contextStore = InMemoryProviderContextStore()
            let viewModel = MeetingViewModel(
                coordinator: MeetingSessionCoordinator(
                    provider: DemoLLMProvider(),
                    repository: InMemoryMeetingRepository()
                ),
                providerSettingsStore: settingsStore,
                providerContextStore: contextStore
            )

            viewModel.providerMode = .openAICompatible
            viewModel.providerBaseURL = " https://api.example.com/v1 "
            viewModel.providerModel = " gpt-test "
            viewModel.providerAPIKey = " sk-test "
            viewModel.contextMeCard = "  我在高压工作里消耗自己  "
            viewModel.contextTasteProfile = "\n先问事实，再给判断\n"

            viewModel.saveRuntimePreferences()
            try await waitFor("runtime preferences save") {
                !viewModel.isBusy && viewModel.runtimePreferencesMessage == "运行配置已保存到本机。"
            }
            let savedSettings = try await settingsStore.loadSettings()
            let savedContext = try await contextStore.loadContext()

            try expect(savedSettings.mode == .openAICompatible)
            try expect(savedSettings.baseURLString == "https://api.example.com/v1")
            try expect(savedSettings.model == "gpt-test")
            try expect(savedSettings.apiKey == "sk-test")
            try expect(savedContext.meCard == "我在高压工作里消耗自己")
            try expect(savedContext.tasteProfile == "先问事实，再给判断")

            viewModel.clearRuntimePreferences()
            try await waitFor("runtime preferences clear") {
                !viewModel.isBusy && viewModel.runtimePreferencesMessage == "运行配置已清空。"
            }
            let clearedSettings = try await settingsStore.loadSettings()
            let clearedContext = try await contextStore.loadContext()

            try expect(clearedSettings == ProviderRuntimeSettings())
            try expect(clearedContext.isEmpty)
            try expect(viewModel.providerMode == .demo)
            try expect(viewModel.providerAPIKey.isEmpty)
            try expect(viewModel.contextMeCard.isEmpty)
            try expect(viewModel.contextTasteProfile.isEmpty)
        }

        try await runner.runAsync("meeting view model exposes activity while async work is running") {
            let settingsStore = SlowProviderSettingsStore(delayNanoseconds: 160_000_000)
            let viewModel = MeetingViewModel(
                coordinator: MeetingSessionCoordinator(
                    provider: DemoLLMProvider(),
                    repository: InMemoryMeetingRepository()
                ),
                providerSettingsStore: settingsStore
            )

            viewModel.saveRuntimePreferences()
            try await waitFor("runtime activity start") {
                viewModel.isBusy && viewModel.activity?.kind == .savingRuntimePreferences
            }
            try expect(viewModel.activity?.title == "正在保存运行配置")
            try expect(viewModel.activity?.usesProvider == false)

            try await waitFor("runtime activity clear") {
                !viewModel.isBusy && viewModel.activity == nil
            }
        }

        try await runner.runAsync("meeting view model retries failed definition request") {
            let provider = FlakyDefinitionProvider(
                success: IssueDefinitionResponse(
                    proposal: completeProposal,
                    readyToPropose: true,
                    thinking: "proposal ready"
                )
            )
            let repository = InMemoryMeetingRepository()
            let viewModel = MeetingViewModel(
                coordinator: MeetingSessionCoordinator(
                    provider: provider,
                    repository: repository
                ),
                meetingRepository: repository,
                providerFactory: { _ in AnyLLMProvider(provider) }
            )

            viewModel.petition = "我想辞职又怕没钱"
            viewModel.startMeeting()
            try await waitFor("failed initial definition") {
                !viewModel.isBusy &&
                viewModel.state?.stage == .defining &&
                viewModel.state?.issueProposal == nil &&
                viewModel.state?.currentQuestions.isEmpty == true &&
                viewModel.errorMessage != nil
            }
            let meetingID = try unwrap(viewModel.state?.id, "Expected started meeting id")

            viewModel.retryDefinition()
            try await waitFor("retried definition proposal") {
                !viewModel.isBusy &&
                viewModel.state?.id == meetingID &&
                viewModel.state?.issueProposal?.isComplete == true &&
                viewModel.errorMessage == nil
            }

            let requestCount = await provider.definitionRequestCount()
            try expect(requestCount == 2)
            try expect(viewModel.state?.taskFrame?.problemDefinition == completeProposal.issueSentence)
        }

        try await runner.runAsync("meeting view model retries failed inquiry request") {
            let provider = FlakyInquiryProvider(
                success: AlignmentInquiryResponse(
                    questions: [
                        ScribeInquiryQuestion(
                            id: "retry_inquiry_action",
                            question: "24 小时内哪个动作最小但真实？",
                            options: [
                                ScribeInquiryOption(id: "rest", label: "先请半天假"),
                                ScribeInquiryOption(id: "custom", label: "都不准，我自己说")
                            ],
                            module: .minimumAction
                        )
                    ],
                    readyForSettlement: false,
                    profile: nil,
                    ledger: ScribeObservationLedger(
                        unansweredQuestions: [
                            UnansweredRoundtableQuestion(
                                fromName: "书记员",
                                question: "24 小时内哪个动作最小但真实？",
                                whyItMatters: "缺少最小行动证据。"
                            )
                        ],
                        moduleSignals: [.creativeHopelessness: ["已经承认没有无代价选项。"]]
                    )
                )
            )
            let repository = InMemoryMeetingRepository()
            let engine = MeetingFlowEngine()
            var state = try engine.start(rawInput: "我想辞职又怕没钱")
            state = try engine.receiveIssueProposal(completeProposal, in: state)
            state = try engine.confirmProposal(in: state)
            state = try engine.receiveOpenings(VoiceID.allCases.map { opening($0) }, in: state)
            state = try engine.appendRoundtableMove(
                RoundtableMove(type: .continueAll),
                turns: [RoundtableTurn(voiceID: .future, text: "先把 24 小时内可做的事落下来。")],
                in: state
            )
            try await repository.save(state)

            let viewModel = MeetingViewModel(
                coordinator: MeetingSessionCoordinator(
                    provider: provider,
                    repository: repository
                ),
                meetingRepository: repository,
                providerFactory: { _ in AnyLLMProvider(provider) }
            )

            viewModel.restoreMeeting(id: state.id)
            try await waitFor("restored inquiry retry seed") {
                !viewModel.isBusy && viewModel.state?.id == state.id
            }

            viewModel.startInquiry()
            try await waitFor("failed initial inquiry") {
                !viewModel.isBusy &&
                viewModel.state?.stage == .inquiry &&
                viewModel.activeInquiryQuestions.isEmpty &&
                viewModel.state?.alignmentProfile == nil &&
                viewModel.errorMessage != nil
            }

            viewModel.retryInquiry()
            try await waitFor("retried inquiry questions") {
                !viewModel.isBusy &&
                viewModel.state?.id == state.id &&
                viewModel.activeInquiryQuestions.map(\.id) == ["retry_inquiry_action"] &&
                viewModel.errorMessage == nil
            }

            let requestCount = await provider.inquiryRequestCount()
            try expect(requestCount == 2)
            try expect(viewModel.activity == nil)
        }

        try await runner.runAsync("session coordinator persists definition and openings") {
            let provider = MockLLMProvider()
            let repository = InMemoryMeetingRepository()
            await provider.register(
                IssueDefinitionResponse(proposal: completeProposal, readyToPropose: true),
                for: .defineIssue
            )
            await provider.register(
                RoundtableOpeningResponse(openings: VoiceID.allCases.map { opening($0) }),
                for: .openRoundtable
            )
            let coordinator = MeetingSessionCoordinator(provider: provider, repository: repository)

            let started = try await coordinator.start(rawInput: "我想辞职又怕没钱")
            let proposed = try await coordinator.requestDefinition()
            let opened = try await coordinator.confirmProposalAndOpenRoundtable()
            let saved = try await repository.load(id: started.id)

            try expect(proposed.issueProposal?.isComplete == true)
            try expect(opened.stage == .roundtable)
            try expect(opened.roundtable.openingTurns.map(\.voiceID) == VoiceID.allCases)
            try expect(saved?.roundtable.openingTurns.count == 5)
        }

        try await runner.runAsync("session coordinator persists runtime snapshot") {
            let repository = InMemoryMeetingRepository()
            let snapshot = MeetingRuntimeSnapshot(
                providerMode: .demo,
                providerModel: "  Demo  ",
                context: ProviderContext(tasteProfile: "  先问事实，再给判断  ")
            )
            let coordinator = MeetingSessionCoordinator(
                provider: MockLLMProvider(),
                repository: repository,
                runtimeSnapshot: snapshot
            )

            let started = try await coordinator.start(rawInput: "我想辞职又怕没钱")
            let saved = try await repository.load(id: started.id)

            try expect(saved?.runtimeSnapshot?.providerLabel == "Demo")
            try expect(saved?.runtimeSnapshot?.context?.tasteProfile == "先问事实，再给判断")
            try expect(saved?.runtimeSnapshot?.contextSummary == "回应偏好")
        }

        try await runner.runAsync("session coordinator forwards provider context") {
            let provider = ContextRecordingProvider(
                definitionResponse: IssueDefinitionResponse(proposal: completeProposal, readyToPropose: true)
            )
            let coordinator = MeetingSessionCoordinator(
                provider: provider,
                repository: InMemoryMeetingRepository(),
                context: ProviderContext(
                    meCard: "  我需要在低噪音里思考  ",
                    tasteProfile: "\n先问边界，再给判断\n"
                )
            )

            _ = try await coordinator.start(rawInput: "我想辞职又怕没钱")
            _ = try await coordinator.requestDefinition()
            let input = await provider.latestDefinitionInput()

            try expect(input?.context?.meCard == "我需要在低噪音里思考")
            try expect(input?.context?.tasteProfile == "先问边界，再给判断")
        }

        try await runner.runAsync("meeting view model rebuilds runtime when restoring unfinished paper") {
            let repository = InMemoryMeetingRepository()
            let provider = ViewModelRuntimeRecordingProvider()
            let engine = MeetingFlowEngine()
            var restored = try engine.start(
                rawInput: "我想辞职又怕没钱",
                runtimeSnapshot: MeetingRuntimeSnapshot(
                    providerMode: .demo,
                    providerModel: "old-demo-runtime",
                    context: ProviderContext(meCard: "纸页原始上下文")
                )
            )
            restored = try engine.receiveIssueProposal(completeProposal, in: restored)
            try await repository.save(restored)

            let viewModel = MeetingViewModel(
                coordinator: MeetingSessionCoordinator(provider: DemoLLMProvider(), repository: repository),
                meetingRepository: repository,
                providerFactory: { _ in AnyLLMProvider(provider) }
            )
            viewModel.providerModel = "current-demo-runtime"
            viewModel.contextMeCard = "当前用户上下文"
            viewModel.contextTasteProfile = "当前回应偏好"

            viewModel.restoreMeeting(id: restored.id)
            try await waitFor("restored unfinished paper") {
                !viewModel.isBusy && viewModel.state?.id == restored.id
            }
            viewModel.confirmProposal()
            try await waitFor("restored paper roundtable") {
                !viewModel.isBusy && viewModel.state?.stage == .roundtable
            }
            let input = await provider.latestOpeningInput()

            try expect(input?.context?.meCard == "当前用户上下文")
            try expect(input?.context?.tasteProfile == "当前回应偏好")
            try expect(viewModel.state?.runtimeSnapshot?.providerModel == "current-demo-runtime")
            try expect(viewModel.state?.runtimeSnapshot?.context?.meCard == "当前用户上下文")
            try expect(viewModel.state?.roundtable.openingTurns.count == 5)
        }

        try await runner.runAsync("meeting view model restores archived paper offline") {
            let repository = InMemoryMeetingRepository()
            var archived = try MeetingFlowEngine().start(rawInput: "已经完成的纸页")
            archived.stage = .archived
            archived.heartSettlement = sampleSettlement
            try await repository.save(archived)

            let viewModel = MeetingViewModel(
                coordinator: MeetingSessionCoordinator(provider: DemoLLMProvider(), repository: repository),
                meetingRepository: repository,
                providerFactory: { _ in throw ProviderRuntimeFactoryError.invalidOpenAICompatibleSettings }
            )
            viewModel.providerMode = .openAICompatible
            viewModel.providerAPIKey = ""

            viewModel.restoreMeeting(id: archived.id)
            try await waitFor("archived paper restore") {
                !viewModel.isBusy && viewModel.state?.id == archived.id
            }

            try expect(viewModel.state?.stage == .archived)
            try expect(viewModel.errorMessage == nil)
        }

        try await runner.runAsync("session coordinator refines proposal from user feedback") {
            let provider = MockLLMProvider()
            let repository = InMemoryMeetingRepository()
            let feedback = "这不是辞职冲动，重点是身体底线和观察期。"
            var refinedProposal = completeProposal
            refinedProposal.issueSentence = "重新定义：身体底线和观察期"
            refinedProposal.expectedResolution = IssueProposalKey(
                title: "圆桌任务",
                content: "围绕身体底线和观察期重新确认代价。",
                details: ["身体底线", "观察期"]
            )
            await provider.register(
                IssueDefinitionResponse(proposal: completeProposal, readyToPropose: true),
                for: .defineIssue
            )
            let coordinator = MeetingSessionCoordinator(provider: provider, repository: repository)

            let started = try await coordinator.start(rawInput: "我想辞职又怕没钱")
            _ = try await coordinator.requestDefinition()
            do {
                _ = try await coordinator.refineProposal(feedback: "  ")
                throw TestFailure("Expected empty proposal feedback error")
            } catch MeetingSessionError.emptyFeedback {
                // expected
            }
            await provider.register(
                IssueDefinitionResponse(proposal: refinedProposal, readyToPropose: true),
                for: .defineIssue
            )
            let refined = try await coordinator.refineProposal(feedback: feedback)
            let saved = try await repository.load(id: started.id)

            try expect(refined.issueProposal?.issueSentence == "重新定义：身体底线和观察期")
            try expect(refined.issueProposal?.expectedResolution.details == ["身体底线", "观察期"])
            try expect(refined.definingDialogue.last?.answer?.freeText == feedback)
            try expect(saved?.definingDialogue.last?.answer?.questionID == "proposal_feedback")
        }

        try await runner.runAsync("session coordinator settles only after readiness") {
            let provider = MockLLMProvider()
            let repository = InMemoryMeetingRepository()
            await provider.register(
                IssueDefinitionResponse(proposal: completeProposal, readyToPropose: true),
                for: .defineIssue
            )
            await provider.register(
                RoundtableOpeningResponse(openings: VoiceID.allCases.map { opening($0) }),
                for: .openRoundtable
            )
            await provider.register(
                RoundtableMoveResponse(
                    turns: [RoundtableTurn(voiceID: .future, text: "先把 24 小时行动放到桌面上。")],
                    ledger: ScribeObservationLedger(moduleSignals: [.minimumAction: ["今晚写预算"]])
                ),
                for: .continueRoundtable
            )
            await provider.register(
                AlignmentInquiryResponse(
                    readyForSettlement: true,
                    profile: completeProfile,
                    ledger: ScribeObservationLedger(moduleSignals: [.minimumAction: ["今晚写预算"]])
                ),
                for: .alignmentInquiry
            )
            await provider.register(
                HeartSettlementResponse(settlement: sampleSettlement),
                for: .heartSettlement
            )
            let coordinator = MeetingSessionCoordinator(provider: provider, repository: repository)

            _ = try await coordinator.start(rawInput: "我想辞职又怕没钱")
            _ = try await coordinator.requestDefinition()
            _ = try await coordinator.confirmProposalAndOpenRoundtable()
            _ = try await coordinator.submitRoundtableMove(RoundtableMove(type: .continueAll))
            _ = try await coordinator.startInquiry()
            let settled = try await coordinator.requestSettlement()

            try expect(settled.stage == .settlement)
            try expect(settled.heartSettlement?.headline == sampleSettlement.headline)
        }

        try await runner.runAsync("session coordinator persists settlement revisions") {
            let provider = MockLLMProvider()
            let repository = InMemoryMeetingRepository()
            await provider.register(
                IssueDefinitionResponse(proposal: completeProposal, readyToPropose: true),
                for: .defineIssue
            )
            await provider.register(
                RoundtableOpeningResponse(openings: VoiceID.allCases.map { opening($0) }),
                for: .openRoundtable
            )
            await provider.register(
                RoundtableMoveResponse(
                    turns: [RoundtableTurn(voiceID: .future, text: "先把 24 小时行动放到桌面上。")],
                    ledger: ScribeObservationLedger(moduleSignals: [.minimumAction: ["今晚写预算"]])
                ),
                for: .continueRoundtable
            )
            await provider.register(
                AlignmentInquiryResponse(
                    readyForSettlement: true,
                    profile: completeProfile,
                    ledger: ScribeObservationLedger(moduleSignals: [.minimumAction: ["今晚写预算"]])
                ),
                for: .alignmentInquiry
            )
            await provider.register(
                HeartSettlementResponse(settlement: sampleSettlement),
                for: .heartSettlement
            )
            let coordinator = MeetingSessionCoordinator(provider: provider, repository: repository)

            let started = try await coordinator.start(rawInput: "我想辞职又怕没钱")
            _ = try await coordinator.requestDefinition()
            _ = try await coordinator.confirmProposalAndOpenRoundtable()
            _ = try await coordinator.submitRoundtableMove(RoundtableMove(type: .continueAll))
            _ = try await coordinator.startInquiry()
            _ = try await coordinator.requestSettlement()
            let revised = try await coordinator.reviseSettlement([
                .dialecticSynthesis: "我自己的归档句。",
                .minimumAction: "今晚只做一件最小的事。"
            ])
            let saved = try await repository.load(id: started.id)

            try expect(revised.heartSettlement?.headline == "我自己的归档句。")
            try expect(saved?.heartSettlement?.resolvedText(for: .minimumAction) == "今晚只做一件最小的事。")
        }

        try await runner.runAsync("file repository saves lists loads and deletes meetings") {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("parallel-me-ios-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let repository = FileMeetingRepository(directoryURL: directory)
            let state = try MeetingFlowEngine().start(rawInput: "我想换工作")

            try await repository.save(state)
            let loaded = try await repository.load(id: state.id)
            let listed = try await repository.list()
            try await repository.delete(id: state.id)
            let deleted = try await repository.load(id: state.id)

            try expect(loaded?.id == state.id)
            try expect(listed.map(\.id) == [state.id])
            try expect(deleted == nil)
        }

        try await runner.runAsync("any meeting repository delegates storage operations") {
            let repository = AnyMeetingRepository(InMemoryMeetingRepository())
            let state = try MeetingFlowEngine().start(rawInput: "我想换城市")

            try await repository.save(state)
            let loaded = try await repository.load(id: state.id)
            let listed = try await repository.list()
            try await repository.delete(id: state.id)
            let deleted = try await repository.load(id: state.id)

            try expect(loaded?.id == state.id)
            try expect(listed.map(\.id) == [state.id])
            try expect(deleted == nil)
        }

        try await runner.runAsync("session events record provider and persistence milestones") {
            let provider = MockLLMProvider()
            let repository = InMemoryMeetingRepository()
            let events = InMemoryMeetingSessionEventSink()
            await provider.register(
                IssueDefinitionResponse(proposal: completeProposal, readyToPropose: true),
                for: .defineIssue
            )
            let coordinator = MeetingSessionCoordinator(
                provider: provider,
                repository: repository,
                eventSink: events
            )

            _ = try await coordinator.start(rawInput: "我想辞职又怕没钱")
            _ = try await coordinator.requestDefinition()
            let kinds = await events.allEvents().map(\.kind)

            try expect(kinds.contains(.started))
            try expect(kinds.contains(.providerRequest))
            try expect(kinds.contains(.providerResponse))
            try expect(kinds.contains(.persisted))
        }

        try runner.run("session diagnostics snapshot summarizes recent failures") {
            let events = [
                MeetingSessionEvent(
                    id: "started",
                    kind: .started,
                    message: "started",
                    createdAt: Date(timeIntervalSince1970: 1)
                ),
                MeetingSessionEvent(
                    id: "request-1",
                    kind: .providerRequest,
                    message: "request definition",
                    createdAt: Date(timeIntervalSince1970: 2)
                ),
                MeetingSessionEvent(
                    id: "response-1",
                    kind: .providerResponse,
                    message: "response definition",
                    trace: ["mock:defineIssue"],
                    createdAt: Date(timeIntervalSince1970: 3)
                ),
                MeetingSessionEvent(
                    id: "persisted",
                    kind: .persisted,
                    message: "persisted",
                    createdAt: Date(timeIntervalSince1970: 4)
                ),
                MeetingSessionEvent(
                    id: "request-2",
                    kind: .providerRequest,
                    message: "request settlement",
                    createdAt: Date(timeIntervalSince1970: 5)
                ),
                MeetingSessionEvent(
                    id: "failed",
                    kind: .failed,
                    message: "模型服务返回 429",
                    trace: ["rate limited"],
                    createdAt: Date(timeIntervalSince1970: 6)
                )
            ]

            let snapshot = MeetingSessionDiagnosticsSnapshot(events: events, limit: 3)
            let pending = MeetingSessionDiagnosticsSnapshot(events: Array(events.prefix(5)), limit: 12)

            try expect(snapshot.totalCount == 6)
            try expect(snapshot.displayedCount == 3)
            try expect(snapshot.recentEvents.map(\.id) == ["persisted", "request-2", "failed"])
            try expect(snapshot.providerRequestCount == 2)
            try expect(snapshot.providerResponseCount == 1)
            try expect(snapshot.persistedCount == 1)
            try expect(snapshot.failureCount == 1)
            try expect(snapshot.latestFailure?.id == "failed")
            try expect(snapshot.pendingProviderResponseCount == 1)
            try expect(snapshot.title == "运行轨迹 · 1 次失败")
            try expect(snapshot.detail == "模型服务返回 429")
            try expect(pending.title == "运行轨迹 · 等待模型响应")
            try expect(pending.detail == "还有 1 个模型请求没有对应响应。")
            try expect(MeetingSessionDiagnosticsSnapshot().isEmpty)
        }

        try await runner.runAsync("demo provider drives a complete local meeting") {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("parallel-me-ios-demo-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let coordinator = MeetingSessionCoordinator(
                provider: DemoLLMProvider(),
                repository: FileMeetingRepository(directoryURL: directory)
            )

            _ = try await coordinator.start(rawInput: "我想辞职又怕没钱")
            let proposed = try await coordinator.requestDefinition()
            let opened = try await coordinator.confirmProposalAndOpenRoundtable()
            let moved = try await coordinator.submitRoundtableMove(RoundtableMove(type: .continueAll))
            let tableAsked = try await coordinator.submitRoundtableMove(
                RoundtableMove(type: .userToTable, userText: "你们都觉得我最不能牺牲什么？")
            )
            let voiceAsked = try await coordinator.submitRoundtableMove(
                RoundtableMove(type: .userToVoice, targetVoiceID: .money, userText: "我需要多少钱才算有退路？")
            )
            let dueled = try await coordinator.submitRoundtableMove(
                RoundtableMove(type: .duel, fromVoiceID: .money, toVoiceID: .lay)
            )
            let inquiry = try await coordinator.startInquiry()
            let question = try unwrap(inquiry.inquiryQuestions.first, "Expected demo inquiry question")
            let option = try unwrap(question.options.first, "Expected demo inquiry option")
            let ready = try await coordinator.submitInquiryAnswers([
                ScribeInquiryAnswer(
                    questionID: question.id,
                    question: question.question,
                    selectedOptionID: option.id,
                    selectedLabel: option.label
                )
            ])
            let settled = try await coordinator.requestSettlement()
            let archived = try await coordinator.archive()

            try expect(proposed.issueProposal?.isComplete == true)
            try expect(opened.roundtable.openingTurns.count == 5)
            try expect(!moved.roundtable.turns.isEmpty)
            try expect(tableAsked.roundtable.moves.last?.type == .userToTable)
            try expect(tableAsked.roundtable.turns.suffix(5).map(\.voiceID) == VoiceID.allCases)
            try expect(voiceAsked.roundtable.moves.last?.targetVoiceID == .money)
            try expect(voiceAsked.roundtable.turns.last?.voiceID == .money)
            try expect(dueled.roundtable.moves.last?.type == .duel)
            try expect(dueled.roundtable.turns.suffix(2).map(\.voiceID) == [.money, .lay])
            try expect(ready.alignmentProfile != nil)
            try expect(settled.stage == .settlement)
            try expect(archived.stage == .archived)
        }

        runner.finish()
    }

    private static var completeProposal: IssueProposal {
        IssueProposal(
            issueSentence: "要不要离开现在的工作",
            surfaceDilemma: IssueProposalKey(
                title: "选择岔路",
                content: "留在高薪但高压的工作，还是离开去恢复生活。",
                details: ["继续留在大厂", "先离开休整"]
            ),
            currentConstraints: IssueProposalKey(
                title: "现实边界",
                content: "当前收入覆盖生活，但身体余量已经明显下降。",
                details: ["月薪 2.5w", "睡眠变差"]
            ),
            coreFears: IssueProposalKey(
                title: "隐秘关切",
                content: "怕失去安全感，也怕继续下去失去自己。",
                details: ["安全感", "自我尊重"]
            ),
            expectedResolution: IssueProposalKey(
                title: "圆桌任务",
                content: "帮我确认什么代价不能碰，什么代价可以承受。",
                details: ["排出代价优先级"]
            )
        )
    }

    private static func opening(_ id: VoiceID) -> VoiceOpeningTurn {
        VoiceOpeningTurn(
            voiceID: id,
            payload: VoiceOpeningPayload(
                thesis: "这件事让你卡住。",
                protectedValue: "守住 \(id.displayName)",
                concern: "要承认代价。",
                taskEvidence: "来自议题。",
                pull: "先说清楚。"
            )
        )
    }

    private static func question(_ id: String, _ text: String, _ purpose: ProbePurpose) -> ScribeQuestion {
        ScribeQuestion(
            id: id,
            text: text,
            options: [
                ScribeProbeOption(id: "a", label: "第一个选项"),
                ScribeProbeOption(id: "b", label: "第二个选项"),
                ScribeProbeOption(id: "custom", label: "都不准，我自己说")
            ],
            purpose: purpose
        )
    }

    private static var completeProfile: AlignmentProfile {
        AlignmentProfile(
            falsifiedFantasy: "没有无代价的自由。",
            coreValueAxis: "用可持续的方式守住自由。",
            acceptedCosts: ["短期收入波动"],
            hegelianSynthesis: HegelianSynthesis(
                thesis: "我想离开高压工作。",
                antithesis: "我也需要现实退路。",
                synthesis: "先用一个月观察期换回判断力。"
            ),
            userSelfStatements: ["我可以接受慢一点，但不能继续耗空。"]
        )
    }

    private static var sampleSettlement: HeartSettlement {
        HeartSettlement(
            creativeHopelessness: SettlementModule(title: "无望", report: "没有无代价的自由。"),
            coreValueAxis: SettlementModule(title: "主轴", report: "守住可持续的自由。"),
            costAcceptanceContract: SettlementModule(title: "契约", report: "接受短期收入波动。"),
            minimumViableCommitment: SettlementModule(title: "行动", report: "今晚写出预算和观察期。"),
            dialecticSynthesis: DialecticSynthesis(
                thesis: "我想离开。",
                antithesis: "我需要退路。",
                synthesis: "先用一个月观察期换回判断力。"
            )
        )
    }
}

@MainActor
private struct Runner {
    private var passed = 0

    mutating func run(_ name: String, _ body: () throws -> Void) throws {
        do {
            try body()
            passed += 1
            print("PASS \(name)")
        } catch {
            print("FAIL \(name): \(error)")
            throw error
        }
    }

    func finish() {
        print("All \(passed) smoke tests passed.")
    }

    mutating func runAsync(_ name: String, _ body: @MainActor () async throws -> Void) async throws {
        do {
            try await body()
            passed += 1
            print("PASS \(name)")
        } catch {
            print("FAIL \(name): \(error)")
            throw error
        }
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    var description: String

    init(_ description: String) {
        self.description = description
    }
}

private func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String = "Expectation failed",
    file: StaticString = #fileID,
    line: UInt = #line
) throws {
    if !condition() {
        throw TestFailure("\(message) at \(file):\(line)")
    }
}

private func unwrap<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else { throw TestFailure(message) }
    return value
}

private func chatCompletionResponseData(content: String) throws -> Data {
    try JSONSerialization.data(
        withJSONObject: [
            "choices": [
                [
                    "message": [
                        "content": content
                    ]
                ]
            ]
        ],
        options: []
    )
}

@MainActor
private func waitFor(
    _ name: String,
    timeout: TimeInterval = 2,
    condition: @MainActor @escaping () -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() >= deadline {
            throw TestFailure("Timed out waiting for \(name)")
        }
        try await Task.sleep(nanoseconds: 20_000_000)
    }
}

private struct CapturedOpenAIRequest: Sendable {
    var urlString: String?
    var method: String?
    var timeout: TimeInterval
    var body: Data?
    var authorization: String?
    var contentType: String?
}

private actor MockOpenAITransport: OpenAICompatibleTransport {
    private let statusCode: Int
    private let responseData: Data
    private var capturedRequest: CapturedOpenAIRequest?

    init(statusCode: Int, responseData: Data) {
        self.statusCode = statusCode
        self.responseData = responseData
    }

    func latestRequest() -> CapturedOpenAIRequest? {
        capturedRequest
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        capturedRequest = CapturedOpenAIRequest(
            urlString: request.url?.absoluteString,
            method: request.httpMethod,
            timeout: request.timeoutInterval,
            body: request.httpBody,
            authorization: request.value(forHTTPHeaderField: "Authorization"),
            contentType: request.value(forHTTPHeaderField: "Content-Type")
        )
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://mock.parallelme.local")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (responseData, response)
    }
}

private actor FlakyDefinitionProvider: LLMProvider {
    private let success: IssueDefinitionResponse
    private var remainingFailures: Int
    private var requests = 0

    init(success: IssueDefinitionResponse, failures: Int = 1) {
        self.success = success
        self.remainingFailures = failures
    }

    func definitionRequestCount() -> Int {
        requests
    }

    func generate<RequestPayload, ResponsePayload>(
        request: LLMRequest<RequestPayload>,
        responseType: ResponsePayload.Type
    ) async throws -> LLMEnvelope<ResponsePayload>
    where RequestPayload: Codable & Sendable, ResponsePayload: Codable & Sendable {
        guard request.kind == .defineIssue else {
            throw MockLLMProviderError.missingResponse(kind: request.kind)
        }
        requests += 1
        if remainingFailures > 0 {
            remainingFailures -= 1
            throw MockLLMProviderError.missingResponse(kind: request.kind)
        }
        guard let payload = success as? ResponsePayload else {
            throw MockLLMProviderError.missingResponse(kind: request.kind)
        }
        return LLMEnvelope(payload: payload, trace: ["flaky:\(request.kind.rawValue)"])
    }
}

private actor FlakyInquiryProvider: LLMProvider {
    private let success: AlignmentInquiryResponse
    private var remainingFailures: Int
    private var requests = 0

    init(success: AlignmentInquiryResponse, failures: Int = 1) {
        self.success = success
        self.remainingFailures = failures
    }

    func inquiryRequestCount() -> Int {
        requests
    }

    func generate<RequestPayload, ResponsePayload>(
        request: LLMRequest<RequestPayload>,
        responseType: ResponsePayload.Type
    ) async throws -> LLMEnvelope<ResponsePayload>
    where RequestPayload: Codable & Sendable, ResponsePayload: Codable & Sendable {
        guard request.kind == .alignmentInquiry else {
            throw MockLLMProviderError.missingResponse(kind: request.kind)
        }
        requests += 1
        if remainingFailures > 0 {
            remainingFailures -= 1
            throw MockLLMProviderError.missingResponse(kind: request.kind)
        }
        guard let payload = success as? ResponsePayload else {
            throw MockLLMProviderError.missingResponse(kind: request.kind)
        }
        return LLMEnvelope(payload: payload, trace: ["flaky:\(request.kind.rawValue)"])
    }
}

private actor ContextRecordingProvider: LLMProvider {
    private let definitionResponse: IssueDefinitionResponse
    private var recordedDefinitionInput: IssueDefinitionInput?

    init(definitionResponse: IssueDefinitionResponse) {
        self.definitionResponse = definitionResponse
    }

    func latestDefinitionInput() -> IssueDefinitionInput? {
        recordedDefinitionInput
    }

    func generate<RequestPayload, ResponsePayload>(
        request: LLMRequest<RequestPayload>,
        responseType: ResponsePayload.Type
    ) async throws -> LLMEnvelope<ResponsePayload>
    where RequestPayload: Codable & Sendable, ResponsePayload: Codable & Sendable {
        guard request.kind == .defineIssue,
              let input = request.payload as? IssueDefinitionInput,
              let payload = definitionResponse as? ResponsePayload else {
            throw MockLLMProviderError.missingResponse(kind: request.kind)
        }
        recordedDefinitionInput = input
        return LLMEnvelope(payload: payload, trace: ["recording:\(request.kind.rawValue)"])
    }
}

private actor ViewModelRuntimeRecordingProvider: LLMProvider {
    private var recordedOpeningInput: RoundtableOpeningInput?

    func latestOpeningInput() -> RoundtableOpeningInput? {
        recordedOpeningInput
    }

    func generate<RequestPayload, ResponsePayload>(
        request: LLMRequest<RequestPayload>,
        responseType: ResponsePayload.Type
    ) async throws -> LLMEnvelope<ResponsePayload>
    where RequestPayload: Codable & Sendable, ResponsePayload: Codable & Sendable {
        guard request.kind == .openRoundtable,
              let input = request.payload as? RoundtableOpeningInput,
              let payload = RoundtableOpeningResponse(
                openings: VoiceID.allCases.map { opening($0) }
              ) as? ResponsePayload else {
            throw MockLLMProviderError.missingResponse(kind: request.kind)
        }
        recordedOpeningInput = input
        return LLMEnvelope(payload: payload, trace: ["recording:\(request.kind.rawValue)"])
    }

    private func opening(_ id: VoiceID) -> VoiceOpeningTurn {
        VoiceOpeningTurn(
            voiceID: id,
            payload: VoiceOpeningPayload(
                thesis: "这件事让你卡住。",
                protectedValue: "守住 \(id.displayName)",
                concern: "要承认代价。",
                taskEvidence: "来自议题。",
                pull: "先说清楚。"
            )
        )
    }
}

private actor SlowProviderSettingsStore: ProviderSettingsStoring {
    private var settings: ProviderRuntimeSettings
    private let delayNanoseconds: UInt64

    init(
        settings: ProviderRuntimeSettings = ProviderRuntimeSettings(),
        delayNanoseconds: UInt64
    ) {
        self.settings = settings
        self.delayNanoseconds = delayNanoseconds
    }

    func loadSettings() async throws -> ProviderRuntimeSettings {
        settings
    }

    func saveSettings(_ settings: ProviderRuntimeSettings) async throws {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        self.settings = settings
    }

    func clearSettings() async throws {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        settings = ProviderRuntimeSettings()
    }
}

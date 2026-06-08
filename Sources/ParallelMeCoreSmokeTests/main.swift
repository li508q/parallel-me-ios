import Foundation
import ParallelMeCore

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
            let inquiry = try engine.startInquiry(in: opened)
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

        try runner.run("settlement revisions override resolved text and headline") {
            var settlement = sampleSettlement
            settlement.revise(moduleID: .coreValues, text: "我要守住自己写下的主轴。")
            settlement.revise(moduleID: .dialecticSynthesis, text: "这是我自己认领的正反合。")

            try expect(settlement.resolvedText(for: .coreValues) == "我要守住自己写下的主轴。")
            try expect(settlement.headline == "这是我自己认领的正反合。")
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

private func expect(_ condition: @autoclosure () -> Bool) throws {
    if !condition() {
        throw TestFailure("Expectation failed")
    }
}

private func unwrap<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else { throw TestFailure(message) }
    return value
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

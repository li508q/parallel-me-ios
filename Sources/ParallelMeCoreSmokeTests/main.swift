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

        try await runner.runAsync("provider factory creates demo provider") {
            let provider = try ProviderRuntimeFactory.makeProvider(settings: ProviderRuntimeSettings(mode: .demo))
            let envelope = try await provider.generate(
                request: LLMRequest(
                    kind: .defineIssue,
                    payload: IssueDefinitionInput(rawInput: "我想辞职又怕没钱", dialogue: [])
                ),
                responseType: IssueDefinitionResponse.self
            )
            try expect(envelope.payload.proposal?.isComplete == true)
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

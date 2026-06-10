import Foundation

public enum MeetingSessionError: Error, Equatable, Sendable {
    case noActiveMeeting
    case missingProposal
    case missingTaskFrame
    case emptyFeedback
    case emptyModelResult
    case settlementNotReady(missing: [SettlementModuleID])
}

public actor MeetingSessionCoordinator<Provider: LLMProvider, Repository: MeetingRepository>: MeetingCoordinating {
    private let provider: Provider
    private let repository: Repository
    private let engine: MeetingFlowEngine
    private let deduplicator: ScribeQuestionDeduplicator
    private let definitionResponseGuard: IssueDefinitionResponseGuard
    private let readinessEvaluator: SettlementReadinessEvaluator
    private let inquiryResponseGuard: AlignmentInquiryResponseGuard
    private let eventSink: any MeetingSessionEventSink
    private let runtimeSnapshot: MeetingRuntimeSnapshot?
    private var state: MeetingFlowState?
    private var context: ProviderContext?

    public init(
        provider: Provider,
        repository: Repository,
        engine: MeetingFlowEngine = MeetingFlowEngine(),
        deduplicator: ScribeQuestionDeduplicator = ScribeQuestionDeduplicator(),
        readinessEvaluator: SettlementReadinessEvaluator = SettlementReadinessEvaluator(),
        eventSink: any MeetingSessionEventSink = NoopMeetingSessionEventSink(),
        context: ProviderContext? = nil,
        runtimeSnapshot: MeetingRuntimeSnapshot? = nil
    ) {
        self.provider = provider
        self.repository = repository
        self.engine = engine
        self.deduplicator = deduplicator
        self.definitionResponseGuard = IssueDefinitionResponseGuard()
        self.readinessEvaluator = readinessEvaluator
        self.inquiryResponseGuard = AlignmentInquiryResponseGuard(readinessEvaluator: readinessEvaluator)
        self.eventSink = eventSink
        let snapshotContext = runtimeSnapshot?.normalized.context
        let explicitContext = context?.normalized
        let effectiveContext = explicitContext?.isEmpty == false ? explicitContext : snapshotContext
        self.context = effectiveContext?.isEmpty == true ? nil : effectiveContext
        var snapshot = runtimeSnapshot?.normalized
        if let context = self.context, snapshot != nil {
            snapshot?.context = context
        }
        self.runtimeSnapshot = snapshot?.normalized
    }

    public func currentState() async -> MeetingFlowState? {
        state
    }

    public func restore(_ restored: MeetingFlowState) async throws -> MeetingFlowState {
        state = restored
        return try await persist(restored)
    }

    public func start(rawInput: String) async throws -> MeetingFlowState {
        let started = try engine.start(rawInput: rawInput, runtimeSnapshot: runtimeSnapshot)
        state = started
        await emit(.started, meetingID: started.id, message: "Meeting started")
        return try await persist(started)
    }

    public func requestDefinition() async throws -> MeetingFlowState {
        let current = try requireState()
        let input = IssueDefinitionInput(
            rawInput: current.rawInput,
            dialogue: current.definingDialogue,
            context: context
        )
        return try await requestDefinitionWithHarness(
            input: input,
            current: current,
            requestMessage: "Requesting issue definition",
            responseMessage: "Received issue definition"
        )
    }

    public func submitProbeAnswers(_ answers: [ScribeAnswer]) async throws -> MeetingFlowState {
        let answered = try engine.answerProbe(answers, in: try requireState())
        state = try await persist(answered)
        return try await requestDefinition()
    }

    public func refineProposal(feedback: String) async throws -> MeetingFlowState {
        let current = try requireState()
        let trimmedFeedback = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFeedback.isEmpty else { throw MeetingSessionError.emptyFeedback }

        var feedbackState = current
        feedbackState.definingDialogue.append(
            DefiningDialogueEntry(
                role: .user,
                answer: ScribeAnswer(
                    questionID: "proposal_feedback",
                    selectedOptionID: nil,
                    selectedOptionLabel: nil,
                    questionText: "你想让书记员如何修订这版议题？",
                    freeText: trimmedFeedback
                )
            )
        )
        state = try await persist(feedbackState)

        let input = IssueDefinitionInput(
            rawInput: feedbackState.rawInput,
            dialogue: feedbackState.definingDialogue,
            currentProposal: feedbackState.issueProposal,
            userFeedback: trimmedFeedback,
            context: context
        )
        return try await requestDefinitionWithHarness(
            input: input,
            current: feedbackState,
            requestMessage: "Refining issue proposal",
            responseMessage: "Received refined definition"
        )
    }

    public func confirmProposalAndOpenRoundtable() async throws -> MeetingFlowState {
        let confirmed = try engine.confirmProposal(in: try requireState())
        guard let taskFrame = confirmed.taskFrame else { throw MeetingSessionError.missingTaskFrame }
        guard let proposal = confirmed.issueProposal else { throw MeetingSessionError.missingProposal }

        await emit(.providerRequest, meetingID: confirmed.id, message: "Requesting roundtable openings")
        let envelope = try await provider.generate(
            request: LLMRequest(
                kind: .openRoundtable,
                payload: RoundtableOpeningInput(taskFrame: taskFrame, proposal: proposal, context: context)
            ),
            responseType: RoundtableOpeningResponse.self
        )
        await emit(.providerResponse, meetingID: confirmed.id, message: "Received roundtable openings", trace: envelope.trace)
        let opened = try engine.receiveOpenings(envelope.payload.openings, in: confirmed)
        state = opened
        return try await persist(opened)
    }

    public func submitRoundtableMove(_ move: RoundtableMove) async throws -> MeetingFlowState {
        let current = try requireState()
        guard let taskFrame = current.taskFrame else { throw MeetingSessionError.missingTaskFrame }
        guard let proposal = current.issueProposal else { throw MeetingSessionError.missingProposal }

        await emit(.providerRequest, meetingID: current.id, message: "Submitting roundtable move")
        let envelope = try await provider.generate(
            request: LLMRequest(
                kind: .continueRoundtable,
                payload: RoundtableMoveInput(
                    taskFrame: taskFrame,
                    proposal: proposal,
                    roundtable: current.roundtable,
                    move: move,
                    context: context
                )
            ),
            responseType: RoundtableMoveResponse.self
        )
        await emit(.providerResponse, meetingID: current.id, message: "Received roundtable move", trace: envelope.trace)

        var next = try engine.appendRoundtableMove(move, turns: envelope.payload.turns, in: current)
        if let ledger = envelope.payload.ledger {
            next.scribeObservationLedger = ledger
        }
        state = next
        return try await persist(next)
    }

    public func startInquiry() async throws -> MeetingFlowState {
        let inquiry = try engine.startInquiry(in: try requireState())
        state = try await persist(inquiry)
        return try await requestNextInquiry()
    }

    public func submitInquiryAnswers(_ answers: [ScribeInquiryAnswer]) async throws -> MeetingFlowState {
        let answered = try engine.answerInquiry(answers, in: try requireState())
        state = try await persist(answered)
        return try await requestNextInquiry()
    }

    public func requestNextInquiry() async throws -> MeetingFlowState {
        let current = try requireState()
        guard let taskFrame = current.taskFrame else { throw MeetingSessionError.missingTaskFrame }
        guard let proposal = current.issueProposal else { throw MeetingSessionError.missingProposal }

        let input = AlignmentInquiryInput(
            taskFrame: taskFrame,
            proposal: proposal,
            roundtable: current.roundtable,
            ledger: current.scribeObservationLedger,
            questions: current.inquiryQuestions,
            answers: current.inquiryAnswers,
            context: context
        )
        return try await requestInquiryWithHarness(input: input, current: current)
    }

    public func requestSettlement() async throws -> MeetingFlowState {
        let current = try requireState()
        guard let taskFrame = current.taskFrame else { throw MeetingSessionError.missingTaskFrame }
        guard let proposal = current.issueProposal else { throw MeetingSessionError.missingProposal }
        guard let profile = current.alignmentProfile else { throw MeetingFlowError.missingAlignmentProfile }

        let readiness = readinessEvaluator.evaluate(
            profile: profile,
            ledger: current.scribeObservationLedger,
            answers: current.inquiryAnswers
        )
        guard readiness.isReady else {
            throw MeetingSessionError.settlementNotReady(missing: readiness.missingModules)
        }

        await emit(.providerRequest, meetingID: current.id, message: "Requesting heart settlement")
        let envelope = try await provider.generate(
            request: LLMRequest(
                kind: .heartSettlement,
                payload: HeartSettlementInput(
                    taskFrame: taskFrame,
                    proposal: proposal,
                    ledger: current.scribeObservationLedger,
                    answers: current.inquiryAnswers,
                    profile: profile,
                    context: context
                )
            ),
            responseType: HeartSettlementResponse.self
        )
        await emit(.providerResponse, meetingID: current.id, message: "Received heart settlement", trace: envelope.trace)
        let settled = try engine.settle(envelope.payload.settlement, profile: profile, in: current)
        state = settled
        return try await persist(settled)
    }

    public func archive() async throws -> MeetingFlowState {
        let archived = try engine.archive(state: try requireState())
        state = archived
        return try await persist(archived)
    }

    public func reviseSettlement(_ revisions: [SettlementModuleID: String]) async throws -> MeetingFlowState {
        let revised = try engine.reviseSettlement(revisions, in: try requireState())
        state = revised
        return try await persist(revised)
    }

    private func requestDefinitionWithHarness(
        input: IssueDefinitionInput,
        current: MeetingFlowState,
        requestMessage: String,
        responseMessage: String
    ) async throws -> MeetingFlowState {
        var input = input
        var failures: [String] = []

        for attempt in 1...3 {
            if attempt > 1 {
                input.harnessFeedback = LLMHarnessFeedback(
                    attempt: attempt,
                    previousFailures: failures,
                    instruction: "请重新生成阶段一定义结果。若本地证据不足，必须返回 1-3 个真实追问；不要返回模板题或空 questions。"
                )
            }
            await emit(.providerRequest, meetingID: current.id, message: "\(requestMessage) (attempt \(attempt))")
            let envelope = try await provider.generate(
                request: LLMRequest(kind: .defineIssue, payload: input),
                responseType: IssueDefinitionResponse.self
            )
            await emit(.providerResponse, meetingID: current.id, message: "\(responseMessage) (attempt \(attempt))", trace: envelope.trace)

            switch definitionOutcome(for: envelope.payload, current: current) {
            case .proposal(let proposal):
                let proposed = try engine.receiveIssueProposal(proposal, in: current)
                state = proposed
                return try await persist(proposed)
            case .questions(let questions):
                let probing = try engine.receiveProbeQuestions(questions, in: current)
                state = probing
                return try await persist(probing)
            case .retry(let reasons):
                failures = reasons
            }
        }

        throw MeetingSessionError.emptyModelResult
    }

    private func requestInquiryWithHarness(
        input: AlignmentInquiryInput,
        current: MeetingFlowState
    ) async throws -> MeetingFlowState {
        var input = input
        var failures: [String] = []

        for attempt in 1...3 {
            if attempt > 1 {
                input.harnessFeedback = LLMHarnessFeedback(
                    attempt: attempt,
                    previousFailures: failures,
                    instruction: "请重新生成最终问询结果。证据不足时必须返回 1-3 个真实问询；证据充足时 questions 必须为空且 profile 必须完整。"
                )
            }
            await emit(.providerRequest, meetingID: current.id, message: "Requesting alignment inquiry (attempt \(attempt))")
            let envelope = try await provider.generate(
                request: LLMRequest(kind: .alignmentInquiry, payload: input),
                responseType: AlignmentInquiryResponse.self
            )
            await emit(.providerResponse, meetingID: current.id, message: "Received alignment inquiry (attempt \(attempt))", trace: envelope.trace)

            switch inquiryOutcome(for: envelope.payload, current: current) {
            case .ready(let response):
                let next = try engine.receiveInquiryQuestions(
                    response.questions,
                    profile: response.profile,
                    ledger: response.ledger,
                    readyForSettlement: response.readyForSettlement,
                    in: current
                )
                state = next
                return try await persist(next)
            case .retry(let reasons):
                failures = reasons
            }
        }

        throw MeetingSessionError.emptyModelResult
    }

    private enum DefinitionOutcome {
        case proposal(IssueProposal)
        case questions([ScribeQuestion])
        case retry([String])
    }

    private enum InquiryOutcome {
        case ready(AlignmentInquiryResponse)
        case retry([String])
    }

    private func definitionOutcome(
        for response: IssueDefinitionResponse,
        current: MeetingFlowState
    ) -> DefinitionOutcome {
        let response = definitionResponseGuard.normalize(response)
        let mustKeepProbing = response.readyToPropose &&
            deduplicator.shouldForceProbe(rawInput: current.rawInput, history: current.definingDialogue)

        if response.readyToPropose, !mustKeepProbing, let proposal = response.proposal, proposal.isComplete {
            return .proposal(proposal)
        }

        let questions = deduplicator.normalize(response.questions, history: current.definingDialogue)
        if !questions.isEmpty {
            return .questions(questions)
        }

        var reasons: [String] = []
        if mustKeepProbing {
            let missing = deduplicator
                .coverage(rawInput: current.rawInput, history: current.definingDialogue)
                .missingPurposes
                .map(\.rawValue)
                .joined(separator: ", ")
            reasons.append("本地证据仍不足，不能进入议题确认；缺口：\(missing.isEmpty ? "用户回答和边界证据不足" : missing)")
        } else if response.readyToPropose {
            reasons.append("readyToPropose=true 但 proposal 不完整，或同时返回了未解决问题")
        } else {
            reasons.append("模型认为信息不足，但没有返回可展示的非重复问题")
        }
        return .retry(reasons)
    }

    private func inquiryOutcome(
        for response: AlignmentInquiryResponse,
        current: MeetingFlowState
    ) -> InquiryOutcome {
        let response = inquiryResponseGuard.normalize(
            response,
            existingQuestions: current.inquiryQuestions,
            existingAnswers: current.inquiryAnswers
        )
        let readiness = readinessEvaluator.evaluate(
            profile: response.profile ?? AlignmentProfile(),
            ledger: response.ledger,
            answers: current.inquiryAnswers
        )

        if response.readyForSettlement {
            return .ready(response)
        }
        if !response.questions.isEmpty {
            return .ready(response)
        }

        let missing = readiness.missingModules.map(\.rawValue).joined(separator: ", ")
        return .retry([
            "最终问询证据仍不足，缺口：\(missing.isEmpty ? "settlement profile 或用户证据不足" : missing)，但模型没有返回可展示的非重复问询"
        ])
    }

    private func requireState() throws -> MeetingFlowState {
        guard let state else { throw MeetingSessionError.noActiveMeeting }
        return state
    }

    private func persist(_ state: MeetingFlowState) async throws -> MeetingFlowState {
        try await repository.save(state)
        await emit(.persisted, meetingID: state.id, message: "State persisted at \(state.stage.rawValue)")
        return state
    }

    private func emit(
        _ kind: MeetingSessionEventKind,
        meetingID: String?,
        message: String,
        trace: [String] = []
    ) async {
        await eventSink.record(
            MeetingSessionEvent(
                meetingID: meetingID,
                kind: kind,
                message: message,
                trace: trace
            )
        )
    }
}

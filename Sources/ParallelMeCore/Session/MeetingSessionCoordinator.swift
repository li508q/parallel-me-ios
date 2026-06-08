import Foundation

public enum MeetingSessionError: Error, Equatable, Sendable {
    case noActiveMeeting
    case missingProposal
    case missingTaskFrame
    case emptyModelResult
    case settlementNotReady(missing: [SettlementModuleID])
}

public actor MeetingSessionCoordinator<Provider: LLMProvider, Repository: MeetingRepository> {
    private let provider: Provider
    private let repository: Repository
    private let engine: MeetingFlowEngine
    private let deduplicator: ScribeQuestionDeduplicator
    private let readinessEvaluator: SettlementReadinessEvaluator
    private var state: MeetingFlowState?
    private var context: ProviderContext?

    public init(
        provider: Provider,
        repository: Repository,
        engine: MeetingFlowEngine = MeetingFlowEngine(),
        deduplicator: ScribeQuestionDeduplicator = ScribeQuestionDeduplicator(),
        readinessEvaluator: SettlementReadinessEvaluator = SettlementReadinessEvaluator(),
        context: ProviderContext? = nil
    ) {
        self.provider = provider
        self.repository = repository
        self.engine = engine
        self.deduplicator = deduplicator
        self.readinessEvaluator = readinessEvaluator
        self.context = context
    }

    public func currentState() -> MeetingFlowState? {
        state
    }

    public func restore(_ restored: MeetingFlowState) async throws -> MeetingFlowState {
        state = restored
        return try await persist(restored)
    }

    public func start(rawInput: String) async throws -> MeetingFlowState {
        let started = try engine.start(rawInput: rawInput)
        state = started
        return try await persist(started)
    }

    public func requestDefinition() async throws -> MeetingFlowState {
        let current = try requireState()
        let input = IssueDefinitionInput(
            rawInput: current.rawInput,
            dialogue: current.definingDialogue,
            context: context
        )
        let envelope = try await provider.generate(
            request: LLMRequest(kind: .defineIssue, payload: input),
            responseType: IssueDefinitionResponse.self
        )
        return try await applyDefinition(envelope.payload, to: current)
    }

    public func submitProbeAnswers(_ answers: [ScribeAnswer]) async throws -> MeetingFlowState {
        let answered = try engine.answerProbe(answers, in: try requireState())
        state = try await persist(answered)
        return try await requestDefinition()
    }

    public func refineProposal(feedback: String) async throws -> MeetingFlowState {
        let current = try requireState()
        let input = IssueDefinitionInput(
            rawInput: current.rawInput,
            dialogue: current.definingDialogue,
            currentProposal: current.issueProposal,
            userFeedback: feedback,
            context: context
        )
        let envelope = try await provider.generate(
            request: LLMRequest(kind: .defineIssue, payload: input),
            responseType: IssueDefinitionResponse.self
        )
        return try await applyDefinition(envelope.payload, to: current)
    }

    public func confirmProposalAndOpenRoundtable() async throws -> MeetingFlowState {
        let confirmed = try engine.confirmProposal(in: try requireState())
        guard let taskFrame = confirmed.taskFrame else { throw MeetingSessionError.missingTaskFrame }
        guard let proposal = confirmed.issueProposal else { throw MeetingSessionError.missingProposal }

        let envelope = try await provider.generate(
            request: LLMRequest(
                kind: .openRoundtable,
                payload: RoundtableOpeningInput(taskFrame: taskFrame, proposal: proposal, context: context)
            ),
            responseType: RoundtableOpeningResponse.self
        )
        let opened = try engine.receiveOpenings(envelope.payload.openings, in: confirmed)
        state = opened
        return try await persist(opened)
    }

    public func submitRoundtableMove(_ move: RoundtableMove) async throws -> MeetingFlowState {
        let current = try requireState()
        guard let taskFrame = current.taskFrame else { throw MeetingSessionError.missingTaskFrame }
        guard let proposal = current.issueProposal else { throw MeetingSessionError.missingProposal }

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

        let envelope = try await provider.generate(
            request: LLMRequest(
                kind: .alignmentInquiry,
                payload: AlignmentInquiryInput(
                    taskFrame: taskFrame,
                    proposal: proposal,
                    roundtable: current.roundtable,
                    ledger: current.scribeObservationLedger,
                    questions: current.inquiryQuestions,
                    answers: current.inquiryAnswers,
                    context: context
                )
            ),
            responseType: AlignmentInquiryResponse.self
        )
        let response = envelope.payload
        let next = try engine.receiveInquiryQuestions(
            response.questions,
            profile: response.profile,
            ledger: response.ledger,
            readyForSettlement: response.readyForSettlement,
            in: current
        )
        state = next
        return try await persist(next)
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
        let settled = try engine.settle(envelope.payload.settlement, profile: profile, in: current)
        state = settled
        return try await persist(settled)
    }

    private func applyDefinition(
        _ response: IssueDefinitionResponse,
        to current: MeetingFlowState
    ) async throws -> MeetingFlowState {
        if let proposal = response.proposal, proposal.isComplete {
            let proposed = try engine.receiveIssueProposal(proposal, in: current)
            state = proposed
            return try await persist(proposed)
        }

        let normalized = deduplicator.normalize(response.questions, history: current.definingDialogue)
        guard !normalized.isEmpty else {
            if response.readyToPropose {
                throw MeetingSessionError.emptyModelResult
            }
            throw MeetingSessionError.emptyModelResult
        }
        let probing = try engine.receiveProbeQuestions(normalized, in: current)
        state = probing
        return try await persist(probing)
    }

    private func requireState() throws -> MeetingFlowState {
        guard let state else { throw MeetingSessionError.noActiveMeeting }
        return state
    }

    private func persist(_ state: MeetingFlowState) async throws -> MeetingFlowState {
        try await repository.save(state)
        return state
    }
}


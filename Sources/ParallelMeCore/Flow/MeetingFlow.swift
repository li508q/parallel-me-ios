import Foundation

public enum MeetingStage: String, Codable, Sendable, CaseIterable {
    case defining
    case roundtable
    case inquiry
    case settlement
    case archived
}

public enum DefiningSubstage: String, Codable, Sendable {
    case probing
    case showingProposal
}

public enum MeetingFlowError: Error, Equatable, Sendable {
    case emptyPetition
    case illegalStage(expected: MeetingStage, actual: MeetingStage)
    case incompleteProposal(missing: [ProbePurpose])
    case missingTaskFrame
    case missingRoundtableOpenings
    case missingAlignmentProfile
}

public struct MeetingFlowState: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var createdAt: Date
    public var stage: MeetingStage
    public var rawInput: String
    public var definingSubstage: DefiningSubstage
    public var definingDialogue: [DefiningDialogueEntry]
    public var currentQuestions: [ScribeQuestion]
    public var issueProposal: IssueProposal?
    public var taskFrame: TaskFrame?
    public var roundtable: RoundtableRecord
    public var inquiryQuestions: [ScribeInquiryQuestion]
    public var inquiryAnswers: [ScribeInquiryAnswer]
    public var alignmentProfile: AlignmentProfile?
    public var scribeObservationLedger: ScribeObservationLedger
    public var heartSettlement: HeartSettlement?

    public init(
        id: String = UUID().uuidString,
        createdAt: Date = Date(),
        rawInput: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.stage = .defining
        self.rawInput = rawInput
        self.definingSubstage = .probing
        self.definingDialogue = []
        self.currentQuestions = []
        self.issueProposal = nil
        self.taskFrame = nil
        self.roundtable = RoundtableRecord()
        self.inquiryQuestions = []
        self.inquiryAnswers = []
        self.alignmentProfile = nil
        self.scribeObservationLedger = ScribeObservationLedger()
        self.heartSettlement = nil
    }
}

public struct MeetingFlowEngine: Sendable {
    public init() {}

    public func start(rawInput: String) throws -> MeetingFlowState {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MeetingFlowError.emptyPetition }
        return MeetingFlowState(rawInput: trimmed)
    }

    public func receiveProbeQuestions(
        _ questions: [ScribeQuestion],
        in state: MeetingFlowState
    ) throws -> MeetingFlowState {
        try require(.defining, state)
        var next = state
        next.currentQuestions = questions
        next.definingSubstage = .probing
        return next
    }

    public func answerProbe(
        _ answers: [ScribeAnswer],
        in state: MeetingFlowState
    ) throws -> MeetingFlowState {
        try require(.defining, state)
        var next = state
        let questionEntries = state.currentQuestions.map {
            DefiningDialogueEntry(role: .scribe, question: $0)
        }
        let answerEntries = answers.map {
            DefiningDialogueEntry(role: .user, answer: $0)
        }
        next.definingDialogue.append(contentsOf: questionEntries + answerEntries)
        next.currentQuestions = []
        next.definingSubstage = .probing
        return next
    }

    public func receiveIssueProposal(
        _ proposal: IssueProposal,
        in state: MeetingFlowState
    ) throws -> MeetingFlowState {
        try require(.defining, state)
        guard proposal.isComplete else {
            throw MeetingFlowError.incompleteProposal(missing: proposal.missingPurposes)
        }
        var next = state
        next.issueProposal = proposal
        next.taskFrame = IssueProposalMapper.taskFrame(from: proposal)
        next.currentQuestions = []
        next.definingSubstage = .showingProposal
        return next
    }

    public func confirmProposal(in state: MeetingFlowState) throws -> MeetingFlowState {
        try require(.defining, state)
        guard let proposal = state.issueProposal, proposal.isComplete else {
            throw MeetingFlowError.incompleteProposal(missing: state.issueProposal?.missingPurposes ?? ProbePurpose.allCases)
        }
        guard state.taskFrame != nil else { throw MeetingFlowError.missingTaskFrame }
        var next = state
        next.stage = .roundtable
        return next
    }

    public func receiveOpenings(
        _ openings: [VoiceOpeningTurn],
        in state: MeetingFlowState
    ) throws -> MeetingFlowState {
        try require(.roundtable, state)
        var next = state
        next.roundtable.openingTurns = VoiceID.allCases.compactMap { id in
            openings.first(where: { $0.voiceID == id })
        }
        return next
    }

    public func appendRoundtableMove(
        _ move: RoundtableMove,
        turns: [RoundtableTurn],
        in state: MeetingFlowState
    ) throws -> MeetingFlowState {
        try require(.roundtable, state)
        guard !state.roundtable.openingTurns.isEmpty else {
            throw MeetingFlowError.missingRoundtableOpenings
        }
        var next = state
        next.roundtable.moves.append(move)
        next.roundtable.turns.append(contentsOf: turns.map { turn in
            var tagged = turn
            if tagged.moveID == nil { tagged.moveID = move.id }
            return tagged
        })
        return next
    }

    public func startInquiry(in state: MeetingFlowState) throws -> MeetingFlowState {
        try require(.roundtable, state)
        guard !state.roundtable.openingTurns.isEmpty else {
            throw MeetingFlowError.missingRoundtableOpenings
        }
        var next = state
        next.stage = .inquiry
        next.inquiryQuestions = []
        next.inquiryAnswers = []
        return next
    }

    public func receiveInquiryQuestions(
        _ questions: [ScribeInquiryQuestion],
        profile: AlignmentProfile?,
        ledger: ScribeObservationLedger,
        readyForSettlement: Bool,
        in state: MeetingFlowState
    ) throws -> MeetingFlowState {
        try require(.inquiry, state)
        var next = state
        next.scribeObservationLedger = ledger
        next.alignmentProfile = profile

        if readyForSettlement {
            guard profile != nil else { throw MeetingFlowError.missingAlignmentProfile }
            next.inquiryQuestions = state.inquiryQuestions
            return next
        }

        let known = Set(state.inquiryQuestions.map(\.id))
        let fresh = questions.filter { !known.contains($0.id) }
        next.inquiryQuestions.append(contentsOf: fresh)
        return next
    }

    public func answerInquiry(
        _ answers: [ScribeInquiryAnswer],
        in state: MeetingFlowState
    ) throws -> MeetingFlowState {
        try require(.inquiry, state)
        var next = state
        let incomingIDs = Set(answers.map(\.questionID))
        next.inquiryAnswers.removeAll { incomingIDs.contains($0.questionID) }
        next.inquiryAnswers.append(contentsOf: answers)
        return next
    }

    public func settle(
        _ settlement: HeartSettlement,
        profile: AlignmentProfile,
        in state: MeetingFlowState
    ) throws -> MeetingFlowState {
        try require(.inquiry, state)
        var next = state
        next.alignmentProfile = profile
        next.heartSettlement = settlement
        next.stage = .settlement
        return next
    }

    public func archive(state: MeetingFlowState) throws -> MeetingFlowState {
        try require(.settlement, state)
        var next = state
        next.stage = .archived
        return next
    }

    private func require(_ expected: MeetingStage, _ state: MeetingFlowState) throws {
        guard state.stage == expected else {
            throw MeetingFlowError.illegalStage(expected: expected, actual: state.stage)
        }
    }
}


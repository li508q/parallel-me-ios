import Foundation

public struct ProviderContext: Codable, Equatable, Sendable {
    public var meCard: String?
    public var tasteProfile: String?

    public init(meCard: String? = nil, tasteProfile: String? = nil) {
        self.meCard = meCard
        self.tasteProfile = tasteProfile
    }

    public var normalized: ProviderContext {
        ProviderContext(
            meCard: meCard?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyProviderContextText,
            tasteProfile: tasteProfile?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyProviderContextText
        )
    }

    public var isEmpty: Bool {
        normalized.meCard == nil && normalized.tasteProfile == nil
    }
}

private extension String {
    var nonEmptyProviderContextText: String? {
        isEmpty ? nil : self
    }
}

public struct IssueDefinitionInput: Codable, Equatable, Sendable {
    public var rawInput: String
    public var dialogue: [DefiningDialogueEntry]
    public var currentProposal: IssueProposal?
    public var userFeedback: String?
    public var harnessFeedback: LLMHarnessFeedback?
    public var context: ProviderContext?

    public init(
        rawInput: String,
        dialogue: [DefiningDialogueEntry],
        currentProposal: IssueProposal? = nil,
        userFeedback: String? = nil,
        harnessFeedback: LLMHarnessFeedback? = nil,
        context: ProviderContext? = nil
    ) {
        self.rawInput = rawInput
        self.dialogue = dialogue
        self.currentProposal = currentProposal
        self.userFeedback = userFeedback
        self.harnessFeedback = harnessFeedback
        self.context = context
    }
}

public struct LLMHarnessFeedback: Codable, Equatable, Sendable {
    public var attempt: Int
    public var previousFailures: [String]
    public var instruction: String

    public init(attempt: Int, previousFailures: [String], instruction: String) {
        self.attempt = attempt
        self.previousFailures = previousFailures
        self.instruction = instruction
    }
}

public struct IssueDefinitionResponse: Codable, Equatable, Sendable {
    public var questions: [ScribeQuestion]
    public var proposal: IssueProposal?
    public var readyToPropose: Bool
    public var thinking: String

    public init(
        questions: [ScribeQuestion] = [],
        proposal: IssueProposal? = nil,
        readyToPropose: Bool = false,
        thinking: String = ""
    ) {
        self.questions = questions
        self.proposal = proposal
        self.readyToPropose = readyToPropose
        self.thinking = thinking
    }
}

public struct RoundtableOpeningInput: Codable, Equatable, Sendable {
    public var taskFrame: TaskFrame
    public var proposal: IssueProposal
    public var context: ProviderContext?

    public init(taskFrame: TaskFrame, proposal: IssueProposal, context: ProviderContext? = nil) {
        self.taskFrame = taskFrame
        self.proposal = proposal
        self.context = context
    }
}

public struct RoundtableOpeningResponse: Codable, Equatable, Sendable {
    public var openings: [VoiceOpeningTurn]

    public init(openings: [VoiceOpeningTurn]) {
        self.openings = openings
    }
}

public struct RoundtableMoveInput: Codable, Equatable, Sendable {
    public var taskFrame: TaskFrame
    public var proposal: IssueProposal
    public var roundtable: RoundtableRecord
    public var move: RoundtableMove
    public var context: ProviderContext?

    public init(
        taskFrame: TaskFrame,
        proposal: IssueProposal,
        roundtable: RoundtableRecord,
        move: RoundtableMove,
        context: ProviderContext? = nil
    ) {
        self.taskFrame = taskFrame
        self.proposal = proposal
        self.roundtable = roundtable
        self.move = move
        self.context = context
    }
}

public struct RoundtableMoveResponse: Codable, Equatable, Sendable {
    public var turns: [RoundtableTurn]
    public var ledger: ScribeObservationLedger?

    public init(turns: [RoundtableTurn], ledger: ScribeObservationLedger? = nil) {
        self.turns = turns
        self.ledger = ledger
    }
}

public struct AlignmentInquiryInput: Codable, Equatable, Sendable {
    public var taskFrame: TaskFrame
    public var proposal: IssueProposal
    public var roundtable: RoundtableRecord
    public var ledger: ScribeObservationLedger
    public var questions: [ScribeInquiryQuestion]
    public var answers: [ScribeInquiryAnswer]
    public var harnessFeedback: LLMHarnessFeedback?
    public var context: ProviderContext?

    public init(
        taskFrame: TaskFrame,
        proposal: IssueProposal,
        roundtable: RoundtableRecord,
        ledger: ScribeObservationLedger,
        questions: [ScribeInquiryQuestion],
        answers: [ScribeInquiryAnswer],
        harnessFeedback: LLMHarnessFeedback? = nil,
        context: ProviderContext? = nil
    ) {
        self.taskFrame = taskFrame
        self.proposal = proposal
        self.roundtable = roundtable
        self.ledger = ledger
        self.questions = questions
        self.answers = answers
        self.harnessFeedback = harnessFeedback
        self.context = context
    }
}

public struct AlignmentInquiryResponse: Codable, Equatable, Sendable {
    public var questions: [ScribeInquiryQuestion]
    public var readyForSettlement: Bool
    public var profile: AlignmentProfile?
    public var ledger: ScribeObservationLedger

    public init(
        questions: [ScribeInquiryQuestion] = [],
        readyForSettlement: Bool = false,
        profile: AlignmentProfile? = nil,
        ledger: ScribeObservationLedger
    ) {
        self.questions = questions
        self.readyForSettlement = readyForSettlement
        self.profile = profile
        self.ledger = ledger
    }
}

public struct HeartSettlementInput: Codable, Equatable, Sendable {
    public var taskFrame: TaskFrame
    public var proposal: IssueProposal
    public var ledger: ScribeObservationLedger
    public var answers: [ScribeInquiryAnswer]
    public var profile: AlignmentProfile
    public var context: ProviderContext?

    public init(
        taskFrame: TaskFrame,
        proposal: IssueProposal,
        ledger: ScribeObservationLedger,
        answers: [ScribeInquiryAnswer],
        profile: AlignmentProfile,
        context: ProviderContext? = nil
    ) {
        self.taskFrame = taskFrame
        self.proposal = proposal
        self.ledger = ledger
        self.answers = answers
        self.profile = profile
        self.context = context
    }
}

public struct HeartSettlementResponse: Codable, Equatable, Sendable {
    public var settlement: HeartSettlement

    public init(settlement: HeartSettlement) {
        self.settlement = settlement
    }
}

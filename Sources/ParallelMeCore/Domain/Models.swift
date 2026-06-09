import Foundation

fileprivate func isCustomAnswerOption(id: String, label: String) -> Bool {
    let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if ["custom", "other", "free_text"].contains(normalizedID) { return true }

    let normalizedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
    return normalizedLabel.hasPrefix("都不准") ||
        normalizedLabel.hasPrefix("都不对") ||
        normalizedLabel.contains("自己说")
}

public struct IssueProposalKey: Codable, Equatable, Sendable {
    public var title: String
    public var content: String
    public var details: [String]

    public init(title: String, content: String, details: [String] = []) {
        self.title = title
        self.content = content
        self.details = details
    }

    public var isMeaningful: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public struct IssueProposal: Codable, Equatable, Sendable {
    public var issueSentence: String
    public var surfaceDilemma: IssueProposalKey
    public var currentConstraints: IssueProposalKey
    public var coreFears: IssueProposalKey
    public var expectedResolution: IssueProposalKey

    public init(
        issueSentence: String,
        surfaceDilemma: IssueProposalKey,
        currentConstraints: IssueProposalKey,
        coreFears: IssueProposalKey,
        expectedResolution: IssueProposalKey
    ) {
        self.issueSentence = issueSentence
        self.surfaceDilemma = surfaceDilemma
        self.currentConstraints = currentConstraints
        self.coreFears = coreFears
        self.expectedResolution = expectedResolution
    }

    public var isComplete: Bool {
        !issueSentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        surfaceDilemma.isMeaningful &&
        currentConstraints.isMeaningful &&
        coreFears.isMeaningful &&
        expectedResolution.isMeaningful
    }

    public var missingPurposes: [ProbePurpose] {
        var missing: [ProbePurpose] = []
        if !surfaceDilemma.isMeaningful { missing.append(.surfaceDilemma) }
        if !currentConstraints.isMeaningful { missing.append(.currentConstraints) }
        if !coreFears.isMeaningful { missing.append(.coreFears) }
        if !expectedResolution.isMeaningful { missing.append(.expectedResolution) }
        return missing
    }
}

public struct TaskFrame: Codable, Equatable, Sendable {
    public var problemDefinition: String
    public var currentState: String
    public var keyFacts: [String]
    public var mainChoices: [String]
    public var coreConflict: String
    public var centralQuestion: String
    public var mainConcerns: [String]
    public var discussionFocus: String

    public init(
        problemDefinition: String,
        currentState: String,
        keyFacts: [String] = [],
        mainChoices: [String] = [],
        coreConflict: String,
        centralQuestion: String,
        mainConcerns: [String] = [],
        discussionFocus: String
    ) {
        self.problemDefinition = problemDefinition
        self.currentState = currentState
        self.keyFacts = keyFacts
        self.mainChoices = mainChoices
        self.coreConflict = coreConflict
        self.centralQuestion = centralQuestion
        self.mainConcerns = mainConcerns
        self.discussionFocus = discussionFocus
    }
}

public enum DialogueRole: String, Codable, Sendable {
    case scribe
    case user
}

public struct ScribeProbeOption: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }

    public var isCustomAnswer: Bool {
        isCustomAnswerOption(id: id, label: label)
    }
}

public struct ScribeQuestion: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var text: String
    public var options: [ScribeProbeOption]
    public var purpose: ProbePurpose

    public init(id: String, text: String, options: [ScribeProbeOption], purpose: ProbePurpose) {
        self.id = id
        self.text = text
        self.options = options
        self.purpose = purpose
    }
}

public struct ScribeAnswer: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var questionID: String
    public var selectedOptionID: String?
    public var selectedOptionLabel: String?
    public var questionText: String?
    public var freeText: String?
    public var answeredAt: Date

    public init(
        id: String = UUID().uuidString,
        questionID: String,
        selectedOptionID: String? = nil,
        selectedOptionLabel: String? = nil,
        questionText: String? = nil,
        freeText: String? = nil,
        answeredAt: Date = Date()
    ) {
        self.id = id
        self.questionID = questionID
        self.selectedOptionID = selectedOptionID
        self.selectedOptionLabel = selectedOptionLabel
        self.questionText = questionText
        self.freeText = freeText
        self.answeredAt = answeredAt
    }
}

public struct DefiningDialogueEntry: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var role: DialogueRole
    public var question: ScribeQuestion?
    public var answer: ScribeAnswer?
    public var thinkingTrace: [String]

    public init(
        id: String = UUID().uuidString,
        role: DialogueRole,
        question: ScribeQuestion? = nil,
        answer: ScribeAnswer? = nil,
        thinkingTrace: [String] = []
    ) {
        self.id = id
        self.role = role
        self.question = question
        self.answer = answer
        self.thinkingTrace = thinkingTrace
    }
}

public struct VoiceOpeningPayload: Codable, Equatable, Sendable {
    public var thesis: String
    public var protectedValue: String
    public var concern: String
    public var taskEvidence: String
    public var pull: String

    public init(thesis: String, protectedValue: String, concern: String, taskEvidence: String, pull: String) {
        self.thesis = thesis
        self.protectedValue = protectedValue
        self.concern = concern
        self.taskEvidence = taskEvidence
        self.pull = pull
    }
}

public struct VoiceOpeningTurn: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var voiceID: VoiceID
    public var name: String
    public var payload: VoiceOpeningPayload
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        voiceID: VoiceID,
        name: String? = nil,
        payload: VoiceOpeningPayload,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.voiceID = voiceID
        self.name = name ?? voiceID.displayName
        self.payload = payload
        self.createdAt = createdAt
    }
}

public enum RoundtableMoveType: String, Codable, Sendable {
    case continueAll = "continue_all"
    case duel
    case userToVoice = "user_to_voice"
    case userToTable = "user_to_table"
}

public struct RoundtableMove: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var type: RoundtableMoveType
    public var targetVoiceID: VoiceID?
    public var fromVoiceID: VoiceID?
    public var toVoiceID: VoiceID?
    public var userText: String?
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        type: RoundtableMoveType,
        targetVoiceID: VoiceID? = nil,
        fromVoiceID: VoiceID? = nil,
        toVoiceID: VoiceID? = nil,
        userText: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.targetVoiceID = targetVoiceID
        self.fromVoiceID = fromVoiceID
        self.toVoiceID = toVoiceID
        self.userText = userText
        self.createdAt = createdAt
    }
}

public struct RoundtableTurn: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var moveID: String?
    public var voiceID: VoiceID?
    public var name: String?
    public var text: String
    public var replyTo: String?
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        moveID: String? = nil,
        voiceID: VoiceID? = nil,
        name: String? = nil,
        text: String,
        replyTo: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.moveID = moveID
        self.voiceID = voiceID
        self.name = name ?? voiceID?.displayName
        self.text = text
        self.replyTo = replyTo
        self.createdAt = createdAt
    }
}

public struct RoundtableRecord: Codable, Equatable, Sendable {
    public var openingTurns: [VoiceOpeningTurn]
    public var turns: [RoundtableTurn]
    public var moves: [RoundtableMove]

    public init(openingTurns: [VoiceOpeningTurn] = [], turns: [RoundtableTurn] = [], moves: [RoundtableMove] = []) {
        self.openingTurns = openingTurns
        self.turns = turns
        self.moves = moves
    }
}

public struct ScribeInquiryOption: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var label: String
    public var meaning: String?

    public init(id: String, label: String, meaning: String? = nil) {
        self.id = id
        self.label = label
        self.meaning = meaning
    }

    public var isCustomAnswer: Bool {
        isCustomAnswerOption(id: id, label: label)
    }
}

public struct ScribeInquiryQuestion: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var question: String
    public var options: [ScribeInquiryOption]
    public var module: SettlementModuleID?

    public init(id: String, question: String, options: [ScribeInquiryOption], module: SettlementModuleID? = nil) {
        self.id = id
        self.question = question
        self.options = options
        self.module = module
    }
}

public struct ScribeInquiryAnswer: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var questionID: String
    public var question: String
    public var selectedOptionID: String
    public var selectedLabel: String
    public var customText: String?
    public var answeredAt: Date

    public init(
        id: String = UUID().uuidString,
        questionID: String,
        question: String,
        selectedOptionID: String,
        selectedLabel: String,
        customText: String? = nil,
        answeredAt: Date = Date()
    ) {
        self.id = id
        self.questionID = questionID
        self.question = question
        self.selectedOptionID = selectedOptionID
        self.selectedLabel = selectedLabel
        self.customText = customText
        self.answeredAt = answeredAt
    }
}

public struct ScribeObservation: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var observation: String
    public var attribution: String
    public var module: SettlementModuleID?
    public var evidence: [String]
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        observation: String,
        attribution: String = "",
        module: SettlementModuleID? = nil,
        evidence: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.observation = observation
        self.attribution = attribution
        self.module = module
        self.evidence = evidence
        self.createdAt = createdAt
    }
}

public struct UnansweredRoundtableQuestion: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var fromVoiceID: VoiceID?
    public var fromName: String?
    public var question: String
    public var whyItMatters: String

    public init(
        id: String = UUID().uuidString,
        fromVoiceID: VoiceID? = nil,
        fromName: String? = nil,
        question: String,
        whyItMatters: String
    ) {
        self.id = id
        self.fromVoiceID = fromVoiceID
        self.fromName = fromName
        self.question = question
        self.whyItMatters = whyItMatters
    }
}

public struct ScribeObservationLedger: Codable, Equatable, Sendable {
    public var observations: [ScribeObservation]
    public var unansweredQuestions: [UnansweredRoundtableQuestion]
    public var moduleSignals: [SettlementModuleID: [String]]
    public var updatedAt: Date

    public init(
        observations: [ScribeObservation] = [],
        unansweredQuestions: [UnansweredRoundtableQuestion] = [],
        moduleSignals: [SettlementModuleID: [String]] = [:],
        updatedAt: Date = Date()
    ) {
        self.observations = observations
        self.unansweredQuestions = unansweredQuestions
        self.moduleSignals = moduleSignals
        self.updatedAt = updatedAt
    }

    public func signalCount(for module: SettlementModuleID) -> Int {
        (moduleSignals[module] ?? []).count + observations.filter { $0.module == module }.count
    }
}

public struct HegelianSynthesis: Codable, Equatable, Sendable {
    public var thesis: String
    public var antithesis: String
    public var synthesis: String

    public init(thesis: String = "", antithesis: String = "", synthesis: String = "") {
        self.thesis = thesis
        self.antithesis = antithesis
        self.synthesis = synthesis
    }
}

public struct AlignmentProfile: Codable, Equatable, Sendable {
    public var falsifiedFantasy: String
    public var coreValueAxis: String
    public var offendedVoices: [VoiceID]
    public var acceptedCosts: [String]
    public var refusedCosts: [String]
    public var unresolvedTensions: [String]
    public var hegelianSynthesis: HegelianSynthesis
    public var userSelfStatements: [String]

    public init(
        falsifiedFantasy: String = "",
        coreValueAxis: String = "",
        offendedVoices: [VoiceID] = [],
        acceptedCosts: [String] = [],
        refusedCosts: [String] = [],
        unresolvedTensions: [String] = [],
        hegelianSynthesis: HegelianSynthesis = HegelianSynthesis(),
        userSelfStatements: [String] = []
    ) {
        self.falsifiedFantasy = falsifiedFantasy
        self.coreValueAxis = coreValueAxis
        self.offendedVoices = offendedVoices
        self.acceptedCosts = acceptedCosts
        self.refusedCosts = refusedCosts
        self.unresolvedTensions = unresolvedTensions
        self.hegelianSynthesis = hegelianSynthesis
        self.userSelfStatements = userSelfStatements
    }
}

public struct SettlementModule: Codable, Equatable, Sendable {
    public var title: String
    public var report: String
    public var evidence: [String]
    public var userRevision: String?

    public init(title: String, report: String, evidence: [String] = [], userRevision: String? = nil) {
        self.title = title
        self.report = report
        self.evidence = evidence
        self.userRevision = userRevision
    }

    public var resolvedText: String {
        let revision = userRevision?.trimmingCharacters(in: .whitespacesAndNewlines)
        return revision?.isEmpty == false ? revision! : report
    }
}

public struct DialecticSynthesis: Codable, Equatable, Sendable {
    public var thesis: String
    public var antithesis: String
    public var synthesis: String
    public var userRevision: String?

    public init(thesis: String, antithesis: String, synthesis: String, userRevision: String? = nil) {
        self.thesis = thesis
        self.antithesis = antithesis
        self.synthesis = synthesis
        self.userRevision = userRevision
    }
}

public struct HeartSettlement: Codable, Equatable, Sendable {
    public var creativeHopelessness: SettlementModule
    public var coreValueAxis: SettlementModule
    public var costAcceptanceContract: SettlementModule
    public var minimumViableCommitment: SettlementModule
    public var dialecticSynthesis: DialecticSynthesis

    public init(
        creativeHopelessness: SettlementModule,
        coreValueAxis: SettlementModule,
        costAcceptanceContract: SettlementModule,
        minimumViableCommitment: SettlementModule,
        dialecticSynthesis: DialecticSynthesis
    ) {
        self.creativeHopelessness = creativeHopelessness
        self.coreValueAxis = coreValueAxis
        self.costAcceptanceContract = costAcceptanceContract
        self.minimumViableCommitment = minimumViableCommitment
        self.dialecticSynthesis = dialecticSynthesis
    }

    public var headline: String {
        let revision = dialecticSynthesis.userRevision?.trimmingCharacters(in: .whitespacesAndNewlines)
        if revision?.isEmpty == false { return revision! }
        if !dialecticSynthesis.synthesis.isEmpty { return dialecticSynthesis.synthesis }
        if !coreValueAxis.resolvedText.isEmpty { return coreValueAxis.resolvedText }
        return creativeHopelessness.resolvedText
    }

    public var missingModules: [SettlementModuleID] {
        SettlementModuleID.allCases.filter {
            resolvedText(for: $0).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public var isComplete: Bool {
        missingModules.isEmpty
    }

    public mutating func revise(moduleID: SettlementModuleID, text: String) {
        let revision = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let stored = revision.isEmpty ? nil : revision
        switch moduleID {
        case .creativeHopelessness:
            creativeHopelessness.userRevision = stored
        case .coreValues:
            coreValueAxis.userRevision = stored
        case .costAcceptance:
            costAcceptanceContract.userRevision = stored
        case .minimumAction:
            minimumViableCommitment.userRevision = stored
        case .dialecticSynthesis:
            dialecticSynthesis.userRevision = stored
        }
    }

    public func resolvedText(for moduleID: SettlementModuleID) -> String {
        switch moduleID {
        case .creativeHopelessness:
            creativeHopelessness.resolvedText
        case .coreValues:
            coreValueAxis.resolvedText
        case .costAcceptance:
            costAcceptanceContract.resolvedText
        case .minimumAction:
            minimumViableCommitment.resolvedText
        case .dialecticSynthesis:
            dialecticSynthesis.userRevision?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyText ??
                dialecticSynthesis.synthesis
        }
    }
}

private extension String {
    var nonEmptyText: String? {
        isEmpty ? nil : self
    }
}

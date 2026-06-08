import Foundation

public struct MeetingSummary: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var stage: MeetingStage
    public var createdAt: Date
    public var updatedAt: Date
    public var searchText: String

    public init(
        id: String,
        title: String,
        subtitle: String,
        stage: MeetingStage,
        createdAt: Date,
        updatedAt: Date,
        searchText: String = ""
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.stage = stage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.searchText = searchText
    }

    public init(state: MeetingFlowState) {
        self.init(
            id: state.id,
            title: MeetingSummary.title(for: state),
            subtitle: MeetingSummary.subtitle(for: state),
            stage: state.stage,
            createdAt: state.createdAt,
            updatedAt: MeetingSummary.updatedAt(for: state),
            searchText: MeetingSummary.searchText(for: state)
        )
    }

    private static func title(for state: MeetingFlowState) -> String {
        if let settlement = state.heartSettlement?.headline.nonEmptySummaryText {
            return settlement
        }
        if let issue = state.issueProposal?.issueSentence.nonEmptySummaryText {
            return issue
        }
        return state.rawInput.nonEmptySummaryText ?? "未命名圆桌"
    }

    private static func subtitle(for state: MeetingFlowState) -> String {
        switch state.stage {
        case .defining:
            return "议题定义中"
        case .roundtable:
            return "五声圆桌 · \(state.roundtable.openingTurns.count) 个开场"
        case .inquiry:
            return "书记员问询 · \(state.inquiryAnswers.count) 个回答"
        case .settlement:
            return "本心落定待归档"
        case .archived:
            return "已归档"
        }
    }

    private static func updatedAt(for state: MeetingFlowState) -> Date {
        ([state.createdAt] + [
            state.roundtable.moves.map(\.createdAt).max(),
            state.roundtable.turns.map(\.createdAt).max(),
            state.inquiryAnswers.map(\.answeredAt).max(),
            state.roundtable.openingTurns.map(\.createdAt).max()
        ]
        .compactMap { $0 })
        .max() ?? state.createdAt
    }

    public func matches(searchText: String) -> Bool {
        let terms = searchText
            .split(whereSeparator: \.isWhitespace)
            .map { String($0).foldedSearchText }
            .filter { !$0.isEmpty }
        guard !terms.isEmpty else { return true }

        let haystack = [
            title,
            subtitle,
            stage.rawValue,
            self.searchText
        ]
        .joined(separator: " ")
        .foldedSearchText

        return terms.allSatisfy { haystack.contains($0) }
    }

    private static func searchText(for state: MeetingFlowState) -> String {
        var parts: [String] = [
            state.rawInput
        ]

        if let context = state.runtimeSnapshot?.context?.normalized {
            parts.append(contentsOf: [
                context.meCard,
                context.tasteProfile
            ].compactMap(\.nonEmptySummaryText))
        }

        for entry in state.definingDialogue {
            if let question = entry.question {
                parts.append(question.text)
                parts.append(contentsOf: question.options.map(\.label))
                parts.append(question.purpose.label)
            }
            if let answer = entry.answer {
                parts.append(contentsOf: [
                    answer.questionText,
                    answer.selectedOptionLabel,
                    answer.freeText
                ].compactMap(\.nonEmptySummaryText))
            }
        }

        if let proposal = state.issueProposal {
            parts.append(proposal.issueSentence)
            parts.append(contentsOf: proposal.surfaceDilemma.searchParts)
            parts.append(contentsOf: proposal.currentConstraints.searchParts)
            parts.append(contentsOf: proposal.coreFears.searchParts)
            parts.append(contentsOf: proposal.expectedResolution.searchParts)
        }

        if let taskFrame = state.taskFrame {
            parts.append(contentsOf: [
                taskFrame.problemDefinition,
                taskFrame.currentState,
                taskFrame.coreConflict,
                taskFrame.centralQuestion,
                taskFrame.discussionFocus
            ])
            parts.append(contentsOf: taskFrame.keyFacts)
            parts.append(contentsOf: taskFrame.mainChoices)
            parts.append(contentsOf: taskFrame.mainConcerns)
        }

        for opening in state.roundtable.openingTurns {
            parts.append(opening.name)
            parts.append(contentsOf: [
                opening.payload.thesis,
                opening.payload.protectedValue,
                opening.payload.concern,
                opening.payload.taskEvidence,
                opening.payload.pull
            ])
        }
        parts.append(contentsOf: state.roundtable.turns.flatMap { turn in
            [
                turn.name,
                turn.text,
                turn.replyTo,
                turn.voiceID?.displayName
            ].compactMap(\.nonEmptySummaryText)
        })
        parts.append(contentsOf: state.roundtable.moves.flatMap { move in
            [
                move.userText,
                move.targetVoiceID?.displayName,
                move.fromVoiceID?.displayName,
                move.toVoiceID?.displayName
            ].compactMap(\.nonEmptySummaryText)
        })

        parts.append(contentsOf: state.inquiryQuestions.flatMap { question in
            [question.question, question.module?.label] + question.options.map(\.label)
        }.compactMap(\.nonEmptySummaryText))
        parts.append(contentsOf: state.inquiryAnswers.flatMap { answer in
            [
                answer.question,
                answer.selectedLabel,
                answer.customText
            ].compactMap(\.nonEmptySummaryText)
        })

        if let profile = state.alignmentProfile {
            parts.append(contentsOf: [
                profile.falsifiedFantasy,
                profile.coreValueAxis,
                profile.hegelianSynthesis.thesis,
                profile.hegelianSynthesis.antithesis,
                profile.hegelianSynthesis.synthesis
            ])
            parts.append(contentsOf: profile.acceptedCosts)
            parts.append(contentsOf: profile.refusedCosts)
            parts.append(contentsOf: profile.unresolvedTensions)
            parts.append(contentsOf: profile.userSelfStatements)
            parts.append(contentsOf: profile.offendedVoices.map(\.displayName))
        }

        parts.append(contentsOf: state.scribeObservationLedger.observations.flatMap { observation in
            [
                observation.observation,
                observation.attribution,
                observation.module?.label
            ] + observation.evidence
        }.compactMap(\.nonEmptySummaryText))
        parts.append(contentsOf: state.scribeObservationLedger.unansweredQuestions.flatMap { question in
            [
                question.fromName,
                question.fromVoiceID?.displayName,
                question.question,
                question.whyItMatters
            ].compactMap(\.nonEmptySummaryText)
        })
        parts.append(contentsOf: state.scribeObservationLedger.moduleSignals.flatMap { module, signals in
            [module.label] + signals
        })

        if let settlement = state.heartSettlement {
            parts.append(contentsOf: [
                settlement.resolvedText(for: .creativeHopelessness),
                settlement.resolvedText(for: .coreValues),
                settlement.resolvedText(for: .costAcceptance),
                settlement.resolvedText(for: .minimumAction),
                settlement.resolvedText(for: .dialecticSynthesis),
                settlement.creativeHopelessness.title,
                settlement.coreValueAxis.title,
                settlement.costAcceptanceContract.title,
                settlement.minimumViableCommitment.title,
                settlement.dialecticSynthesis.thesis,
                settlement.dialecticSynthesis.antithesis
            ])
        }

        return parts
            .compactMap(\.nonEmptySummaryText)
            .joined(separator: " ")
    }
}

private extension String {
    var nonEmptySummaryText: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var foldedSearchText: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

private extension Optional where Wrapped == String {
    var nonEmptySummaryText: String? {
        self?.nonEmptySummaryText
    }
}

private extension IssueProposalKey {
    var searchParts: [String] {
        [title, content] + details
    }
}

import Foundation

public struct ProbeCoverage: Equatable, Sendable {
    public var answeredPurposes: Set<ProbePurpose>
    public var askedPurposes: Set<ProbePurpose>
    public var askedTexts: [String]
    public var rawSignalPurposes: Set<ProbePurpose>
    public var missingPurposes: [ProbePurpose]
    public var userAnswerCount: Int
    public var articulatedAnswerCount: Int
    public var boundaryAnswerCount: Int

    public init(
        answeredPurposes: Set<ProbePurpose>,
        askedPurposes: Set<ProbePurpose>,
        askedTexts: [String],
        rawSignalPurposes: Set<ProbePurpose> = [],
        missingPurposes: [ProbePurpose],
        userAnswerCount: Int = 0,
        articulatedAnswerCount: Int = 0,
        boundaryAnswerCount: Int = 0
    ) {
        self.answeredPurposes = answeredPurposes
        self.askedPurposes = askedPurposes
        self.askedTexts = askedTexts
        self.rawSignalPurposes = rawSignalPurposes
        self.missingPurposes = missingPurposes
        self.userAnswerCount = userAnswerCount
        self.articulatedAnswerCount = articulatedAnswerCount
        self.boundaryAnswerCount = boundaryAnswerCount
    }
}

public struct IssueDefinitionEvidenceReadiness: Equatable, Sendable {
    public var blockingPurposes: [ProbePurpose]

    public init(blockingPurposes: [ProbePurpose]) {
        self.blockingPurposes = blockingPurposes
    }

    public var isReady: Bool {
        blockingPurposes.isEmpty
    }
}

public struct IssueDefinitionEvidenceEvaluator: Sendable {
    private let minimumUserAnswers: Int
    private let minimumArticulatedAnswers: Int
    private let minimumBoundaryConfirmations: Int

    public init(
        minimumUserAnswers: Int = 4,
        minimumArticulatedAnswers: Int = 1,
        minimumBoundaryConfirmations: Int = 1
    ) {
        self.minimumUserAnswers = minimumUserAnswers
        self.minimumArticulatedAnswers = minimumArticulatedAnswers
        self.minimumBoundaryConfirmations = minimumBoundaryConfirmations
    }

    public func coverage(rawInput: String, history: [DefiningDialogueEntry]) -> ProbeCoverage {
        var questionByID: [String: ScribeQuestion] = [:]
        var askedPurposes = Set<ProbePurpose>()
        var answeredPurposes = Set<ProbePurpose>()
        var askedTexts: [String] = []
        let rawSignalPurposes = detectedPurposes(in: rawInput)
        var userAnswerCount = 0
        var articulatedAnswerCount = 0
        var boundaryAnswerCount = 0

        for entry in history {
            if let question = entry.question {
                questionByID[question.id] = question
                askedPurposes.insert(question.purpose)
                askedTexts.append(question.text)
            }

            if let answer = entry.answer {
                userAnswerCount += 1
                let answerText = [
                    answer.selectedOptionLabel,
                    answer.freeText
                ]
                .compactMap { $0 }
                .joined(separator: " ")
                if isSubstantiveAnswerEvidence(answerText),
                   let purpose = questionByID[answer.questionID]?.purpose ?? inferPurpose(from: answer.questionText ?? "") {
                    answeredPurposes.insert(purpose)
                    if isArticulatedAnswerEvidence(answerText) {
                        articulatedAnswerCount += 1
                    }
                    if isBoundaryConfirmation(answerText) {
                        boundaryAnswerCount += 1
                    }
                }
            }
        }

        let missing = ProbePurpose.allCases.filter { !answeredPurposes.contains($0) }
        return ProbeCoverage(
            answeredPurposes: answeredPurposes,
            askedPurposes: askedPurposes,
            askedTexts: askedTexts,
            rawSignalPurposes: rawSignalPurposes,
            missingPurposes: missing,
            userAnswerCount: userAnswerCount,
            articulatedAnswerCount: articulatedAnswerCount,
            boundaryAnswerCount: boundaryAnswerCount
        )
    }

    public func evaluate(rawInput: String, history: [DefiningDialogueEntry]) -> IssueDefinitionEvidenceReadiness {
        IssueDefinitionEvidenceReadiness(
            blockingPurposes: blockingPurposes(
                for: coverage(rawInput: rawInput, history: history)
            )
        )
    }

    public func blockingPurposes(rawInput: String, history: [DefiningDialogueEntry]) -> [ProbePurpose] {
        blockingPurposes(for: coverage(rawInput: rawInput, history: history))
    }

    private func blockingPurposes(for coverage: ProbeCoverage) -> [ProbePurpose] {
        var blockers = coverage.missingPurposes

        if coverage.userAnswerCount < minimumUserAnswers {
            blockers.append(contentsOf: coverage.missingPurposes.isEmpty ? ProbePurpose.allCases : coverage.missingPurposes)
        }

        if coverage.articulatedAnswerCount < minimumArticulatedAnswers {
            blockers.append(.coreFears)
            blockers.append(.surfaceDilemma)
        }

        if coverage.boundaryAnswerCount < minimumBoundaryConfirmations {
            blockers.append(.currentConstraints)
            blockers.append(.expectedResolution)
        }

        return deduplicatedPurposes(blockers)
    }

    private func isSubstantiveAnswerEvidence(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let withoutCustomPlaceholder = normalizedUserEvidence(trimmed)
        guard !withoutCustomPlaceholder.isEmpty else { return false }

        return withoutCustomPlaceholder.range(
            of: #"^(我)?(还)?(不知道|不清楚|说不清|不确定|没想好|没有想好)(。|！|!|？|\?)?$"#,
            options: .regularExpression
        ) == nil
    }

    private func isArticulatedAnswerEvidence(_ text: String) -> Bool {
        let normalized = normalizedUserEvidence(text)
        guard isSubstantiveAnswerEvidence(normalized) else { return false }
        return normalized.count >= 12
    }

    private func isBoundaryConfirmation(_ text: String) -> Bool {
        normalizedUserEvidence(text).range(
            of: #"(一变|什么情况下|边界|底线|最坏|失败成本|代价|不能碰|可以承受|观察期|验证|判断规则|停|继续|扛不住|条件|现金流|时间|身体)"#,
            options: .regularExpression
        ) != nil
    }

    private func normalizedUserEvidence(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "都不准，我自己说", with: "")
            .replacingOccurrences(of: "都不准", with: "")
            .replacingOccurrences(of: "都不对", with: "")
            .replacingOccurrences(of: "我自己说", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func detectedPurposes(in text: String) -> Set<ProbePurpose> {
        var result = Set<ProbePurpose>()
        if text.range(of: #"(还是|要不要|该不该|选择|岔路|一边|另一边|A|B|哪条路)"#, options: .regularExpression) != nil {
            result.insert(.surfaceDilemma)
        }
        if text.range(of: #"(月薪|年薪|收入|钱|时间|父母|老家|稳定|年龄|身体|睡眠|现金流|失败成本|合同|签证)"#, options: .regularExpression) != nil {
            result.insert(.currentConstraints)
        }
        if text.range(of: #"(害怕|担心|怕|焦虑|愧疚|不甘心|后悔|自由|体面|安全感|价值|尊严|亏欠|失去|底线)"#, options: .regularExpression) != nil {
            result.insert(.coreFears)
        }
        if text.range(of: #"(希望|想让|想知道|验证|确认|看清|圆桌|讨论|判断规则|产出|观察期|下一步)"#, options: .regularExpression) != nil {
            result.insert(.expectedResolution)
        }
        return result
    }

    private func inferPurpose(from text: String) -> ProbePurpose? {
        let detected = detectedPurposes(in: text)
        return ProbePurpose.allCases.first(where: { detected.contains($0) })
    }

    private func deduplicatedPurposes(_ purposes: [ProbePurpose]) -> [ProbePurpose] {
        var seen = Set<ProbePurpose>()
        var result: [ProbePurpose] = []
        for purpose in purposes {
            guard !seen.contains(purpose) else { continue }
            seen.insert(purpose)
            result.append(purpose)
        }
        return result
    }
}

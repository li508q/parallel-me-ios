import Foundation

public struct ProbeCoverage: Equatable, Sendable {
    public var answeredPurposes: Set<ProbePurpose>
    public var askedPurposes: Set<ProbePurpose>
    public var askedTexts: [String]
    public var missingPurposes: [ProbePurpose]

    public init(
        answeredPurposes: Set<ProbePurpose>,
        askedPurposes: Set<ProbePurpose>,
        askedTexts: [String],
        missingPurposes: [ProbePurpose]
    ) {
        self.answeredPurposes = answeredPurposes
        self.askedPurposes = askedPurposes
        self.askedTexts = askedTexts
        self.missingPurposes = missingPurposes
    }
}

public struct ScribeQuestionDeduplicator: Sendable {
    public init() {}

    public func normalize(
        _ questions: [ScribeQuestion],
        history: [DefiningDialogueEntry] = [],
        maxPerTurn: Int = 3
    ) -> [ScribeQuestion] {
        let historicalTexts = history.compactMap(\.question?.text)
        var seenPurposes = Set<ProbePurpose>()
        var seenTexts: [String] = []
        var normalized: [ScribeQuestion] = []

        for question in questions {
            if seenPurposes.contains(question.purpose) { continue }
            if historicalTexts.contains(where: { areSimilar($0, question.text) }) { continue }
            if seenTexts.contains(where: { areSimilar($0, question.text) }) { continue }

            var next = question
            next.options = normalizedOptions(question.options)
            guard next.options.count >= 2 else { continue }

            seenPurposes.insert(next.purpose)
            seenTexts.append(next.text)
            normalized.append(next)
            if normalized.count == maxPerTurn { break }
        }

        return normalized
    }

    public func coverage(rawInput: String, history: [DefiningDialogueEntry]) -> ProbeCoverage {
        var questionByID: [String: ScribeQuestion] = [:]
        var askedPurposes = Set<ProbePurpose>()
        var answeredPurposes = Set<ProbePurpose>()
        var askedTexts: [String] = []
        var combined = rawInput

        for entry in history {
            if let question = entry.question {
                questionByID[question.id] = question
                askedPurposes.insert(question.purpose)
                askedTexts.append(question.text)
                combined += "\n\(question.text)\n\(question.options.map(\.label).joined(separator: "\n"))"
            }
            if let answer = entry.answer {
                let answerText = [
                    answer.questionText,
                    answer.selectedOptionLabel,
                    answer.freeText
                ]
                .compactMap { $0 }
                .joined(separator: " ")
                combined += "\n\(answerText)"
                if !answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let purpose = questionByID[answer.questionID]?.purpose ?? inferPurpose(from: answer.questionText ?? "") {
                    answeredPurposes.insert(purpose)
                }
            }
        }

        let detected = detectedPurposes(in: combined).union(answeredPurposes)
        let missing = ProbePurpose.allCases.filter { !detected.contains($0) }
        return ProbeCoverage(
            answeredPurposes: answeredPurposes,
            askedPurposes: askedPurposes,
            askedTexts: askedTexts,
            missingPurposes: missing
        )
    }

    public func shouldForceProbe(rawInput: String, history: [DefiningDialogueEntry]) -> Bool {
        let coverage = coverage(rawInput: rawInput, history: history)
        guard !coverage.missingPurposes.isEmpty else { return false }
        let userAnswerCount = history.filter { $0.answer != nil }.count
        if userAnswerCount >= 3,
           !coverage.missingPurposes.contains(.surfaceDilemma),
           !coverage.missingPurposes.contains(.currentConstraints),
           (!coverage.missingPurposes.contains(.coreFears) || !coverage.missingPurposes.contains(.expectedResolution)) {
            return false
        }
        return true
    }

    public func areSimilar(_ lhs: String, _ rhs: String) -> Bool {
        let left = normalizeText(lhs)
        let right = normalizeText(rhs)
        guard !left.isEmpty, !right.isEmpty else { return false }
        if left == right { return true }
        if left.count >= 10, right.count >= 10, left.contains(right) || right.contains(left) {
            return true
        }

        let leftBigrams = bigrams(left)
        let rightBigrams = bigrams(right)
        guard !leftBigrams.isEmpty, !rightBigrams.isEmpty else { return false }
        let overlap = leftBigrams.intersection(rightBigrams).count
        let union = leftBigrams.union(rightBigrams).count
        return Double(overlap) / Double(union) >= 0.58
    }

    private func normalizedOptions(_ options: [ScribeProbeOption]) -> [ScribeProbeOption] {
        var cleaned = options
            .map { ScribeProbeOption(id: $0.id.trimmingCharacters(in: .whitespacesAndNewlines), label: $0.label.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.label.isEmpty }

        if !cleaned.contains(where: isCustomOption) {
            if cleaned.count >= 4 {
                cleaned = Array(cleaned.prefix(3))
            }
            cleaned.append(ScribeProbeOption(id: "custom", label: "都不准，我自己说"))
        }
        return Array(cleaned.prefix(4))
    }

    private func isCustomOption(_ option: ScribeProbeOption) -> Bool {
        option.isCustomAnswer
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

    private func normalizeText(_ text: String) -> String {
        let replaced = text
            .replacingOccurrences(of: "你希望这次圆桌最终帮你验证什么", with: "圆桌验证任务")
            .replacingOccurrences(of: "你希望这次圆桌讨论帮自己验证什么", with: "圆桌验证任务")
        let scalars = replaced.unicodeScalars.filter { scalar in
            scalar.properties.isAlphabetic || scalar.properties.isMath || scalar.properties.numericType != nil
        }
        return String(String.UnicodeScalarView(scalars)).lowercased()
    }

    private func bigrams(_ text: String) -> Set<String> {
        let chars = Array(text)
        guard chars.count > 1 else { return text.isEmpty ? [] : [text] }
        var result = Set<String>()
        for index in 0..<(chars.count - 1) {
            result.insert(String(chars[index...index + 1]))
        }
        return result
    }
}

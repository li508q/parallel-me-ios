import Foundation

public struct ScribeQuestionDeduplicator: Sendable {
    private let evidenceEvaluator: IssueDefinitionEvidenceEvaluator

    public init(evidenceEvaluator: IssueDefinitionEvidenceEvaluator = IssueDefinitionEvidenceEvaluator()) {
        self.evidenceEvaluator = evidenceEvaluator
    }

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
        evidenceEvaluator.coverage(rawInput: rawInput, history: history)
    }

    public func shouldForceProbe(rawInput: String, history: [DefiningDialogueEntry]) -> Bool {
        !evidenceEvaluator.evaluate(rawInput: rawInput, history: history).isReady
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

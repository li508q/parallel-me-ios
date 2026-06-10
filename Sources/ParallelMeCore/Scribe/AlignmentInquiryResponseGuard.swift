import Foundation

public struct AlignmentInquiryResponseGuard: Sendable {
    private let readinessEvaluator: SettlementReadinessEvaluator

    public init(readinessEvaluator: SettlementReadinessEvaluator = SettlementReadinessEvaluator()) {
        self.readinessEvaluator = readinessEvaluator
    }

    public func normalize(
        _ response: AlignmentInquiryResponse,
        existingAnswers: [ScribeInquiryAnswer]
    ) -> AlignmentInquiryResponse {
        normalize(response, existingQuestions: [], existingAnswers: existingAnswers)
    }

    public func normalize(
        _ response: AlignmentInquiryResponse,
        existingQuestions: [ScribeInquiryQuestion],
        existingAnswers: [ScribeInquiryAnswer]
    ) -> AlignmentInquiryResponse {
        let hasSettlementProfile = response.profile != nil
        let readiness = readinessEvaluator.evaluate(
            profile: response.profile ?? AlignmentProfile(),
            ledger: response.ledger,
            answers: existingAnswers
        )

        var guarded = response
        let normalizedQuestions = normalizeQuestions(
            response.questions,
            existingQuestions: existingQuestions,
            existingAnswers: existingAnswers
        )
        guarded.questions = normalizedQuestions
        guarded.readyForSettlement =
            response.readyForSettlement &&
            guarded.questions.isEmpty &&
            hasSettlementProfile &&
            readiness.isReady
        return guarded
    }

    private func normalizeQuestions(
        _ questions: [ScribeInquiryQuestion],
        existingQuestions: [ScribeInquiryQuestion],
        existingAnswers: [ScribeInquiryAnswer],
        maxPerTurn: Int = 3
    ) -> [ScribeInquiryQuestion] {
        let answeredIDs = Set(existingAnswers.map(\.questionID))
        let knownIDs = Set(existingQuestions.map(\.id))
        let activeQuestions = existingQuestions.filter { !answeredIDs.contains($0.id) }
        let historicalTexts = existingQuestions.map(\.question) + existingAnswers.map(\.question)
        let activeModules = Set(activeQuestions.compactMap(\.module))
        var seenTexts: [String] = []
        var seenModules = Set<SettlementModuleID>()
        var normalized: [ScribeInquiryQuestion] = []

        for question in questions {
            if knownIDs.contains(question.id) { continue }
            let trimmedQuestion = question.question.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedQuestion.isEmpty { continue }
            if historicalTexts.contains(where: { areSimilar($0, trimmedQuestion) }) { continue }
            if seenTexts.contains(where: { areSimilar($0, trimmedQuestion) }) { continue }

            var next = question
            next.question = trimmedQuestion
            next.module = next.module ?? inferModule(from: trimmedQuestion)
            if let module = next.module {
                if activeModules.contains(module) || seenModules.contains(module) { continue }
                seenModules.insert(module)
            }
            next.options = normalizedOptions(next.options)
            guard next.options.count >= 2 else { continue }

            normalized.append(next)
            seenTexts.append(trimmedQuestion)
            if normalized.count == maxPerTurn { break }
        }

        return normalized
    }

    private func normalizedOptions(_ options: [ScribeInquiryOption]) -> [ScribeInquiryOption] {
        var cleaned = options
            .map {
                ScribeInquiryOption(
                    id: $0.id.trimmingCharacters(in: .whitespacesAndNewlines),
                    label: $0.label.trimmingCharacters(in: .whitespacesAndNewlines),
                    meaning: $0.meaning?.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            .filter { !$0.label.isEmpty }

        if !cleaned.contains(where: \.isCustomAnswer) {
            if cleaned.count >= 4 {
                cleaned = Array(cleaned.prefix(3))
            }
            cleaned.append(ScribeInquiryOption(id: "custom", label: "都不准，我自己说"))
        }
        return Array(cleaned.prefix(4))
    }

    private func inferModule(from text: String) -> SettlementModuleID? {
        if text.range(of: #"(无代价|完美答案|走不通|失望|无望)"#, options: .regularExpression) != nil {
            return .creativeHopelessness
        }
        if text.range(of: #"(价值|底线|自由|尊严|稳定|关系|身体|不像自己)"#, options: .regularExpression) != nil {
            return .coreValues
        }
        if text.range(of: #"(代价|成本|损失|接受|承认|准备)"#, options: .regularExpression) != nil {
            return .costAcceptance
        }
        if text.range(of: #"(24|今晚|明天|行动|下一步|验证|最小)"#, options: .regularExpression) != nil {
            return .minimumAction
        }
        if text.range(of: #"(相反|合成|同时|不完美|真实|正反|两个声音)"#, options: .regularExpression) != nil {
            return .dialecticSynthesis
        }
        return nil
    }

    private func areSimilar(_ lhs: String, _ rhs: String) -> Bool {
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

    private func normalizeText(_ text: String) -> String {
        let scalars = text.unicodeScalars.filter { scalar in
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

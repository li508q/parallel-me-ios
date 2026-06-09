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
        guarded.questions = normalizedQuestions.isEmpty && !readiness.isReady
            ? recoveryQuestions(
                missingModules: readiness.missingModules,
                existingQuestions: existingQuestions,
                existingAnswers: existingAnswers
            )
            : normalizedQuestions
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

    private func recoveryQuestions(
        missingModules: [SettlementModuleID],
        existingQuestions: [ScribeInquiryQuestion],
        existingAnswers: [ScribeInquiryAnswer],
        maxPerTurn: Int = 3
    ) -> [ScribeInquiryQuestion] {
        let answeredIDs = Set(existingAnswers.map(\.questionID))
        let activeModules = Set(existingQuestions.filter { !answeredIDs.contains($0.id) }.compactMap(\.module))
        var historicalTexts = existingQuestions.map(\.question) + existingAnswers.map(\.question)
        var recovered: [ScribeInquiryQuestion] = []

        for module in missingModules where !activeModules.contains(module) {
            let question = recoveryQuestion(for: module, existingTexts: historicalTexts)
            recovered.append(question)
            historicalTexts.append(question.question)
            if recovered.count == maxPerTurn { break }
        }

        return recovered
    }

    private func recoveryQuestion(
        for module: SettlementModuleID,
        existingTexts: [String]
    ) -> ScribeInquiryQuestion {
        let candidates = recoveryTextCandidates(for: module)
        let selectedIndex = candidates.indices.first { index in
            !existingTexts.contains(where: { areSimilar($0, candidates[index]) })
        } ?? candidates.indices.last ?? 0
        return ScribeInquiryQuestion(
            id: "recovery_\(module.rawValue)_\(selectedIndex + 1)",
            question: candidates[selectedIndex],
            options: recoveryOptions(for: module),
            module: module
        )
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

    private func recoveryTextCandidates(for module: SettlementModuleID) -> [String] {
        switch module {
        case .creativeHopelessness:
            return [
                "这件事里，哪一个“无代价解决方案”已经不太可能了？",
                "如果不再等完美答案，最需要承认的失望是什么？",
                "你已经试过、但现在看起来走不通的办法是什么？"
            ]
        case .coreValues:
            return [
                "这次选择里，最不能被你背叛的价值是什么？",
                "如果只能守住一个东西，你更想守住自由、稳定、关系、身体，还是别的？",
                "哪个底线一旦被越过，你会觉得自己不像自己？"
            ]
        case .costAcceptance:
            return [
                "为了更接近真实选择，你愿意承认哪一种代价？",
                "哪种损失你虽然不喜欢，但可以开始为它做准备？",
                "这条路最不舒服的成本是什么，你能接受到什么程度？"
            ]
        case .minimumAction:
            return [
                "24 小时内，哪个动作最小但能让局面更真实一点？",
                "今晚或明天，你能做哪一步来验证这次判断？",
                "如果只做一个不会压垮自己的行动，它会是什么？"
            ]
        case .dialecticSynthesis:
            return [
                "如果把两个相反声音都留下，它们能合成哪一句更诚实的话？",
                "你既想要的东西和你也必须承认的东西，能不能同时成立？",
                "这件事最后有没有一个“不完美但更真实”的说法？"
            ]
        }
    }

    private func recoveryOptions(for module: SettlementModuleID) -> [ScribeInquiryOption] {
        let options: [ScribeInquiryOption]
        switch module {
        case .creativeHopelessness:
            options = [
                ScribeInquiryOption(id: "no_cost_free", label: "没有无代价方案"),
                ScribeInquiryOption(id: "old_strategy_failed", label: "旧办法已经失效"),
                ScribeInquiryOption(id: "still_grieving", label: "我还在为它难过")
            ]
        case .coreValues:
            options = [
                ScribeInquiryOption(id: "freedom", label: "自由和尊严"),
                ScribeInquiryOption(id: "stability", label: "稳定和安全"),
                ScribeInquiryOption(id: "relationship", label: "关系和亏欠")
            ]
        case .costAcceptance:
            options = [
                ScribeInquiryOption(id: "money", label: "短期收入波动"),
                ScribeInquiryOption(id: "time", label: "更慢的时间表"),
                ScribeInquiryOption(id: "misunderstood", label: "被误解或失望")
            ]
        case .minimumAction:
            options = [
                ScribeInquiryOption(id: "write", label: "写出一个现实清单"),
                ScribeInquiryOption(id: "talk", label: "找一个可信的人确认"),
                ScribeInquiryOption(id: "rest", label: "先把身体状态拉回来")
            ]
        case .dialecticSynthesis:
            options = [
                ScribeInquiryOption(id: "both_true", label: "两个声音都是真的"),
                ScribeInquiryOption(id: "slow_commit", label: "先慢一点承诺"),
                ScribeInquiryOption(id: "conditional_path", label: "用条件换行动")
            ]
        }
        return options + [ScribeInquiryOption(id: "custom", label: "都不准，我自己说")]
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

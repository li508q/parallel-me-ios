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

    public func recoveryQuestions(
        rawInput: String,
        history: [DefiningDialogueEntry],
        maxPerTurn: Int = 3
    ) -> [ScribeQuestion] {
        let coverage = coverage(rawInput: rawInput, history: history)
        let blockingPurposes = evidenceEvaluator.blockingPurposes(rawInput: rawInput, history: history)
        var askedTexts = coverage.askedTexts
        var recovered: [ScribeQuestion] = []

        for purpose in blockingPurposes {
            let question = recoveryQuestion(
                for: purpose,
                rawInput: rawInput,
                askedTexts: askedTexts
            )
            guard !recovered.contains(where: { areSimilar($0.text, question.text) }) else { continue }
            recovered.append(question)
            askedTexts.append(question.text)
            if recovered.count == maxPerTurn { break }
        }

        return recovered
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

    private func recoveryQuestion(
        for purpose: ProbePurpose,
        rawInput: String,
        askedTexts: [String]
    ) -> ScribeQuestion {
        let candidates = recoveryTextCandidates(for: purpose, rawInput: rawInput)
        let selectedIndex = candidates.indices.first { index in
            !askedTexts.contains(where: { areSimilar($0, candidates[index]) })
        } ?? candidates.indices.last ?? 0
        return ScribeQuestion(
            id: "recovery_\(purpose.rawValue)_\(selectedIndex + 1)",
            text: candidates[selectedIndex],
            options: recoveryOptions(for: purpose),
            purpose: purpose
        )
    }

    private func recoveryTextCandidates(for purpose: ProbePurpose, rawInput: String) -> [String] {
        let focus = rawInputFocus(rawInput)
        switch purpose {
        case .surfaceDilemma:
            return [
                "\(focus)现在最像哪一个具体岔路？",
                "如果只把\(focus)说成两个方向，它们分别是什么？",
                "\(focus)里真正需要被摆上桌面的选择是什么？"
            ]
        case .currentConstraints:
            return [
                "\(focus)里哪条现实限制最硬，足以改变判断？",
                "现在最不能忽略的现实条件是什么：钱、时间、身体、承诺，还是别的？",
                "如果今天就要推迟决定，最真实的外部原因会是什么？"
            ]
        case .coreFears:
            return [
                "如果这次选错，你最怕具体失去什么？",
                "\(focus)背后哪个东西最不能被牺牲？",
                "这件事里最不想承认、但一直在保护的担心是什么？"
            ]
        case .expectedResolution:
            return [
                "你希望这场圆桌最后帮你拿到哪种判断材料？",
                "\(focus)谈完以后，你最想带走一个答案、一个标准，还是一个行动？",
                "这次讨论如果有用，最后应该让你更确定什么？"
            ]
        }
    }

    private func recoveryOptions(for purpose: ProbePurpose) -> [ScribeProbeOption] {
        let options: [ScribeProbeOption]
        switch purpose {
        case .surfaceDilemma:
            options = [
                ScribeProbeOption(id: "two_paths", label: "两个选择都代价很大"),
                ScribeProbeOption(id: "unclear_choice", label: "我还没分清真正选择"),
                ScribeProbeOption(id: "not_binary", label: "其实不是二选一")
            ]
        case .currentConstraints:
            options = [
                ScribeProbeOption(id: "money_time_body", label: "钱、时间或身体最硬"),
                ScribeProbeOption(id: "commitment", label: "已有承诺最硬"),
                ScribeProbeOption(id: "no_external_limit", label: "外部限制不硬，是心里卡")
            ]
        case .coreFears:
            options = [
                ScribeProbeOption(id: "security", label: "安全感或体面"),
                ScribeProbeOption(id: "freedom", label: "自由或尊严"),
                ScribeProbeOption(id: "relationship", label: "关系或亏欠")
            ]
        case .expectedResolution:
            options = [
                ScribeProbeOption(id: "decision_standard", label: "一个判断标准"),
                ScribeProbeOption(id: "next_action", label: "一个最小下一步"),
                ScribeProbeOption(id: "voice_map", label: "分清谁在保护什么")
            ]
        }
        return options + [ScribeProbeOption(id: "custom", label: "都不准，我自己说")]
    }

    private func rawInputFocus(_ rawInput: String) -> String {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "这件事" }
        return "“\(String(trimmed.prefix(24)))”"
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

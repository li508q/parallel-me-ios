import Foundation

public struct SettlementReadiness: Equatable, Sendable {
    public var missingModules: [SettlementModuleID]
    public var isReady: Bool { missingModules.isEmpty }

    public init(missingModules: [SettlementModuleID]) {
        self.missingModules = missingModules
    }
}

public struct SettlementReadinessEvaluator: Sendable {
    public init() {}

    public func evaluate(
        profile: AlignmentProfile,
        ledger: ScribeObservationLedger,
        answers: [ScribeInquiryAnswer]
    ) -> SettlementReadiness {
        var missing: [SettlementModuleID] = []

        if profile.falsifiedFantasy.trimmedForReadiness.isEmpty &&
            ledger.signalCount(for: .creativeHopelessness) == 0 {
            missing.append(.creativeHopelessness)
        }

        if profile.coreValueAxis.trimmedForReadiness.isEmpty &&
            ledger.signalCount(for: .coreValues) == 0 {
            missing.append(.coreValues)
        }

        if profile.acceptedCosts.isEmpty && profile.refusedCosts.isEmpty &&
            ledger.signalCount(for: .costAcceptance) == 0 {
            missing.append(.costAcceptance)
        }

        let hasActionAnswer = answers.contains(where: isSubstantiveActionAnswer)
        if !hasActionAnswer && ledger.signalCount(for: .minimumAction) == 0 {
            missing.append(.minimumAction)
        }

        if profile.hegelianSynthesis.synthesis.trimmedForReadiness.isEmpty &&
            profile.userSelfStatements.isEmpty {
            missing.append(.dialecticSynthesis)
        }

        return SettlementReadiness(missingModules: missing)
    }

    private func isSubstantiveActionAnswer(_ answer: ScribeInquiryAnswer) -> Bool {
        let isActionQuestion =
            answer.question.localizedStandardContains("24") ||
            answer.question.localizedStandardContains("行动") ||
            answer.question.localizedStandardContains("下一步")
        let answerText = [
            answer.selectedLabel,
            answer.customText
        ]
        .compactMap { $0 }
        .joined(separator: " ")

        let evidence = answerText
            .replacingOccurrences(of: "都不准，我自己说", with: "")
            .replacingOccurrences(of: "都不准", with: "")
            .replacingOccurrences(of: "都不对", with: "")
            .replacingOccurrences(of: "我自己说", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !evidence.isEmpty else { return false }
        if evidence.range(
            of: #"^(我)?(还)?(不知道|不清楚|说不清|不确定|没想好|没有想好)(。|！|!|？|\?)?$"#,
            options: .regularExpression
        ) != nil {
            return false
        }

        return isActionQuestion ||
            evidence.localizedStandardContains("24") ||
            evidence.localizedStandardContains("行动") ||
            evidence.localizedStandardContains("今晚") ||
            evidence.localizedStandardContains("明天") ||
            evidence.localizedStandardContains("下一步")
    }
}

private extension String {
    var trimmedForReadiness: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

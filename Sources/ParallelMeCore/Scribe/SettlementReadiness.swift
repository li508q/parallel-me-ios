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

        let hasActionAnswer = answers.contains { answer in
            answer.question.localizedStandardContains("24") ||
            answer.question.localizedStandardContains("行动") ||
            answer.selectedLabel.localizedStandardContains("行动") ||
            (answer.customText ?? "").localizedStandardContains("行动")
        }
        if !hasActionAnswer && ledger.signalCount(for: .minimumAction) == 0 {
            missing.append(.minimumAction)
        }

        if profile.hegelianSynthesis.synthesis.trimmedForReadiness.isEmpty &&
            profile.userSelfStatements.isEmpty {
            missing.append(.dialecticSynthesis)
        }

        return SettlementReadiness(missingModules: missing)
    }
}

private extension String {
    var trimmedForReadiness: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}


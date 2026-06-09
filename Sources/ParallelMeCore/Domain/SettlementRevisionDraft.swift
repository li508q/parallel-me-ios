import Foundation

public struct SettlementRevisionDraft: Codable, Equatable, Sendable {
    public var creativeHopelessness: String
    public var coreValues: String
    public var costAcceptance: String
    public var minimumAction: String
    public var dialecticSynthesis: String

    private var baseline: [SettlementModuleID: String]

    public init(
        creativeHopelessness: String,
        coreValues: String,
        costAcceptance: String,
        minimumAction: String,
        dialecticSynthesis: String,
        baseline: [SettlementModuleID: String] = [:]
    ) {
        self.creativeHopelessness = creativeHopelessness
        self.coreValues = coreValues
        self.costAcceptance = costAcceptance
        self.minimumAction = minimumAction
        self.dialecticSynthesis = dialecticSynthesis
        self.baseline = baseline
    }

    public init(settlement: HeartSettlement) {
        let values: [SettlementModuleID: String] = [
            .creativeHopelessness: settlement.resolvedText(for: .creativeHopelessness),
            .coreValues: settlement.resolvedText(for: .coreValues),
            .costAcceptance: settlement.resolvedText(for: .costAcceptance),
            .minimumAction: settlement.resolvedText(for: .minimumAction),
            .dialecticSynthesis: settlement.resolvedText(for: .dialecticSynthesis)
        ]
        self.init(
            creativeHopelessness: values[.creativeHopelessness] ?? "",
            coreValues: values[.coreValues] ?? "",
            costAcceptance: values[.costAcceptance] ?? "",
            minimumAction: values[.minimumAction] ?? "",
            dialecticSynthesis: values[.dialecticSynthesis] ?? "",
            baseline: values.mapValues { $0.normalizedRevisionText }
        )
    }

    public var revisions: [SettlementModuleID: String] {
        var output: [SettlementModuleID: String] = [:]
        for moduleID in SettlementModuleID.allCases {
            let value = text(for: moduleID).normalizedRevisionText
            guard !value.isEmpty, value != baseline[moduleID] else { continue }
            output[moduleID] = value
        }
        return output
    }

    public var hasChanges: Bool {
        !revisions.isEmpty
    }

    public var hasDraftEdits: Bool {
        SettlementModuleID.allCases.contains { moduleID in
            text(for: moduleID).normalizedRevisionText != baseline[moduleID]
        }
    }

    public var hasEmptyRequiredText: Bool {
        SettlementModuleID.allCases.contains { text(for: $0).normalizedRevisionText.isEmpty }
    }

    public var canApply: Bool {
        hasChanges && !hasEmptyRequiredText
    }

    public var canArchive: Bool {
        !hasDraftEdits && !hasEmptyRequiredText
    }

    public func text(for moduleID: SettlementModuleID) -> String {
        switch moduleID {
        case .creativeHopelessness:
            creativeHopelessness
        case .coreValues:
            coreValues
        case .costAcceptance:
            costAcceptance
        case .minimumAction:
            minimumAction
        case .dialecticSynthesis:
            dialecticSynthesis
        }
    }
}

private extension String {
    var normalizedRevisionText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

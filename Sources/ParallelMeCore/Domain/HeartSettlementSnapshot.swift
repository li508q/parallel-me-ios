import Foundation

public struct HeartSettlementSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var headline: String
    public var rows: [HeartSettlementRow]

    public init(
        title: String = "本心落定",
        headline: String,
        rows: [HeartSettlementRow]
    ) {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.headline = headline.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rows = rows
    }

    public init(settlement: HeartSettlement) {
        self.init(
            headline: settlement.headline,
            rows: SettlementModuleID.allCases.map { moduleID in
                HeartSettlementRow(moduleID: moduleID, settlement: settlement)
            }
        )
    }

    public var isComplete: Bool {
        !title.isEmpty
            && !headline.isEmpty
            && rows.map(\.moduleID) == SettlementModuleID.allCases
            && rows.allSatisfy(\.isMeaningful)
    }
}

public struct HeartSettlementRow: Codable, Equatable, Sendable, Identifiable {
    public var moduleID: SettlementModuleID
    public var title: String
    public var body: String
    public var details: [String]

    public var id: String {
        moduleID.rawValue
    }

    public init(
        moduleID: SettlementModuleID,
        title: String,
        body: String,
        details: [String] = []
    ) {
        self.moduleID = moduleID
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        self.details = details.compactMap(\.nonEmptyHeartSettlementText)
    }

    public init(moduleID: SettlementModuleID, settlement: HeartSettlement) {
        self.init(
            moduleID: moduleID,
            title: moduleID.label,
            body: settlement.resolvedText(for: moduleID),
            details: settlement.details(for: moduleID)
        )
    }

    public var isMeaningful: Bool {
        !title.isEmpty && !body.isEmpty
    }
}

private extension HeartSettlement {
    func details(for moduleID: SettlementModuleID) -> [String] {
        switch moduleID {
        case .creativeHopelessness:
            return creativeHopelessness.evidence
        case .coreValues:
            return coreValueAxis.evidence
        case .costAcceptance:
            return costAcceptanceContract.evidence
        case .minimumAction:
            return minimumViableCommitment.evidence
        case .dialecticSynthesis:
            return [dialecticSynthesis.thesis, dialecticSynthesis.antithesis]
        }
    }
}

private extension String {
    var nonEmptyHeartSettlementText: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

import Foundation

public struct IssueProposalSnapshot: Codable, Equatable, Sendable {
    public var issueSentence: String
    public var rows: [IssueProposalRow]

    public init(issueSentence: String, rows: [IssueProposalRow]) {
        self.issueSentence = issueSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rows = rows
    }

    public init(proposal: IssueProposal) {
        self.init(
            issueSentence: proposal.issueSentence,
            rows: [
                IssueProposalRow(purpose: .surfaceDilemma, key: proposal.surfaceDilemma),
                IssueProposalRow(purpose: .currentConstraints, key: proposal.currentConstraints),
                IssueProposalRow(purpose: .coreFears, key: proposal.coreFears),
                IssueProposalRow(purpose: .expectedResolution, key: proposal.expectedResolution)
            ]
        )
    }

    public var isComplete: Bool {
        !issueSentence.isEmpty
            && rows.map(\.purpose) == ProbePurpose.allCases
            && rows.allSatisfy(\.isMeaningful)
    }
}

public struct IssueProposalRow: Codable, Equatable, Sendable, Identifiable {
    public var purpose: ProbePurpose
    public var title: String
    public var body: String
    public var details: [String]

    public var id: String {
        purpose.rawValue
    }

    public init(
        purpose: ProbePurpose,
        title: String,
        body: String,
        details: [String] = []
    ) {
        self.purpose = purpose
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        self.details = details.compactMap(\.nonEmptyIssueProposalText)
    }

    public init(purpose: ProbePurpose, key: IssueProposalKey) {
        self.init(
            purpose: purpose,
            title: purpose.issueProposalDisplayTitle,
            body: key.content,
            details: key.details
        )
    }

    public var isMeaningful: Bool {
        !title.isEmpty && !body.isEmpty
    }
}

private extension ProbePurpose {
    var issueProposalDisplayTitle: String {
        switch self {
        case .surfaceDilemma: "选择岔路"
        case .currentConstraints: "现实边界"
        case .coreFears: "隐秘关切"
        case .expectedResolution: "圆桌任务"
        }
    }
}

private extension String {
    var nonEmptyIssueProposalText: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

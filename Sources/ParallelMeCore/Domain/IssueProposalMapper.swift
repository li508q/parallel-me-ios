import Foundation

public enum IssueProposalMapper {
    public static func taskFrame(from proposal: IssueProposal) -> TaskFrame {
        TaskFrame(
            problemDefinition: proposal.issueSentence.isEmpty ? proposal.surfaceDilemma.content : proposal.issueSentence,
            currentState: proposal.currentConstraints.content,
            keyFacts: proposal.currentConstraints.details,
            mainChoices: proposal.surfaceDilemma.details,
            coreConflict: proposal.coreFears.content,
            centralQuestion: proposal.expectedResolution.content,
            mainConcerns: proposal.coreFears.details,
            discussionFocus: proposal.expectedResolution.details.first ?? proposal.expectedResolution.content
        )
    }
}


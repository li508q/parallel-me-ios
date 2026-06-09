public struct IssueDefinitionResponseGuard: Sendable {
    public init() {}

    public func normalize(_ response: IssueDefinitionResponse) -> IssueDefinitionResponse {
        let hasFollowUpQuestions = !response.questions.isEmpty
        let hasCompleteProposal = response.proposal?.isComplete == true

        var guarded = response
        guarded.readyToPropose =
            response.readyToPropose &&
            !hasFollowUpQuestions &&
            hasCompleteProposal

        if !guarded.readyToPropose {
            guarded.proposal = nil
        }
        return guarded
    }
}

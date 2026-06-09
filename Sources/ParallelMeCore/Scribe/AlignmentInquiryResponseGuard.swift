public struct AlignmentInquiryResponseGuard: Sendable {
    private let readinessEvaluator: SettlementReadinessEvaluator

    public init(readinessEvaluator: SettlementReadinessEvaluator = SettlementReadinessEvaluator()) {
        self.readinessEvaluator = readinessEvaluator
    }

    public func normalize(
        _ response: AlignmentInquiryResponse,
        existingAnswers: [ScribeInquiryAnswer]
    ) -> AlignmentInquiryResponse {
        let hasFollowUpQuestions = !response.questions.isEmpty
        let hasSettlementProfile = response.profile != nil
        let hasSufficientSettlementEvidence = response.profile.map { profile in
            readinessEvaluator.evaluate(
                profile: profile,
                ledger: response.ledger,
                answers: existingAnswers
            ).isReady
        } ?? false

        var guarded = response
        guarded.readyForSettlement =
            response.readyForSettlement &&
            !hasFollowUpQuestions &&
            hasSettlementProfile &&
            hasSufficientSettlementEvidence
        return guarded
    }
}

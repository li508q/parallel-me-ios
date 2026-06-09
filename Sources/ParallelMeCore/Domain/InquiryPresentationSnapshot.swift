import Foundation

public enum InquiryPresentationMode: String, Codable, Equatable, Sendable {
    case questions
    case settlementRequest
}

public struct SettlementRequestControlSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var isEnabled: Bool
    public var isVisible: Bool

    public init(title: String, systemImage: String, isEnabled: Bool, isVisible: Bool = true) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.isVisible = isVisible
    }
}

public struct SettlementRequestPresentationSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var detail: String
    public var messageTone: SettlementRequestMessageTone
    public var continueInquiryAction: SettlementRequestControlSnapshot
    public var requestSettlementAction: SettlementRequestControlSnapshot

    public init(availability: SettlementRequestAvailabilitySnapshot) {
        title = availability.title
        detail = availability.detail
        messageTone = availability.messageTone
        continueInquiryAction = SettlementRequestControlSnapshot(
            title: availability.continueInquiryActionTitle,
            systemImage: "arrow.clockwise",
            isEnabled: availability.canContinueInquiry,
            isVisible: availability.canContinueInquiry
        )
        requestSettlementAction = SettlementRequestControlSnapshot(
            title: availability.requestActionTitle,
            systemImage: "sparkles",
            isEnabled: availability.canRequestSettlement
        )
    }
}

public struct InquiryStagePresentationSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var mode: InquiryPresentationMode
    public var activeQuestions: [ScribeInquiryQuestion]
    public var settlementRequest: SettlementRequestPresentationSnapshot

    public init(state: MeetingFlowState, isBusy: Bool = false) {
        let answered = Set(state.inquiryAnswers.map(\.questionID))
        let activeQuestions = state.inquiryQuestions.filter { !answered.contains($0.id) }
        self.title = "书记员问询"
        self.mode = activeQuestions.isEmpty ? .settlementRequest : .questions
        self.activeQuestions = activeQuestions
        self.settlementRequest = SettlementRequestPresentationSnapshot(
            availability: SettlementRequestAvailabilitySnapshot(state: state, isBusy: isBusy)
        )
    }
}

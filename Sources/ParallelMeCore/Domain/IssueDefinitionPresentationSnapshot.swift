import Foundation

public enum IssueDefinitionPresentationMode: String, Codable, Equatable, Sendable {
    case proposal
    case loading
    case recovery
    case questions
}

public struct IssueDefinitionActionSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var isEnabled: Bool

    public init(title: String, systemImage: String, isEnabled: Bool) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
    }
}

public struct IssueDefinitionRecoveryPresentationSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var detail: String
    public var retryAction: IssueDefinitionActionSnapshot

    public init(isEnabled: Bool = true) {
        title = "书记员这一步没有完成。"
        detail = "可以重新整理本次议题；当前纸页会保留，不需要回首页重写。"
        retryAction = IssueDefinitionActionSnapshot(
            title: "重新整理议题",
            systemImage: "arrow.clockwise",
            isEnabled: isEnabled
        )
    }
}

public struct IssueDefinitionRevisionPresentationSnapshot: Codable, Equatable, Sendable {
    public var prompt: String
    public var action: IssueDefinitionActionSnapshot

    public init(feedback: String, isBusy: Bool) {
        prompt = "哪里不准？直接写给书记员"
        action = IssueDefinitionActionSnapshot(
            title: "修订这版议题",
            systemImage: "arrow.triangle.2.circlepath",
            isEnabled: !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBusy
        )
    }
}

public struct IssueDefinitionStagePresentationSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var rawInput: String
    public var mode: IssueDefinitionPresentationMode
    public var loadingTitle: String
    public var recovery: IssueDefinitionRecoveryPresentationSnapshot
    public var revision: IssueDefinitionRevisionPresentationSnapshot

    public init(state: MeetingFlowState, isBusy: Bool, proposalFeedback: String = "") {
        title = "本次议题"
        rawInput = state.rawInput
        loadingTitle = "书记员正在整理问题"
        recovery = IssueDefinitionRecoveryPresentationSnapshot(isEnabled: !isBusy)
        revision = IssueDefinitionRevisionPresentationSnapshot(
            feedback: proposalFeedback,
            isBusy: isBusy
        )

        if state.issueProposal != nil {
            mode = .proposal
        } else if !state.currentQuestions.isEmpty {
            mode = .questions
        } else if isBusy {
            mode = .loading
        } else {
            mode = .recovery
        }
    }
}

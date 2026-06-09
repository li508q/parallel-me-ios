import Foundation

public enum ScribeAnswerBatchKind: String, Codable, Sendable {
    case definition
    case inquiry
}

public struct ScribeAnswerBatchActionSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var isEnabled: Bool

    public init(title: String, systemImage: String, isEnabled: Bool) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
    }
}

public struct ScribeAnswerOptionPresentationSnapshot: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var label: String
    public var isSelected: Bool
    public var selectedSystemImage: String?

    public init(id: String, label: String, isSelected: Bool) {
        self.id = id
        self.label = label
        self.isSelected = isSelected
        self.selectedSystemImage = isSelected ? "checkmark.circle.fill" : nil
    }

    public init(option: ScribeProbeOption, selection: ScribeProbeAnswerSelection?) {
        self.init(
            id: option.id,
            label: option.label,
            isSelected: selection?.selectedOptionID == option.id
        )
    }

    public init(option: ScribeInquiryOption, selection: ScribeInquiryAnswerSelection?) {
        self.init(
            id: option.id,
            label: option.label,
            isSelected: selection?.selectedOptionID == option.id
        )
    }
}

public struct ScribeCustomAnswerPresentationSnapshot: Codable, Equatable, Sendable {
    public var prompt: String
    public var isSelected: Bool
    public var selectedSystemImage: String?
    public var action: ScribeAnswerBatchActionSnapshot

    public init(kind: ScribeAnswerBatchKind, customText: String, isSelected: Bool) {
        prompt = kind.customAnswerPrompt
        self.isSelected = isSelected
        selectedSystemImage = isSelected ? "checkmark.circle.fill" : nil
        action = ScribeAnswerBatchActionSnapshot(
            title: "选用这句回答",
            systemImage: "text.bubble.fill",
            isEnabled: !customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }
}

public struct ScribeAnswerBatchPresentationSnapshot: Codable, Equatable, Sendable {
    public var kind: ScribeAnswerBatchKind
    public var title: String
    public var progressText: String
    public var submitAction: ScribeAnswerBatchActionSnapshot

    public init(
        kind: ScribeAnswerBatchKind,
        answeredCount: Int,
        questionCount: Int,
        canSubmit: Bool,
        isBusy: Bool
    ) {
        self.kind = kind
        self.title = kind.batchTitle
        self.progressText = "\(answeredCount) / \(questionCount)"
        self.submitAction = ScribeAnswerBatchActionSnapshot(
            title: kind.submitActionTitle,
            systemImage: "checkmark.circle.fill",
            isEnabled: canSubmit && !isBusy
        )
    }

    public init(
        questions: [ScribeQuestion],
        draft: ScribeProbeAnswerBatchDraft,
        isBusy: Bool
    ) {
        let missingCount = draft.missingQuestionIDs(in: questions).count
        self.init(
            kind: .definition,
            answeredCount: questions.count - missingCount,
            questionCount: questions.count,
            canSubmit: draft.canSubmit(questions: questions),
            isBusy: isBusy
        )
    }

    public init(
        questions: [ScribeInquiryQuestion],
        draft: ScribeInquiryAnswerBatchDraft,
        isBusy: Bool
    ) {
        let missingCount = draft.missingQuestionIDs(in: questions).count
        self.init(
            kind: .inquiry,
            answeredCount: questions.count - missingCount,
            questionCount: questions.count,
            canSubmit: draft.canSubmit(questions: questions),
            isBusy: isBusy
        )
    }
}

private extension ScribeAnswerBatchKind {
    var batchTitle: String {
        switch self {
        case .definition:
            return "书记员追问"
        case .inquiry:
            return "本轮问询"
        }
    }

    var submitActionTitle: String {
        switch self {
        case .definition:
            return "提交本轮回答"
        case .inquiry:
            return "提交本轮问询"
        }
    }

    var customAnswerPrompt: String {
        switch self {
        case .definition:
            return "写下更准确的回答"
        case .inquiry:
            return "写下你的真实答案"
        }
    }
}

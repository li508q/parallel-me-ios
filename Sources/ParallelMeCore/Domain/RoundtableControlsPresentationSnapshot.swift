import Foundation

public struct RoundtableControlButtonSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var isEnabled: Bool

    public init(title: String, systemImage: String, isEnabled: Bool) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
    }
}

public struct RoundtableTextQuestionControlSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var prompt: String
    public var action: RoundtableControlButtonSnapshot

    public init(title: String, prompt: String, action: RoundtableControlButtonSnapshot) {
        self.title = title
        self.prompt = prompt
        self.action = action
    }
}

public struct RoundtableVoiceQuestionControlSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var pickerTitle: String
    public var prompt: String
    public var action: RoundtableControlButtonSnapshot

    public init(
        title: String,
        pickerTitle: String,
        prompt: String,
        action: RoundtableControlButtonSnapshot
    ) {
        self.title = title
        self.pickerTitle = pickerTitle
        self.prompt = prompt
        self.action = action
    }
}

public struct RoundtableDuelControlSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var fromPickerTitle: String
    public var toPickerTitle: String
    public var action: RoundtableControlButtonSnapshot

    public init(
        title: String,
        fromPickerTitle: String,
        toPickerTitle: String,
        action: RoundtableControlButtonSnapshot
    ) {
        self.title = title
        self.fromPickerTitle = fromPickerTitle
        self.toPickerTitle = toPickerTitle
        self.action = action
    }
}

public struct RoundtableControlsPresentationSnapshot: Codable, Equatable, Sendable {
    public var statusSystemImage: String
    public var continueAction: RoundtableControlButtonSnapshot
    public var inquiryAction: RoundtableControlButtonSnapshot
    public var askTable: RoundtableTextQuestionControlSnapshot
    public var askVoice: RoundtableVoiceQuestionControlSnapshot
    public var duel: RoundtableDuelControlSnapshot

    public init(
        availability: RoundtableActionAvailabilitySnapshot,
        tableQuestion: String,
        voiceQuestion: String,
        selectedVoice: VoiceID,
        duelFrom: VoiceID,
        duelTo: VoiceID
    ) {
        statusSystemImage = availability.canStartInquiry ? "checkmark.seal.fill" : "hourglass"
        continueAction = RoundtableControlButtonSnapshot(
            title: "继续一轮",
            systemImage: "arrow.triangle.2.circlepath",
            isEnabled: availability.canContinueRoundtable
        )
        inquiryAction = RoundtableControlButtonSnapshot(
            title: availability.inquiryActionTitle,
            systemImage: "arrow.right.circle.fill",
            isEnabled: availability.canStartInquiry
        )
        askTable = RoundtableTextQuestionControlSnapshot(
            title: "问全桌",
            prompt: "把你想抛给全桌的问题写在这里",
            action: RoundtableControlButtonSnapshot(
                title: "发送给全桌",
                systemImage: "paperplane.fill",
                isEnabled: availability.canAskTable && !tableQuestion.normalizedRoundtableControlText.isEmpty
            )
        )
        askVoice = RoundtableVoiceQuestionControlSnapshot(
            title: "问一声",
            pickerTitle: "声音",
            prompt: "问这一声一句",
            action: RoundtableControlButtonSnapshot(
                title: "发送给\(selectedVoice.displayName)",
                systemImage: "person.wave.2.fill",
                isEnabled: availability.canAskVoice && !voiceQuestion.normalizedRoundtableControlText.isEmpty
            )
        )
        duel = RoundtableDuelControlSnapshot(
            title: "让两声对话",
            fromPickerTitle: "发问",
            toPickerTitle: "回应",
            action: RoundtableControlButtonSnapshot(
                title: "开始对话",
                systemImage: "arrow.left.and.right",
                isEnabled: availability.canStartDuel && duelFrom != duelTo
            )
        )
    }
}

private extension String {
    var normalizedRoundtableControlText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

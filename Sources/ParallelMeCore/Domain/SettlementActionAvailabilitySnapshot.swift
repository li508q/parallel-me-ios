public enum SettlementActionMessageTone: String, Codable, Sendable {
    case muted
    case warning
}

public struct SettlementActionAvailabilitySnapshot: Equatable, Sendable {
    public var canApplyRevision: Bool
    public var canArchive: Bool
    public var message: String
    public var messageTone: SettlementActionMessageTone

    public init(draft: SettlementRevisionDraft, isBusy: Bool = false) {
        if isBusy {
            self.canApplyRevision = false
            self.canArchive = false
            self.message = "正在处理这一步，先不要修改或保存。"
            self.messageTone = .muted
        } else if draft.hasEmptyRequiredText {
            self.canApplyRevision = false
            self.canArchive = false
            self.message = "每一栏都需要保留一句可归档的语言。"
            self.messageTone = .warning
        } else if draft.hasChanges {
            self.canApplyRevision = true
            self.canArchive = false
            self.message = "应用修订后再保存纸页，归档会使用你确认过的文本。"
            self.messageTone = .muted
        } else {
            self.canApplyRevision = false
            self.canArchive = true
            self.message = "改动后再应用修订；保存纸页会使用当前落定。"
            self.messageTone = .muted
        }
    }
}

public struct SettlementStageSnapshot: Equatable, Sendable {
    public var stage: MeetingStage
    public var hasSettlement: Bool
    public var canShowSettlementEditor: Bool
    public var title: String
    public var detail: String
    public var systemImage: String
    public var recoveryActionTitle: String

    public init(state: MeetingFlowState) {
        self.stage = state.stage
        self.hasSettlement = state.heartSettlement != nil
        self.canShowSettlementEditor = state.stage == .settlement && state.heartSettlement != nil

        if canShowSettlementEditor {
            self.title = "本心落定"
            self.detail = "确认这五个模块后，就可以把这张纸页保存到本机。"
            self.systemImage = "checkmark.seal.fill"
            self.recoveryActionTitle = "继续落定"
        } else {
            self.title = "本心落定缺失"
            self.detail = "这张纸页处在落定阶段，但没有找到可修订、可保存的五模块内容。先回首页，从纸页库重新打开，或保留这张纸页用于排查。"
            self.systemImage = "exclamationmark.triangle.fill"
            self.recoveryActionTitle = "回首页"
        }
    }
}

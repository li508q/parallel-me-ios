public struct MeetingExportAvailabilitySnapshot: Equatable, Sendable {
    public var stage: MeetingStage
    public var canExport: Bool
    public var shouldShowExportControl: Bool
    public var actionTitle: String
    public var accessibilityHint: String
    public var blockerMessage: String?

    public init(state: MeetingFlowState) {
        self.init(
            stage: state.stage,
            hasCompleteSettlement: state.heartSettlement?.isComplete == true
        )
    }

    public init(stage: MeetingStage, hasCompleteSettlement: Bool? = nil) {
        self.stage = stage
        let settlementIsExportable = hasCompleteSettlement ?? (stage == .archived)
        self.canExport = stage == .archived && settlementIsExportable
        self.shouldShowExportControl = stage == .archived

        if canExport {
            self.actionTitle = "导出纸页"
            self.accessibilityHint = "通过 iOS 分享这张已归档纸页"
            self.blockerMessage = nil
        } else if stage == .archived {
            self.actionTitle = "无法导出"
            self.accessibilityHint = "这张归档纸页缺少完整本心落定，不能导出"
            self.blockerMessage = "这张已归档纸页缺少完整本心落定，暂时不能导出。"
        } else {
            self.actionTitle = "归档后导出"
            self.accessibilityHint = "完成落定并保存纸页后才能导出"
            self.blockerMessage = nil
        }
    }
}

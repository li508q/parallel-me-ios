public struct MeetingExportAvailabilitySnapshot: Equatable, Sendable {
    public var stage: MeetingStage
    public var canExport: Bool
    public var actionTitle: String
    public var accessibilityHint: String

    public init(state: MeetingFlowState) {
        self.init(stage: state.stage)
    }

    public init(stage: MeetingStage) {
        self.stage = stage
        self.canExport = stage == .archived
        if stage == .archived {
            self.actionTitle = "导出纸页"
            self.accessibilityHint = "通过 iOS 分享这张已归档纸页"
        } else {
            self.actionTitle = "归档后导出"
            self.accessibilityHint = "完成落定并保存纸页后才能导出"
        }
    }
}

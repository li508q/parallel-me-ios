public struct RuntimePreferencesActionAvailabilitySnapshot: Equatable, Sendable {
    public var canEdit: Bool
    public var canSave: Bool
    public var canClear: Bool
    public var message: String?

    public init(isBusy: Bool = false) {
        self.canEdit = !isBusy
        self.canSave = !isBusy
        self.canClear = !isBusy
        self.message = isBusy ? "运行配置正在处理，完成前先别修改。" : nil
    }
}

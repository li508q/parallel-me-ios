public struct PaperLibraryActionAvailabilitySnapshot: Equatable, Sendable {
    public var canRestore: Bool
    public var canDelete: Bool
    public var message: String?

    public init(isBusy: Bool = false) {
        self.canRestore = !isBusy
        self.canDelete = !isBusy
        self.message = isBusy ? "纸页库正在处理，完成前先别打开或删除纸页。" : nil
    }
}

public struct RuntimePreferencesActionAvailabilitySnapshot: Equatable, Sendable {
    public var canEdit: Bool
    public var canSave: Bool
    public var canClear: Bool
    public var message: String?

    public init(
        providerSettings: ProviderRuntimeSettings = ProviderRuntimeSettings(),
        isBusy: Bool = false
    ) {
        self.canEdit = !isBusy
        self.canSave = !isBusy && providerSettings.isUsable
        self.canClear = !isBusy
        if isBusy {
            self.message = "运行配置正在处理，完成前先别修改。"
        } else if !providerSettings.isUsable {
            self.message = "OpenAI 配置还不完整，检查 Base URL、模型名和 API Key 后再保存。"
        } else {
            self.message = nil
        }
    }
}

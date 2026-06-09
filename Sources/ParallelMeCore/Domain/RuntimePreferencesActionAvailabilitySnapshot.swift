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

public struct RuntimePreferencesControlSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var isEnabled: Bool

    public init(title: String, systemImage: String, isEnabled: Bool) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
    }
}

public struct RuntimePreferencesStatusMessageSnapshot: Codable, Equatable, Sendable {
    public var text: String
    public var systemImage: String
    public var dismissSystemImage: String

    public init(text: String) {
        self.text = text
        self.systemImage = "checkmark.circle.fill"
        self.dismissSystemImage = "xmark"
    }
}

public struct RuntimePreferencesPresentationSnapshot: Codable, Equatable, Sendable {
    public var providerPickerTitle: String
    public var shouldShowOpenAIFields: Bool
    public var baseURLPrompt: String
    public var modelPrompt: String
    public var apiKeyPrompt: String
    public var contextSectionTitle: String
    public var meCardPrompt: String
    public var tasteProfilePrompt: String
    public var canEdit: Bool
    public var saveAction: RuntimePreferencesControlSnapshot
    public var clearAction: RuntimePreferencesControlSnapshot
    public var advisoryMessage: String?
    public var statusMessage: RuntimePreferencesStatusMessageSnapshot?

    public init(
        providerSettings: ProviderRuntimeSettings = ProviderRuntimeSettings(),
        isBusy: Bool = false,
        statusMessage: String? = nil
    ) {
        let availability = RuntimePreferencesActionAvailabilitySnapshot(
            providerSettings: providerSettings,
            isBusy: isBusy
        )
        self.providerPickerTitle = "Provider"
        self.shouldShowOpenAIFields = providerSettings.mode == .openAICompatible
        self.baseURLPrompt = "Base URL"
        self.modelPrompt = "Model"
        self.apiKeyPrompt = "API Key"
        self.contextSectionTitle = "个人上下文"
        self.meCardPrompt = "我是谁 / 长期处境"
        self.tasteProfilePrompt = "偏好的语气 / 判断方式"
        self.canEdit = availability.canEdit
        self.saveAction = RuntimePreferencesControlSnapshot(
            title: "保存",
            systemImage: "square.and.arrow.down",
            isEnabled: availability.canSave
        )
        self.clearAction = RuntimePreferencesControlSnapshot(
            title: "清空",
            systemImage: "trash",
            isEnabled: availability.canClear
        )
        self.advisoryMessage = availability.message
        self.statusMessage = statusMessage.map(RuntimePreferencesStatusMessageSnapshot.init(text:))
    }
}

import Foundation

public struct HomeStartActionSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var isEnabled: Bool

    public init(title: String, systemImage: String, isEnabled: Bool) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
    }
}

public struct PetitionStarterPromptPresentationSnapshot: Codable, Equatable, Sendable, Identifiable {
    public var prompt: PetitionStarterPrompt
    public var accessibilityLabel: String
    public var accessibilityHint: String

    public init(prompt: PetitionStarterPrompt) {
        self.prompt = prompt
        self.accessibilityLabel = prompt.title
        self.accessibilityHint = "填入起笔困惑：\(prompt.seedText)"
    }

    public var id: String {
        prompt.id
    }
}

public struct HomeStartPresentationSnapshot: Codable, Equatable, Sendable {
    public var brand: String
    public var headline: String
    public var detail: String
    public var readiness: MeetingStartReadinessSnapshot
    public var shouldShowStarterPrompts: Bool
    public var canUseStarterPrompts: Bool
    public var starterPrompts: [PetitionStarterPromptPresentationSnapshot]
    public var canEditPetition: Bool
    public var startAction: HomeStartActionSnapshot

    public init(
        petition: String,
        providerSettings: ProviderRuntimeSettings,
        isBusy: Bool = false,
        starterPrompts: [PetitionStarterPrompt] = PetitionStarterPrompts.all
    ) {
        let readiness = MeetingStartReadinessSnapshot(
            petition: petition,
            providerSettings: providerSettings,
            isBusy: isBusy
        )
        self.brand = "ParallelMe"
        self.headline = "今天，想听见哪件事？"
        self.detail = "书记员先帮你定义议题，再让五声坐下来慢慢摊开。"
        self.readiness = readiness
        self.shouldShowStarterPrompts = petition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        self.canUseStarterPrompts = readiness.canUseStarterPrompts
        self.starterPrompts = starterPrompts.map(PetitionStarterPromptPresentationSnapshot.init(prompt:))
        self.canEditPetition = readiness.canEditPetition
        self.startAction = HomeStartActionSnapshot(
            title: readiness.actionTitle,
            systemImage: "arrow.right.circle.fill",
            isEnabled: readiness.canStart
        )
    }
}

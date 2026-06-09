import Foundation

public enum MeetingStartBlocker: String, Codable, Equatable, Sendable, CaseIterable {
    case emptyPetition
    case invalidBaseURL
    case missingModel
    case missingAPIKey
    case busy
}

public struct MeetingStartReadinessSnapshot: Codable, Equatable, Sendable {
    public var blockers: [MeetingStartBlocker]
    public var providerMode: ProviderRuntimeMode

    public init(
        petition: String,
        providerSettings: ProviderRuntimeSettings,
        isBusy: Bool = false
    ) {
        var blockers: [MeetingStartBlocker] = []
        if petition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blockers.append(.emptyPetition)
        }
        if providerSettings.mode == .openAICompatible {
            if providerSettings.resolvedBaseURL == nil {
                blockers.append(.invalidBaseURL)
            }
            if providerSettings.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blockers.append(.missingModel)
            }
            if providerSettings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blockers.append(.missingAPIKey)
            }
        }
        if isBusy {
            blockers.append(.busy)
        }

        self.blockers = blockers
        self.providerMode = providerSettings.mode
    }

    public var canStart: Bool {
        blockers.isEmpty
    }

    public var canEditPetition: Bool {
        !blockers.contains(.busy)
    }

    public var canUseStarterPrompts: Bool {
        canEditPetition
    }

    public var title: String {
        if blockers.contains(.busy) {
            return "书记员正在整理"
        }
        if blockers.contains(.emptyPetition) {
            return "先写下一句真实困惑"
        }
        let missingProviderLabels = providerBlockerLabels
        if !missingProviderLabels.isEmpty {
            return "模型配置还不完整"
        }
        return "可以开始五声圆桌"
    }

    public var detail: String {
        if blockers.contains(.busy) {
            return "这一步完成前先别重复提交，纸页会自动保存。"
        }
        if blockers.contains(.emptyPetition) {
            return "可以从上面的起点卡片开始，也可以直接写自己的第一句话。"
        }
        let missingProviderLabels = providerBlockerLabels
        if !missingProviderLabels.isEmpty {
            return "OpenAI 模式还差：\(missingProviderLabels.joined(separator: "、"))。"
        }
        switch providerMode {
        case .demo:
            return "Demo 模式会在本机生成完整流程，适合先体验产品动线。"
        case .openAICompatible:
            return "这次会议会使用当前 OpenAI-compatible 配置，并把非敏感运行信息记录到纸页。"
        }
    }

    public var actionTitle: String {
        if blockers.contains(.busy) {
            return "书记员整理中"
        }
        return canStart ? "开始五声圆桌" : "还不能开始"
    }

    private var providerBlockerLabels: [String] {
        blockers.compactMap { blocker in
            switch blocker {
            case .invalidBaseURL:
                return "Base URL"
            case .missingModel:
                return "模型名"
            case .missingAPIKey:
                return "API Key"
            case .emptyPetition, .busy:
                return nil
            }
        }
    }
}

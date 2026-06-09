import Foundation

public struct MeetingRuntimeSnapshot: Codable, Equatable, Sendable {
    public var providerMode: ProviderRuntimeMode
    public var providerModel: String
    public var providerBaseURLString: String?
    public var context: ProviderContext?

    public init(
        providerMode: ProviderRuntimeMode = .demo,
        providerModel: String = "",
        providerBaseURLString: String? = nil,
        context: ProviderContext? = nil
    ) {
        self.providerMode = providerMode
        self.providerModel = providerModel
        self.providerBaseURLString = providerBaseURLString
        self.context = context
    }

    public init(settings: ProviderRuntimeSettings, context: ProviderContext? = nil) {
        let settings = settings.normalized
        self.init(
            providerMode: settings.mode,
            providerModel: settings.model,
            providerBaseURLString: settings.baseURLString,
            context: context
        )
    }

    public var normalized: MeetingRuntimeSnapshot {
        let context = context?.normalized
        return MeetingRuntimeSnapshot(
            providerMode: providerMode,
            providerModel: providerModel.normalizedRuntimeSnapshotText ?? providerMode.displayName,
            providerBaseURLString: providerBaseURLString.normalizedRuntimeSnapshotText,
            context: context?.isEmpty == true ? nil : context
        )
    }

    public var providerLabel: String {
        switch providerMode {
        case .demo:
            return "Demo"
        case .openAICompatible:
            return providerModel.normalizedRuntimeSnapshotText ?? "OpenAI"
        }
    }

    public var contextSummary: String? {
        guard let context = context?.normalized, !context.isEmpty else { return nil }
        var parts: [String] = []
        if context.meCard != nil { parts.append("个人背景") }
        if context.tasteProfile != nil { parts.append("回应偏好") }
        return parts.joined(separator: " · ")
    }
}

private extension Optional where Wrapped == String {
    var normalizedRuntimeSnapshotText: String? {
        guard let trimmed = self?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

private extension String {
    var normalizedRuntimeSnapshotText: String? {
        Optional(self).normalizedRuntimeSnapshotText
    }
}

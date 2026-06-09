import Foundation

public enum VoiceOpeningDetailKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case protectedValue = "protected_value"
    case concern
    case taskEvidence = "task_evidence"
    case pull

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .protectedValue:
            return "守护"
        case .concern:
            return "担心"
        case .taskEvidence:
            return "证据"
        case .pull:
            return "追问职责"
        }
    }
}

public struct VoiceOpeningDetailSnapshot: Codable, Equatable, Sendable, Identifiable {
    public var kind: VoiceOpeningDetailKind
    public var title: String
    public var body: String

    public var id: String {
        kind.rawValue
    }

    public init(kind: VoiceOpeningDetailKind, body: String) {
        self.kind = kind
        self.title = kind.title
        self.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isMeaningful: Bool {
        !title.isEmpty && !body.isEmpty
    }
}

public struct VoiceOpeningSnapshot: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var voiceID: VoiceID
    public var name: String
    public var thesis: String
    public var details: [VoiceOpeningDetailSnapshot]

    public init(
        id: String,
        voiceID: VoiceID,
        name: String,
        thesis: String,
        details: [VoiceOpeningDetailSnapshot]
    ) {
        self.id = id
        self.voiceID = voiceID
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.thesis = thesis.trimmingCharacters(in: .whitespacesAndNewlines)
        self.details = details
    }

    public init(turn: VoiceOpeningTurn) {
        self.init(
            id: turn.id,
            voiceID: turn.voiceID,
            name: turn.name,
            thesis: turn.payload.thesis,
            details: VoiceOpeningDetailKind.allCases.map { kind in
                VoiceOpeningDetailSnapshot(kind: kind, body: turn.payload.text(for: kind))
            }
        )
    }

    public var isComplete: Bool {
        !name.isEmpty
            && !thesis.isEmpty
            && details.map(\.kind) == VoiceOpeningDetailKind.allCases
            && details.allSatisfy(\.isMeaningful)
    }
}

private extension VoiceOpeningPayload {
    func text(for kind: VoiceOpeningDetailKind) -> String {
        switch kind {
        case .protectedValue:
            return protectedValue
        case .concern:
            return concern
        case .taskEvidence:
            return taskEvidence
        case .pull:
            return pull
        }
    }
}

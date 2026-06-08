import Foundation

public enum VoiceID: String, CaseIterable, Codable, Sendable, Identifiable {
    case lay
    case money
    case roam
    case filial
    case future

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .lay: "躺平的我"
        case .money: "搞钱的我"
        case .roam: "出走的我"
        case .filial: "被牵挂的我"
        case .future: "5 年后的我"
        }
    }
}

public enum ProbePurpose: String, CaseIterable, Codable, Sendable, Identifiable {
    case surfaceDilemma = "surface_dilemma"
    case currentConstraints = "current_constraints"
    case coreFears = "core_fears"
    case expectedResolution = "expected_resolution"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .surfaceDilemma: "具象化的困惑"
        case .currentConstraints: "真实的处境"
        case .coreFears: "隐秘的关切"
        case .expectedResolution: "渴望的终局"
        }
    }
}

public enum SettlementModuleID: String, CaseIterable, Codable, Sendable, Identifiable {
    case creativeHopelessness = "creative_hopelessness"
    case coreValues = "core_values"
    case costAcceptance = "cost_acceptance"
    case minimumAction = "minimum_action"
    case dialecticSynthesis = "dialectic_synthesis"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .creativeHopelessness: "创造性无望"
        case .coreValues: "核心价值主轴"
        case .costAcceptance: "痛苦接纳契约"
        case .minimumAction: "最小行动承诺"
        case .dialecticSynthesis: "正反合"
        }
    }
}

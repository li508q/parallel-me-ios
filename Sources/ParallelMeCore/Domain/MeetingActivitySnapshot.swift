import Foundation

public enum MeetingActivityKind: String, CaseIterable, Codable, Sendable {
    case savingRuntimePreferences
    case clearingRuntimePreferences
    case startingMeeting
    case submittingDefinitionAnswers
    case refiningProposal
    case confirmingProposal
    case continuingRoundtable
    case askingTable
    case askingVoice
    case startingDuel
    case startingInquiry
    case submittingInquiryAnswers
    case requestingSettlement
    case revisingSettlement
    case archivingPaper
    case restoringPaper
    case deletingPaper
}

public struct MeetingActivitySnapshot: Equatable, Identifiable, Sendable {
    public var kind: MeetingActivityKind
    public var title: String
    public var detail: String
    public var systemImage: String
    public var usesProvider: Bool

    public var id: String { kind.rawValue }

    public init(kind: MeetingActivityKind) {
        self.kind = kind

        switch kind {
        case .savingRuntimePreferences:
            title = "正在保存运行配置"
            detail = "Provider 和个人上下文会保存在这台设备上。"
            systemImage = "square.and.arrow.down"
            usesProvider = false
        case .clearingRuntimePreferences:
            title = "正在清空运行配置"
            detail = "会移除本地 Provider 配置和个人上下文。"
            systemImage = "trash"
            usesProvider = false
        case .startingMeeting:
            title = "书记员正在接住这件事"
            detail = "先把原始困惑整理成可追问或可确认的议题。"
            systemImage = "pencil.and.outline"
            usesProvider = true
        case .submittingDefinitionAnswers:
            title = "书记员正在吸收本轮回答"
            detail = "这一轮问题会一起送回，避免只处理最后一个答案。"
            systemImage = "checkmark.bubble"
            usesProvider = true
        case .refiningProposal:
            title = "书记员正在修订议题"
            detail = "会优先按照你的反馈改写当前提案。"
            systemImage = "arrow.triangle.2.circlepath"
            usesProvider = true
        case .confirmingProposal:
            title = "五声正在入席"
            detail = "固定五声会各自完成开场，不新增临时角色。"
            systemImage = "person.3.sequence"
            usesProvider = true
        case .continuingRoundtable:
            title = "圆桌正在继续"
            detail = "五声会基于已有议题和发言补充一轮。"
            systemImage = "arrow.triangle.2.circlepath"
            usesProvider = true
        case .askingTable:
            title = "正在把问题抛给全桌"
            detail = "五声都会回应你刚刚提出的问题。"
            systemImage = "paperplane"
            usesProvider = true
        case .askingVoice:
            title = "正在追问其中一声"
            detail = "只有被选中的声音会回应这句追问。"
            systemImage = "person.wave.2"
            usesProvider = true
        case .startingDuel:
            title = "正在安排两声对话"
            detail = "只有指定的两声会围绕当前议题交锋。"
            systemImage = "arrow.left.and.right"
            usesProvider = true
        case .startingInquiry:
            title = "书记员正在进入问询"
            detail = "没有固定题数上限，只补齐足够生成落定的证据。"
            systemImage = "questionmark.bubble"
            usesProvider = true
        case .submittingInquiryAnswers:
            title = "书记员正在校对问询证据"
            detail = "本轮问询会作为一个整体提交，再判断是否足够落定。"
            systemImage = "checkmark.circle"
            usesProvider = true
        case .requestingSettlement:
            title = "正在生成本心落定"
            detail = "会基于圆桌、问询和证据账本整理五个落定模块。"
            systemImage = "sparkles"
            usesProvider = true
        case .revisingSettlement:
            title = "正在应用你的修订"
            detail = "归档会使用你确认过的最终文本。"
            systemImage = "pencil.and.scribble"
            usesProvider = false
        case .archivingPaper:
            title = "正在保存纸页"
            detail = "这张纸页会进入本机纸页库，可稍后重新打开。"
            systemImage = "archivebox"
            usesProvider = false
        case .restoringPaper:
            title = "正在打开纸页"
            detail = "未完成纸页会重建运行环境，已归档纸页可离线阅读。"
            systemImage = "arrow.uturn.forward"
            usesProvider = false
        case .deletingPaper:
            title = "正在删除纸页"
            detail = "本机纸页库会同步移除这条记录。"
            systemImage = "trash"
            usesProvider = false
        }
    }
}

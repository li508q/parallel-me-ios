import Foundation

public struct PetitionStarterPrompt: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var detail: String
    public var seedText: String
    public var accentVoiceID: VoiceID

    public init(
        id: String,
        title: String,
        detail: String,
        seedText: String,
        accentVoiceID: VoiceID
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.seedText = seedText
        self.accentVoiceID = accentVoiceID
    }
}

public enum PetitionStarterPrompts {
    public static let all: [PetitionStarterPrompt] = [
        PetitionStarterPrompt(
            id: "work-cashflow",
            title: "想离开，但怕断粮",
            detail: "工作、现金流、身体余量互相拉扯",
            seedText: "我想离开现在的工作，但又怕现金流断掉，也怕自己只是太累了才想逃。",
            accentVoiceID: .money
        ),
        PetitionStarterPrompt(
            id: "family-self",
            title: "想选自己，又怕伤人",
            detail: "家庭期待和自己的愿望都是真的",
            seedText: "我想按自己的方式做一个决定，但很怕让家人失望，也怕最后证明自己太自私。",
            accentVoiceID: .filial
        ),
        PetitionStarterPrompt(
            id: "rest-ambition",
            title: "想休息，又怕落后",
            detail: "恢复、竞争和长期方向卡在一起",
            seedText: "我很想停下来休息一段时间，可是一想到同龄人都在往前走，就觉得自己会被落下。",
            accentVoiceID: .lay
        ),
        PetitionStarterPrompt(
            id: "new-road",
            title: "想换路，但不敢赌",
            detail: "新方向有吸引力，旧轨道也有安全感",
            seedText: "我想开始一个新的方向，但不确定这是不是冲动，也不知道要付出哪些代价。",
            accentVoiceID: .roam
        )
    ]
}

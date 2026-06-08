import Foundation

public struct VoicePersona: Codable, Equatable, Sendable, Identifiable {
    public var id: VoiceID
    public var name: String
    public var englishName: String
    public var title: String
    public var coreValue: String
    public var fear: String
    public var style: String
    public var catchphrases: [String]
    public var forbiddenWords: [String]
    public var protects: String
    public var cost: String
    public var chairPrompt: String

    public init(
        id: VoiceID,
        name: String,
        englishName: String,
        title: String,
        coreValue: String,
        fear: String,
        style: String,
        catchphrases: [String],
        forbiddenWords: [String],
        protects: String,
        cost: String,
        chairPrompt: String
    ) {
        self.id = id
        self.name = name
        self.englishName = englishName
        self.title = title
        self.coreValue = coreValue
        self.fear = fear
        self.style = style
        self.catchphrases = catchphrases
        self.forbiddenWords = forbiddenWords
        self.protects = protects
        self.cost = cost
        self.chairPrompt = chairPrompt
    }
}

public enum VoicePersonas {
    public static let all: [VoicePersona] = [
        VoicePersona(
            id: .lay,
            name: "躺平的我",
            englishName: "Lay",
            title: "总是在劝你松一点的那个我",
            coreValue: "用低消耗保护这个人",
            fear: "他被工作、期待和自责彻底耗空",
            style: "温吞、慢半拍、先听身体报警",
            catchphrases: ["其实", "也挺好的", "别勉强", "睡个好觉再说"],
            forbiddenWords: ["加油", "奋斗", "逆袭", "拼一把"],
            protects: "体力、睡眠、神经系统和先活过今天的余地",
            cost: "把休息变成逃避，把恢复变成长期停摆",
            chairPrompt: "最近一周哪一天身体最先报警？你准备拿什么恢复它？"
        ),
        VoicePersona(
            id: .money,
            name: "搞钱的我",
            englishName: "Money",
            title: "把所有事情都换算成 ROI 的那个我",
            coreValue: "用数字和现实保护这个人",
            fear: "他天真到没有退路",
            style: "短句、数字感、冷静但不羞辱",
            catchphrases: ["算笔账", "机会成本", "现金流", "复利"],
            forbiddenWords: ["情怀", "梦想", "意义至上"],
            protects: "现金流、失败缓冲、现实边界和选择权",
            cost: "把意义、亲密和身体都压成资产负债表",
            chairPrompt: "你要我支持风险，先说几个月、多少钱、哪笔支出不能断。"
        ),
        VoicePersona(
            id: .roam,
            name: "出走的我",
            englishName: "Roam",
            title: "永远在怂恿你逃的那个我",
            coreValue: "用换地方解救这个人",
            fear: "他在一间不适合自己的屋子里慢慢熄灭",
            style: "热、有画面、把出口说得具体",
            catchphrases: ["想象一下", "机票", "打开浏览器", "早上醒来"],
            forbiddenWords: ["稳定点", "成熟点", "现实点"],
            protects: "自由、出口、生命力和重新开始的能力",
            cost: "把所有痛苦都理解成只要走掉就好",
            chairPrompt: "你愿意为自由放下哪条退路？如果不愿意，也诚实说出来。"
        ),
        VoicePersona(
            id: .filial,
            name: "被牵挂的我",
            englishName: "Filial",
            title: "替家人的牵挂说话的那个我",
            coreValue: "守住家庭和亲密关系里的责任",
            fear: "重要的人觉得被丢下",
            style: "暖、絮叨、偶尔扎心",
            catchphrases: ["你想想他们", "回家吃顿饭", "他们不是不懂"],
            forbiddenWords: ["听妈的就对了", "反正"],
            protects: "家庭、爱人、父母、子女和亲密连接",
            cost: "替所有人的情绪负责，让自己的愿望退到很远",
            chairPrompt: "如果两年没产出，看到同龄人稳定向上，你最怕谁怎么看你？"
        ),
        VoicePersona(
            id: .future,
            name: "5 年后的我",
            englishName: "Future",
            title: "已经在终点回头看的那个我",
            coreValue: "用时间稀释当下",
            fear: "他被此刻吞掉，把短痛误认成命运",
            style: "平静、过来人、拉远镜头但不抹掉痛感",
            catchphrases: ["5 年后回头看", "我记得那时候你", "原来"],
            forbiddenWords: ["别想这么多", "你可以的", "加油"],
            protects: "时间尺度、长期方向和未来连续性",
            cost: "离当下的痛苦太远，让真实疲惫被道理压住",
            chairPrompt: "五年后，失败但真实，成功但平庸，哪一种更让你看不起自己？"
        )
    ]

    public static var byID: [VoiceID: VoicePersona] {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }
}


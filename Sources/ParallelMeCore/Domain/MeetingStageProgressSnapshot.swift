import Foundation

public struct MeetingStageProgressItem: Codable, Equatable, Sendable, Identifiable {
    public var stage: MeetingStage
    public var title: String
    public var detail: String
    public var isCurrent: Bool
    public var isCompleted: Bool

    public init(
        stage: MeetingStage,
        title: String,
        detail: String,
        isCurrent: Bool,
        isCompleted: Bool
    ) {
        self.stage = stage
        self.title = title
        self.detail = detail
        self.isCurrent = isCurrent
        self.isCompleted = isCompleted
    }

    public var id: MeetingStage {
        stage
    }
}

public struct MeetingStageProgressSnapshot: Codable, Equatable, Sendable {
    public var items: [MeetingStageProgressItem]
    public var currentIndex: Int

    public init(stage: MeetingStage) {
        let stages = MeetingStage.allCases
        let currentIndex = stages.firstIndex(of: stage) ?? 0
        self.currentIndex = currentIndex
        self.items = stages.enumerated().map { index, item in
            MeetingStageProgressItem(
                stage: item,
                title: item.progressTitle,
                detail: item.progressDetail,
                isCurrent: item == stage,
                isCompleted: index < currentIndex
            )
        }
    }

    public var totalCount: Int {
        items.count
    }

    public var currentPosition: Int {
        currentIndex + 1
    }

    public var currentItem: MeetingStageProgressItem {
        items[currentIndex]
    }
}

private extension MeetingStage {
    var progressTitle: String {
        switch self {
        case .defining:
            return "定义"
        case .roundtable:
            return "圆桌"
        case .inquiry:
            return "问询"
        case .settlement:
            return "落定"
        case .archived:
            return "归档"
        }
    }

    var progressDetail: String {
        switch self {
        case .defining:
            return "书记员整理四键议题"
        case .roundtable:
            return "五声围绕任务发言"
        case .inquiry:
            return "补齐落定证据"
        case .settlement:
            return "确认可执行承诺"
        case .archived:
            return "保存为本地纸页"
        }
    }
}

import Foundation

public struct MeetingLibrarySnapshot: Codable, Equatable, Sendable {
    public var recent: [MeetingSummary]
    public var unfinished: [MeetingSummary]
    public var archived: [MeetingSummary]
    public var totalCount: Int

    public init(
        recent: [MeetingSummary] = [],
        unfinished: [MeetingSummary] = [],
        archived: [MeetingSummary] = [],
        totalCount: Int = 0
    ) {
        self.recent = recent
        self.unfinished = unfinished
        self.archived = archived
        self.totalCount = totalCount
    }

    public init(states: [MeetingFlowState], recentLimit: Int = 5) {
        let summaries = states
            .map(MeetingSummary.init(state:))
            .sorted { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.updatedAt > rhs.updatedAt
            }

        self.init(
            recent: Array(summaries.prefix(max(0, recentLimit))),
            unfinished: summaries.filter { $0.stage != .archived },
            archived: summaries.filter { $0.stage == .archived },
            totalCount: summaries.count
        )
    }

    public var resumable: MeetingSummary? {
        unfinished.first
    }

    public var archivedCount: Int {
        archived.count
    }

    public var unfinishedCount: Int {
        unfinished.count
    }

    public var isEmpty: Bool {
        totalCount == 0
    }
}

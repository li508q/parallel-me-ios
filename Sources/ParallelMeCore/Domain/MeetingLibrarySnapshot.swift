import Foundation

public enum MeetingLibraryFilter: String, CaseIterable, Codable, Sendable, Identifiable {
    case all
    case unfinished
    case archived

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all:
            return "全部"
        case .unfinished:
            return "未完成"
        case .archived:
            return "已归档"
        }
    }

    fileprivate func includes(_ summary: MeetingSummary) -> Bool {
        switch self {
        case .all:
            return true
        case .unfinished:
            return summary.stage != .archived
        case .archived:
            return summary.stage == .archived
        }
    }
}

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
        self.init(summaries: states.map(MeetingSummary.init(state:)), recentLimit: recentLimit)
    }

    public init(summaries: [MeetingSummary], recentLimit: Int = 5) {
        let sorted = summaries
            .sorted { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.updatedAt > rhs.updatedAt
            }

        self.init(
            recent: Array(sorted.prefix(max(0, recentLimit))),
            unfinished: sorted.filter { $0.stage != .archived },
            archived: sorted.filter { $0.stage == .archived },
            totalCount: sorted.count
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

    public func filtered(
        searchText: String,
        filter: MeetingLibraryFilter = .all,
        recentLimit: Int = 5
    ) -> MeetingLibrarySnapshot {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty || filter != .all else { return self }
        return MeetingLibrarySnapshot(
            summaries: allSummaries.filter { summary in
                filter.includes(summary) && (query.isEmpty || summary.matches(searchText: query))
            },
            recentLimit: recentLimit
        )
    }

    private var allSummaries: [MeetingSummary] {
        unfinished + archived
    }
}

public enum MeetingLibraryPresentationGroupKind: String, Codable, Sendable, Identifiable {
    case unfinished
    case archived

    public var id: String { rawValue }
}

public struct MeetingLibraryPresentationGroup: Codable, Equatable, Sendable, Identifiable {
    public var kind: MeetingLibraryPresentationGroupKind
    public var title: String
    public var meetings: [MeetingSummary]

    public var id: MeetingLibraryPresentationGroupKind {
        kind
    }

    public init(
        kind: MeetingLibraryPresentationGroupKind,
        title: String,
        meetings: [MeetingSummary]
    ) {
        self.kind = kind
        self.title = title
        self.meetings = meetings
    }
}

public struct MeetingLibraryPresentationSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var statusText: String
    public var hasSearchQuery: Bool
    public var isFiltering: Bool
    public var shouldShowLibrary: Bool
    public var emptyStateText: String?
    public var groups: [MeetingLibraryPresentationGroup]

    public init(
        library: MeetingLibrarySnapshot,
        sourceLibrary: MeetingLibrarySnapshot,
        searchText: String,
        filter: MeetingLibraryFilter
    ) {
        title = "纸页库"
        hasSearchQuery = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        isFiltering = filter != .all
        shouldShowLibrary = !sourceLibrary.isEmpty
        statusText = if hasSearchQuery || isFiltering {
            "\(library.totalCount) 个匹配"
        } else {
            "\(sourceLibrary.totalCount) 张 · \(sourceLibrary.archivedCount) 已归档"
        }

        var groups: [MeetingLibraryPresentationGroup] = []
        if !library.unfinished.isEmpty {
            groups.append(
                MeetingLibraryPresentationGroup(
                    kind: .unfinished,
                    title: "未完成",
                    meetings: library.unfinished
                )
            )
        }
        if !library.archived.isEmpty {
            groups.append(
                MeetingLibraryPresentationGroup(
                    kind: .archived,
                    title: "已归档",
                    meetings: library.archived
                )
            )
        }
        self.groups = groups

        emptyStateText = if library.isEmpty {
            switch (hasSearchQuery, filter) {
            case (true, _):
                "没有匹配纸页"
            case (false, .unfinished):
                "暂时没有未完成纸页"
            case (false, .archived):
                "暂时没有已归档纸页"
            case (false, .all):
                "纸页库还是空的"
            }
        } else {
            nil
        }
    }
}

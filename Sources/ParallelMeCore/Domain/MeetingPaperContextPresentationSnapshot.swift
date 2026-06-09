import Foundation

public struct MeetingPaperContextActionSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var isEnabled: Bool
    public var accessibilityLabel: String
    public var accessibilityHint: String?

    public init(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.accessibilityLabel = accessibilityLabel ?? title
        self.accessibilityHint = accessibilityHint
    }
}

public struct MeetingRuntimeContextRowSnapshot: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var body: String

    public init(id: String, title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }
}

public struct MeetingRuntimePresentationSnapshot: Codable, Equatable, Sendable {
    public var providerSystemImage: String
    public var providerLabel: String
    public var contextSummary: String?
    public var contextTitle: String
    public var contextRows: [MeetingRuntimeContextRowSnapshot]

    public init(snapshot: MeetingRuntimeSnapshot) {
        let normalized = snapshot.normalized
        let context = normalized.context?.normalized
        var rows: [MeetingRuntimeContextRowSnapshot] = []
        if let meCard = context?.meCard {
            rows.append(
                MeetingRuntimeContextRowSnapshot(
                    id: "me-card",
                    title: "个人背景",
                    body: meCard
                )
            )
        }
        if let tasteProfile = context?.tasteProfile {
            rows.append(
                MeetingRuntimeContextRowSnapshot(
                    id: "taste-profile",
                    title: "回应偏好",
                    body: tasteProfile
                )
            )
        }

        self.providerSystemImage = "slider.horizontal.3"
        self.providerLabel = normalized.providerLabel
        self.contextSummary = normalized.contextSummary
        self.contextTitle = "会话上下文"
        self.contextRows = rows
    }

    public var hasContextRows: Bool {
        !contextRows.isEmpty
    }
}

public struct MeetingPaperExportPresentationSnapshot: Codable, Equatable, Sendable {
    public var shouldShowControl: Bool
    public var canExport: Bool
    public var canSharePreparedFile: Bool
    public var action: MeetingPaperContextActionSnapshot
    public var blockerMessage: String?
    public var shareMessage: String

    public init(
        availability: MeetingExportAvailabilitySnapshot,
        isBusy: Bool,
        hasPreparedFile: Bool,
        preparedFileName: String? = nil
    ) {
        self.shouldShowControl = availability.shouldShowExportControl
        self.canExport = availability.canExport
        self.canSharePreparedFile = availability.canExport && hasPreparedFile
        self.blockerMessage = availability.blockerMessage
        self.shareMessage = "ParallelMe 纸页"
        self.action = MeetingPaperContextActionSnapshot(
            title: availability.actionTitle,
            systemImage: "square.and.arrow.up",
            isEnabled: availability.canExport && !isBusy,
            accessibilityLabel: availability.actionTitle,
            accessibilityHint: preparedFileName ?? availability.accessibilityHint
        )
    }
}

public struct MeetingPaperContextPresentationSnapshot: Codable, Equatable, Sendable {
    public var summaryTitle: String
    public var summarySubtitle: String
    public var stepCountText: String
    public var closeAction: MeetingPaperContextActionSnapshot
    public var export: MeetingPaperExportPresentationSnapshot
    public var runtime: MeetingRuntimePresentationSnapshot?
    public var timelineDisclosureTitle: String
    public var timeline: MeetingTimelinePresentationSnapshot

    public init(
        state: MeetingFlowState,
        isBusy: Bool,
        isTimelineExpanded: Bool,
        hasPreparedExportFile: Bool = false,
        preparedExportFileName: String? = nil
    ) {
        let summary = MeetingSummary(state: state)
        let timelineSnapshot = MeetingTimelineSnapshot(state: state)
        let timeline = timelineSnapshot.presentation(isExpanded: isTimelineExpanded)
        self.summaryTitle = summary.title
        self.summarySubtitle = summary.subtitle
        self.stepCountText = "\(timelineSnapshot.totalCount) 步"
        self.closeAction = MeetingPaperContextActionSnapshot(
            title: "回首页",
            systemImage: "house",
            isEnabled: !isBusy,
            accessibilityLabel: "回到首页，稍后继续这张纸页"
        )
        self.export = MeetingPaperExportPresentationSnapshot(
            availability: MeetingExportAvailabilitySnapshot(state: state),
            isBusy: isBusy,
            hasPreparedFile: hasPreparedExportFile,
            preparedFileName: preparedExportFileName
        )
        self.runtime = state.runtimeSnapshot.map(MeetingRuntimePresentationSnapshot.init(snapshot:))
        self.timelineDisclosureTitle = "纸页脉络 · \(timeline.title)"
        self.timeline = timeline
    }
}

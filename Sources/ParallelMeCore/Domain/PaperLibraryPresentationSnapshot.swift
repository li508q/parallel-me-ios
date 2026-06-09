import Foundation

public struct PaperLibraryActionPresentationSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var isEnabled: Bool
    public var accessibilityLabel: String

    public init(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        accessibilityLabel: String? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.accessibilityLabel = accessibilityLabel ?? title
    }
}

public struct PaperDeletionConfirmationPresentationSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var message: String
    public var destructiveActionTitle: String
    public var cancelActionTitle: String

    public init(meeting: MeetingSummary) {
        self.title = "删除这张纸页？"
        self.message = "“\(meeting.title)” 会从这台设备移除。这个操作不能撤销。"
        self.destructiveActionTitle = "删除纸页"
        self.cancelActionTitle = "取消"
    }
}

public struct PaperDeletionPresentationSnapshot: Codable, Equatable, Sendable {
    public var meetingID: String
    public var action: PaperLibraryActionPresentationSnapshot
    public var confirmation: PaperDeletionConfirmationPresentationSnapshot

    public init(
        meeting: MeetingSummary,
        availability: PaperLibraryActionAvailabilitySnapshot
    ) {
        self.meetingID = meeting.id
        self.action = PaperLibraryActionPresentationSnapshot(
            title: "删除纸页",
            systemImage: "trash",
            isEnabled: availability.canDelete,
            accessibilityLabel: "删除纸页"
        )
        self.confirmation = PaperDeletionConfirmationPresentationSnapshot(meeting: meeting)
    }
}

public struct ResumeMeetingPresentationSnapshot: Codable, Equatable, Sendable {
    public var meetingID: String
    public var eyebrow: String
    public var title: String
    public var subtitle: String
    public var restoreAction: PaperLibraryActionPresentationSnapshot
    public var deletion: PaperDeletionPresentationSnapshot

    public init(meeting: MeetingSummary, isBusy: Bool = false) {
        let availability = PaperLibraryActionAvailabilitySnapshot(isBusy: isBusy)
        self.meetingID = meeting.id
        self.eyebrow = "继续未完成纸页"
        self.title = meeting.title
        self.subtitle = meeting.subtitle
        self.restoreAction = PaperLibraryActionPresentationSnapshot(
            title: "继续",
            systemImage: "arrow.uturn.forward.circle.fill",
            isEnabled: availability.canRestore
        )
        self.deletion = PaperDeletionPresentationSnapshot(
            meeting: meeting,
            availability: availability
        )
    }
}

import Foundation

public struct SettlementControlButtonSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var isEnabled: Bool

    public init(title: String, systemImage: String, isEnabled: Bool) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
    }
}

public struct SettlementControlsPresentationSnapshot: Codable, Equatable, Sendable {
    public var applyRevisionAction: SettlementControlButtonSnapshot
    public var archiveAction: SettlementControlButtonSnapshot

    public init(availability: SettlementActionAvailabilitySnapshot) {
        applyRevisionAction = SettlementControlButtonSnapshot(
            title: "应用修订",
            systemImage: "pencil.and.scribble",
            isEnabled: availability.canApplyRevision
        )
        archiveAction = SettlementControlButtonSnapshot(
            title: "保存纸页",
            systemImage: "archivebox.fill",
            isEnabled: availability.canArchive
        )
    }
}

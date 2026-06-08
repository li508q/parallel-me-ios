import Foundation

public enum MeetingResumePolicy {
    public static func candidate(in states: [MeetingFlowState]) -> MeetingFlowState? {
        states
            .filter { $0.stage != .archived }
            .max { MeetingSummary(state: $0).updatedAt < MeetingSummary(state: $1).updatedAt }
    }

    public static func summary(in states: [MeetingFlowState]) -> MeetingSummary? {
        candidate(in: states).map(MeetingSummary.init(state:))
    }
}

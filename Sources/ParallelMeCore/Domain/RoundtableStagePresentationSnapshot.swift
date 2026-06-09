public enum RoundtableStageStatusTone: String, Codable, Equatable, Sendable {
    case muted
    case warning
    case success
}

public struct RoundtableStagePresentationSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var statusTitle: String
    public var statusDetail: String
    public var statusSystemImage: String
    public var statusTone: RoundtableStageStatusTone
    public var isControlPanelEnabled: Bool
    public var controls: RoundtableControlsPresentationSnapshot

    public init(
        state: MeetingFlowState,
        isBusy: Bool = false,
        tableQuestion: String = "",
        voiceQuestion: String = "",
        selectedVoice: VoiceID = .future,
        duelFrom: VoiceID = .money,
        duelTo: VoiceID = .lay
    ) {
        let availability = RoundtableActionAvailabilitySnapshot(state: state, isBusy: isBusy)
        let controls = RoundtableControlsPresentationSnapshot(
            availability: availability,
            tableQuestion: tableQuestion,
            voiceQuestion: voiceQuestion,
            selectedVoice: selectedVoice,
            duelFrom: duelFrom,
            duelTo: duelTo
        )

        self.title = "五声圆桌"
        self.statusTitle = availability.statusTitle
        self.statusDetail = availability.statusDetail
        self.statusSystemImage = controls.statusSystemImage
        self.statusTone = availability.canStartInquiry ? .success : RoundtableStageStatusTone(
            messageTone: availability.messageTone
        )
        self.isControlPanelEnabled = !availability.blockers.contains(.busy)
        self.controls = controls
    }
}

private extension RoundtableStageStatusTone {
    init(messageTone: RoundtableActionMessageTone) {
        switch messageTone {
        case .muted:
            self = .muted
        case .warning:
            self = .warning
        }
    }
}

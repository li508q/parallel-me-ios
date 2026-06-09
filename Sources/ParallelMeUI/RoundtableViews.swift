import ParallelMeCore
import ParallelMeDesign
import SwiftUI

struct RoundtableView: View {
    var state: MeetingFlowState
    @ObservedObject var viewModel: MeetingViewModel
    @State private var tableQuestion = ""
    @State private var voiceQuestion = ""
    @State private var selectedVoice: VoiceID = .future
    @State private var duelFrom: VoiceID = .money
    @State private var duelTo: VoiceID = .lay

    private var transcript: RoundtableTranscriptSnapshot {
        RoundtableTranscriptSnapshot(record: state.roundtable)
    }

    private var actionAvailability: RoundtableActionAvailabilitySnapshot {
        RoundtableActionAvailabilitySnapshot(state: state, isBusy: viewModel.isBusy)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            Text("五声圆桌")
                .font(ParallelMeTypography.bodyStrong)
            ForEach(transcript.sections) { section in
                RoundtableTranscriptSectionView(section: section)
            }
            roundtableControls
        }
    }

    private var roundtableControls: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            HStack(alignment: .top, spacing: ParallelMeSpacing.sm) {
                Image(systemName: actionAvailability.canStartInquiry ? "checkmark.seal.fill" : "hourglass")
                    .foregroundStyle(actionAvailability.canStartInquiry ? ParallelMeColor.rest : statusColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(actionAvailability.statusTitle)
                        .font(ParallelMeTypography.bodyStrong)
                        .foregroundStyle(ParallelMeColor.ink)
                    Text(actionAvailability.statusDetail)
                        .font(ParallelMeTypography.compact)
                        .foregroundStyle(statusColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Button(action: viewModel.continueRoundtable) {
                    Label("继续一轮", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
                .disabled(!actionAvailability.canContinueRoundtable)
                Button(action: viewModel.startInquiry) {
                    Label(actionAvailability.inquiryActionTitle, systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!actionAvailability.canStartInquiry)
            }
            DisclosureGroup("问全桌") {
                VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                    TextField("把你想抛给全桌的问题写在这里", text: $tableQuestion, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        viewModel.askTable(tableQuestion)
                        tableQuestion = ""
                    } label: {
                        Label("发送给全桌", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!actionAvailability.canAskTable || tableQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.top, ParallelMeSpacing.sm)
            }
            DisclosureGroup("问一声") {
                VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                    Picker("声音", selection: $selectedVoice) {
                        ForEach(VoiceID.allCases) { voice in
                            Text(voice.displayName).tag(voice)
                        }
                    }
                    TextField("问这一声一句", text: $voiceQuestion, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        viewModel.askVoice(selectedVoice, text: voiceQuestion)
                        voiceQuestion = ""
                    } label: {
                        Label("发送给\(selectedVoice.displayName)", systemImage: "person.wave.2.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!actionAvailability.canAskVoice || voiceQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.top, ParallelMeSpacing.sm)
            }
            DisclosureGroup("让两声对话") {
                VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                    Picker("发问", selection: $duelFrom) {
                        ForEach(VoiceID.allCases) { voice in
                            Text(voice.displayName).tag(voice)
                        }
                    }
                    Picker("回应", selection: $duelTo) {
                        ForEach(VoiceID.allCases) { voice in
                            Text(voice.displayName).tag(voice)
                        }
                    }
                    Button {
                        viewModel.startDuel(from: duelFrom, to: duelTo)
                    } label: {
                        Label("开始对话", systemImage: "arrow.left.and.right")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!actionAvailability.canStartDuel || duelFrom == duelTo)
                }
                .padding(.top, ParallelMeSpacing.sm)
            }
        }
        .disabled(viewModel.isBusy)
        .padding(ParallelMeSpacing.md)
        .background(ParallelMeColor.paperLift)
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                .stroke(ParallelMeColor.line.opacity(0.75), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch actionAvailability.messageTone {
        case .muted:
            return ParallelMeColor.inkMuted
        case .warning:
            return ParallelMeColor.filial
        }
    }
}

private struct RoundtableTranscriptSectionView: View {
    var section: RoundtableTranscriptSection

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(section.title)
                    .font(ParallelMeTypography.eyebrow)
                    .foregroundStyle(ParallelMeColor.inkMuted)
                Text(section.detail)
                    .font(ParallelMeTypography.compact)
                    .foregroundStyle(ParallelMeColor.inkMuted)
            }

            ForEach(section.openingTurns) { turn in
                VoiceOpeningView(turn: turn)
            }
            ForEach(section.turns) { turn in
                VoiceTurnView(name: turn.name ?? "圆桌", voiceID: turn.voiceID, text: turn.text, footnote: nil)
            }
        }
        .padding(ParallelMeSpacing.sm)
        .background(ParallelMeColor.paperLift.opacity(section.kind == .opening ? 0.55 : 0.85))
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                .stroke(ParallelMeColor.line.opacity(0.55), lineWidth: 1)
        )
    }
}

private struct VoiceOpeningView: View {
    var turn: VoiceOpeningTurn

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
            VoiceTurnView(
                name: turn.name,
                voiceID: turn.voiceID,
                text: turn.payload.thesis,
                footnote: turn.payload.pull
            )
            HStack(alignment: .top, spacing: ParallelMeSpacing.xs) {
                VoiceOpeningDetail(title: "守护", text: turn.payload.protectedValue)
                VoiceOpeningDetail(title: "担心", text: turn.payload.concern)
            }
        }
    }
}

private struct VoiceOpeningDetail: View {
    var title: String
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(ParallelMeTypography.eyebrow)
                .foregroundStyle(ParallelMeColor.inkMuted)
            Text(text)
                .font(ParallelMeTypography.compact)
                .foregroundStyle(ParallelMeColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(ParallelMeSpacing.sm)
        .background(ParallelMeColor.paper.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
    }
}

private struct VoiceTurnView: View {
    var name: String
    var voiceID: VoiceID?
    var text: String
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
            Text(name)
                .font(ParallelMeTypography.eyebrow)
                .foregroundStyle(voiceID.map { ParallelMeTheme.voiceColor($0.rawValue) } ?? ParallelMeColor.inkMuted)
            Text(text)
                .font(ParallelMeTypography.body)
                .foregroundStyle(ParallelMeColor.ink)
            if let footnote {
                Text(footnote)
                    .font(ParallelMeTypography.compact)
                    .foregroundStyle(ParallelMeColor.inkMuted)
            }
        }
        .padding(ParallelMeSpacing.md)
        .background((voiceID.map { ParallelMeTheme.voiceColor($0.rawValue) } ?? ParallelMeColor.line).opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
    }
}

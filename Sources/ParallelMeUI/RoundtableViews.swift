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

    private var presentation: RoundtableStagePresentationSnapshot {
        RoundtableStagePresentationSnapshot(
            state: state,
            isBusy: viewModel.isBusy,
            tableQuestion: tableQuestion,
            voiceQuestion: voiceQuestion,
            selectedVoice: selectedVoice,
            duelFrom: duelFrom,
            duelTo: duelTo
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            Text(presentation.title)
                .font(ParallelMeTypography.bodyStrong)
            ForEach(transcript.sections) { section in
                RoundtableTranscriptSectionView(section: section)
            }
            roundtableControls
        }
    }

    private var roundtableControls: some View {
        let stagePresentation = presentation
        let controlsPresentation = stagePresentation.controls

        return VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            HStack(alignment: .top, spacing: ParallelMeSpacing.sm) {
                Image(systemName: stagePresentation.statusSystemImage)
                    .foregroundStyle(statusColor(for: stagePresentation.statusTone))
                VStack(alignment: .leading, spacing: 3) {
                    Text(stagePresentation.statusTitle)
                        .font(ParallelMeTypography.bodyStrong)
                        .foregroundStyle(ParallelMeColor.ink)
                    Text(stagePresentation.statusDetail)
                        .font(ParallelMeTypography.compact)
                        .foregroundStyle(statusColor(for: stagePresentation.statusTone))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Button(action: viewModel.continueRoundtable) {
                    Label(
                        controlsPresentation.continueAction.title,
                        systemImage: controlsPresentation.continueAction.systemImage
                    )
                }
                .buttonStyle(.bordered)
                .disabled(!controlsPresentation.continueAction.isEnabled)
                Button(action: viewModel.startInquiry) {
                    Label(
                        controlsPresentation.inquiryAction.title,
                        systemImage: controlsPresentation.inquiryAction.systemImage
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(!controlsPresentation.inquiryAction.isEnabled)
            }
            DisclosureGroup(controlsPresentation.askTable.title) {
                VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                    TextField(controlsPresentation.askTable.prompt, text: $tableQuestion, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        viewModel.askTable(tableQuestion)
                        tableQuestion = ""
                    } label: {
                        Label(
                            controlsPresentation.askTable.action.title,
                            systemImage: controlsPresentation.askTable.action.systemImage
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(!controlsPresentation.askTable.action.isEnabled)
                }
                .padding(.top, ParallelMeSpacing.sm)
            }
            DisclosureGroup(controlsPresentation.askVoice.title) {
                VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                    Picker(controlsPresentation.askVoice.pickerTitle, selection: $selectedVoice) {
                        ForEach(VoiceID.allCases) { voice in
                            Text(voice.displayName).tag(voice)
                        }
                    }
                    TextField(controlsPresentation.askVoice.prompt, text: $voiceQuestion, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        viewModel.askVoice(selectedVoice, text: voiceQuestion)
                        voiceQuestion = ""
                    } label: {
                        Label(
                            controlsPresentation.askVoice.action.title,
                            systemImage: controlsPresentation.askVoice.action.systemImage
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(!controlsPresentation.askVoice.action.isEnabled)
                }
                .padding(.top, ParallelMeSpacing.sm)
            }
            DisclosureGroup(controlsPresentation.duel.title) {
                VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                    Picker(controlsPresentation.duel.fromPickerTitle, selection: $duelFrom) {
                        ForEach(VoiceID.allCases) { voice in
                            Text(voice.displayName).tag(voice)
                        }
                    }
                    Picker(controlsPresentation.duel.toPickerTitle, selection: $duelTo) {
                        ForEach(VoiceID.allCases) { voice in
                            Text(voice.displayName).tag(voice)
                        }
                    }
                    Button {
                        viewModel.startDuel(from: duelFrom, to: duelTo)
                    } label: {
                        Label(
                            controlsPresentation.duel.action.title,
                            systemImage: controlsPresentation.duel.action.systemImage
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(!controlsPresentation.duel.action.isEnabled)
                }
                .padding(.top, ParallelMeSpacing.sm)
            }
        }
        .disabled(!stagePresentation.isControlPanelEnabled)
        .padding(ParallelMeSpacing.md)
        .background(ParallelMeColor.paperLift)
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                .stroke(ParallelMeColor.line.opacity(0.75), lineWidth: 1)
        )
    }

    private func statusColor(for tone: RoundtableStageStatusTone) -> Color {
        switch tone {
        case .muted:
            return ParallelMeColor.inkMuted
        case .warning:
            return ParallelMeColor.filial
        case .success:
            return ParallelMeColor.rest
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
                VoiceOpeningView(snapshot: VoiceOpeningSnapshot(turn: turn))
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
    var snapshot: VoiceOpeningSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
            VoiceTurnView(
                name: snapshot.name,
                voiceID: snapshot.voiceID,
                text: snapshot.thesis,
                footnote: nil
            )
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 132), spacing: ParallelMeSpacing.sm)],
                alignment: .leading,
                spacing: ParallelMeSpacing.xs
            ) {
                ForEach(snapshot.details.filter(\.isMeaningful)) { detail in
                    VoiceOpeningDetail(title: detail.title, text: detail.body)
                }
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
        .padding(.vertical, ParallelMeSpacing.xs)
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

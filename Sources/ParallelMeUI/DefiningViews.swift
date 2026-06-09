import ParallelMeCore
import ParallelMeDesign
import SwiftUI

struct DefiningView: View {
    var state: MeetingFlowState
    @ObservedObject var viewModel: MeetingViewModel
    @State private var proposalFeedback = ""

    private var presentation: IssueDefinitionStagePresentationSnapshot {
        IssueDefinitionStagePresentationSnapshot(
            state: state,
            isBusy: viewModel.isBusy,
            proposalFeedback: proposalFeedback
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Text(presentation.title)
                .font(ParallelMeTypography.bodyStrong)
            Text(presentation.rawInput)
                .font(ParallelMeTypography.body)
                .foregroundStyle(ParallelMeColor.inkMuted)

            switch presentation.mode {
            case .proposal:
                let confirmation = ProposalConfirmationAvailabilitySnapshot(
                    state: state,
                    isBusy: viewModel.isBusy
                )
                if let proposal = state.issueProposal {
                    IssueProposalView(snapshot: IssueProposalSnapshot(proposal: proposal))
                }
                ProposalRevisionView(
                    feedback: $proposalFeedback,
                    presentation: presentation.revision
                ) {
                    viewModel.refineProposal(proposalFeedback)
                }
                Button(action: viewModel.confirmProposal) {
                    Label(
                        confirmation.actionTitle,
                        systemImage: confirmation.actionSystemImage
                    )
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!confirmation.canConfirm)
                Text(confirmation.message)
                    .font(ParallelMeTypography.compact)
                    .foregroundStyle(messageColor(for: confirmation.messageTone))
                    .fixedSize(horizontal: false, vertical: true)
            case .loading:
                ProgressView(presentation.loadingTitle)
                    .font(ParallelMeTypography.compact)
                    .padding(.top, ParallelMeSpacing.sm)
            case .recovery:
                DefinitionRetryView(
                    snapshot: presentation.recovery,
                    retry: viewModel.retryDefinition
                )
            case .questions:
                ProbeQuestionBatchView(
                    questions: state.currentQuestions,
                    isBusy: viewModel.isBusy
                ) { answers in
                    viewModel.submitProbeAnswers(answers)
                }
            }
        }
        .padding(ParallelMeSpacing.md)
        .background(ParallelMeColor.paperLift)
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
    }

    private func messageColor(for tone: ProposalConfirmationMessageTone) -> Color {
        switch tone {
        case .muted:
            return ParallelMeColor.inkMuted
        case .warning:
            return ParallelMeColor.filial
        }
    }
}

private struct DefinitionRetryView: View {
    var snapshot: IssueDefinitionRecoveryPresentationSnapshot
    var retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Text(snapshot.title)
                .font(ParallelMeTypography.bodyStrong)
                .foregroundStyle(ParallelMeColor.ink)
            Text(snapshot.detail)
                .font(ParallelMeTypography.compact)
                .foregroundStyle(ParallelMeColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: retry) {
                Label(
                    snapshot.retryAction.title,
                    systemImage: snapshot.retryAction.systemImage
                )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!snapshot.retryAction.isEnabled)
        }
        .padding(.top, ParallelMeSpacing.sm)
    }
}

private struct ProposalRevisionView: View {
    @Binding var feedback: String
    var presentation: IssueDefinitionRevisionPresentationSnapshot
    var refine: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Divider()
                .padding(.vertical, ParallelMeSpacing.xs)
            TextField(presentation.prompt, text: $feedback, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(ParallelMeTypography.body)
                .lineLimit(2...4)
            Button(action: refine) {
                Label(
                    presentation.action.title,
                    systemImage: presentation.action.systemImage
                )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!presentation.action.isEnabled)
        }
    }
}

private struct IssueProposalView: View {
    var snapshot: IssueProposalSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            ForEach(snapshot.rows) { row in
                proposalRow(row.title, row.body)
            }
        }
        .padding(.vertical, ParallelMeSpacing.sm)
    }

    private func proposalRow(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(ParallelMeTypography.eyebrow)
                .foregroundStyle(ParallelMeColor.inkMuted)
            Text(body)
                .font(ParallelMeTypography.body)
                .foregroundStyle(ParallelMeColor.ink)
        }
    }
}

private struct ProbeQuestionBatchView: View {
    var questions: [ScribeQuestion]
    var isBusy: Bool
    var submit: ([ScribeAnswer]) -> Void
    @State private var draft = ScribeProbeAnswerBatchDraft()

    private var presentation: ScribeAnswerBatchPresentationSnapshot {
        ScribeAnswerBatchPresentationSnapshot(
            questions: questions,
            draft: draft,
            isBusy: isBusy
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(presentation.title)
                    .font(ParallelMeTypography.eyebrow)
                    .foregroundStyle(ParallelMeColor.inkMuted)
                Spacer()
                Text(presentation.progressText)
                    .font(ParallelMeTypography.compact)
                    .foregroundStyle(ParallelMeColor.inkMuted)
            }

            ForEach(questions) { question in
                ProbeQuestionView(
                    question: question,
                    batchKind: presentation.kind,
                    selection: draft.selection(for: question.id)
                ) { option, customText in
                    draft.select(question: question, option: option, customText: customText)
                }
                .disabled(isBusy)
            }

            Button {
                submit(draft.answers(for: questions))
            } label: {
                Label(
                    presentation.submitAction.title,
                    systemImage: presentation.submitAction.systemImage
                )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!presentation.submitAction.isEnabled)
        }
        .onChange(of: questions.map(\.id)) { _, _ in
            draft = ScribeProbeAnswerBatchDraft()
        }
    }
}

private struct ProbeQuestionView: View {
    var question: ScribeQuestion
    var batchKind: ScribeAnswerBatchKind
    var selection: ScribeProbeAnswerSelection?
    var select: (ScribeProbeOption, String?) -> Void
    @State private var customAnswer = ""

    private var regularOptions: [ScribeProbeOption] {
        question.options.filter { !$0.isCustomAnswer }
    }

    private var customOption: ScribeProbeOption? {
        question.options.first(where: \.isCustomAnswer)
    }

    private var customPresentation: ScribeCustomAnswerPresentationSnapshot {
        ScribeCustomAnswerPresentationSnapshot(
            kind: batchKind,
            customText: customAnswer,
            isSelected: customOption.map(isSelected) == true
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Text(question.text)
                .font(ParallelMeTypography.bodyStrong)
            ForEach(regularOptions) { option in
                Button {
                    select(option, nil)
                } label: {
                    HStack {
                        Text(option.label)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if isSelected(option) {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                }
                .buttonStyle(.bordered)
            }
            if let customOption {
                VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
                    TextField(customPresentation.prompt, text: $customAnswer, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(ParallelMeTypography.body)
                        .lineLimit(2...4)
                    Button {
                        select(customOption, customAnswer)
                    } label: {
                        HStack {
                            Label(
                                customPresentation.action.title,
                                systemImage: customPresentation.action.systemImage
                            )
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if customPresentation.isSelected {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!customPresentation.action.isEnabled)
                }
                .onChange(of: customAnswer) { _, newValue in
                    if isSelected(customOption) {
                        select(customOption, newValue)
                    }
                }
            }
        }
        .padding(.top, ParallelMeSpacing.sm)
    }

    private func isSelected(_ option: ScribeProbeOption) -> Bool {
        selection?.selectedOptionID == option.id
    }
}

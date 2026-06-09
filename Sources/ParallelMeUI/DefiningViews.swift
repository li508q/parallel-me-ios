import ParallelMeCore
import ParallelMeDesign
import SwiftUI

struct DefiningView: View {
    var state: MeetingFlowState
    @ObservedObject var viewModel: MeetingViewModel
    @State private var proposalFeedback = ""

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Text("本次议题")
                .font(ParallelMeTypography.bodyStrong)
            Text(state.rawInput)
                .font(ParallelMeTypography.body)
                .foregroundStyle(ParallelMeColor.inkMuted)
            if let proposal = state.issueProposal {
                let confirmation = ProposalConfirmationAvailabilitySnapshot(
                    state: state,
                    isBusy: viewModel.isBusy
                )
                IssueProposalView(proposal: proposal)
                ProposalRevisionView(
                    feedback: $proposalFeedback,
                    isBusy: viewModel.isBusy
                ) {
                    viewModel.refineProposal(proposalFeedback)
                }
                Button(action: viewModel.confirmProposal) {
                    Label(confirmation.actionTitle, systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!confirmation.canConfirm)
                Text(confirmation.message)
                    .font(ParallelMeTypography.compact)
                    .foregroundStyle(messageColor(for: confirmation.messageTone))
                    .fixedSize(horizontal: false, vertical: true)
            } else if state.currentQuestions.isEmpty {
                if viewModel.isBusy {
                    ProgressView("书记员正在整理问题")
                        .font(ParallelMeTypography.compact)
                        .padding(.top, ParallelMeSpacing.sm)
                } else {
                    DefinitionRetryView(retry: viewModel.retryDefinition)
                }
            } else {
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
    var retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Text("书记员这一步没有完成。")
                .font(ParallelMeTypography.bodyStrong)
                .foregroundStyle(ParallelMeColor.ink)
            Text("可以重新整理本次议题；当前纸页会保留，不需要回首页重写。")
                .font(ParallelMeTypography.compact)
                .foregroundStyle(ParallelMeColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: retry) {
                Label("重新整理议题", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, ParallelMeSpacing.sm)
    }
}

private struct ProposalRevisionView: View {
    @Binding var feedback: String
    var isBusy: Bool
    var refine: () -> Void

    private var canRefine: Bool {
        !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBusy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Divider()
                .padding(.vertical, ParallelMeSpacing.xs)
            TextField("哪里不准？直接写给书记员", text: $feedback, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(ParallelMeTypography.body)
                .lineLimit(2...4)
            Button(action: refine) {
                Label("修订这版议题", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!canRefine)
        }
    }
}

private struct IssueProposalView: View {
    var proposal: IssueProposal

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            proposalRow("选择岔路", proposal.surfaceDilemma.content)
            proposalRow("现实边界", proposal.currentConstraints.content)
            proposalRow("隐秘关切", proposal.coreFears.content)
            proposalRow("圆桌任务", proposal.expectedResolution.content)
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

    private var canSubmit: Bool {
        draft.canSubmit(questions: questions) && !isBusy
    }

    private var submittedCount: Int {
        questions.count - draft.missingQuestionIDs(in: questions).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("书记员追问")
                    .font(ParallelMeTypography.eyebrow)
                    .foregroundStyle(ParallelMeColor.inkMuted)
                Spacer()
                Text("\(submittedCount) / \(questions.count)")
                    .font(ParallelMeTypography.compact)
                    .foregroundStyle(ParallelMeColor.inkMuted)
            }

            ForEach(questions) { question in
                ProbeQuestionView(
                    question: question,
                    selection: draft.selection(for: question.id)
                ) { option, customText in
                    draft.select(question: question, option: option, customText: customText)
                }
                .disabled(isBusy)
            }

            Button {
                submit(draft.answers(for: questions))
            } label: {
                Label("提交本轮回答", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmit)
        }
        .onChange(of: questions.map(\.id)) { _, _ in
            draft = ScribeProbeAnswerBatchDraft()
        }
    }
}

private struct ProbeQuestionView: View {
    var question: ScribeQuestion
    var selection: ScribeProbeAnswerSelection?
    var select: (ScribeProbeOption, String?) -> Void
    @State private var customAnswer = ""

    private var regularOptions: [ScribeProbeOption] {
        question.options.filter { !$0.isCustomAnswer }
    }

    private var customOption: ScribeProbeOption? {
        question.options.first(where: \.isCustomAnswer)
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
                    TextField("写下更准确的回答", text: $customAnswer, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(ParallelMeTypography.body)
                        .lineLimit(2...4)
                    Button {
                        select(customOption, customAnswer)
                    } label: {
                        HStack {
                            Label("选用这句回答", systemImage: "text.bubble.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if isSelected(customOption) {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(customAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

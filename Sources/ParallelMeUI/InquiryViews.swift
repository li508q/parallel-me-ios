import ParallelMeCore
import ParallelMeDesign
import SwiftUI

struct InquiryView: View {
    var state: MeetingFlowState
    var activeQuestions: [ScribeInquiryQuestion]
    @ObservedObject var viewModel: MeetingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            Text("书记员问询")
                .font(ParallelMeTypography.bodyStrong)
            if activeQuestions.isEmpty {
                SettlementRequestView(
                    snapshot: SettlementRequestAvailabilitySnapshot(state: state, isBusy: viewModel.isBusy),
                    requestSettlement: viewModel.requestSettlement,
                    continueInquiry: viewModel.retryInquiry
                )
            } else {
                InquiryQuestionBatchView(
                    questions: activeQuestions,
                    isBusy: viewModel.isBusy
                ) { answers in
                    viewModel.submitInquiryAnswers(answers)
                }
            }
        }
    }
}

private struct SettlementRequestView: View {
    var snapshot: SettlementRequestAvailabilitySnapshot
    var requestSettlement: () -> Void
    var continueInquiry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Text(snapshot.title)
                .font(ParallelMeTypography.bodyStrong)
                .foregroundStyle(ParallelMeColor.ink)
            Text(snapshot.detail)
                .font(ParallelMeTypography.compact)
                .foregroundStyle(messageColor)
                .fixedSize(horizontal: false, vertical: true)

            if snapshot.canContinueInquiry {
                Button(action: continueInquiry) {
                    Label(snapshot.continueInquiryActionTitle, systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button(action: requestSettlement) {
                Label(snapshot.requestActionTitle, systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!snapshot.canRequestSettlement)
        }
        .padding(ParallelMeSpacing.md)
        .background(ParallelMeColor.paperLift)
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                .stroke(ParallelMeColor.line.opacity(0.75), lineWidth: 1)
        )
    }

    private var messageColor: Color {
        switch snapshot.messageTone {
        case .muted:
            return ParallelMeColor.inkMuted
        case .warning:
            return ParallelMeColor.filial
        }
    }
}

private struct InquiryQuestionBatchView: View {
    var questions: [ScribeInquiryQuestion]
    var isBusy: Bool
    var submit: ([ScribeInquiryAnswer]) -> Void
    @State private var draft = ScribeInquiryAnswerBatchDraft()

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
                InquiryQuestionView(
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
            draft = ScribeInquiryAnswerBatchDraft()
        }
    }
}

private struct InquiryQuestionView: View {
    var question: ScribeInquiryQuestion
    var batchKind: ScribeAnswerBatchKind
    var selection: ScribeInquiryAnswerSelection?
    var select: (ScribeInquiryOption, String?) -> Void
    @State private var customAnswer = ""

    private var regularOptions: [ScribeInquiryOption] {
        question.options.filter { !$0.isCustomAnswer }
    }

    private var customOption: ScribeInquiryOption? {
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
            Text(question.question)
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
    }

    private func isSelected(_ option: ScribeInquiryOption) -> Bool {
        selection?.selectedOptionID == option.id
    }
}

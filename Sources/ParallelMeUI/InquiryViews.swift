import ParallelMeCore
import ParallelMeDesign
import SwiftUI

struct InquiryView: View {
    var state: MeetingFlowState
    @ObservedObject var viewModel: MeetingViewModel

    private var presentation: InquiryStagePresentationSnapshot {
        InquiryStagePresentationSnapshot(state: state, isBusy: viewModel.isBusy)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            Text(presentation.title)
                .font(ParallelMeTypography.bodyStrong)
            switch presentation.mode {
            case .settlementRequest:
                SettlementRequestView(
                    snapshot: presentation.settlementRequest,
                    requestSettlement: viewModel.requestSettlement,
                    continueInquiry: viewModel.retryInquiry
                )
            case .questions:
                InquiryQuestionBatchView(
                    questions: presentation.activeQuestions,
                    isBusy: viewModel.isBusy
                ) { answers in
                    viewModel.submitInquiryAnswers(answers)
                }
            }
        }
    }
}

private struct SettlementRequestView: View {
    var snapshot: SettlementRequestPresentationSnapshot
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

            if snapshot.continueInquiryAction.isVisible {
                Button(action: continueInquiry) {
                    Label(
                        snapshot.continueInquiryAction.title,
                        systemImage: snapshot.continueInquiryAction.systemImage
                    )
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!snapshot.continueInquiryAction.isEnabled)
            }

            Button(action: requestSettlement) {
                Label(
                    snapshot.requestSettlementAction.title,
                    systemImage: snapshot.requestSettlementAction.systemImage
                )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!snapshot.requestSettlementAction.isEnabled)
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
                let optionPresentation = ScribeAnswerOptionPresentationSnapshot(
                    option: option,
                    selection: selection
                )
                Button {
                    select(option, nil)
                } label: {
                    HStack {
                        Text(optionPresentation.label)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let systemImage = optionPresentation.selectedSystemImage {
                            Image(systemName: systemImage)
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
                            if let systemImage = customPresentation.selectedSystemImage {
                                Image(systemName: systemImage)
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

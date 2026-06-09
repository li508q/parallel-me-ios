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

    private var canSubmit: Bool {
        draft.canSubmit(questions: questions) && !isBusy
    }

    private var submittedCount: Int {
        questions.count - draft.missingQuestionIDs(in: questions).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("本轮问询")
                    .font(ParallelMeTypography.eyebrow)
                    .foregroundStyle(ParallelMeColor.inkMuted)
                Spacer()
                Text("\(submittedCount) / \(questions.count)")
                    .font(ParallelMeTypography.compact)
                    .foregroundStyle(ParallelMeColor.inkMuted)
            }

            ForEach(questions) { question in
                InquiryQuestionView(
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
                Label("提交本轮问询", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmit)
        }
        .onChange(of: questions.map(\.id)) { _, _ in
            draft = ScribeInquiryAnswerBatchDraft()
        }
    }
}

private struct InquiryQuestionView: View {
    var question: ScribeInquiryQuestion
    var selection: ScribeInquiryAnswerSelection?
    var select: (ScribeInquiryOption, String?) -> Void
    @State private var customAnswer = ""

    private var regularOptions: [ScribeInquiryOption] {
        question.options.filter { !$0.isCustomAnswer }
    }

    private var customOption: ScribeInquiryOption? {
        question.options.first(where: \.isCustomAnswer)
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
                    TextField("写下你的真实答案", text: $customAnswer, axis: .vertical)
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
    }

    private func isSelected(_ option: ScribeInquiryOption) -> Bool {
        selection?.selectedOptionID == option.id
    }
}

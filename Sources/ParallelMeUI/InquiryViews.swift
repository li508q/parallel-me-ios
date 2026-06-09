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
            if activeQuestions.isEmpty, state.alignmentProfile != nil {
                Text("书记员已经拿到足够证据，可以生成本心落定。")
                    .font(ParallelMeTypography.body)
                    .foregroundStyle(ParallelMeColor.inkMuted)
                Button(action: viewModel.requestSettlement) {
                    Label("生成本心落定", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isBusy)
            } else if activeQuestions.isEmpty {
                if viewModel.isBusy {
                    ProgressView("书记员正在校对最后的问题")
                } else {
                    InquiryRetryView(retry: viewModel.retryInquiry)
                }
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

private struct InquiryRetryView: View {
    var retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Text("书记员这一步没有完成。")
                .font(ParallelMeTypography.bodyStrong)
                .foregroundStyle(ParallelMeColor.ink)
            Text("可以沿用当前圆桌材料，重新整理下一轮问询；这张纸页会保留。")
                .font(ParallelMeTypography.compact)
                .foregroundStyle(ParallelMeColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: retry) {
                Label("重新整理问询", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(ParallelMeSpacing.md)
        .background(ParallelMeColor.paperLift)
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                .stroke(ParallelMeColor.line.opacity(0.75), lineWidth: 1)
        )
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

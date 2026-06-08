import ParallelMeCore
import ParallelMeDesign
import SwiftUI

public struct ParallelMeRootView: View {
    @StateObject private var viewModel: MeetingViewModel

    public init(viewModel: MeetingViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? MeetingViewModel.makeDefault())
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                ParallelMeColor.paper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: ParallelMeSpacing.lg) {
                        header
                        if let error = viewModel.errorMessage {
                            ErrorBanner(message: error, dismiss: viewModel.dismissError)
                        }
                        if let state = viewModel.state {
                            MeetingStageRail(stage: state.stage)
                            stageBody(state, viewModel: viewModel)
                        } else {
                            startCard
                            VoicePrimerGrid()
                        }
                    }
                    .padding(.horizontal, ParallelMeSpacing.md)
                    .padding(.vertical, ParallelMeSpacing.xl)
                }
            }
            .parallelMeInlineNavigationTitle()
        }
        .task {
            await viewModel.loadProviderSettings()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Text("ParallelMe")
                .font(ParallelMeTypography.eyebrow)
                .foregroundStyle(ParallelMeColor.inkMuted)
            Text("今天，想听见哪件事？")
                .font(ParallelMeTypography.title)
                .foregroundStyle(ParallelMeColor.ink)
            Text("书记员先帮你定义议题，再让五声坐下来慢慢摊开。")
                .font(ParallelMeTypography.body)
                .foregroundStyle(ParallelMeColor.inkMuted)
        }
    }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            ProviderSettingsPanel(viewModel: viewModel)
            TextEditor(text: $viewModel.petition)
                .font(ParallelMeTypography.body)
                .foregroundStyle(ParallelMeColor.ink)
                .frame(minHeight: 150)
                .scrollContentBackground(.hidden)
                .padding(ParallelMeSpacing.sm)
                .background(ParallelMeColor.paperLift)
                .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                        .stroke(ParallelMeColor.line, lineWidth: 1)
                )
            Button {
                viewModel.startMeeting()
            } label: {
                Label(viewModel.isBusy ? "书记员整理中" : "开始五声圆桌", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canStart)
        }
    }

    @ViewBuilder
    private func stageBody(_ state: MeetingFlowState, viewModel: MeetingViewModel) -> some View {
        switch state.stage {
        case .defining:
            DefiningView(state: state, viewModel: viewModel)
        case .roundtable:
            RoundtableView(state: state, viewModel: viewModel)
        case .inquiry:
            InquiryView(state: state, activeQuestions: viewModel.activeInquiryQuestions, viewModel: viewModel)
        case .settlement:
            if let settlement = state.heartSettlement {
                SettlementView(settlement: settlement, archive: viewModel.archive)
            }
        case .archived:
            ArchivedView(reset: viewModel.reset)
        }
    }
}

private struct ProviderSettingsPanel: View {
    @ObservedObject var viewModel: MeetingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Picker("Provider", selection: $viewModel.providerMode) {
                ForEach(ProviderRuntimeMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.providerMode == .openAICompatible {
                VStack(spacing: ParallelMeSpacing.sm) {
                    TextField("Base URL", text: $viewModel.providerBaseURL)
                        .textContentType(.URL)
                    TextField("Model", text: $viewModel.providerModel)
                    SecureField("API Key", text: $viewModel.providerAPIKey)
                }
                .textFieldStyle(.roundedBorder)
                .font(ParallelMeTypography.compact)
            }
        }
        .padding(ParallelMeSpacing.md)
        .background(ParallelMeColor.paperLift)
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                .stroke(ParallelMeColor.line, lineWidth: 1)
        )
    }
}

private extension View {
    @ViewBuilder
    func parallelMeInlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

private struct ErrorBanner: View {
    var message: String
    var dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: ParallelMeSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(ParallelMeTypography.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: dismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(ParallelMeColor.filial)
        .padding(ParallelMeSpacing.md)
        .background(ParallelMeColor.filial.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
    }
}

public struct MeetingStageRail: View {
    public var stage: MeetingStage

    public init(stage: MeetingStage) {
        self.stage = stage
    }

    public var body: some View {
        HStack(spacing: ParallelMeSpacing.xs) {
            ForEach(MeetingStage.allCases, id: \.self) { item in
                Capsule()
                    .fill(item == stage ? ParallelMeColor.ink : ParallelMeColor.line)
                    .frame(height: item == stage ? 8 : 4)
                    .accessibilityLabel(Text(item.rawValue))
            }
        }
    }
}

public struct VoicePrimerGrid: View {
    public init() {}

    public var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: ParallelMeSpacing.sm)], spacing: ParallelMeSpacing.sm) {
            ForEach(VoicePersonas.all) { persona in
                VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
                    Text(persona.name)
                        .font(ParallelMeTypography.bodyStrong)
                        .foregroundStyle(ParallelMeColor.ink)
                    Text(persona.coreValue)
                        .font(ParallelMeTypography.compact)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(ParallelMeSpacing.md)
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                .background(ParallelMeTheme.voiceColor(persona.id.rawValue).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                        .stroke(ParallelMeTheme.voiceColor(persona.id.rawValue).opacity(0.35), lineWidth: 1)
                )
            }
        }
    }
}

private struct DefiningView: View {
    var state: MeetingFlowState
    @ObservedObject var viewModel: MeetingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Text("本次议题")
                .font(ParallelMeTypography.bodyStrong)
            Text(state.rawInput)
                .font(ParallelMeTypography.body)
                .foregroundStyle(ParallelMeColor.inkMuted)
            if let proposal = state.issueProposal {
                IssueProposalView(proposal: proposal)
                Button(action: viewModel.confirmProposal) {
                    Label("确认议题，进入圆桌", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isBusy)
            } else if state.currentQuestions.isEmpty {
                ProgressView("书记员正在整理问题")
                    .font(ParallelMeTypography.compact)
                    .padding(.top, ParallelMeSpacing.sm)
            } else {
                ForEach(state.currentQuestions) { question in
                    ProbeQuestionView(question: question) { option in
                        viewModel.answerProbe(question: question, option: option)
                    }
                    .disabled(viewModel.isBusy)
                }
            }
        }
        .padding(ParallelMeSpacing.md)
        .background(ParallelMeColor.paperLift)
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
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

private struct ProbeQuestionView: View {
    var question: ScribeQuestion
    var answer: (ScribeProbeOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Text(question.text)
                .font(ParallelMeTypography.bodyStrong)
            ForEach(question.options) { option in
                Button {
                    answer(option)
                } label: {
                    Text(option.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.top, ParallelMeSpacing.sm)
    }
}

private struct RoundtableView: View {
    var state: MeetingFlowState
    @ObservedObject var viewModel: MeetingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            Text("五声圆桌")
                .font(ParallelMeTypography.bodyStrong)
            ForEach(state.roundtable.openingTurns) { turn in
                VoiceTurnView(name: turn.name, voiceID: turn.voiceID, text: turn.payload.thesis, footnote: turn.payload.pull)
            }
            ForEach(state.roundtable.turns) { turn in
                VoiceTurnView(name: turn.name ?? "圆桌", voiceID: turn.voiceID, text: turn.text, footnote: nil)
            }
            HStack {
                Button(action: viewModel.continueRoundtable) {
                    Label("继续一轮", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
                Button(action: viewModel.startInquiry) {
                    Label("进入问询", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .disabled(viewModel.isBusy)
        }
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

private struct InquiryView: View {
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
                ProgressView("书记员正在校对最后的问题")
            } else {
                ForEach(activeQuestions) { question in
                    VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                        Text(question.question)
                            .font(ParallelMeTypography.bodyStrong)
                        ForEach(question.options) { option in
                            Button {
                                viewModel.answerInquiry(question: question, option: option)
                            } label: {
                                Text(option.label)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .disabled(viewModel.isBusy)
                }
            }
        }
    }
}

private struct ArchivedView: View {
    var reset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            Text("这张纸页已经归档。")
                .font(ParallelMeTypography.body)
                .foregroundStyle(ParallelMeColor.inkMuted)
            Button(action: reset) {
                Label("开始新的圆桌", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

public struct SettlementView: View {
    public var settlement: HeartSettlement
    public var archive: () -> Void

    public init(settlement: HeartSettlement, archive: @escaping () -> Void = {}) {
        self.settlement = settlement
        self.archive = archive
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            Text("本心落定")
                .font(ParallelMeTypography.title)
            Text(settlement.headline)
                .font(ParallelMeTypography.bodyStrong)
            module("创造性无望", settlement.creativeHopelessness.resolvedText)
            module("核心价值主轴", settlement.coreValueAxis.resolvedText)
            module("痛苦接纳契约", settlement.costAcceptanceContract.resolvedText)
            module("最小行动承诺", settlement.minimumViableCommitment.resolvedText)
            Button(action: archive) {
                Label("保存纸页", systemImage: "archivebox.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .foregroundStyle(ParallelMeColor.ink)
    }

    private func module(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
            Text(title)
                .font(ParallelMeTypography.eyebrow)
                .foregroundStyle(ParallelMeColor.inkMuted)
            Text(body)
                .font(ParallelMeTypography.body)
        }
        .padding(.vertical, ParallelMeSpacing.xs)
    }
}

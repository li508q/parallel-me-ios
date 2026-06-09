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
                            MeetingPaperContextView(
                                state: state,
                                isBusy: viewModel.isBusy,
                                close: viewModel.closeCurrentPaper
                            )
                            stageBody(state, viewModel: viewModel)
                        } else {
                            if let resumable = viewModel.resumableMeeting {
                                ResumeMeetingCard(
                                    meeting: resumable,
                                    restore: viewModel.restoreMeeting,
                                    delete: viewModel.deleteMeeting
                                )
                            }
                            startCard
                            PaperLibrarySection(
                                library: viewModel.visibleMeetingLibrary,
                                sourceLibrary: viewModel.meetingLibrary,
                                searchText: $viewModel.librarySearchText,
                                restore: viewModel.restoreMeeting,
                                delete: viewModel.deleteMeeting
                            )
                            VoicePrimerGrid()
                        }
                        if !viewModel.sessionEvents.isEmpty {
                            SessionDiagnosticsPanel(events: viewModel.sessionEvents)
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
            await viewModel.loadProviderContext()
            await viewModel.loadMeetingLibrary()
            await viewModel.loadSessionEvents()
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
            if viewModel.petition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                PetitionStarterPromptGrid { prompt in
                    viewModel.useStarterPrompt(prompt)
                }
            }
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
            StartReadinessView(snapshot: viewModel.startReadiness)
            Button {
                viewModel.startMeeting()
            } label: {
                Label(viewModel.startReadiness.actionTitle, systemImage: "arrow.right.circle.fill")
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
                SettlementView(
                    settlement: settlement,
                    revise: viewModel.reviseSettlement,
                    archive: viewModel.archive
                )
            }
        case .archived:
            ArchivedView(state: state, reset: viewModel.reset)
        }
    }
}

private struct DefiningView: View {
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
                IssueProposalView(proposal: proposal)
                ProposalRevisionView(
                    feedback: $proposalFeedback,
                    isBusy: viewModel.isBusy
                ) {
                    viewModel.refineProposal(proposalFeedback)
                }
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
                    ProbeQuestionView(question: question) { option, customText in
                        viewModel.answerProbe(question: question, option: option, customText: customText)
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

private struct ProbeQuestionView: View {
    var question: ScribeQuestion
    var answer: (ScribeProbeOption, String?) -> Void
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
                    answer(option, nil)
                } label: {
                    Text(option.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }
            if let customOption {
                CustomAnswerComposer(
                    text: $customAnswer,
                    placeholder: "写下更准确的回答",
                    title: "用这句回答",
                    systemImage: "text.bubble.fill"
                ) {
                    answer(customOption, customAnswer)
                }
            }
        }
        .padding(.top, ParallelMeSpacing.sm)
    }
}

private struct CustomAnswerComposer: View {
    @Binding var text: String
    var placeholder: String
    var title: String
    var systemImage: String
    var submit: () -> Void

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(ParallelMeTypography.body)
                .lineLimit(2...4)
            Button(action: submit) {
                Label(title, systemImage: systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!canSubmit)
        }
    }
}

private struct RoundtableView: View {
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

    private var transition: RoundtableTransitionSnapshot {
        RoundtableTransitionSnapshot(record: state.roundtable)
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
                Image(systemName: transition.canStartInquiry ? "checkmark.seal.fill" : "hourglass")
                    .foregroundStyle(transition.canStartInquiry ? ParallelMeColor.rest : ParallelMeColor.inkMuted)
                VStack(alignment: .leading, spacing: 3) {
                    Text(transition.statusTitle)
                        .font(ParallelMeTypography.bodyStrong)
                        .foregroundStyle(ParallelMeColor.ink)
                    Text(transition.statusDetail)
                        .font(ParallelMeTypography.compact)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Button(action: viewModel.continueRoundtable) {
                    Label("继续一轮", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
                Button(action: viewModel.startInquiry) {
                    Label(transition.inquiryActionTitle, systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!transition.canStartInquiry)
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
                    .disabled(tableQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                    .disabled(voiceQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                    .disabled(duelFrom == duelTo)
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
                    InquiryQuestionView(question: question) { option, customText in
                        viewModel.answerInquiry(question: question, option: option, customText: customText)
                    }
                    .disabled(viewModel.isBusy)
                }
            }
        }
    }
}

private struct InquiryQuestionView: View {
    var question: ScribeInquiryQuestion
    var answer: (ScribeInquiryOption, String?) -> Void
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
                    answer(option, nil)
                } label: {
                    Text(option.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }
            if let customOption {
                CustomAnswerComposer(
                    text: $customAnswer,
                    placeholder: "写下你的真实答案",
                    title: "用这句回答",
                    systemImage: "text.bubble.fill"
                ) {
                    answer(customOption, customAnswer)
                }
            }
        }
    }
}

private struct ArchivedView: View {
    var state: MeetingFlowState
    var reset: () -> Void

    private var snapshot: MeetingArchiveSnapshot {
        MeetingArchiveSnapshot(state: state)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.lg) {
            VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                Text("归档纸页")
                    .font(ParallelMeTypography.eyebrow)
                    .foregroundStyle(ParallelMeColor.inkMuted)
                Text(snapshot.summary.title)
                    .font(ParallelMeTypography.title)
                    .foregroundStyle(ParallelMeColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("已保存为本地纸页，可以随时回到首页从纸页库打开。")
                    .font(ParallelMeTypography.body)
                    .foregroundStyle(ParallelMeColor.inkMuted)
            }

            if snapshot.hasSettlement {
                ArchiveSection(title: "本心落定", rows: snapshot.settlementRows)
            }

            if snapshot.hasIssue {
                ArchiveSection(title: "本次议题", rows: snapshot.issueRows)
            }

            if !snapshot.timelineItems.isEmpty {
                DisclosureGroup("完整脉络 · \(snapshot.timelineItems.count) 步") {
                    VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                        ForEach(snapshot.timelineItems) { item in
                            TimelineRow(item: item)
                        }
                    }
                    .padding(.top, ParallelMeSpacing.xs)
                }
                .font(ParallelMeTypography.compact)
                .foregroundStyle(ParallelMeColor.ink)
                .padding(ParallelMeSpacing.md)
                .background(ParallelMeColor.paperLift)
                .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                        .stroke(ParallelMeColor.line.opacity(0.75), lineWidth: 1)
                )
            }

            Button(action: reset) {
                Label("开始新的圆桌", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct ArchiveSection: View {
    var title: String
    var rows: [MeetingArchiveRow]

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            Text(title)
                .font(ParallelMeTypography.bodyStrong)
                .foregroundStyle(ParallelMeColor.ink)
            VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                ForEach(rows) { row in
                    ArchiveRowView(row: row)
                }
            }
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

private struct ArchiveRowView: View {
    var row: MeetingArchiveRow

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
            Text(row.title)
                .font(ParallelMeTypography.eyebrow)
                .foregroundStyle(ParallelMeColor.inkMuted)
            Text(row.body)
                .font(ParallelMeTypography.body)
                .foregroundStyle(ParallelMeColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !row.details.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(row.details, id: \.self) { detail in
                        Text("· \(detail)")
                            .font(ParallelMeTypography.compact)
                            .foregroundStyle(ParallelMeColor.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.bottom, ParallelMeSpacing.xs)
    }
}

public struct SettlementView: View {
    public var settlement: HeartSettlement
    public var revise: ([SettlementModuleID: String]) -> Void
    public var archive: () -> Void
    @State private var draft: SettlementRevisionDraft

    public init(
        settlement: HeartSettlement,
        revise: @escaping ([SettlementModuleID: String]) -> Void = { _ in },
        archive: @escaping () -> Void = {}
    ) {
        self.settlement = settlement
        self.revise = revise
        self.archive = archive
        _draft = State(initialValue: SettlementRevisionDraft(settlement: settlement))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            Text("本心落定")
                .font(ParallelMeTypography.title)
            Text(settlement.headline)
                .font(ParallelMeTypography.bodyStrong)
            SettlementModuleEditor(title: "创造性无望", text: $draft.creativeHopelessness)
            SettlementModuleEditor(title: "核心价值主轴", text: $draft.coreValues)
            SettlementModuleEditor(title: "痛苦接纳契约", text: $draft.costAcceptance)
            SettlementModuleEditor(title: "最小行动承诺", text: $draft.minimumAction)
            SettlementModuleEditor(title: "正反合", text: $draft.dialecticSynthesis)
            if draft.hasEmptyRequiredText {
                Text("每一栏都需要保留一句可归档的语言。")
                    .font(ParallelMeTypography.compact)
                    .foregroundStyle(ParallelMeColor.filial)
            } else if draft.hasChanges {
                Text("应用修订后再保存纸页，归档会使用你确认过的文本。")
                    .font(ParallelMeTypography.compact)
                    .foregroundStyle(ParallelMeColor.inkMuted)
            } else if !draft.hasChanges {
                Text("改动后再应用修订；保存纸页会使用当前落定。")
                    .font(ParallelMeTypography.compact)
                    .foregroundStyle(ParallelMeColor.inkMuted)
            }
            Button {
                revise(draft.revisions)
            } label: {
                Label("应用修订", systemImage: "pencil.and.scribble")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!draft.canApply)
            Button(action: archive) {
                Label("保存纸页", systemImage: "archivebox.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!draft.canArchive)
        }
        .foregroundStyle(ParallelMeColor.ink)
        .onAppear {
            loadDrafts(from: settlement)
        }
        .onChange(of: settlement) { _, newValue in
            loadDrafts(from: newValue)
        }
    }

    private func loadDrafts(from settlement: HeartSettlement) {
        draft = SettlementRevisionDraft(settlement: settlement)
    }
}

private struct SettlementModuleEditor: View {
    var title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
            Text(title)
                .font(ParallelMeTypography.eyebrow)
                .foregroundStyle(ParallelMeColor.inkMuted)
            TextEditor(text: $text)
                .font(ParallelMeTypography.body)
                .frame(minHeight: 88)
                .scrollContentBackground(.hidden)
                .padding(ParallelMeSpacing.sm)
                .background(ParallelMeColor.paperLift)
                .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                        .stroke(ParallelMeColor.line.opacity(0.75), lineWidth: 1)
                )
        }
        .padding(.vertical, ParallelMeSpacing.xs)
    }
}

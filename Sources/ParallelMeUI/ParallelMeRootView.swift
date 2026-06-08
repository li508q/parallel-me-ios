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
                SettlementView(
                    settlement: settlement,
                    revise: viewModel.reviseSettlement,
                    archive: viewModel.archive
                )
            }
        case .archived:
            ArchivedView(reset: viewModel.reset)
        }
    }
}

private struct MeetingPaperContextView: View {
    var state: MeetingFlowState
    var isBusy: Bool
    var close: () -> Void

    private var summary: MeetingSummary {
        MeetingSummary(state: state)
    }

    private var timelineItems: [MeetingTimelineItem] {
        MeetingTimeline.items(for: state)
    }

    private var visibleItems: [MeetingTimelineItem] {
        Array(timelineItems.suffix(5))
    }

    private var exportDocument: MeetingExportDocument {
        MeetingExportDocument(state: state)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            HStack(alignment: .top, spacing: ParallelMeSpacing.sm) {
                VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
                    Text(summary.title)
                        .font(ParallelMeTypography.bodyStrong)
                        .foregroundStyle(ParallelMeColor.ink)
                        .lineLimit(2)
                    Text(summary.subtitle)
                        .font(ParallelMeTypography.compact)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                }
                Spacer(minLength: ParallelMeSpacing.sm)
                VStack(alignment: .trailing, spacing: ParallelMeSpacing.xs) {
                    Text("\(timelineItems.count) 步")
                        .font(ParallelMeTypography.eyebrow)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                        .padding(.horizontal, ParallelMeSpacing.sm)
                        .padding(.vertical, ParallelMeSpacing.xs)
                        .background(ParallelMeColor.paper)
                        .clipShape(Capsule())
                    Button(action: close) {
                        Label("回首页", systemImage: "house")
                            .labelStyle(.iconOnly)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isBusy)
                    .accessibilityLabel(Text("回到首页，稍后继续这张纸页"))
                    ShareLink(
                        item: exportDocument.markdown,
                        subject: Text(exportDocument.title)
                    ) {
                        Label("导出纸页", systemImage: "square.and.arrow.up")
                            .labelStyle(.iconOnly)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(Text("导出这张纸页"))
                }
            }

            if let snapshot = state.runtimeSnapshot {
                RuntimeSnapshotView(snapshot: snapshot)
            }

            DisclosureGroup("纸页脉络") {
                VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                    ForEach(visibleItems) { item in
                        TimelineRow(item: item)
                    }
                }
                .padding(.top, ParallelMeSpacing.xs)
            }
            .font(ParallelMeTypography.compact)
            .foregroundStyle(ParallelMeColor.ink)
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

private struct RuntimeSnapshotView: View {
    var snapshot: MeetingRuntimeSnapshot

    private var context: ProviderContext? {
        snapshot.context?.normalized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
            HStack(spacing: ParallelMeSpacing.xs) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                Text(snapshot.providerLabel)
                    .font(ParallelMeTypography.compact.weight(.medium))
                if let summary = snapshot.contextSummary {
                    Text(summary)
                        .font(ParallelMeTypography.compact)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                }
            }
            .foregroundStyle(ParallelMeColor.ink)

            if let context, !context.isEmpty {
                DisclosureGroup("会话上下文") {
                    VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
                        if let meCard = context.meCard {
                            RuntimeSnapshotRow(title: "个人背景", text: meCard)
                        }
                        if let tasteProfile = context.tasteProfile {
                            RuntimeSnapshotRow(title: "回应偏好", text: tasteProfile)
                        }
                    }
                    .padding(.top, ParallelMeSpacing.xs)
                }
                .font(ParallelMeTypography.compact)
                .foregroundStyle(ParallelMeColor.ink)
            }
        }
    }
}

private struct RuntimeSnapshotRow: View {
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
                .lineLimit(3)
        }
    }
}

private struct TimelineRow: View {
    var item: MeetingTimelineItem

    var body: some View {
        HStack(alignment: .top, spacing: ParallelMeSpacing.sm) {
            Circle()
                .fill(color(for: item.stage))
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(ParallelMeTypography.compact.weight(.medium))
                    .foregroundStyle(ParallelMeColor.ink)
                Text(item.detail)
                    .font(ParallelMeTypography.compact)
                    .foregroundStyle(ParallelMeColor.inkMuted)
                    .lineLimit(2)
            }
        }
    }

    private func color(for stage: MeetingStage) -> Color {
        switch stage {
        case .defining:
            return ParallelMeColor.inkMuted
        case .roundtable:
            return ParallelMeColor.roam
        case .inquiry:
            return ParallelMeColor.future
        case .settlement:
            return ParallelMeColor.money
        case .archived:
            return ParallelMeColor.rest
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
            DisclosureGroup("个人上下文") {
                VStack(spacing: ParallelMeSpacing.sm) {
                    TextField("我是谁 / 长期处境", text: $viewModel.contextMeCard, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("偏好的语气 / 判断方式", text: $viewModel.contextTasteProfile, axis: .vertical)
                        .lineLimit(2...5)
                }
                .textFieldStyle(.roundedBorder)
                .font(ParallelMeTypography.compact)
                .padding(.top, ParallelMeSpacing.xs)
            }
            .font(ParallelMeTypography.compact)
            .foregroundStyle(ParallelMeColor.ink)
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

private struct ResumeMeetingCard: View {
    var meeting: MeetingSummary
    var restore: (String) -> Void
    var delete: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Text("继续未完成纸页")
                .font(ParallelMeTypography.eyebrow)
                .foregroundStyle(ParallelMeColor.inkMuted)
            Text(meeting.title)
                .font(ParallelMeTypography.bodyStrong)
                .foregroundStyle(ParallelMeColor.ink)
                .lineLimit(2)
            Text(meeting.subtitle)
                .font(ParallelMeTypography.compact)
                .foregroundStyle(ParallelMeColor.inkMuted)
            HStack(spacing: ParallelMeSpacing.sm) {
                Button {
                    restore(meeting.id)
                } label: {
                    Label("继续", systemImage: "arrow.uturn.forward.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button(role: .destructive) {
                    delete(meeting.id)
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(ParallelMeSpacing.md)
        .background(ParallelMeColor.future.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                .stroke(ParallelMeColor.future.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct PaperLibrarySection: View {
    var library: MeetingLibrarySnapshot
    var sourceLibrary: MeetingLibrarySnapshot
    @Binding var searchText: String
    var restore: (String) -> Void
    var delete: (String) -> Void

    private var hasQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        if !sourceLibrary.isEmpty {
            VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text("纸页库")
                        .font(ParallelMeTypography.bodyStrong)
                        .foregroundStyle(ParallelMeColor.ink)
                    Spacer()
                    Text(statusText)
                        .font(ParallelMeTypography.compact)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                }

                HStack(spacing: ParallelMeSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(ParallelMeColor.inkMuted)
                    TextField("搜索纸页", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(ParallelMeTypography.compact)
                    if hasQuery {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                        .accessibilityLabel(Text("清空搜索"))
                    }
                }
                .padding(.horizontal, ParallelMeSpacing.sm)
                .padding(.vertical, ParallelMeSpacing.xs)
                .background(ParallelMeColor.paperLift)
                .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                        .stroke(ParallelMeColor.line.opacity(0.75), lineWidth: 1)
                )

                if library.isEmpty {
                    Text("没有匹配纸页")
                        .font(ParallelMeTypography.compact)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                        .padding(ParallelMeSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ParallelMeColor.paperLift)
                        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
                } else {
                    if !library.unfinished.isEmpty {
                        PaperLibraryGroup(
                            title: "未完成",
                            meetings: library.unfinished,
                            tint: ParallelMeColor.future,
                            restore: restore,
                            delete: delete
                        )
                    }

                    if !library.archived.isEmpty {
                        PaperLibraryGroup(
                            title: "已归档",
                            meetings: library.archived,
                            tint: ParallelMeColor.money,
                            restore: restore,
                            delete: delete
                        )
                    }
                }
            }
        }
    }

    private var statusText: String {
        if hasQuery {
            return "\(library.totalCount) 个匹配"
        }
        return "\(sourceLibrary.totalCount) 张 · \(sourceLibrary.archivedCount) 已归档"
    }
}

private struct PaperLibraryGroup: View {
    var title: String
    var meetings: [MeetingSummary]
    var tint: Color
    var restore: (String) -> Void
    var delete: (String) -> Void

    var body: some View {
        DisclosureGroup("\(title) · \(meetings.count)") {
            VStack(spacing: ParallelMeSpacing.sm) {
                ForEach(meetings) { meeting in
                    PaperLibraryRow(
                        meeting: meeting,
                        tint: tint,
                        restore: restore,
                        delete: delete
                    )
                }
            }
            .padding(.top, ParallelMeSpacing.xs)
        }
        .font(ParallelMeTypography.compact)
        .foregroundStyle(ParallelMeColor.ink)
    }
}

private struct PaperLibraryRow: View {
    var meeting: MeetingSummary
    var tint: Color
    var restore: (String) -> Void
    var delete: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: ParallelMeSpacing.sm) {
            Button {
                restore(meeting.id)
            } label: {
                VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
                    Text(meeting.title)
                        .font(ParallelMeTypography.bodyStrong)
                        .foregroundStyle(ParallelMeColor.ink)
                        .lineLimit(2)
                    Text(meeting.subtitle)
                        .font(ParallelMeTypography.compact)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                delete(meeting.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("删除纸页"))
        }
        .padding(ParallelMeSpacing.md)
        .background(ParallelMeColor.paperLift)
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                .stroke(tint.opacity(0.35), lineWidth: 1)
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

private struct SessionDiagnosticsPanel: View {
    var events: [MeetingSessionEvent]

    var body: some View {
        DisclosureGroup("运行轨迹") {
            VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                ForEach(events.reversed()) { event in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: ParallelMeSpacing.xs) {
                            Text(label(for: event.kind))
                                .font(ParallelMeTypography.eyebrow)
                                .foregroundStyle(color(for: event.kind))
                            Text(event.message)
                                .font(ParallelMeTypography.compact)
                                .foregroundStyle(ParallelMeColor.ink)
                                .lineLimit(2)
                        }
                        if let trace = event.trace.first {
                            Text(trace)
                                .font(ParallelMeTypography.compact)
                                .foregroundStyle(ParallelMeColor.inkMuted)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, ParallelMeSpacing.xs)
        }
        .font(ParallelMeTypography.compact)
        .foregroundStyle(ParallelMeColor.ink)
        .padding(ParallelMeSpacing.md)
        .background(ParallelMeColor.paperLift.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                .stroke(ParallelMeColor.line.opacity(0.55), lineWidth: 1)
        )
    }

    private func label(for kind: MeetingSessionEventKind) -> String {
        switch kind {
        case .started:
            return "开始"
        case .providerRequest:
            return "请求"
        case .providerResponse:
            return "响应"
        case .persisted:
            return "保存"
        case .failed:
            return "失败"
        }
    }

    private func color(for kind: MeetingSessionEventKind) -> Color {
        switch kind {
        case .started:
            return ParallelMeColor.rest
        case .providerRequest:
            return ParallelMeColor.roam
        case .providerResponse:
            return ParallelMeColor.future
        case .persisted:
            return ParallelMeColor.money
        case .failed:
            return ParallelMeColor.filial
        }
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
            roundtableControls
        }
    }

    private var roundtableControls: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
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
    public var revise: ([SettlementModuleID: String]) -> Void
    public var archive: () -> Void
    @State private var creativeDraft = ""
    @State private var valueDraft = ""
    @State private var costDraft = ""
    @State private var actionDraft = ""
    @State private var synthesisDraft = ""

    public init(
        settlement: HeartSettlement,
        revise: @escaping ([SettlementModuleID: String]) -> Void = { _ in },
        archive: @escaping () -> Void = {}
    ) {
        self.settlement = settlement
        self.revise = revise
        self.archive = archive
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            Text("本心落定")
                .font(ParallelMeTypography.title)
            Text(settlement.headline)
                .font(ParallelMeTypography.bodyStrong)
            SettlementModuleEditor(title: "创造性无望", text: $creativeDraft)
            SettlementModuleEditor(title: "核心价值主轴", text: $valueDraft)
            SettlementModuleEditor(title: "痛苦接纳契约", text: $costDraft)
            SettlementModuleEditor(title: "最小行动承诺", text: $actionDraft)
            SettlementModuleEditor(title: "正反合", text: $synthesisDraft)
            Button {
                revise([
                    .creativeHopelessness: creativeDraft,
                    .coreValues: valueDraft,
                    .costAcceptance: costDraft,
                    .minimumAction: actionDraft,
                    .dialecticSynthesis: synthesisDraft
                ])
            } label: {
                Label("应用修订", systemImage: "pencil.and.scribble")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            Button(action: archive) {
                Label("保存纸页", systemImage: "archivebox.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .foregroundStyle(ParallelMeColor.ink)
        .onAppear {
            loadDrafts(from: settlement)
        }
    }

    private func loadDrafts(from settlement: HeartSettlement) {
        creativeDraft = settlement.resolvedText(for: .creativeHopelessness)
        valueDraft = settlement.resolvedText(for: .coreValues)
        costDraft = settlement.resolvedText(for: .costAcceptance)
        actionDraft = settlement.resolvedText(for: .minimumAction)
        synthesisDraft = settlement.resolvedText(for: .dialecticSynthesis)
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

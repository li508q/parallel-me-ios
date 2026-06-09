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
                        if let activity = viewModel.activity {
                            ActivityBanner(activity: activity)
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
                                    isBusy: viewModel.isBusy,
                                    restore: viewModel.restoreMeeting,
                                    delete: viewModel.deleteMeeting
                                )
                            }
                            startCard
                            PaperLibrarySection(
                                library: viewModel.visibleMeetingLibrary,
                                sourceLibrary: viewModel.meetingLibrary,
                                isBusy: viewModel.isBusy,
                                searchText: $viewModel.librarySearchText,
                                filter: $viewModel.libraryFilter,
                                restore: viewModel.restoreMeeting,
                                delete: viewModel.deleteMeeting
                            )
                            VoicePrimerGrid()
                        }
                        if !viewModel.sessionDiagnostics.isEmpty || viewModel.currentPaperHealth != nil {
                            SessionDiagnosticsPanel(
                                snapshot: viewModel.sessionDiagnostics,
                                paperHealth: viewModel.currentPaperHealth
                            )
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
        let readiness = viewModel.startReadiness
        return VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            ProviderSettingsPanel(viewModel: viewModel)
            if viewModel.petition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                PetitionStarterPromptGrid { prompt in
                    viewModel.useStarterPrompt(prompt)
                }
                .disabled(!readiness.canUseStarterPrompts)
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
                .disabled(!readiness.canEditPetition)
            StartReadinessView(snapshot: readiness)
            Button {
                viewModel.startMeeting()
            } label: {
                Label(readiness.actionTitle, systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!readiness.canStart)
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
            let snapshot = SettlementStageSnapshot(state: state)
            if snapshot.canShowSettlementEditor, let settlement = state.heartSettlement {
                SettlementView(
                    settlement: settlement,
                    isBusy: viewModel.isBusy,
                    revise: viewModel.reviseSettlement,
                    archive: viewModel.archive
                )
            } else {
                SettlementUnavailableView(snapshot: snapshot, reset: viewModel.reset)
            }
        case .archived:
            ArchivedView(state: state, reset: viewModel.reset)
        }
    }
}

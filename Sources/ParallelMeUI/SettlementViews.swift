import ParallelMeCore
import ParallelMeDesign
import SwiftUI

public struct SettlementView: View {
    public var settlement: HeartSettlement
    public var isBusy: Bool
    public var revise: ([SettlementModuleID: String]) -> Void
    public var archive: () -> Void
    @State private var draft: SettlementRevisionDraft

    public init(
        settlement: HeartSettlement,
        isBusy: Bool = false,
        revise: @escaping ([SettlementModuleID: String]) -> Void = { _ in },
        archive: @escaping () -> Void = {}
    ) {
        self.settlement = settlement
        self.isBusy = isBusy
        self.revise = revise
        self.archive = archive
        _draft = State(initialValue: SettlementRevisionDraft(settlement: settlement))
    }

    private var actionAvailability: SettlementActionAvailabilitySnapshot {
        SettlementActionAvailabilitySnapshot(draft: draft, isBusy: isBusy)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            Text("本心落定")
                .font(ParallelMeTypography.title)
            Text(settlement.headline)
                .font(ParallelMeTypography.bodyStrong)
            SettlementModuleEditor(title: "创造性无望", text: $draft.creativeHopelessness, isDisabled: isBusy)
            SettlementModuleEditor(title: "核心价值主轴", text: $draft.coreValues, isDisabled: isBusy)
            SettlementModuleEditor(title: "痛苦接纳契约", text: $draft.costAcceptance, isDisabled: isBusy)
            SettlementModuleEditor(title: "最小行动承诺", text: $draft.minimumAction, isDisabled: isBusy)
            SettlementModuleEditor(title: "正反合", text: $draft.dialecticSynthesis, isDisabled: isBusy)
            Text(actionAvailability.message)
                .font(ParallelMeTypography.compact)
                .foregroundStyle(messageColor)
            Button {
                revise(draft.revisions)
            } label: {
                Label("应用修订", systemImage: "pencil.and.scribble")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!actionAvailability.canApplyRevision)
            Button(action: archive) {
                Label("保存纸页", systemImage: "archivebox.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!actionAvailability.canArchive)
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

    private var messageColor: Color {
        switch actionAvailability.messageTone {
        case .muted:
            return ParallelMeColor.inkMuted
        case .warning:
            return ParallelMeColor.filial
        }
    }
}

private struct SettlementModuleEditor: View {
    var title: String
    @Binding var text: String
    var isDisabled: Bool

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
                .disabled(isDisabled)
        }
        .padding(.vertical, ParallelMeSpacing.xs)
    }
}

struct SettlementUnavailableView: View {
    var snapshot: SettlementStageSnapshot
    var reset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            HStack(alignment: .top, spacing: ParallelMeSpacing.sm) {
                Image(systemName: snapshot.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ParallelMeColor.filial)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
                    Text(snapshot.title)
                        .font(ParallelMeTypography.title)
                        .foregroundStyle(ParallelMeColor.ink)
                    Text(snapshot.detail)
                        .font(ParallelMeTypography.body)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: reset) {
                Label(snapshot.recoveryActionTitle, systemImage: "house")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(ParallelMeSpacing.md)
        .background(ParallelMeColor.paperLift)
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                .stroke(ParallelMeColor.filial.opacity(0.35), lineWidth: 1)
        )
    }
}

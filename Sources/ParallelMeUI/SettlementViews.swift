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

    private var controlsPresentation: SettlementControlsPresentationSnapshot {
        SettlementControlsPresentationSnapshot(availability: actionAvailability)
    }

    private var snapshot: HeartSettlementSnapshot {
        HeartSettlementSnapshot(settlement: settlement)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            Text(snapshot.title)
                .font(ParallelMeTypography.title)
            Text(snapshot.headline)
                .font(ParallelMeTypography.bodyStrong)
            ForEach(snapshot.rows) { row in
                SettlementModuleEditor(
                    title: row.title,
                    text: binding(for: row.moduleID),
                    isDisabled: isBusy
                )
            }
            Text(actionAvailability.message)
                .font(ParallelMeTypography.compact)
                .foregroundStyle(messageColor)
            Button {
                revise(draft.revisions)
            } label: {
                Label(
                    controlsPresentation.applyRevisionAction.title,
                    systemImage: controlsPresentation.applyRevisionAction.systemImage
                )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!controlsPresentation.applyRevisionAction.isEnabled)
            Button(action: archive) {
                Label(
                    controlsPresentation.archiveAction.title,
                    systemImage: controlsPresentation.archiveAction.systemImage
                )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!controlsPresentation.archiveAction.isEnabled)
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

    private func binding(for moduleID: SettlementModuleID) -> Binding<String> {
        Binding(
            get: {
                draft.text(for: moduleID)
            },
            set: { newValue in
                draft.setText(newValue, for: moduleID)
            }
        )
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
                Label(snapshot.recoveryActionTitle, systemImage: snapshot.recoveryActionSystemImage)
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

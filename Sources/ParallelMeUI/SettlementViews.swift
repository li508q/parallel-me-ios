import ParallelMeCore
import ParallelMeDesign
import SwiftUI

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

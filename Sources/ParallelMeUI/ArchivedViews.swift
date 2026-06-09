import ParallelMeCore
import ParallelMeDesign
import SwiftUI

struct ArchivedView: View {
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

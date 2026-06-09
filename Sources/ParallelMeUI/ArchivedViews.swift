import ParallelMeCore
import ParallelMeDesign
import SwiftUI

struct ArchivedView: View {
    var state: MeetingFlowState
    var reset: () -> Void

    private var snapshot: MeetingArchiveSnapshot {
        MeetingArchiveSnapshot(state: state)
    }

    private var presentation: MeetingArchivePresentationSnapshot {
        MeetingArchivePresentationSnapshot(snapshot: snapshot)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.lg) {
            VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                Text(presentation.eyebrow)
                    .font(ParallelMeTypography.eyebrow)
                    .foregroundStyle(ParallelMeColor.inkMuted)
                Text(presentation.title)
                    .font(ParallelMeTypography.title)
                    .foregroundStyle(ParallelMeColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(presentation.detail)
                    .font(ParallelMeTypography.body)
                    .foregroundStyle(ParallelMeColor.inkMuted)
            }

            ForEach(presentation.sections) { section in
                ArchiveSection(section: section)
            }

            if let timeline = presentation.timeline {
                DisclosureGroup(timeline.title) {
                    VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                        ForEach(timeline.items) { item in
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
                Label(
                    presentation.resetAction.title,
                    systemImage: presentation.resetAction.systemImage
                )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct ArchiveSection: View {
    var section: MeetingArchiveSectionSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            Text(section.title)
                .font(ParallelMeTypography.bodyStrong)
                .foregroundStyle(ParallelMeColor.ink)
            VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                ForEach(section.rows) { row in
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

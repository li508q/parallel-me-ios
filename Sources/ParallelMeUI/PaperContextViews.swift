import ParallelMeCore
import ParallelMeDesign
import SwiftUI

struct MeetingPaperContextView: View {
    var state: MeetingFlowState
    var isBusy: Bool
    var close: () -> Void
    @State private var isTimelineExpanded = false
    @State private var exportFileURL: URL?
    @State private var exportErrorMessage: String?

    private var presentation: MeetingPaperContextPresentationSnapshot {
        MeetingPaperContextPresentationSnapshot(
            state: state,
            isBusy: isBusy,
            isTimelineExpanded: isTimelineExpanded,
            hasPreparedExportFile: exportFileURL != nil,
            preparedExportFileName: exportFileURL?.lastPathComponent
        )
    }

    private var exportDocument: MeetingExportDocument {
        MeetingExportDocument(state: state)
    }

    private var exportAvailability: MeetingExportAvailabilitySnapshot {
        MeetingExportAvailabilitySnapshot(state: state)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            HStack(alignment: .top, spacing: ParallelMeSpacing.sm) {
                VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
                    Text(presentation.summaryTitle)
                        .font(ParallelMeTypography.bodyStrong)
                        .foregroundStyle(ParallelMeColor.ink)
                        .lineLimit(2)
                    Text(presentation.summarySubtitle)
                        .font(ParallelMeTypography.compact)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                }
                Spacer(minLength: ParallelMeSpacing.sm)
                VStack(alignment: .trailing, spacing: ParallelMeSpacing.xs) {
                    Text(presentation.stepCountText)
                        .font(ParallelMeTypography.eyebrow)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                        .padding(.horizontal, ParallelMeSpacing.sm)
                        .padding(.vertical, ParallelMeSpacing.xs)
                        .background(ParallelMeColor.paper)
                        .clipShape(Capsule())
                    Button(action: close) {
                        Label(
                            presentation.closeAction.title,
                            systemImage: presentation.closeAction.systemImage
                        )
                            .labelStyle(.iconOnly)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!presentation.closeAction.isEnabled)
                    .accessibilityLabel(Text(presentation.closeAction.accessibilityLabel))
                    if presentation.export.shouldShowControl {
                        exportControl
                    }
                }
            }

            if let exportErrorMessage {
                Text(exportErrorMessage)
                    .font(ParallelMeTypography.compact)
                    .foregroundStyle(ParallelMeColor.filial)
            } else if let blockerMessage = presentation.export.blockerMessage {
                Text(blockerMessage)
                    .font(ParallelMeTypography.compact)
                    .foregroundStyle(ParallelMeColor.filial)
            }

            if let runtime = presentation.runtime {
                RuntimeSnapshotView(snapshot: runtime)
            }

            DisclosureGroup(presentation.timelineDisclosureTitle) {
                VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                    ForEach(presentation.timeline.items) { item in
                        TimelineRow(item: item)
                    }
                    if let control = presentation.timeline.expansionControl {
                        Button {
                            isTimelineExpanded.toggle()
                        } label: {
                            Label(control.title, systemImage: control.systemImage)
                        }
                        .buttonStyle(.borderless)
                        .font(ParallelMeTypography.compact.weight(.medium))
                        .foregroundStyle(ParallelMeColor.ink)
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
        .task(id: state) {
            if exportAvailability.canExport {
                prepareExportFile()
            } else {
                exportFileURL = nil
                exportErrorMessage = nil
            }
        }
    }

    @ViewBuilder
    private var exportControl: some View {
        if presentation.export.canSharePreparedFile, let exportFileURL {
            ShareLink(
                item: exportFileURL,
                subject: Text(exportDocument.title),
                message: Text(presentation.export.shareMessage)
            ) {
                Label(
                    presentation.export.action.title,
                    systemImage: presentation.export.action.systemImage
                )
                    .labelStyle(.iconOnly)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)
            .disabled(!presentation.export.action.isEnabled)
            .accessibilityLabel(Text(presentation.export.action.accessibilityLabel))
            .accessibilityHint(Text(presentation.export.action.accessibilityHint ?? exportDocument.fileName))
        } else {
            Button(action: prepareExportFile) {
                Label(
                    presentation.export.action.title,
                    systemImage: presentation.export.action.systemImage
                )
                    .labelStyle(.iconOnly)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)
            .disabled(!presentation.export.action.isEnabled)
            .accessibilityLabel(Text(presentation.export.action.accessibilityLabel))
            .accessibilityHint(Text(presentation.export.action.accessibilityHint ?? ""))
        }
    }

    private func prepareExportFile() {
        guard presentation.export.canExport else { return }
        do {
            let file = try MeetingExportFileWriter().write(document: exportDocument)
            exportFileURL = file.url
            exportErrorMessage = nil
        } catch {
            exportFileURL = nil
            exportErrorMessage = "纸页文件暂时没有准备好，请稍后再试。"
        }
    }
}

private struct RuntimeSnapshotView: View {
    var snapshot: MeetingRuntimePresentationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
            HStack(spacing: ParallelMeSpacing.xs) {
                Image(systemName: snapshot.providerSystemImage)
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

            if snapshot.hasContextRows {
                DisclosureGroup(snapshot.contextTitle) {
                    VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
                        ForEach(snapshot.contextRows) { row in
                            RuntimeSnapshotRow(title: row.title, text: row.body)
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

struct TimelineRow: View {
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

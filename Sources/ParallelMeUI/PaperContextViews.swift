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

    private var summary: MeetingSummary {
        MeetingSummary(state: state)
    }

    private var timelineSnapshot: MeetingTimelineSnapshot {
        MeetingTimelineSnapshot(state: state)
    }

    private var visibleItems: [MeetingTimelineItem] {
        timelineSnapshot.visibleItems(isExpanded: isTimelineExpanded)
    }

    private var timelineTitle: String {
        if isTimelineExpanded || !timelineSnapshot.hasHiddenHistory {
            return "完整 \(timelineSnapshot.totalCount) 步"
        }
        return "最近 \(visibleItems.count) / 共 \(timelineSnapshot.totalCount) 步"
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
                    Text("\(timelineSnapshot.totalCount) 步")
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
                    if exportAvailability.shouldShowExportControl {
                        exportControl
                    }
                }
            }

            if let exportErrorMessage {
                Text(exportErrorMessage)
                    .font(ParallelMeTypography.compact)
                    .foregroundStyle(ParallelMeColor.filial)
            } else if let blockerMessage = exportAvailability.blockerMessage {
                Text(blockerMessage)
                    .font(ParallelMeTypography.compact)
                    .foregroundStyle(ParallelMeColor.filial)
            }

            if let snapshot = state.runtimeSnapshot {
                RuntimeSnapshotView(snapshot: snapshot)
            }

            DisclosureGroup("纸页脉络 · \(timelineTitle)") {
                VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                    ForEach(visibleItems) { item in
                        TimelineRow(item: item)
                    }
                    if timelineSnapshot.hasHiddenHistory {
                        Button {
                            isTimelineExpanded.toggle()
                        } label: {
                            Label(
                                isTimelineExpanded ? "收起" : "展开全部",
                                systemImage: isTimelineExpanded ? "chevron.up.circle" : "list.bullet.rectangle"
                            )
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
        if exportAvailability.canExport, let exportFileURL {
            ShareLink(
                item: exportFileURL,
                subject: Text(exportDocument.title),
                message: Text("ParallelMe 纸页")
            ) {
                Label(exportAvailability.actionTitle, systemImage: "square.and.arrow.up")
                    .labelStyle(.iconOnly)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(Text(exportAvailability.actionTitle))
            .accessibilityHint(Text(exportDocument.fileName))
        } else {
            Button(action: prepareExportFile) {
                Label(exportAvailability.actionTitle, systemImage: "square.and.arrow.up")
                    .labelStyle(.iconOnly)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)
            .disabled(isBusy || !exportAvailability.canExport)
            .accessibilityLabel(Text(exportAvailability.actionTitle))
            .accessibilityHint(Text(exportAvailability.accessibilityHint))
        }
    }

    private func prepareExportFile() {
        guard exportAvailability.canExport else { return }
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

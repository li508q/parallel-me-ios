import ParallelMeCore
import ParallelMeDesign
import SwiftUI

extension View {
    @ViewBuilder
    func parallelMeInlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

struct ErrorBanner: View {
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

struct ActivityBanner: View {
    var activity: MeetingActivitySnapshot

    var body: some View {
        HStack(alignment: .top, spacing: ParallelMeSpacing.sm) {
            ProgressView()
                .controlSize(.small)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: ParallelMeSpacing.xs) {
                    Image(systemName: activity.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                    Text(activity.title)
                        .font(ParallelMeTypography.compact.weight(.medium))
                }
                Text(activity.detail)
                    .font(ParallelMeTypography.compact)
                    .foregroundStyle(ParallelMeColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if activity.usesProvider {
                Text("模型")
                    .font(ParallelMeTypography.eyebrow)
                    .foregroundStyle(ParallelMeColor.future)
                    .padding(.horizontal, ParallelMeSpacing.xs)
                    .padding(.vertical, 3)
                    .background(ParallelMeColor.future.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .foregroundStyle(ParallelMeColor.ink)
        .padding(ParallelMeSpacing.md)
        .background(ParallelMeColor.paperLift)
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                .stroke(ParallelMeColor.future.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(activity.title))
        .accessibilityHint(Text(activity.detail))
    }
}

struct SessionDiagnosticsPanel: View {
    var snapshot: MeetingSessionDiagnosticsSnapshot
    var paperHealth: MeetingStateHealthSnapshot?

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
                if let paperHealth {
                    paperHealthView(paperHealth)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(snapshot.detail)
                        .font(ParallelMeTypography.compact)
                        .foregroundStyle(snapshot.hasFailures ? ParallelMeColor.filial : ParallelMeColor.inkMuted)
                    HStack(spacing: ParallelMeSpacing.xs) {
                        diagnosticsPill("请求", snapshot.providerRequestCount, color: ParallelMeColor.roam)
                        diagnosticsPill("响应", snapshot.providerResponseCount, color: ParallelMeColor.future)
                        diagnosticsPill("保存", snapshot.persistedCount, color: ParallelMeColor.money)
                    }
                }

                VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                    ForEach(snapshot.recentEvents.reversed()) { event in
                        eventRow(event)
                    }
                }
            }
            .padding(.top, ParallelMeSpacing.xs)
        } label: {
            HStack(spacing: ParallelMeSpacing.xs) {
                Image(systemName: snapshot.hasFailures ? "exclamationmark.triangle.fill" : "waveform.path.ecg")
                    .foregroundStyle(snapshot.hasFailures ? ParallelMeColor.filial : ParallelMeColor.inkMuted)
                Text(snapshot.title)
            }
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

    private func paperHealthView(_ health: MeetingStateHealthSnapshot) -> some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: ParallelMeSpacing.xs) {
                Image(systemName: icon(for: health.tone))
                    .foregroundStyle(color(for: health.tone))
                Text(health.title)
                    .font(ParallelMeTypography.compact.weight(.medium))
                    .foregroundStyle(ParallelMeColor.ink)
                Spacer()
                Text(label(for: health.stage))
                    .font(ParallelMeTypography.eyebrow)
                    .foregroundStyle(ParallelMeColor.inkMuted)
            }
            Text(health.detail)
                .font(ParallelMeTypography.compact)
                .foregroundStyle(health.tone == .blocked ? ParallelMeColor.filial : ParallelMeColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(health.findings.prefix(4)) { finding in
                HStack(alignment: .top, spacing: ParallelMeSpacing.xs) {
                    Image(systemName: finding.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(color(for: finding.tone))
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(finding.title)
                            .font(ParallelMeTypography.eyebrow)
                            .foregroundStyle(ParallelMeColor.ink)
                        Text(finding.detail)
                            .font(ParallelMeTypography.compact)
                            .foregroundStyle(ParallelMeColor.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(ParallelMeSpacing.sm)
        .background(ParallelMeColor.paper.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                .stroke(color(for: health.tone).opacity(0.25), lineWidth: 1)
        )
    }

    private func eventRow(_ event: MeetingSessionEvent) -> some View {
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

    private func diagnosticsPill(_ title: String, _ count: Int, color: Color) -> some View {
        Text("\(title) \(count)")
            .font(ParallelMeTypography.eyebrow)
            .foregroundStyle(color)
            .padding(.horizontal, ParallelMeSpacing.xs)
            .padding(.vertical, 3)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }

    private func label(for stage: MeetingStage) -> String {
        switch stage {
        case .defining:
            return "定义"
        case .roundtable:
            return "圆桌"
        case .inquiry:
            return "问询"
        case .settlement:
            return "落定"
        case .archived:
            return "归档"
        }
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

    private func icon(for tone: MeetingStateHealthTone) -> String {
        switch tone {
        case .ok:
            return "checkmark.seal.fill"
        case .warning:
            return "exclamationmark.circle.fill"
        case .blocked:
            return "exclamationmark.triangle.fill"
        }
    }

    private func color(for tone: MeetingStateHealthTone) -> Color {
        switch tone {
        case .ok:
            return ParallelMeColor.rest
        case .warning:
            return ParallelMeColor.money
        case .blocked:
            return ParallelMeColor.filial
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

    private var snapshot: MeetingStageProgressSnapshot {
        MeetingStageProgressSnapshot(stage: stage)
    }

    public init(stage: MeetingStage) {
        self.stage = stage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("第 \(snapshot.currentPosition) / \(snapshot.totalCount) 步")
                    .font(ParallelMeTypography.eyebrow)
                    .foregroundStyle(ParallelMeColor.inkMuted)
                Spacer()
                Text(snapshot.currentItem.title)
                    .font(ParallelMeTypography.compact.weight(.medium))
                    .foregroundStyle(ParallelMeColor.ink)
            }

            Text(snapshot.currentItem.detail)
                .font(ParallelMeTypography.compact)
                .foregroundStyle(ParallelMeColor.inkMuted)

            HStack(spacing: ParallelMeSpacing.xs) {
                ForEach(snapshot.items) { item in
                    VStack(spacing: ParallelMeSpacing.xs) {
                        Capsule()
                            .fill(color(for: item))
                            .frame(height: item.isCurrent ? 8 : 5)
                        Text(item.title)
                            .font(ParallelMeTypography.eyebrow)
                            .foregroundStyle(item.isCurrent ? ParallelMeColor.ink : ParallelMeColor.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(Text(accessibilityText(for: item)))
                }
            }
        }
        .padding(.horizontal, ParallelMeSpacing.xs)
        .accessibilityElement(children: .contain)
    }

    private func color(for item: MeetingStageProgressItem) -> Color {
        if item.isCurrent { return ParallelMeColor.ink }
        if item.isCompleted { return ParallelMeColor.rest }
        return ParallelMeColor.line
    }

    private func accessibilityText(for item: MeetingStageProgressItem) -> String {
        if item.isCurrent {
            return "当前阶段，\(item.title)，\(item.detail)"
        }
        if item.isCompleted {
            return "已完成阶段，\(item.title)"
        }
        return "未开始阶段，\(item.title)"
    }
}

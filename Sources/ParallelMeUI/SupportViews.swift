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

struct SessionDiagnosticsPanel: View {
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

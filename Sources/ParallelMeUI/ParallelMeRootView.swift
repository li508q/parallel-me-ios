import ParallelMeCore
import ParallelMeDesign
import SwiftUI

public struct ParallelMeRootView: View {
    @State private var petition = ""
    @State private var state: MeetingFlowState?
    private let engine = MeetingFlowEngine()

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                ParallelMeColor.paper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: ParallelMeSpacing.lg) {
                        header
                        if let state {
                            MeetingStageRail(stage: state.stage)
                            stageBody(state)
                        } else {
                            startCard
                            VoicePrimerGrid()
                        }
                    }
                    .padding(.horizontal, ParallelMeSpacing.md)
                    .padding(.vertical, ParallelMeSpacing.xl)
                }
            }
            .parallelMeInlineNavigationTitle()
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
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            TextEditor(text: $petition)
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
            Button {
                state = try? engine.start(rawInput: petition)
            } label: {
                Label("开始五声圆桌", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(petition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @ViewBuilder
    private func stageBody(_ state: MeetingFlowState) -> some View {
        switch state.stage {
        case .defining:
            DefiningPlaceholderView(rawInput: state.rawInput)
        case .roundtable:
            RoundtablePlaceholderView(record: state.roundtable)
        case .inquiry:
            InquiryPlaceholderView(questions: state.inquiryQuestions)
        case .settlement:
            if let settlement = state.heartSettlement {
                SettlementView(settlement: settlement)
            }
        case .archived:
            Text("这张纸页已经归档。")
                .font(ParallelMeTypography.body)
        }
    }
}

private extension View {
    @ViewBuilder
    func parallelMeInlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
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

public struct VoicePrimerGrid: View {
    public init() {}

    public var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: ParallelMeSpacing.sm)], spacing: ParallelMeSpacing.sm) {
            ForEach(VoicePersonas.all) { persona in
                VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
                    Text(persona.name)
                        .font(ParallelMeTypography.bodyStrong)
                        .foregroundStyle(ParallelMeColor.ink)
                    Text(persona.coreValue)
                        .font(ParallelMeTypography.compact)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(ParallelMeSpacing.md)
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                .background(ParallelMeTheme.voiceColor(persona.id.rawValue).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                        .stroke(ParallelMeTheme.voiceColor(persona.id.rawValue).opacity(0.35), lineWidth: 1)
                )
            }
        }
    }
}

private struct DefiningPlaceholderView: View {
    var rawInput: String

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Text("本次议题")
                .font(ParallelMeTypography.bodyStrong)
            Text(rawInput)
                .font(ParallelMeTypography.body)
                .foregroundStyle(ParallelMeColor.inkMuted)
        }
        .padding(ParallelMeSpacing.md)
        .background(ParallelMeColor.paperLift)
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
    }
}

private struct RoundtablePlaceholderView: View {
    var record: RoundtableRecord

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Text("五声圆桌")
                .font(ParallelMeTypography.bodyStrong)
            Text("已收到 \(record.openingTurns.count) 个开场声音。")
                .font(ParallelMeTypography.body)
                .foregroundStyle(ParallelMeColor.inkMuted)
        }
    }
}

private struct InquiryPlaceholderView: View {
    var questions: [ScribeInquiryQuestion]

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Text("书记员问询")
                .font(ParallelMeTypography.bodyStrong)
            Text("等待 \(questions.count) 个最终问题被回答。")
                .font(ParallelMeTypography.body)
                .foregroundStyle(ParallelMeColor.inkMuted)
        }
    }
}

public struct SettlementView: View {
    public var settlement: HeartSettlement

    public init(settlement: HeartSettlement) {
        self.settlement = settlement
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.md) {
            Text("本心落定")
                .font(ParallelMeTypography.title)
            Text(settlement.headline)
                .font(ParallelMeTypography.bodyStrong)
            module("创造性无望", settlement.creativeHopelessness.resolvedText)
            module("核心价值主轴", settlement.coreValueAxis.resolvedText)
            module("痛苦接纳契约", settlement.costAcceptanceContract.resolvedText)
            module("最小行动承诺", settlement.minimumViableCommitment.resolvedText)
        }
        .foregroundStyle(ParallelMeColor.ink)
    }

    private func module(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
            Text(title)
                .font(ParallelMeTypography.eyebrow)
                .foregroundStyle(ParallelMeColor.inkMuted)
            Text(body)
                .font(ParallelMeTypography.body)
        }
        .padding(.vertical, ParallelMeSpacing.xs)
    }
}

import ParallelMeCore
import ParallelMeDesign
import SwiftUI

struct ProviderSettingsPanel: View {
    @ObservedObject var viewModel: MeetingViewModel

    private var availability: RuntimePreferencesActionAvailabilitySnapshot {
        RuntimePreferencesActionAvailabilitySnapshot(
            providerSettings: viewModel.providerSettings,
            isBusy: viewModel.isBusy
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Picker("Provider", selection: $viewModel.providerMode) {
                ForEach(ProviderRuntimeMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!availability.canEdit)

            if viewModel.providerMode == .openAICompatible {
                VStack(spacing: ParallelMeSpacing.sm) {
                    TextField("Base URL", text: $viewModel.providerBaseURL)
                        .textContentType(.URL)
                    TextField("Model", text: $viewModel.providerModel)
                    SecureField("API Key", text: $viewModel.providerAPIKey)
                }
                .textFieldStyle(.roundedBorder)
                .font(ParallelMeTypography.compact)
                .disabled(!availability.canEdit)
            }
            DisclosureGroup("个人上下文") {
                VStack(spacing: ParallelMeSpacing.sm) {
                    TextField("我是谁 / 长期处境", text: $viewModel.contextMeCard, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("偏好的语气 / 判断方式", text: $viewModel.contextTasteProfile, axis: .vertical)
                        .lineLimit(2...5)
                }
                .textFieldStyle(.roundedBorder)
                .font(ParallelMeTypography.compact)
                .padding(.top, ParallelMeSpacing.xs)
            }
            .font(ParallelMeTypography.compact)
            .foregroundStyle(ParallelMeColor.ink)
            .disabled(!availability.canEdit)

            HStack(spacing: ParallelMeSpacing.sm) {
                Button {
                    viewModel.saveRuntimePreferences()
                } label: {
                    Label("保存", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!availability.canSave)

                Button(role: .destructive) {
                    viewModel.clearRuntimePreferences()
                } label: {
                    Label("清空", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!availability.canClear)
            }

            if let message = availability.message {
                Text(message)
                    .font(ParallelMeTypography.compact)
                    .foregroundStyle(ParallelMeColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let message = viewModel.runtimePreferencesMessage {
                HStack(alignment: .top, spacing: ParallelMeSpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(message)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        viewModel.dismissRuntimePreferencesMessage()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                }
                .font(ParallelMeTypography.compact)
                .foregroundStyle(ParallelMeColor.rest)
            }
        }
        .padding(ParallelMeSpacing.md)
        .background(ParallelMeColor.paperLift)
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                .stroke(ParallelMeColor.line, lineWidth: 1)
        )
    }
}

struct PetitionStarterPromptGrid: View {
    var prompts: [PetitionStarterPrompt] = PetitionStarterPrompts.all
    var select: (PetitionStarterPrompt) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: ParallelMeSpacing.sm)], spacing: ParallelMeSpacing.sm) {
            ForEach(prompts) { prompt in
                Button {
                    select(prompt)
                } label: {
                    VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
                        HStack(spacing: ParallelMeSpacing.xs) {
                            Circle()
                                .fill(ParallelMeTheme.voiceColor(prompt.accentVoiceID.rawValue))
                                .frame(width: 8, height: 8)
                            Text(prompt.title)
                                .font(ParallelMeTypography.bodyStrong)
                                .foregroundStyle(ParallelMeColor.ink)
                                .lineLimit(2)
                                .minimumScaleFactor(0.82)
                        }
                        Text(prompt.detail)
                            .font(ParallelMeTypography.compact)
                            .foregroundStyle(ParallelMeColor.inkMuted)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                    .padding(ParallelMeSpacing.md)
                    .background(ParallelMeTheme.voiceColor(prompt.accentVoiceID.rawValue).opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                            .stroke(ParallelMeTheme.voiceColor(prompt.accentVoiceID.rawValue).opacity(0.32), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(prompt.title))
                .accessibilityHint(Text("填入起笔困惑：\(prompt.seedText)"))
            }
        }
    }
}

struct StartReadinessView: View {
    var snapshot: MeetingStartReadinessSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: ParallelMeSpacing.sm) {
            Image(systemName: snapshot.canStart ? "checkmark.seal.fill" : "info.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(snapshot.canStart ? ParallelMeColor.rest : ParallelMeColor.inkMuted)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.title)
                    .font(ParallelMeTypography.compact.weight(.medium))
                    .foregroundStyle(ParallelMeColor.ink)
                Text(snapshot.detail)
                    .font(ParallelMeTypography.compact)
                    .foregroundStyle(ParallelMeColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(ParallelMeSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ParallelMeColor.paper.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.control))
        .overlay(
            RoundedRectangle(cornerRadius: ParallelMeRadius.control)
                .stroke(ParallelMeColor.line.opacity(0.6), lineWidth: 1)
        )
    }
}

struct ResumeMeetingCard: View {
    var meeting: MeetingSummary
    var isBusy: Bool
    var restore: (String) -> Void
    var delete: (String) -> Void

    private var availability: PaperLibraryActionAvailabilitySnapshot {
        PaperLibraryActionAvailabilitySnapshot(isBusy: isBusy)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Text("继续未完成纸页")
                .font(ParallelMeTypography.eyebrow)
                .foregroundStyle(ParallelMeColor.inkMuted)
            Text(meeting.title)
                .font(ParallelMeTypography.bodyStrong)
                .foregroundStyle(ParallelMeColor.ink)
                .lineLimit(2)
            Text(meeting.subtitle)
                .font(ParallelMeTypography.compact)
                .foregroundStyle(ParallelMeColor.inkMuted)
            HStack(spacing: ParallelMeSpacing.sm) {
                Button {
                    restore(meeting.id)
                } label: {
                    Label("继续", systemImage: "arrow.uturn.forward.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!availability.canRestore)
                DeletePaperButton(meeting: meeting, canDelete: availability.canDelete, delete: delete) {
                    Image(systemName: "trash")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(ParallelMeSpacing.md)
        .background(ParallelMeColor.future.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                .stroke(ParallelMeColor.future.opacity(0.35), lineWidth: 1)
        )
    }
}

struct PaperLibrarySection: View {
    var library: MeetingLibrarySnapshot
    var sourceLibrary: MeetingLibrarySnapshot
    var isBusy: Bool
    @Binding var searchText: String
    @Binding var filter: MeetingLibraryFilter
    var restore: (String) -> Void
    var delete: (String) -> Void

    private var hasQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isFiltering: Bool {
        filter != .all
    }

    private var availability: PaperLibraryActionAvailabilitySnapshot {
        PaperLibraryActionAvailabilitySnapshot(isBusy: isBusy)
    }

    var body: some View {
        if !sourceLibrary.isEmpty {
            VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text("纸页库")
                        .font(ParallelMeTypography.bodyStrong)
                        .foregroundStyle(ParallelMeColor.ink)
                    Spacer()
                    Text(statusText)
                        .font(ParallelMeTypography.compact)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                }

                if let message = availability.message {
                    Text(message)
                        .font(ParallelMeTypography.compact)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: ParallelMeSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(ParallelMeColor.inkMuted)
                    TextField("搜索纸页", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(ParallelMeTypography.compact)
                    if hasQuery {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                        .accessibilityLabel(Text("清空搜索"))
                    }
                }
                .padding(.horizontal, ParallelMeSpacing.sm)
                .padding(.vertical, ParallelMeSpacing.xs)
                .background(ParallelMeColor.paperLift)
                .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                        .stroke(ParallelMeColor.line.opacity(0.75), lineWidth: 1)
                )

                Picker("纸页类型", selection: $filter) {
                    ForEach(MeetingLibraryFilter.allCases) { libraryFilter in
                        Text(libraryFilter.title).tag(libraryFilter)
                    }
                }
                .pickerStyle(.segmented)
                .font(ParallelMeTypography.compact)
                .disabled(sourceLibrary.totalCount == 0)

                if library.isEmpty {
                    Text(emptyStateText)
                        .font(ParallelMeTypography.compact)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                        .padding(ParallelMeSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ParallelMeColor.paperLift)
                        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
                } else {
                    if !library.unfinished.isEmpty {
                        PaperLibraryGroup(
                            title: "未完成",
                            meetings: library.unfinished,
                            tint: ParallelMeColor.future,
                            availability: availability,
                            restore: restore,
                            delete: delete
                        )
                    }

                    if !library.archived.isEmpty {
                        PaperLibraryGroup(
                            title: "已归档",
                            meetings: library.archived,
                            tint: ParallelMeColor.money,
                            availability: availability,
                            restore: restore,
                            delete: delete
                        )
                    }
                }
            }
        }
    }

    private var statusText: String {
        if hasQuery || isFiltering {
            return "\(library.totalCount) 个匹配"
        }
        return "\(sourceLibrary.totalCount) 张 · \(sourceLibrary.archivedCount) 已归档"
    }

    private var emptyStateText: String {
        switch (hasQuery, filter) {
        case (true, _):
            return "没有匹配纸页"
        case (false, .unfinished):
            return "暂时没有未完成纸页"
        case (false, .archived):
            return "暂时没有已归档纸页"
        case (false, .all):
            return "纸页库还是空的"
        }
    }
}

private struct PaperLibraryGroup: View {
    var title: String
    var meetings: [MeetingSummary]
    var tint: Color
    var availability: PaperLibraryActionAvailabilitySnapshot
    var restore: (String) -> Void
    var delete: (String) -> Void

    var body: some View {
        DisclosureGroup("\(title) · \(meetings.count)") {
            VStack(spacing: ParallelMeSpacing.sm) {
                ForEach(meetings) { meeting in
                    PaperLibraryRow(
                        meeting: meeting,
                        tint: tint,
                        availability: availability,
                        restore: restore,
                        delete: delete
                    )
                }
            }
            .padding(.top, ParallelMeSpacing.xs)
        }
        .font(ParallelMeTypography.compact)
        .foregroundStyle(ParallelMeColor.ink)
    }
}

private struct PaperLibraryRow: View {
    var meeting: MeetingSummary
    var tint: Color
    var availability: PaperLibraryActionAvailabilitySnapshot
    var restore: (String) -> Void
    var delete: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: ParallelMeSpacing.sm) {
            Button {
                restore(meeting.id)
            } label: {
                VStack(alignment: .leading, spacing: ParallelMeSpacing.xs) {
                    Text(meeting.title)
                        .font(ParallelMeTypography.bodyStrong)
                        .foregroundStyle(ParallelMeColor.ink)
                        .lineLimit(2)
                    Text(meeting.subtitle)
                        .font(ParallelMeTypography.compact)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(!availability.canRestore)

            DeletePaperButton(meeting: meeting, canDelete: availability.canDelete, delete: delete) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("删除纸页"))
        }
        .padding(ParallelMeSpacing.md)
        .background(ParallelMeColor.paperLift)
        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: ParallelMeRadius.card)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct DeletePaperButton<Label: View>: View {
    var meeting: MeetingSummary
    var canDelete: Bool
    var delete: (String) -> Void
    @ViewBuilder var label: () -> Label
    @State private var isConfirmingDelete = false

    var body: some View {
        Button(role: .destructive) {
            isConfirmingDelete = true
        } label: {
            label()
        }
        .disabled(!canDelete)
        .confirmationDialog(
            "删除这张纸页？",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("删除纸页", role: .destructive) {
                delete(meeting.id)
            }
            .disabled(!canDelete)
            Button("取消", role: .cancel) {}
        } message: {
            Text("“\(meeting.title)” 会从这台设备移除。这个操作不能撤销。")
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

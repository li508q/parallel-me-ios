import ParallelMeCore
import ParallelMeDesign
import SwiftUI

struct ProviderSettingsPanel: View {
    @ObservedObject var viewModel: MeetingViewModel

    private var presentation: RuntimePreferencesPresentationSnapshot {
        RuntimePreferencesPresentationSnapshot(
            providerSettings: viewModel.providerSettings,
            isBusy: viewModel.isBusy,
            statusMessage: viewModel.runtimePreferencesMessage
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Picker(presentation.providerPickerTitle, selection: $viewModel.providerMode) {
                ForEach(ProviderRuntimeMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!presentation.canEdit)

            if presentation.shouldShowOpenAIFields {
                VStack(spacing: ParallelMeSpacing.sm) {
                    TextField(presentation.baseURLPrompt, text: $viewModel.providerBaseURL)
                        .textContentType(.URL)
                    TextField(presentation.modelPrompt, text: $viewModel.providerModel)
                    SecureField(presentation.apiKeyPrompt, text: $viewModel.providerAPIKey)
                }
                .textFieldStyle(.roundedBorder)
                .font(ParallelMeTypography.compact)
                .disabled(!presentation.canEdit)
            }
            DisclosureGroup(presentation.contextSectionTitle) {
                VStack(spacing: ParallelMeSpacing.sm) {
                    TextField(presentation.meCardPrompt, text: $viewModel.contextMeCard, axis: .vertical)
                        .lineLimit(2...5)
                    TextField(presentation.tasteProfilePrompt, text: $viewModel.contextTasteProfile, axis: .vertical)
                        .lineLimit(2...5)
                }
                .textFieldStyle(.roundedBorder)
                .font(ParallelMeTypography.compact)
                .padding(.top, ParallelMeSpacing.xs)
            }
            .font(ParallelMeTypography.compact)
            .foregroundStyle(ParallelMeColor.ink)
            .disabled(!presentation.canEdit)

            HStack(spacing: ParallelMeSpacing.sm) {
                Button {
                    viewModel.saveRuntimePreferences()
                } label: {
                    Label(
                        presentation.saveAction.title,
                        systemImage: presentation.saveAction.systemImage
                    )
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!presentation.saveAction.isEnabled)

                Button(role: .destructive) {
                    viewModel.clearRuntimePreferences()
                } label: {
                    Label(
                        presentation.clearAction.title,
                        systemImage: presentation.clearAction.systemImage
                    )
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!presentation.clearAction.isEnabled)
            }

            if let message = presentation.advisoryMessage {
                Text(message)
                    .font(ParallelMeTypography.compact)
                    .foregroundStyle(ParallelMeColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let message = presentation.statusMessage {
                HStack(alignment: .top, spacing: ParallelMeSpacing.xs) {
                    Image(systemName: message.systemImage)
                    Text(message.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        viewModel.dismissRuntimePreferencesMessage()
                    } label: {
                        Image(systemName: message.dismissSystemImage)
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
    var prompts: [PetitionStarterPromptPresentationSnapshot] =
        PetitionStarterPrompts.all.map(PetitionStarterPromptPresentationSnapshot.init(prompt:))
    var select: (PetitionStarterPrompt) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: ParallelMeSpacing.sm)], spacing: ParallelMeSpacing.sm) {
            ForEach(prompts) { snapshot in
                let prompt = snapshot.prompt
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
                .accessibilityLabel(Text(snapshot.accessibilityLabel))
                .accessibilityHint(Text(snapshot.accessibilityHint))
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

    private var presentation: ResumeMeetingPresentationSnapshot {
        ResumeMeetingPresentationSnapshot(meeting: meeting, isBusy: isBusy)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
            Text(presentation.eyebrow)
                .font(ParallelMeTypography.eyebrow)
                .foregroundStyle(ParallelMeColor.inkMuted)
            Text(presentation.title)
                .font(ParallelMeTypography.bodyStrong)
                .foregroundStyle(ParallelMeColor.ink)
                .lineLimit(2)
            Text(presentation.subtitle)
                .font(ParallelMeTypography.compact)
                .foregroundStyle(ParallelMeColor.inkMuted)
            HStack(spacing: ParallelMeSpacing.sm) {
                Button {
                    restore(presentation.meetingID)
                } label: {
                    Label(
                        presentation.restoreAction.title,
                        systemImage: presentation.restoreAction.systemImage
                    )
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!presentation.restoreAction.isEnabled)
                DeletePaperButton(deletion: presentation.deletion, delete: delete) {
                    Image(systemName: presentation.deletion.action.systemImage)
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

    private var presentation: MeetingLibraryPresentationSnapshot {
        MeetingLibraryPresentationSnapshot(
            library: library,
            sourceLibrary: sourceLibrary,
            searchText: searchText,
            filter: filter
        )
    }

    private var availability: PaperLibraryActionAvailabilitySnapshot {
        PaperLibraryActionAvailabilitySnapshot(isBusy: isBusy)
    }

    var body: some View {
        if presentation.shouldShowLibrary {
            VStack(alignment: .leading, spacing: ParallelMeSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(presentation.title)
                        .font(ParallelMeTypography.bodyStrong)
                        .foregroundStyle(ParallelMeColor.ink)
                    Spacer()
                    Text(presentation.statusText)
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
                    Image(systemName: presentation.search.systemImage)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                    TextField(presentation.search.prompt, text: $searchText)
                        .textFieldStyle(.plain)
                        .font(ParallelMeTypography.compact)
                    if presentation.search.clearAction.isEnabled {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: presentation.search.clearAction.systemImage)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                        .accessibilityLabel(Text(presentation.search.clearAction.accessibilityLabel))
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

                Picker(presentation.filterControl.title, selection: $filter) {
                    ForEach(MeetingLibraryFilter.allCases) { libraryFilter in
                        Text(libraryFilter.title).tag(libraryFilter)
                    }
                }
                .pickerStyle(.segmented)
                .font(ParallelMeTypography.compact)
                .disabled(!presentation.filterControl.isEnabled)

                if let emptyStateText = presentation.emptyStateText {
                    Text(emptyStateText)
                        .font(ParallelMeTypography.compact)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                        .padding(ParallelMeSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ParallelMeColor.paperLift)
                        .clipShape(RoundedRectangle(cornerRadius: ParallelMeRadius.card))
                } else {
                    ForEach(presentation.groups) { group in
                        PaperLibraryGroup(
                            title: group.displayTitle,
                            meetings: group.meetings,
                            tint: tint(for: group.kind),
                            availability: availability,
                            restore: restore,
                            delete: delete
                        )
                    }
                }
            }
        }
    }

    private func tint(for kind: MeetingLibraryPresentationGroupKind) -> Color {
        switch kind {
        case .unfinished:
            return ParallelMeColor.future
        case .archived:
            return ParallelMeColor.money
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
        DisclosureGroup(title) {
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

    private var deletion: PaperDeletionPresentationSnapshot {
        PaperDeletionPresentationSnapshot(
            meeting: meeting,
            availability: availability
        )
    }

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

            DeletePaperButton(deletion: deletion, delete: delete) {
                Image(systemName: deletion.action.systemImage)
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.borderless)
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
    var deletion: PaperDeletionPresentationSnapshot
    var delete: (String) -> Void
    @ViewBuilder var label: () -> Label
    @State private var isConfirmingDelete = false

    var body: some View {
        Button(role: .destructive) {
            isConfirmingDelete = true
        } label: {
            label()
        }
        .disabled(!deletion.action.isEnabled)
        .accessibilityLabel(Text(deletion.action.accessibilityLabel))
        .confirmationDialog(
            deletion.confirmation.title,
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(deletion.confirmation.destructiveActionTitle, role: .destructive) {
                delete(deletion.meetingID)
            }
            .disabled(!deletion.action.isEnabled)
            Button(deletion.confirmation.cancelActionTitle, role: .cancel) {}
        } message: {
            Text(deletion.confirmation.message)
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
                    Text(persona.roleContract.productRole)
                        .font(ParallelMeTypography.compact)
                        .foregroundStyle(ParallelMeColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(persona.coreValue)
                        .font(ParallelMeTypography.compact)
                        .foregroundStyle(ParallelMeColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(ParallelMeSpacing.md)
                .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
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

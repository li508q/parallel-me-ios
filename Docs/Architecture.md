# Architecture

The iOS implementation separates product logic from presentation.

## Layers

| Layer | Description |
| --- | --- |
| Domain | Value types for meetings, proposals, voices, roundtables, inquiry, and settlement. |
| Flow | A reducer-like engine that validates legal stage transitions. |
| Scribe | Coverage, deduplication, and readiness rules. |
| Provider | Protocols for model calls and local mocks. |
| Session | Actor-based application coordinator that turns user intent and provider responses into legal flow transitions. |
| Storage | Repository protocol and local implementations. |
| UI | SwiftUI views and `MeetingViewModel`; the UI never calls provider APIs directly. |
| App | Thin composition root. |

## Why This Shape

The web version proves the product but couples state orchestration to page components. The iOS version keeps the meeting path inside `MeetingFlowEngine`, so tests can verify user logic without launching UI or calling an LLM.

`MeetingSessionCoordinator` sits above the flow engine. It is intentionally an actor: model calls, persistence, and user actions can arrive asynchronously, but state transitions still pass through one serialized coordinator.

Stage-one proposal refinement also lives in the coordinator. User feedback is appended to `definingDialogue`, persisted, then sent back through the provider boundary as `IssueDefinitionInput.userFeedback`; the UI only dispatches the intent and renders the regenerated proposal.

## UI Composition

`ParallelMeRootView` stays focused on app-level composition: loading the view model, choosing the current stage surface, and arranging the home or active-paper shell. Stage-specific surfaces remain in the UI module, while reusable home, paper-context, timeline, stage rail, error, and diagnostics views live in smaller files. This keeps SwiftUI iteration local and prevents presentation details from growing back into one page-level component.

## Provider Strategy

The provider boundary is intentionally typed:

- `ProviderPromptSpec` defines the role, hard constraints, and JSON response contract for every model-facing task.
- `OpenAICompatibleProvider` converts each product task into a chat-completions request and decodes the strict JSON result into the expected payload type.
- `DemoLLMProvider` is a deterministic local provider for UI development, simulator smoke runs, and demos without an API key.
- `MockLLMProvider` is the precise test double used when a test needs one exact payload per task.
- `ProviderContext` carries optional durable user background and response preferences through every provider payload. Prompt specs explicitly treat it as calibration only, so it cannot override the current petition, proposal, moves, answers, or feedback.

This keeps prompt iteration, network transport, and product state transitions independently testable.

## Persistence Strategy

`MeetingRepository` is the only persistence interface known to the session layer. Current implementations are:

- `InMemoryMeetingRepository` for tests.
- `FileMeetingRepository` for local JSON persistence in the app sandbox.

The repository stores full `MeetingFlowState`, which makes debugging easier and allows later migration into SwiftData without changing the flow engine.
`PetitionStarterPrompts` provides the home screen's first-sentence seeds from Core, keeping onboarding copy stable and testable instead of scattered through SwiftUI.
`MeetingStartReadinessSnapshot` derives home-screen start blockers, button text, and user-facing guidance from the raw petition and provider settings.
`MeetingSummary` derives stable archive-list display data from the full state, so the UI can show recent papers without duplicating product wording rules.
`MeetingStageProgressSnapshot` derives the five-step product rail, localized stage titles, current position, and completion state from `MeetingStage`.
`MeetingTimeline` derives the active paper's progress markers from the same state, and `MeetingTimelineSnapshot` defines recent-versus-full timeline presentation, so UI and future debug/export surfaces share one interpretation of the meeting path.
`RoundtableTranscriptSnapshot` groups voice openings, user moves, model replies, and legacy ungrouped turns into one tested reading model used by the SwiftUI roundtable and Markdown export.
`RoundtableTransitionSnapshot` derives whether the roundtable has complete openings and at least one substantive exchange, so the UI cannot make inquiry available before there is real material.
`MeetingResumePolicy` chooses the latest unfinished paper from saved states, keeping resume behavior testable outside SwiftUI.
`MeetingLibrarySnapshot` groups and filters saved papers into recent, unfinished, and archived sections. `MeetingSummary` derives a searchable text index from the full meeting state, keeping home library behavior out of SwiftUI.
`MeetingArchiveSnapshot` derives archived-paper detail rows and full timeline data from Core state, so restored archived papers can be inspected without rebuilding business rules in SwiftUI.
`MeetingExportDocument` renders a saved paper into deterministic Markdown from Core state, so sharing/exporting can evolve without moving product formatting rules into SwiftUI.
`MeetingExportFileWriter` writes that Markdown to a named local `.md` file for iOS sharing while keeping file IO testable outside SwiftUI.
`SettlementRevisionDraft` owns settlement editing state and validation, so SwiftUI can render editable modules without deciding which revisions are meaningful.

Provider runtime settings are split deliberately:

- Non-sensitive metadata, such as mode, base URL, and model, is stored as local JSON.
- API keys are stored through `SecretStore`; the default app implementation uses Keychain.
- Tests use in-memory secret storage and verify that API keys never appear in metadata JSON.

Provider context is stored separately from provider credentials:

- `FileProviderContextStore` stores normalized optional context as local JSON.
- Empty or whitespace-only fields are dropped before persistence and before provider requests.
- Tests verify that stored context is normalized, clearable, and actually forwarded by the session coordinator.
- `MeetingViewModel` exposes explicit save and clear actions for runtime preferences, so provider metadata, Keychain secrets, and context can be managed before a meeting starts.

Each new meeting also stores a `MeetingRuntimeSnapshot` in `MeetingFlowState`. The snapshot records the provider mode, model, non-sensitive endpoint metadata, and normalized provider context used when the paper started. Settlement and archive timestamps are stored on the same state, so library sorting and timeline display can reflect real lifecycle events instead of inferring them from earlier answers. This gives restored meetings and debugging views one durable source of truth without storing API keys in meeting JSON.
When an unfinished paper is restored from the library, `MeetingViewModel` rebuilds the session coordinator before the next model-backed action. The rebuilt runtime uses the current provider credentials and current provider context, falling back to the paper's stored context only when the current context is empty, and writes that effective runtime snapshot back onto the restored state. Archived papers bypass provider rebuilding so they remain readable offline even when credentials are missing or invalid.

## Project Generation

`project.yml` is the source of truth for Xcode project shape. `ParallelMe.xcodeproj` is generated with XcodeGen and checked in so iOS developers can open the app directly in Xcode.
The app target resources live under `App/ParallelMe`, including `Assets.xcassets` and `PrivacyInfo.xcprivacy`; regenerate the project after adding or moving app resources.

## Debugging Strategy

- Every model-facing action returns a typed payload.
- Starter petition prompts are defined in Core and tested for uniqueness and usable seed text before SwiftUI renders them.
- Home-screen start readiness is derived in Core and tested for empty petitions and incomplete provider settings.
- Every user-visible transition is represented by `MeetingStage`.
- Stage rail labels and completion state are derived in Core and tested against the fixed product flow.
- Roundtable-to-inquiry readiness is derived in Core and tested as a minimum evidence guard, while preserving no maximum round cap.
- Current-paper timeline items and recent/full presentation snapshots are derived in Core and tested against complete meeting progress.
- Roundtable transcript grouping is derived in Core and shared by live UI and export.
- Archived-paper detail rows are derived in Core and tested against user settlement revisions.
- Settlement and archive timestamps are stored in Core state and tested through summaries, library sorting, and timelines.
- Resume selection is derived in Core and ignores archived papers.
- Paper library grouping, ordering, and search filtering are derived in Core and tested without UI.
- Runtime snapshots make provider and context state visible on the active paper and are tested through flow and session persistence.
- Runtime preferences can be saved or cleared explicitly from the UI and are tested through the view model.
- Restored unfinished papers rebuild provider runtime before continuing, while archived papers remain inspectable offline.
- Markdown export is generated in Core and tested against archived paper state, including user settlement revisions.
- Markdown export file writing is tested with a temporary local directory before the UI shares the file URL.
- Settlement revision drafts are normalized and tested before UI sends revisions back to the session coordinator.
- Repeated questions are filtered before they reach UI.
- Proposal feedback is persisted as part of the defining dialogue before a refined proposal is requested.
- The final inquiry loop has no hard cap; tests assert this invariant.
- Provider prompt specs are tested for product invariants such as fixed voices, free-text exits, no hard inquiry cap, context boundaries, and required settlement modules.
- The provider layer is protocol-based, so model calls can be mocked in unit tests.
- Session events record provider requests, provider responses, persistence, and failures; the default app keeps the latest events in memory and exposes them through the collapsible running trace panel.

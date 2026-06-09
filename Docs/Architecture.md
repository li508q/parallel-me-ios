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

`ParallelMeRootView` stays focused on app-level composition: loading the view model, choosing the current stage surface, and arranging the home or active-paper shell. Stage-specific surfaces remain in the UI module, split by product step across `DefiningViews`, `RoundtableViews`, `InquiryViews`, `SettlementViews`, and `ArchivedViews`, while reusable home, paper-context, timeline, stage rail, error, and diagnostics views live in smaller files. This keeps SwiftUI iteration local and prevents presentation details from growing back into one page-level component.

## Provider Strategy

The provider boundary is intentionally typed:

- `ProviderPromptSpec` defines the role, hard constraints, and JSON response contract for every model-facing task.
- `VoiceRoleContracts` is the single Core catalog for fixed-voice product roles. Each voice carries a role function, evidence lens, questioning duty, and boundary, and provider prompts, demo openings, and the home primer consume that catalog instead of re-describing the cast in separate places.
- `OpenAICompatibleProvider` converts each product task into a chat-completions request and decodes the strict JSON result into the expected payload type. Its HTTP transport is injectable, and its response parser extracts the first balanced JSON object so fenced payloads with trailing notes remain testable without live network calls.
- `DemoLLMProvider` is a deterministic local provider for UI development, simulator smoke runs, and demos without an API key.
- `MockLLMProvider` is the precise test double used when a test needs one exact payload per task.
- `ProviderContext` carries optional durable user background and response preferences through every provider payload. Prompt specs explicitly treat it as calibration only, so it cannot override the current petition, proposal, moves, answers, or feedback.

This keeps prompt iteration, network transport, and product state transitions independently testable.

## Persistence Strategy

`MeetingRepository` is the only persistence interface known to the session layer. Current implementations are:

- `InMemoryMeetingRepository` for tests.
- `FileMeetingRepository` for local JSON persistence in the app sandbox.

The repository stores full `MeetingFlowState`, which makes debugging easier and allows later migration into SwiftData without changing the flow engine.
`FileMeetingRepository` skips unreadable JSON records when listing the local library, so one damaged or legacy file cannot hide the rest of the user's saved papers.
`PetitionStarterPrompts` provides the home screen's first-sentence seeds from Core, keeping onboarding copy stable and testable instead of scattered through SwiftUI.
`MeetingStartReadinessSnapshot` derives home-screen start blockers, button text, input editability, and user-facing guidance from the raw petition and provider settings.
`ScribeProbeAnswerBatchDraft` keeps a stage-one question turn together until every current question has an answer, preserving multi-question definition rounds.
`IssueDefinitionEvidenceEvaluator` owns the stage-one evidence guard: raw petition keywords are stored as signals, but proposal readiness requires user-answer coverage for all four purposes plus minimum exploration, articulation, and boundary evidence. `ScribeQuestionDeduplicator` uses the evaluator when it needs recovery questions, and `MeetingSessionCoordinator` applies the same evaluator-backed guard after provider responses, so a model cannot move the paper into proposal confirmation just by returning `readyToPropose=true`.
`ScribeInquiryAnswerBatchDraft` keeps final inquiry turns together under the same rule, so evidence-gathering cannot skip a visible question.
`MeetingSummary` derives stable archive-list display data from the full state, so the UI can show recent papers without duplicating product wording rules.
`MeetingStageProgressSnapshot` derives the five-step product rail, localized stage titles, current position, and completion state from `MeetingStage`.
`MeetingActivitySnapshot` derives tested in-flight action copy, icon intent, and provider-versus-local classification so SwiftUI can explain waiting states without embedding product logic in view files.
`MeetingSessionDiagnosticsSnapshot` derives recent trace rows, event counts, pending provider responses, and latest failure copy from raw session events so the debug panel stays useful without becoming another source of product logic. Failed requests close one pending provider response in that event stream, so the UI does not imply a model call is still waiting after it has already failed.
`MeetingStateHealthSnapshot` diagnoses the active paper's structural and evidence readiness, including missing issue context, incomplete roundtable evidence, insufficient settlement evidence, incomplete settlement payloads, and legacy archived-paper gaps, so the debug panel can explain restored states without parsing JSON.
`MeetingTimeline` derives the active paper's progress markers from the same state, and `MeetingTimelineSnapshot` defines recent-versus-full timeline presentation, including collapsed titles and expansion controls, so UI and future debug/export surfaces share one interpretation of the meeting path.
`ProposalConfirmationAvailabilitySnapshot` derives whether the confirmed issue proposal can safely enter the roundtable, including restored states that have proposal text but no task frame.
`IssueProposalSnapshot` derives the fixed four-key display rows from a proposal, so the defining screen, archived detail, and Markdown export share one title order and do not duplicate issue wording in SwiftUI.
`RoundtableTranscriptSnapshot` groups voice openings, user moves, model replies, and legacy ungrouped turns into one tested reading model used by the SwiftUI roundtable and Markdown export. `VoiceOpeningSnapshot` derives the fixed opening thesis/detail rows from each voice opening, so the UI and export preserve the same protected value, concern, evidence, and questioning duty.
`RoundtableActionAvailabilitySnapshot` derives whether roundtable moves and inquiry entry are safe, so restored states with partial openings or missing task context cannot expose misleading move buttons. `RoundtableControlsPresentationSnapshot` derives the visible roundtable action labels, icons, prompts, and input-dependent send gates from that availability snapshot.
`RoundtableTransitionSnapshot` derives whether the roundtable has complete openings and at least one substantive exchange, so the UI cannot make inquiry available before there is real material.
`MeetingResumePolicy` chooses the latest unfinished paper from saved states, keeping resume behavior testable outside SwiftUI.
`MeetingLibrarySnapshot` groups, status-filters, and full-text searches saved papers into recent, unfinished, and archived sections. `MeetingLibraryPresentationSnapshot` derives home-library status copy, empty states, and visible groups from the filtered and source libraries. `MeetingSummary` derives a searchable text index from the full meeting state, keeping home library behavior out of SwiftUI.
`PaperLibraryActionAvailabilitySnapshot` locks restore and delete actions while a paper-library operation is in flight.
`MeetingArchiveSnapshot` derives archived-paper detail rows and full timeline data from Core state, so restored archived papers can be inspected without rebuilding business rules in SwiftUI.
`MeetingExportAvailabilitySnapshot` defines when a paper can be shared from the UI, keeping export entry points aligned with the archive lifecycle. `MeetingExportDocument` renders a saved paper into deterministic Markdown from Core state, so sharing/exporting can evolve without moving product formatting rules into SwiftUI.
`MeetingExportFileWriter` writes that Markdown to a named local `.md` file for iOS sharing while keeping file IO testable outside SwiftUI.
`RuntimePreferencesActionAvailabilitySnapshot` blocks invalid OpenAI-compatible settings from being saved and locks provider/context editing while a runtime preference operation is in flight.
`SettlementRequestAvailabilitySnapshot` derives whether the inquiry stage can request the final Heart Settlement or should continue asking questions, keeping unanswered-question and evidence-readiness gates out of SwiftUI.
`SettlementStageSnapshot` keeps restored settlement-stage papers from rendering a blank body when the Heart Settlement payload is missing. `HeartSettlementSnapshot` derives the fixed five-module display rows from a settlement, so the settlement editor, archived detail, and Markdown export share one canonical module order and title set. `SettlementRevisionDraft` owns settlement editing state and validation, and `SettlementActionAvailabilitySnapshot` derives busy-aware apply/archive availability so SwiftUI can render editable modules without deciding which actions are safe.

Provider runtime settings are split deliberately:

- Non-sensitive metadata, such as mode, base URL, and model, is stored as local JSON.
- API keys are stored through `SecretStore`; the default app implementation uses Keychain.
- Runtime provider settings are normalized before persistence, runtime snapshots, and provider creation, so UI whitespace cannot leak into requests or saved debug metadata.
- Tests use in-memory secret storage and verify that API keys never appear in metadata JSON.

Provider context is stored separately from provider credentials:

- `FileProviderContextStore` stores normalized optional context as local JSON.
- Empty or whitespace-only fields are dropped before persistence and before provider requests.
- Tests verify that stored context is normalized, clearable, and actually forwarded by the session coordinator.
- `MeetingViewModel` exposes explicit save and clear actions for runtime preferences, so provider metadata, Keychain secrets, and context can be managed before a meeting starts.

Each new meeting also stores a `MeetingRuntimeSnapshot` in `MeetingFlowState`. The snapshot records the provider mode, model, non-sensitive endpoint metadata, and normalized provider context used when the paper started. Settlement and archive timestamps are stored on the same state, so library sorting and timeline display can reflect real lifecycle events instead of inferring them from earlier answers. This gives restored meetings and debugging views one durable source of truth without storing API keys in meeting JSON.
When an unfinished paper is restored from the library, `MeetingViewModel` rebuilds the session coordinator before the next model-backed action. The rebuilt runtime uses the current provider credentials and current provider context, falling back to the paper's stored context only when the current context is empty, and writes that effective runtime snapshot back onto the restored state. Archived papers bypass provider rebuilding so they remain readable offline even when credentials are missing or invalid.

If an async operation fails after the coordinator has already persisted a valid intermediate state, `MeetingViewModel` adopts the coordinator's latest state before surfacing the error. This keeps partial transitions such as entering inquiry recoverable from the current paper instead of leaving the UI on stale state.

## Project Generation

`project.yml` is the source of truth for Xcode project shape. `ParallelMe.xcodeproj` is generated with XcodeGen and checked in so iOS developers can open the app directly in Xcode.
The app target resources live under `App/ParallelMe`, including `Assets.xcassets` and `PrivacyInfo.xcprivacy`; regenerate the project after adding or moving app resources.

## Debugging Strategy

- Every model-facing action returns a typed payload.
- Starter petition prompts are defined in Core and tested for uniqueness and usable seed text before SwiftUI renders them.
- Home-screen start readiness is derived in Core and tested for empty petitions, incomplete provider settings, and busy input locking.
- Stage-one answer batches are derived in Core and the flow engine rejects partial answers for the current question turn.
- Final inquiry answer batches are derived in Core and the flow engine rejects partial answers for the current active inquiry turn.
- Every user-visible transition is represented by `MeetingStage`.
- Stage rail labels and completion state are derived in Core and tested against the fixed product flow.
- In-flight activity banners are derived in Core and tested so waiting states stay specific to the user's current action.
- Definition-stage recovery keeps a started paper retryable when the first model-backed definition request fails.
- `IssueDefinitionEvidenceEvaluator` treats the raw petition as signal only; Core requires user-answer evidence, minimum exploration, user articulation, and a boundary confirmation before accepting a provider proposal.
- If the model returns an early complete proposal, the session coordinator forces more scribe questions until the local evidence guard passes.
- If the model returns only duplicate or unusable definition questions, Core generates purpose-targeted recovery questions instead of failing the paper.
- Inquiry-stage recovery keeps a paper retryable when the first model-backed inquiry request fails after the inquiry stage has been persisted.
- Inquiry-stage guarding filters repeated or already answered question text, restores missing module questions when the provider returns only duplicates, and only counts substantive action answers as minimum-action evidence.
- Roundtable-to-inquiry readiness is derived in Core and tested as a minimum evidence guard, while preserving no maximum round cap.
- Roundtable move actions are derived in Core and require complete fixed-voice openings, confirmed issue context, and task-frame availability.
- Inquiry-to-settlement availability is derived in Core and requires no active questions, complete issue context, an alignment profile, and evidence for all settlement modules.
- Current-paper timeline items and recent/full presentation snapshots are derived in Core and tested against complete meeting progress.
- Roundtable transcript grouping is derived in Core and shared by live UI and export.
- Archived-paper detail rows are derived in Core and tested against user settlement revisions.
- Settlement and archive timestamps are stored in Core state and tested through summaries, library sorting, and timelines.
- Resume selection is derived in Core and ignores archived papers.
- Paper library grouping, ordering, status filtering, and search filtering are derived in Core and tested without UI.
- Paper library restore/delete actions lock while paper-library work is in flight.
- Runtime snapshots make provider and context state visible on the active paper and are tested through flow and session persistence.
- Runtime preferences can be saved or cleared explicitly from the UI and are tested through the view model.
- Runtime preference fields and actions lock while runtime preference work is in flight.
- Runtime preference persistence happens only after provider creation succeeds, so failed unfinished-paper restores cannot overwrite saved settings or context with invalid draft configuration.
- Restored unfinished papers rebuild provider runtime before continuing, while archived papers remain inspectable offline.
- Export availability is derived in Core, so the UI only prepares Markdown files for archived papers with complete Heart Settlement content.
- Markdown export is generated in Core and tested against archived paper state, including user settlement revisions.
- Markdown export file writing is tested with a temporary local directory before the UI shares the file URL.
- Settlement revision drafts are normalized and tested before UI sends revisions back to the session coordinator.
- Archive is guarded in Core by complete Heart Settlement content, not only by the current stage.
- Settlement apply/archive buttons are derived from Core action availability and lock while an async operation is in flight.
- Repeated questions are filtered before they reach UI.
- Proposal feedback is persisted as part of the defining dialogue before a refined proposal is requested.
- Proposal confirmation availability is derived in Core, so restored incomplete proposals cannot expose a misleading roundtable action.
- The final inquiry loop has no hard cap; tests assert this invariant.
- Voice role contracts are tested for complete fixed-voice coverage, distinct boundaries, and prompt-ready text before any provider spec consumes them.
- Provider prompt specs are tested for product invariants such as fixed voices, shared voice-role contracts, free-text exits, no hard inquiry cap, context boundaries, non-template inquiry rules, and required settlement modules.
- Definition and inquiry response guarding are tested through the session coordinator so contradictory provider responses cannot swallow follow-up questions.
- OpenAI-compatible transport is injectable and smoke-tested for request shape, strict JSON response format, fenced JSON decoding, and HTTP error bodies.
- Runtime provider settings normalization is tested across validation, persistence, snapshots, and OpenAI-compatible provider factory requests.
- The provider layer is protocol-based, so model calls can be mocked in unit tests.
- Session events record provider requests, provider responses, persistence, and failures; Core derives the diagnostics snapshot, the active paper health snapshot, and the default app exposes both through the collapsible running trace panel.

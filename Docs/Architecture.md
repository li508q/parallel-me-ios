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

## Provider Strategy

The provider boundary is intentionally typed:

- `ProviderPromptSpec` defines the role, hard constraints, and JSON response contract for every model-facing task.
- `OpenAICompatibleProvider` converts each product task into a chat-completions request and decodes the strict JSON result into the expected payload type.
- `DemoLLMProvider` is a deterministic local provider for UI development, simulator smoke runs, and demos without an API key.
- `MockLLMProvider` is the precise test double used when a test needs one exact payload per task.

This keeps prompt iteration, network transport, and product state transitions independently testable.

## Persistence Strategy

`MeetingRepository` is the only persistence interface known to the session layer. Current implementations are:

- `InMemoryMeetingRepository` for tests.
- `FileMeetingRepository` for local JSON persistence in the app sandbox.

The repository stores full `MeetingFlowState`, which makes debugging easier and allows later migration into SwiftData without changing the flow engine.
`MeetingSummary` derives stable archive-list display data from the full state, so the UI can show recent papers without duplicating product wording rules.
`MeetingTimeline` derives the active paper's progress markers from the same state, so UI and future debug/export surfaces share one interpretation of the meeting path.
`MeetingResumePolicy` chooses the latest unfinished paper from saved states, keeping resume behavior testable outside SwiftUI.

Provider runtime settings are split deliberately:

- Non-sensitive metadata, such as mode, base URL, and model, is stored as local JSON.
- API keys are stored through `SecretStore`; the default app implementation uses Keychain.
- Tests use in-memory secret storage and verify that API keys never appear in metadata JSON.

## Project Generation

`project.yml` is the source of truth for Xcode project shape. `ParallelMe.xcodeproj` is generated with XcodeGen and checked in so iOS developers can open the app directly in Xcode.

## Debugging Strategy

- Every model-facing action returns a typed payload.
- Every user-visible transition is represented by `MeetingStage`.
- Current-paper timeline items are derived in Core and tested against complete meeting progress.
- Resume selection is derived in Core and ignores archived papers.
- Repeated questions are filtered before they reach UI.
- Proposal feedback is persisted as part of the defining dialogue before a refined proposal is requested.
- The final inquiry loop has no hard cap; tests assert this invariant.
- Provider prompt specs are tested for product invariants such as fixed voices, free-text exits, no hard inquiry cap, and required settlement modules.
- The provider layer is protocol-based, so model calls can be mocked in unit tests.
- Session events record provider requests, provider responses, persistence, and failures for future debug surfaces.

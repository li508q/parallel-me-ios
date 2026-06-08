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

## Provider Strategy

The provider boundary is intentionally typed:

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

Provider runtime settings are split deliberately:

- Non-sensitive metadata, such as mode, base URL, and model, is stored as local JSON.
- API keys are stored through `SecretStore`; the default app implementation uses Keychain.
- Tests use in-memory secret storage and verify that API keys never appear in metadata JSON.

## Project Generation

`project.yml` is the source of truth for Xcode project shape. `ParallelMe.xcodeproj` is generated with XcodeGen and checked in so iOS developers can open the app directly in Xcode.

## Debugging Strategy

- Every model-facing action returns a typed payload.
- Every user-visible transition is represented by `MeetingStage`.
- Repeated questions are filtered before they reach UI.
- The final inquiry loop has no hard cap; tests assert this invariant.
- The provider layer is protocol-based, so model calls can be mocked in unit tests.
- Session events record provider requests, provider responses, persistence, and failures for future debug surfaces.

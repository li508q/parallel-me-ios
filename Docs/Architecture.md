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
| UI | SwiftUI views that render state and emit user intent. |
| App | Thin composition root. |

## Why This Shape

The web version proves the product but couples state orchestration to page components. The iOS version keeps the meeting path inside `MeetingFlowEngine`, so tests can verify user logic without launching UI or calling an LLM.

`MeetingSessionCoordinator` sits above the flow engine. It is intentionally an actor: model calls, persistence, and user actions can arrive asynchronously, but state transitions still pass through one serialized coordinator.

## Debugging Strategy

- Every model-facing action returns a typed payload.
- Every user-visible transition is represented by `MeetingStage`.
- Repeated questions are filtered before they reach UI.
- The final inquiry loop has no hard cap; tests assert this invariant.
- The provider layer is protocol-based, so model calls can be mocked in unit tests.

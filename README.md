# ParallelMe iOS

ParallelMe iOS is a native Swift reimplementation of the ParallelMe product: a scribe-guided five-voice roundtable that helps a user define a real dilemma, let five inner voices speak, answer the final questions that matter, and settle on a small accountable next action.

This repository intentionally does not port the web app one file at a time. It keeps the product logic in a testable Swift core, then lets SwiftUI render that state.

## Product Flow

1. `Defining`: the scribe turns a raw petition into a four-key issue proposal, then lets the user refine that definition before confirmation.
2. `Roundtable`: five fixed voices open and continue the discussion.
3. `Inquiry`: the scribe asks only the remaining high-density questions needed for settlement.
4. `Settlement`: the user receives and can revise the final Heart Settlement.
5. `Archive`: the completed meeting is stored locally.

There is no global question-count cap. The app closes loops through explicit sufficiency checks: proposal completeness, purpose coverage, duplicate filtering, proposal refinement, inquiry readiness, and user confirmation.

## Modules

| Module | Responsibility |
| --- | --- |
| `ParallelMeCore` | Product domain models, five-voice personas, flow engine, scribe deduplication, LLM/provider protocols. |
| `ParallelMeDesign` | iPhone design tokens: color, spacing, typography, motion intent. |
| `ParallelMeUI` | SwiftUI surfaces plus `MeetingViewModel`, rendering core state and dispatching user intent through the session coordinator. |
| `App/ParallelMe` | Thin iOS app entry point. |
| `ParallelMeCoreSmokeTests` | Executable tests for flow rules, persona invariants, deduplication, session coordination, and no hard inquiry cap. |

`MeetingSessionCoordinator` is the app-service boundary. It owns the active meeting state, calls an injected `LLMProvider`, applies the `MeetingFlowEngine`, and persists through an injected `MeetingRepository`.
The default app also wires an in-memory session event sink so the SwiftUI running trace can show provider requests, responses, persistence, and failures while developing or debugging a meeting.

## Runtime Providers

- `DemoLLMProvider` drives a complete local meeting without network, useful for UI work and smoke tests.
- `OpenAICompatibleProvider` targets `/chat/completions` with `response_format: json_object`, uses `ProviderPromptSpec` for tested product contracts, and decodes structured JSON back into typed product payloads.
- `FileMeetingRepository` stores meeting state as local JSON files; `InMemoryMeetingRepository` stays available for tests.
- Optional `ProviderContext` stores the user's durable background and response preferences locally, then passes them through every provider task as calibration rather than as a replacement for the current meeting evidence.

## Local Development

The core package can be verified without Xcode:

```bash
swift run ParallelMeCoreSmokeTests
```

To generate the iOS project after installing Xcode and XcodeGen:

```bash
xcodegen generate
open ParallelMe.xcodeproj
```

`ParallelMe.xcodeproj` is checked in for convenience and generated from `project.yml`. Regenerate it after project-structure changes.

The app target includes `App/ParallelMe/PrivacyInfo.xcprivacy`, `Assets.xcassets`, a display name, and launch-screen color metadata so Xcode can package the app with install-time identity and privacy declarations.

The current machine has Swift command-line tools available, but `xcodebuild` points at Command Line Tools rather than full Xcode, and this toolchain does not expose `XCTest` or Swift `Testing`. `ParallelMeCoreSmokeTests` is therefore the first executable verification layer. Standard XCTest, UI tests, and simulator verification should be added once full Xcode is installed.

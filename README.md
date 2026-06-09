# ParallelMe iOS

ParallelMe iOS is a native Swift reimplementation of the ParallelMe product: a scribe-guided five-voice roundtable that helps a user define a real dilemma, let five inner voices speak, answer the final questions that matter, and settle on a small accountable next action.

This repository intentionally does not port the web app one file at a time. It keeps the product logic in a testable Swift core, then lets SwiftUI render that state.

## Product Flow

1. `Defining`: the scribe turns a raw petition into a four-key issue proposal, then lets the user refine that definition before confirmation.
2. `Roundtable`: five fixed voices open and continue the discussion.
3. `Inquiry`: the scribe asks only the remaining high-density questions needed for settlement.
4. `Settlement`: the user receives and can revise the final Heart Settlement.
5. `Archive`: the completed meeting is stored locally, reopenable as a readable paper, and exportable as Markdown.

There is no global question-count cap. The app closes loops through explicit sufficiency checks: proposal completeness, purpose coverage, duplicate filtering, proposal refinement, inquiry readiness, and user confirmation.

## Modules

| Module | Responsibility |
| --- | --- |
| `ParallelMeCore` | Product domain models, five-voice personas, flow engine, scribe deduplication, LLM/provider protocols. |
| `ParallelMeDesign` | iPhone design tokens: color, spacing, typography, motion intent. |
| `ParallelMeUI` | SwiftUI surfaces plus `MeetingViewModel`, split into root composition, home/library, paper context, support, and stage-specific view files. |
| `App/ParallelMe` | Thin iOS app entry point. |
| `ParallelMeCoreSmokeTests` | Executable tests for flow rules, persona invariants, deduplication, session coordination, and no hard inquiry cap. |

`MeetingSessionCoordinator` is the app-service boundary. It owns the active meeting state, calls an injected `LLMProvider`, applies the `MeetingFlowEngine`, and persists through an injected `MeetingRepository`.
The default app also wires an in-memory session event sink so the SwiftUI running trace can show provider requests, responses, persistence, and failures while developing or debugging a meeting.
The running trace is summarized by Core before SwiftUI renders it, so failure counts and pending provider requests are testable outside the interface.

## Runtime Providers

- `DemoLLMProvider` drives a complete local meeting without network, useful for UI work and smoke tests.
- `OpenAICompatibleProvider` targets `/chat/completions` with `response_format: json_object`, uses `ProviderPromptSpec` for tested product contracts, and decodes structured JSON back into typed product payloads through an injectable HTTP transport.
- `ProviderRuntimeSettings` normalizes provider URL, model, and API key text before persistence, runtime snapshots, and provider creation.
- `FileMeetingRepository` stores meeting state as local JSON files; `InMemoryMeetingRepository` stays available for tests.
- `PetitionStarterPrompts` keeps the home screen's first-sentence seeds in Core so onboarding copy is testable.
- `MeetingStartReadinessSnapshot` explains empty petitions and incomplete provider settings before the first model-backed step.
- Definition retry recovery keeps a started paper usable if the first model-backed definition request fails.
- `ScribeProbeAnswerBatchDraft` keeps multi-question definition turns together so the scribe receives a complete answer batch.
- `ScribeInquiryAnswerBatchDraft` keeps multi-question inquiry turns together before the settlement readiness check advances.
- Optional `ProviderContext` stores the user's durable background and response preferences locally, then passes them through every provider task as calibration rather than as a replacement for the current meeting evidence.
- Runtime preferences can be explicitly saved or cleared from the home screen before starting a meeting.
- `MeetingRuntimeSnapshot` records the non-secret provider/context state used when a meeting starts, making restored papers and debug views explainable.
- `MeetingActivitySnapshot` gives every in-flight action a tested title, detail, icon, and provider/local classification for the iPhone status banner.
- `MeetingSessionDiagnosticsSnapshot` summarizes provider requests, responses, persistence, failures, and recent trace events for the in-app debug panel.
- `MeetingStageProgressSnapshot` drives the five-step iPhone stage rail from Core state.
- `RoundtableTransitionSnapshot` keeps final inquiry gated on complete fixed-voice openings and at least one real roundtable exchange, without adding a maximum round cap.
- Restored unfinished papers rebuild their provider runtime before continuing, so the next model action uses the current credentials and context; archived papers remain readable offline.
- Settlement and archive timestamps are stored on the meeting state, so summaries, library ordering, and timelines reflect real lifecycle events.
- `RoundtableTranscriptSnapshot` groups openings and user-driven moves for live reading and Markdown export.
- `MeetingLibrarySnapshot` groups, status-filters, and full-text searches local papers across recent, unfinished, and archived sections.
- `MeetingArchiveSnapshot` derives archived-paper detail rows and full timeline data for restored papers.
- Export controls are gated by Core state, so only archived papers prepare shareable Markdown files.
- `MeetingExportDocument` renders a paper into Markdown, and `MeetingExportFileWriter` writes a named `.md` file for iOS sharing and developer-readable inspection.
- `SettlementRevisionDraft` keeps final-card edits normalized, change-aware, and safe to archive.

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

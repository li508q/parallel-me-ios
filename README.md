# ParallelMe iOS

ParallelMe iOS is a native Swift reimplementation of the ParallelMe product: a scribe-guided five-voice roundtable that helps a user define a real dilemma, let five inner voices speak, answer the final questions that matter, and settle on a small accountable next action.

This repository intentionally does not port the web app one file at a time. It keeps the product logic in a testable Swift core, then lets SwiftUI render that state.

## Product Flow

1. `Defining`: the scribe turns a raw petition into a four-key issue proposal.
2. `Roundtable`: five fixed voices open and continue the discussion.
3. `Inquiry`: the scribe asks only the remaining high-density questions needed for settlement.
4. `Settlement`: the user receives and can revise the final Heart Settlement.
5. `Archive`: the completed meeting is stored locally.

There is no global question-count cap. The app closes loops through explicit sufficiency checks: proposal completeness, purpose coverage, duplicate filtering, inquiry readiness, and user confirmation.

## Modules

| Module | Responsibility |
| --- | --- |
| `ParallelMeCore` | Product domain models, five-voice personas, flow engine, scribe deduplication, LLM/provider protocols. |
| `ParallelMeDesign` | iPhone design tokens: color, spacing, typography, motion intent. |
| `ParallelMeUI` | SwiftUI surfaces that render core state and dispatch user intent. |
| `App/ParallelMe` | Thin iOS app entry point. |
| `Tests/ParallelMeCoreTests` | Unit tests for flow rules, persona invariants, deduplication, and no hard inquiry cap. |

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

The current machine has Swift command-line tools available, but `xcodebuild` points at Command Line Tools rather than full Xcode, and this toolchain does not expose `XCTest` or Swift `Testing`. `ParallelMeCoreSmokeTests` is therefore the first executable verification layer. Standard XCTest and UI tests should be added once full Xcode is installed.

# Testing

The first test layer is `ParallelMeCore`.

## Required Coverage

- A roundtable cannot start before a complete issue proposal exists.
- The five voice list is stable and complete.
- Stage-one questions are deduplicated by purpose and similar wording.
- Stage-one proposal feedback is persisted and can regenerate the four-key proposal.
- Final inquiry has no global maximum question count.
- Settlement readiness depends on evidence and profile completeness, not on the number of turns.
- Session coordination persists each meaningful transition and records debug events.
- Demo mode can drive a complete local meeting from petition to archive.

## Running Tests

```bash
swift run ParallelMeCoreSmokeTests
```

This machine's command-line Swift toolchain does not expose `XCTest` or Swift `Testing`, so the repository includes a small executable smoke-test runner that still exercises the core unit rules. UI and simulator tests should be added once a full Xcode installation is available.

Current smoke coverage includes 23 checks across flow rules, provider configuration, secure settings persistence, deduplication, proposal refinement, settlement readiness, user settlement revisions, archive summaries, repositories, session events, and all demo roundtable move types.

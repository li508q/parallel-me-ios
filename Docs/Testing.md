# Testing

The first test layer is `ParallelMeCore`.

## Required Coverage

- A roundtable cannot start before a complete issue proposal exists.
- The five voice list is stable and complete.
- Stage-one questions are deduplicated by purpose and similar wording.
- Final inquiry has no global maximum question count.
- Settlement readiness depends on evidence and profile completeness, not on the number of turns.

## Running Tests

```bash
swift run ParallelMeCoreSmokeTests
```

This machine's command-line Swift toolchain does not expose `XCTest` or Swift `Testing`, so the repository includes a small executable smoke-test runner that still exercises the core unit rules. UI and simulator tests should be added once a full Xcode installation is available.

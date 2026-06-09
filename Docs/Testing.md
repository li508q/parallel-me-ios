# Testing

The first test layer is `ParallelMeCore`.

## Required Coverage

- A roundtable cannot start before a complete issue proposal exists.
- The five voice list is stable and complete.
- Starter prompts are distinct, non-empty first-sentence seeds and can be applied by the view model.
- Start readiness explains empty petitions and incomplete provider settings before the first meeting step.
- Stage-one answer batches must cover every current scribe question before the flow can continue.
- Inquiry answer batches must cover every current active inquiry question before the flow can continue.
- Stage-one questions are deduplicated by purpose and similar wording.
- Free-text answers are preserved for both defining questions and final inquiry.
- Stage-one proposal feedback is persisted and can regenerate the four-key proposal.
- Final inquiry has no global maximum question count.
- Provider prompt specs preserve fixed voices, free-text exits, no hard inquiry cap, context boundaries, and required settlement modules.
- Provider context is normalized, persisted separately from credentials, clearable, and forwarded into provider requests.
- Runtime preferences can be explicitly saved and cleared through the view model before any meeting starts.
- Runtime snapshots are normalized in the flow engine and persisted by the session coordinator without storing API keys.
- Restored unfinished papers rebuild the UI runtime before continuing and archived papers can be opened without valid provider credentials.
- Stage progress exposes fixed, localized product steps and completion state.
- Roundtable inquiry readiness requires complete fixed-voice openings and at least one substantive roundtable exchange.
- Meeting timeline derives active-paper progress and recent/full presentation snapshots without UI-specific business logic.
- Roundtable transcript grouping covers openings, user moves, model replies, and legacy ungrouped turns.
- Meeting archive snapshot derives archived detail rows from Core state and preserves user settlement revisions.
- Settlement and archive timestamps drive summary freshness, library ordering, and timeline rows.
- Meeting export renders archived papers into Markdown using Core state and user settlement revisions.
- Meeting export writes named Markdown files to a local directory before iOS sharing.
- Settlement revision drafts emit only meaningful changes and block blank module text.
- Meeting library grouping, sorting, summary search, and full-paper content search are tested in Core.
- Resume policy selects the latest unfinished paper and ignores archived papers.
- Settlement readiness depends on evidence and profile completeness, not on the number of turns.
- Session coordination persists each meaningful transition and records debug events.
- Demo mode can drive a complete local meeting from petition to archive.

## Running Tests

```bash
swift run ParallelMeCoreSmokeTests
```

This machine's command-line Swift toolchain does not expose `XCTest` or Swift `Testing`, so the repository includes a small executable smoke-test runner that still exercises the core unit rules. UI and simulator tests should be added once a full Xcode installation is available.

Current smoke coverage includes 54 checks across flow rules, starter prompts, start readiness, in-flight activity snapshots, stage-one answer batching, inquiry answer batching, stage progress, roundtable inquiry readiness, runtime snapshots, restored-paper runtime rebuilding, lifecycle timestamps, paper library grouping and full-paper search, archived detail snapshots, Markdown export, export file writing, provider prompt contracts, provider configuration, secure settings persistence, provider context persistence, runtime preference actions, deduplication, free-text answers, proposal refinement, resume policy, meeting timeline, roundtable transcript grouping, settlement readiness, settlement revision drafts, user settlement revisions, archive summaries, repositories, session events, and all demo roundtable move types.

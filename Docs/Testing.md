# Testing

The first test layer is `ParallelMeCore`.

## Required Coverage

- A roundtable cannot start before a complete issue proposal exists.
- The five voice list is stable and complete.
- Starter prompts are distinct, non-empty first-sentence seeds and can be applied by the view model.
- Start readiness explains empty petitions and incomplete provider settings before the first meeting step, and locks starter/petition editing while start work is in flight.
- Stage-one answer batches must cover every current scribe question before the flow can continue.
- Inquiry answer batches must cover every current active inquiry question before the flow can continue.
- Settlement request availability explains unanswered inquiry questions, missing profiles, missing task context, incomplete settlement evidence, and busy state before generating Heart Settlement.
- Stage-one questions are deduplicated by purpose and similar wording.
- Free-text answers are preserved for both defining questions and final inquiry.
- Stage-one proposal feedback is persisted and can regenerate the four-key proposal.
- Proposal confirmation availability explains missing proposals, incomplete proposals, missing task frames, and busy state before entering roundtable.
- Roundtable action availability explains incomplete openings, missing task frames, and busy state before submitting roundtable moves or entering inquiry.
- Final inquiry has no global maximum question count.
- Provider prompt specs preserve fixed voices, free-text exits, no hard inquiry cap, context boundaries, non-template inquiry rules, and required settlement modules.
- Contradictory definition provider responses cannot mark a proposal ready while also introducing unanswered follow-up questions.
- Contradictory inquiry provider responses cannot mark settlement ready while also introducing unanswered follow-up questions.
- OpenAI-compatible provider tests assert request URL, headers, body shape, strict JSON response format, balanced fenced JSON extraction, and HTTP error body propagation without live network calls.
- Runtime provider settings normalize URL, model, and API key text before persistence, runtime snapshots, and provider factory requests.
- Runtime provider settings load failures surface friendly user-facing copy instead of raw Swift errors.
- Provider context is normalized, persisted separately from credentials, clearable, and forwarded into provider requests.
- Runtime preferences can be explicitly saved and cleared through the view model before any meeting starts.
- Runtime preference action availability blocks invalid OpenAI-compatible settings and locks provider/context editing while async preference work is in flight.
- Runtime preference saves cannot bypass availability checks when called directly on the view model.
- Runtime snapshots are normalized in the flow engine and persisted by the session coordinator without storing API keys.
- Failed initial definition requests can be retried from the same started paper.
- Failed initial inquiry requests can be retried from the same inquiry paper after the persisted state is adopted by the view model.
- Restored unfinished papers rebuild the UI runtime before continuing and archived papers can be opened without valid provider credentials.
- Stage progress exposes fixed, localized product steps and completion state.
- Roundtable inquiry readiness requires complete fixed-voice openings and at least one substantive roundtable exchange.
- Meeting timeline derives active-paper progress and recent/full presentation snapshots without UI-specific business logic.
- Roundtable transcript grouping covers openings, user moves, model replies, and legacy ungrouped turns.
- Meeting archive snapshot derives archived detail rows from Core state and preserves user settlement revisions.
- Settlement and archive timestamps drive summary freshness, library ordering, and timeline rows.
- Export availability is gated to archived papers with complete Heart Settlement content before the UI prepares a shareable Markdown file.
- Paper library action availability locks restore/delete actions while async paper-library work is in flight.
- Meeting export renders archived papers into Markdown using Core state and user settlement revisions.
- Meeting export writes named Markdown files to a local directory before iOS sharing.
- File-backed paper listing skips unreadable JSON records without hiding still-readable saved papers.
- Settlement stage snapshots expose a recovery path when restored state is missing its Heart Settlement.
- Archive rejects settlement states that do not contain a complete five-module Heart Settlement.
- Settlement revision drafts emit only meaningful changes and block blank module text.
- Settlement action availability locks apply/archive actions while async work is in flight.
- Meeting library grouping, sorting, summary search, and full-paper content search are tested in Core.
- Resume policy selects the latest unfinished paper and ignores archived papers.
- Settlement readiness depends on evidence and profile completeness, not on the number of turns.
- Session coordination persists each meaningful transition and records debug events.
- Session diagnostics summarize recent events, failures, provider requests closed by responses or failures, and event counts in Core.
- Meeting state health snapshots diagnose restored-paper structural gaps, inquiry evidence gaps, and healthy completed states in Core.
- Demo mode can drive a complete local meeting from petition to archive.

## Running Tests

```bash
swift run ParallelMeCoreSmokeTests
```

This machine's command-line Swift toolchain does not expose `XCTest` or Swift `Testing`, so the repository includes a small executable smoke-test runner that still exercises the core unit rules. UI and simulator tests should be added once a full Xcode installation is available.

Current smoke coverage includes 78 checks across flow rules, starter prompts, start readiness and busy input locking, definition retry recovery, definition response guarding, definition fallback question recovery, inquiry retry recovery, in-flight activity snapshots, stage-one answer batching, inquiry answer batching, proposal confirmation availability, stage progress, roundtable inquiry readiness, roundtable action availability, settlement request availability, inquiry response guarding, runtime snapshots, restored-paper runtime rebuilding, missing restored-paper feedback, lifecycle timestamps, paper library grouping, status filtering, full-paper search, and paper-library action availability, archived detail snapshots, export availability, Markdown export, export file writing, file repository resilience, provider prompt contracts, provider configuration, provider settings normalization, OpenAI-compatible transport, OpenAI-compatible JSON extraction, secure settings persistence, provider context persistence, runtime preference actions, runtime preference action availability, runtime preference save gating, runtime load error copy, deduplication, unanswered-question coverage, free-text answers, proposal refinement, resume policy, meeting timeline, roundtable transcript grouping, settlement readiness, settlement stage recovery, settlement revision drafts, settlement action availability, archive completeness, user settlement revisions, archive summaries, repositories, session events, session diagnostics, meeting state health, and all demo roundtable move types.

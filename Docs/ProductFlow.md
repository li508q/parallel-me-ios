# Product Flow

ParallelMe is not a generic chat app. A meeting has a host, a fixed cast, and a real ending.

During an active meeting, the iOS app keeps a current-paper timeline visible near a five-step stage rail. The stage rail names the current step in product language, while the timeline starts with the most recent steps to preserve focus and can expand into the full paper history when the user needs to re-read the path that led here. This gives the user a compact sense of what has already happened without turning the product into a raw chat transcript.

Before a meeting, the user can optionally keep a private personal context: who they are, what long-running situation they are in, and what response style helps them think. This context is local, reusable, explicitly saveable or clearable from the start screen, and sent to provider tasks only as background calibration; the current petition and later answers remain the source of truth for the meeting. When a meeting starts, the app stores a non-secret runtime snapshot on that paper so restored meetings can show which provider and context were actually used.

## 1. Raw Petition

The user starts with a messy, emotional, incomplete description. The product should accept this as-is. The first job is not advice; it is issue definition.

On iOS, the empty home screen offers a small set of starter prompts. They are not templates for the final answer; they are safe first sentences that help the user begin when the page is blank. Selecting one fills the raw petition editor, and the user can rewrite it before starting the meeting.

Before the first model-backed step, the home screen explains whether the meeting can start. Empty petitions and incomplete OpenAI-compatible settings are surfaced as explicit readiness blockers instead of leaving the user with a disabled button and no reason. Once the first model-backed step is in flight, the starter cards and raw petition editor lock so the paper uses the exact first sentence the user submitted.
If the first definition request fails after a paper has been created, the defining screen offers an explicit retry action on the same paper instead of forcing the user back to the home screen.

## 2. Scribe Defining

The scribe completes a four-key issue proposal:

- `surface_dilemma`: the visible choice fork.
- `current_constraints`: the real-world constraints.
- `core_fears`: the value, loss, or fear underneath the surface choice.
- `expected_resolution`: what the roundtable must help verify.

The scribe can ask 1-3 questions per turn. There is no total-turn cap. Repetition is prevented by purpose coverage and question-similarity filtering.

Every question must include a free-text escape. If the provided options miss the user's real answer, the user can write their own language and that text becomes part of the meeting evidence. When the scribe asks multiple questions in one turn, iOS keeps them as one answer batch; the user answers every current question before the app sends the batch back to the scribe.

## 3. Proposal Confirmation

The user can confirm, edit, or ask the scribe to refine the proposal. The app cannot enter the roundtable until the proposal is complete enough to map into a task frame.

On iOS, proposal refinement is a first-class loop: the user can write what feels inaccurate, the feedback is stored in the defining dialogue, and the scribe regenerates the four-key proposal before the user confirms.

## 4. Five-Voice Roundtable

The fixed voices are:

- 躺平的我
- 搞钱的我
- 出走的我
- 被牵挂的我
- 5 年后的我

They are not agents invented per session. They are stable product personas with durable values and fears. The user can continue the table, ask one voice, ask all voices, or let two voices speak directly.

The iOS roundtable exposes all four moves explicitly: continue all voices, ask the whole table, ask a selected voice, and start a two-voice dialogue. The visible transcript is grouped by opening and by each user move, so a long meeting still reads like a facilitated roundtable rather than a flat chat log.

The app cannot enter final inquiry from a bare opening. All five fixed voices must have opened, and at least one roundtable move must receive a concrete response before the inquiry action becomes available. This is a minimum evidence guard, not a maximum round cap: the user can continue the table as long as useful, then move to inquiry when there is real material to question.

## 5. Invisible Scribe Observation

The scribe maintains a background ledger. This ledger records evidence for the final settlement modules but does not interrupt the roundtable or appear as a user-facing diagnosis.

## 6. Final Inquiry

The inquiry loop asks only questions that can still change the settlement quality. If the first inquiry request fails after the paper has entered inquiry, the app keeps the paper in inquiry and offers an explicit retry action that reuses the current roundtable evidence instead of sending the user back to the roundtable. The loop closes when the five settlement landing zones are sufficiently supported:

- creative hopelessness
- core value axis
- cost acceptance
- minimum action
- dialectic synthesis

The loop is sufficiency-driven, not count-driven. Like stage-one defining, each visible inquiry turn is answered as a batch: if the scribe asks multiple high-density questions together, the app waits until every current question has an answer before sending the turn back.

## 7. Heart Settlement

The final card must be concrete, revisable, and actionable. Authority stays with the user: modules can be accepted or revised, and the minimum action should be small enough to do within 24 hours. Revision is draft-based: unchanged text is not resubmitted, blank modules cannot be applied, and changed language becomes the canonical text used by archive summaries.

## 8. Archive And Return

After settlement, the user can archive the meeting as a local paper, reopen it as a readable detail view, and export the archived paper as a named Markdown file through the iOS share sheet. Archive requires a complete Heart Settlement with all five modules present, so an incomplete recovered state cannot be saved as a finished paper. Export controls only prepare files after archive and only when the archived paper still has complete settlement content; a recovered legacy paper that lacks that content stays readable but shows why export is unavailable. The archived detail keeps the final Heart Settlement, the confirmed issue definition, and the full paper timeline visible in the app. During an unfinished meeting, the user can safely return to the home screen without deleting the paper. The home screen promotes the latest unfinished paper as the primary resume action and keeps a searchable paper library grouped into unfinished and archived sections. The paper library can be filtered by all, unfinished, or archived papers, and search covers the paper's title, stage, raw petition, issue definition, roundtable turns, inquiry answers, and settlement text. The user can restore or delete any saved paper from that library; deletion is always protected by an explicit confirmation because papers are local private records. This keeps ParallelMe from becoming a one-off chat transcript; each meeting becomes part of a private local memory.

# Product Flow

ParallelMe is not a generic chat app. A meeting has a host, a fixed cast, and a real ending.

During an active meeting, the iOS app keeps a current-paper timeline visible near the stage rail. This gives the user a compact sense of what has already happened without turning the product into a raw chat transcript.

Before a meeting, the user can optionally keep a private personal context: who they are, what long-running situation they are in, and what response style helps them think. This context is local, reusable, and sent to provider tasks only as background calibration; the current petition and later answers remain the source of truth for the meeting. When a meeting starts, the app stores a non-secret runtime snapshot on that paper so restored meetings can show which provider and context were actually used.

## 1. Raw Petition

The user starts with a messy, emotional, incomplete description. The product should accept this as-is. The first job is not advice; it is issue definition.

## 2. Scribe Defining

The scribe completes a four-key issue proposal:

- `surface_dilemma`: the visible choice fork.
- `current_constraints`: the real-world constraints.
- `core_fears`: the value, loss, or fear underneath the surface choice.
- `expected_resolution`: what the roundtable must help verify.

The scribe can ask 1-3 questions per turn. There is no total-turn cap. Repetition is prevented by purpose coverage and question-similarity filtering.

Every question must include a free-text escape. If the provided options miss the user's real answer, the user can write their own language and that text becomes part of the meeting evidence.

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

The iOS roundtable exposes all four moves explicitly: continue all voices, ask the whole table, ask a selected voice, and start a two-voice dialogue.

## 5. Invisible Scribe Observation

The scribe maintains a background ledger. This ledger records evidence for the final settlement modules but does not interrupt the roundtable or appear as a user-facing diagnosis.

## 6. Final Inquiry

The inquiry loop asks only questions that can still change the settlement quality. It closes when the five settlement landing zones are sufficiently supported:

- creative hopelessness
- core value axis
- cost acceptance
- minimum action
- dialectic synthesis

The loop is sufficiency-driven, not count-driven.

## 7. Heart Settlement

The final card must be concrete, revisable, and actionable. Authority stays with the user: modules can be accepted or revised, and the minimum action should be small enough to do within 24 hours. If the user rewrites the synthesis or any module, that language becomes the canonical text used by archive summaries.

## 8. Archive And Return

After settlement, the user can archive the meeting as a local paper, reopen it as a readable detail view, and export the paper as Markdown. The archived detail keeps the final Heart Settlement, the confirmed issue definition, and the full paper timeline visible in the app. During an unfinished meeting, the user can safely return to the home screen without deleting the paper. The home screen promotes the latest unfinished paper as the primary resume action and keeps a searchable paper library grouped into unfinished and archived sections. Search covers the paper's title, stage, raw petition, issue definition, roundtable turns, inquiry answers, and settlement text. The user can restore or delete any saved paper from that library. This keeps ParallelMe from becoming a one-off chat transcript; each meeting becomes part of a private local memory.

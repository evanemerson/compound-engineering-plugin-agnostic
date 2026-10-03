# Punch list — 2026-10-02 five-session triage

Built from a triage of five open Claude Code sessions on 2026-10-02. This file
is the tracker. Items are numbered as the user knows them — **do not renumber
them**, even after items close, because the user refers to them by number
across sessions.

Each item carries a `status:` line so `check-residual-integrity.sh` and
`cepa:file-todos` consumers can read state.

---

## Closed

1. **File the missing handoff for the #75–#78 session.**
   status: completed
   Done 2026-10-02. `docs/handoff/2026-10-02-file-todos-grep-spellings-and-ci-enforcer.md`,
   plus `3e5e974` recording that a concurrent session resolved.

2. **Write back the four OB1 policy decisions in tab 2.**
   status: completed
   Done 2026-10-02 as PR #79 (`86332d8`). Findings #1, #3, #4 closed
   `completed`; #2 left `deferred` pending OpenRouter zero-retention
   verification, which has no record in this repo. Open P1s 8 → 7.

3. **Close tabs 1, 3, 4.**
   status: completed
   Done 2026-10-02. Nothing was owed in any of them.

---

## Open — in dependency order

4. **Build `scripts/check-doc-greps.sh`.**
   status: pending
   severity: P2
   The last prevention item with no mechanism behind it. Must assert a skill's
   fenced grep patterns against BOTH its committed fixture AND a corpus diff —
   #77 proved the fixture half alone is insufficient (a fix scored 13/13 on the
   fixture, then lost rows on 51 of 193 corpus files).
   **Undecided before starting:** whether to adopt the
   `(skill, fixture, expected)` triple convention at all. Marginal for one
   pattern pair; pays off as a house style. The 2026-10-02 handoff lists this
   as an open question, not a settled task.
   Needs a fresh session and a plan. Run via `/cepa:task`.

5. **Work residual 2i, then 2j, then 2g, then 2c.** (2i, 2j, 2g closed; 2c open)
   status: in_progress
   severity: P2
   **2i CLOSED** — PR #80 (`afe7ce1`), merged 2026-10-03. The re-Write PHI gate
   is executable: `scrub-seal` before the hand-edit, `scrub-verify` before
   `writeback`. Verified live against the loaded copy.
   **2j CLOSED** — PR #81 (`17271ee`), merged 2026-10-03. The payload path is
   minted per run, so concurrent runs no longer collide. 2j was filed BY #80's
   review and did not exist when this list was written.
   **2g CLOSED** — PR #82 (`feat/fenced-block-state-checker`), 2026-10-03.
   `scripts/check-fenced-block-state.sh` + its controls, CI-gated in
   `residual-integrity.yml`. The checker WAS the fix: 2g had six instances, two
   written by sessions actively enforcing the rule, so review alone was
   measurably not holding. `extract-fenced-blocks.py` (committed in #80) did
   the extraction half; #82 added the gate, the allowlist, and four probe
   fixes the gate's own first cut needed. The shard owns the detail.
   **Remaining: 2c.**
   Also surfaced by #81's review and still open: **2k/2l** — document the
   seal/verify contract in the `cepa:brain` skill, and state the non-zero-block
   stop rule once in `cepa:autonomy` rather than per command file.
   The shard `memory/tasks.d/2026-09-26-forced-phi-scrub-verification.md`
   **IS the plan. Do not write another one.**
   Order: 2c next. Leave 2e, 2f, 2d filed — they are the honest limits of
   a numeric-only scrub, not defects.
   Kept as the record of why the order was 2i → 2j → 2g: 2i was coupled to 2g,
   because its marker count must cross a fenced-block boundary and therefore
   goes through the filesystem. 2i was the first real test of 2g's rule — and
   it failed it, which is instance 5.

6. **Hand the dpc-pro discrepancy to that repo.**
   status: completed
   severity: P3
   **Done 2026-10-03. Answer: NO DRIFT. The checker was wrong, not the files.**
   A prompt was written here and run in a dpc-pro session. Its finding is now
   item 8 below — the deliverable from this repo was the prompt; the answer came
   back as evidence against our own checker.
   `review-2026-08-14-224500.md` in dpc-pro reads 6 status rows against 21
   headings. Newly visible after #77 — the checker was blind to it before. May
   be real counter drift or a non-tallyable shape.
   **Checked 2026-10-02: NOT done.** The 2026-10-02 handoff records it under
   "Unsettled — decide before starting" as an open question. No prompt has been
   written and nothing has been handed off.
   **Never run anything in `~/webapps/dpc-pro` from here** (CLAUDE.md, outermost
   rule). The deliverable from this repo is a written prompt the user runs in
   that repo's own session. An unrun command with clear instructions is a
   completed task here.

7. **Build the anchor-digit checker.**
   status: pending
   severity: P3
   Filed as the unchecked P3 in `memory/tasks.d/2026-09-25-main.md:29`. Extracts
   headings matching `^#{2,4} .*\(\d+\)` and resolves in-page anchors. Gates the
   heading half of the count-drift rule. The other two legs of that class are
   NOT hard-gateable and the checker's header must say so.

8. **`check-residual-integrity.sh` counts `status:` only as the FIRST field on
   a bullet.**
   status: pending
   severity: P2
   Filed 2026-10-03 from item 6's dpc-pro answer. **Positional, not a spelling
   gap** — `-i` and the bold alternation cannot reach it, so this is a DIFFERENT
   defect from the one PR #77 fixed, in the same construct.

   `FIELD_PRE` (line 219) is anchored `^` and allows one list marker, so a
   `status:` field that follows another field on the same line never matches.

   Measured here 2026-10-03 against the live fragments — both of dpc-pro's
   reported shapes MISS:
   - `- **confidence:** 100 · **class:** judgment · **status:** pending` → miss
   - `- category: X | agent: Y | status: pending` → miss
   - `- **status:** pending` → MATCH
   - `  status: applied` → MATCH

   Measured in dpc-pro across its 200-file corpus: **29 files undercount, 3
   badly.** `review-2026-08-14-224500.md` reads 6 of a real 21;
   `review-2026-08-28-215841.md` reads 8 of a real 21. **Both tally 21 rows to
   21 `### N` headings, so NEITHER is drift** — the checker was wrong.

   **A third shape has no denominator.** `review-20260627-162353.md` has 42 rows
   and ZERO `### N` headings (titles are unnumbered). `counter_convention:`
   assumes a numerator/denominator mismatch; this is a missing denominator. The
   escape hatch may not cover it — decide that explicitly.

   **The over-match risk is real and already measured.** Relaxing `^` makes
   narrative prose match: `The status: pending means nothing has run yet.` is
   correctly rejected today. Any fix must diff old against new on a real corpus
   and treat a lost row AND a gained prose row as regressions — the #77 lesson
   (fixture 13/13, then 51 of 193 files lost rows) applies directly.

   This is the "fix scoped to the reported instance leaves the rest of the
   construct live" class CLAUDE.md records three times. #77 closed the spelling
   half; this is the positional half.

---

## How this list is used

When the user asks "where am I" or opens a new session, read this file first.
Report the open items by their original numbers with the closed ones struck
through. Recommend the next item by number.

The user's stated constraint: they lose track across many tabs, and want to be
reminded when it is time to start the next item.

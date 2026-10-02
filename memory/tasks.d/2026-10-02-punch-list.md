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

5. **Work residual 2i, then 2g, then 2c.**
   status: pending
   severity: P1
   2i is the last unenforced P1 in the repo — a PHI-scrub guard that exists
   only as prose. The shard
   `memory/tasks.d/2026-09-26-forced-phi-scrub-verification.md` **IS the plan.
   Do not write another one.**
   Order: 2i → 2g → 2c. Leave 2e, 2f, 2d filed — they are the honest limits of
   a numeric-only scrub, not defects.
   2i is coupled to 2g: the count must cross a fenced-block boundary, so it
   goes through the filesystem. 2i is the first real test of 2g's rule.

6. **Hand the dpc-pro discrepancy to that repo.**
   status: pending
   severity: P3
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

---

## How this list is used

When the user asks "where am I" or opens a new session, read this file first.
Report the open items by their original numbers with the closed ones struck
through. Recommend the next item by number.

The user's stated constraint: they lose track across many tabs, and want to be
reminded when it is time to start the next item.

# Punch list — 2026-10-02 five-session triage

Built from a triage of five open Claude Code sessions on 2026-10-02. This file
is the tracker. Items are numbered as the user knows them — **do not renumber
them**, even after items close, because the user refers to them by number
across sessions.

Each item carries a `status:` line so `check-residual-integrity.sh` and
`cepa:file-todos` consumers can read state.

---

## Closed

L1. **File the missing handoff for the #75–#78 session.**
   status: completed
   Done 2026-10-02. `docs/handoff/2026-10-02-file-todos-grep-spellings-and-ci-enforcer.md`,
   plus `3e5e974` recording that a concurrent session resolved.

L2. **Write back the four OB1 policy decisions in tab 2.**
   status: completed
   Done 2026-10-02 as PR #79 (`86332d8`). Findings #1, #3, #4 closed
   `completed`; #2 left `deferred` pending OpenRouter zero-retention
   verification, which has no record in this repo. Open P1s 8 → 7.

L3. **Close tabs 1, 3, 4.**
   status: completed
   Done 2026-10-02. Nothing was owed in any of them.

---

## Open — in dependency order

L4. **Build `scripts/check-doc-greps.sh`.**
   status: pending
   owner: unassigned
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

L5. **Work residual 2i, then 2j, then 2g, then 2c.** (all four closed)
   status: completed
   severity: P2
   **2i CLOSED** — PR #80 (`afe7ce1`), merged 2026-10-03. The re-Write PHI gate
   is executable: `scrub-seal` before the hand-edit, `scrub-verify` before
   `writeback`. Verified live against the loaded copy.
   **2j CLOSED** — PR #81 (`17271ee`), merged 2026-10-03. The payload path is
   minted per run, so concurrent runs no longer collide. 2j was filed BY #80's
   review and did not exist when this list was written.
   **2g CLOSED** — PR #82 (`d926225`), merged 2026-10-04.
   `scripts/check-fenced-block-state.sh` + its controls, CI-gated in
   `residual-integrity.yml`. The checker WAS the fix: 2g had six instances, two
   written by sessions actively enforcing the rule, so review alone was
   measurably not holding. `extract-fenced-blocks.py` (committed in #80) did
   the extraction half; #82 added the gate, the allowlist, and four probe
   fixes the gate's own first cut needed. The shard owns the detail.
   **2c CLOSED** — PR #83 (`d92d3c3`), merged 2026-10-05. Leg 5 of
   `check-model-pins.sh` resolves skill section-NAME citations. Plugin
   freshness verified after merge: both hops OK at `d92d3c3`.
   **Left open by #83, filed in the shard, NOT on this list:** 2c-r7 (the full
   mutation sweep takes 224 min locally; CI bounds the step at 150, so the
   weekly run is expected to be CANCELLED and open a failure issue) and 2c-r8
   (five model-pin legs own no unique killer). See item 11.
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

L6. **Hand the dpc-pro discrepancy to that repo.**
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

L7. **Build the anchor-digit checker.**
   status: pending
   owner: unassigned
   severity: P3
   Filed as the unchecked P3 in `memory/tasks.d/2026-09-25-main.md:29`. Extracts
   headings matching `^#{2,4} .*\(\d+\)` and resolves in-page anchors. Gates the
   heading half of the count-drift rule. The other two legs of that class are
   NOT hard-gateable and the checker's header must say so.

L8. **`check-residual-integrity.sh` counts `status:` only as the FIRST field on
   a bullet.**
   status: completed
   **CLOSED 2026-10-06** — PR #85 (`fe342a6`), v1.29.1. FIELD_PRE gained a
   third branch: a `status:`/`severity:` field after ` · ` or ` | ` on a line
   that starts as a field, outside inline code. 4 deferred review findings are
   owned by `memory/tasks.d/2026-10-06-fix-integrity-positional-status-field.md`.
   **Proven on dpc-pro's 206-file corpus by two read-only hand-off probes** (the
   only corpus holding the positive shapes): 0 files LOST rows; 4 GAINED,
   including `08-14-224500` 6->21 and `08-28-215841` 8->21, each now equal to
   its 21 headings. `08-20-115716` went 12->24: the 12 new lines are genuine
   `| **status:** pending` fields, the exact target shape, verified line by line.
   **The expected "about 29 files" was wrong** — relayed from the first dpc-pro
   session without the command that produced it. Kept as the lesson: a relayed
   count with no probe is not an expectation. Remaining dpc-pro gaps are item 13.
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

L9. **Hop 1 of the freshness check printed `UNKNOWN` on every plugin merge.**
   status: completed
   severity: P3
   **Fixed operationally 2026-10-04.** The marketplace clone at
   `~/.claude/plugins/marketplaces/cepa` was SHALLOW — exactly 1 commit — so it
   could never contain an older plugin-touching SHA. The checker was correct:
   `UNKNOWN` means "could not tell", and it could not.
   Fix: `git -C ~/.claude/plugins/marketplaces/cepa fetch --unshallow origin`.
   Before: shallow, 1 commit, 4.1M, hop 1 UNKNOWN. After: 145 commits, 5.4M,
   hop 1 OK. HEAD, branch and clean tree unchanged. Held through #83's merge:
   both hops OK at `d92d3c3`.
   **The fix first proposed for this was WRONG — keep the disproof.** The #82
   session suggested probing ancestor-or-descendant instead of an exact object.
   Measured on the shallow clone:
   `git -C <clone> merge-base --is-ancestor 17271ee HEAD` →
   `fatal: Not a valid object name 17271ee`, rc=128. The object is ABSENT,
   not unreachable, so changing the question cannot find it. That fix would
   have added code and still printed `UNKNOWN`.
   This is one machine's state. A re-clone by `claude plugin` may make it
   shallow again; the same command fixes it.

L10. **Make cepa agree with the global session roles.**
    status: completed
    **CLOSED 2026-10-05** — PR #84 (`3b46209`), v1.29.0. Merged by coord@main
    after the three checks (Handoff `done`; PR head == Handoff `Head: 18e0c4c`;
    update-branch was a no-op, CI green). Both plugin hops refreshed; freshness
    rc=0 at `3b46209`. The roles worktree is parked detached at `origin/main`
    and the branch is deleted. 12 review findings were deferred and are owned
    by `memory/tasks.d/2026-10-05-feat-roles-session-roles.md` — read them there.
    severity: P2
    Global `~/.claude/CLAUDE.md` § "Sessions and roles" (2026-10-04) defines
    worker `tabN@<wt>`, coord@<wt> and coord@main; worker branches
    `<type>/<wt>/<desc>`; a Handoff block in place of `## Next steps`; and no
    worker ever offers or acts on a PR it did not open.
    Dispatched 2026-10-05 as `tab1@roles` in worktree `.claude/worktrees/roles`,
    branch `feat/roles/session-roles` off `origin/main` @ `d92d3c3`. coord@main
    (the main-checkout coordinator) owns the merge and the plugin refresh.
    The first prompt had four problems, all corrected before dispatch: it named
    the worker `tab1@main` (the main checkout hosts no workers); it told the
    worker to merge; it sent the worker into another repo for evidence; and it
    missed three sites — `autonomy/SKILL.md:539` (the canonical
    "return to trunk" row), `lfg.md:89`, and `task.md:553`.

L11. **Fix the mutation sweep's CI bound (residual 2c-r7).**
    status: in_progress
    severity: P2
    owner: coord@main — code merged; waiting only on the proof below.
    **MERGED 2026-10-21** — PR #89 (`9a140d3`), v1.32.0, by `tab2@integrity`.
    The sweep now runs as 8 parallel shards plus a merge job, and only the merge
    job can turn the run green. A shard that hits its limit still reports: each
    unrun mutant is `NOT-RUN`, and the issue opens with "classified X of Y". The
    run goes red when a shard uses over 60% of its limit, before a timeout can
    erase results. Hosted proof: run 39619703190 at `135257c`, 98/98 classified,
    43.4 min wall-clock, slowest shard 34% of its 120-min limit.
    The worker's first cut had bumped to 1.31.0, which #88 had already shipped;
    coord@main caught it before merge (a trial merge was CLEAN, so git gave no
    warning) and the worker re-bumped to 1.32.0.
    **To close:** the next SCHEDULED run (Monday 2026-10-26, 06:17 UTC cron)
    passes. Then coord@main closes issue #61, which the worker left untouched.
    7 P3s deferred as 2c-r7a–g in the forced-PHI-scrub shard.

L12. **Make cepa enforce the coord@<wt> rule (finding #8 of PR #84).**
    status: completed
    **CLOSED 2026-10-17** — PR #87 (`c5b0932`), v1.30.0, by `tab2@roles`. New
    `cepa:autonomy` §10f: a worktree coordinator writes tracked state only in a
    `/cepa:task` or `/cepa:lfg` run whose probe reads PARKED; every other command
    stops or runs report-only, and each command file points at §10f once.
    Gated by `scripts/check-coord-write-guard.sh` in `residual-integrity.yml`.
    Merged by coord@main after the three checks: Handoff `done`; PR head ==
    Handoff `Head: a32e3a8`; update-branch -> `543df03`, CI green. Plugin hops
    refreshed; freshness rc=0 at `c5b0932`. Roles worktree parked; branch deleted.
    Merged as-is, which accepts the worker's two recommendations: keep its
    judgment-class review fixes (`todos/review-2026-10-06-095036.md` #4-#6, #10,
    #11, #13-#15, #18, #19), and leave #16 (a re-check before every commit)
    deferred. The 3 deferred findings are owned by
    `memory/tasks.d/2026-10-06-feat-roles-coord-wt-write-guard.md`.

L13. **dpc-pro findings files the checker still cannot reconcile.**
    status: pending
    owner: dpc-pro (hand-off only; nothing in this repo is owed yet).
    **Measured 2026-10-06 in a dpc-pro session** with the item 13 probe (cepa
    pattern pinned at `fe342a6`): 206 review files, 36 listed. The full output
    was written to that session's /tmp scratchpad and is NOW GONE (checked
    2026-10-16) — this entry, copied from the session's on-screen summary, is
    the only durable copy. Open findings were judged by reading each file; the
    session did NOT check whether later PRs closed them.

    | file | open | how state is written |
    |---|---|---|
    | review-20260718-pr27-reconcile | 0 | headings only (`HIGH/applied`) |
    | review-20260719-210914 | 5 or 6 | headings only; #10 says APPLIED, its text says deferred |
    | review-20260721-181500 | 5 | headings only; #7–#11 open only via a `## Deferred` section |
    | review-2026-08-01-060253 | 4 | `status:` rows; `### 10-21` is ONE heading over 12 findings |
    | review-2026-08-01-193000 | 7 headings (16 items) | #22–#28 have no row; open only via `## Deferred` |
    | review-2026-09-01-032223 | 6 | #1–#6 state in headings (applied); open #7–#12 HAVE rows |
    | review-20260715-idempotency-pr20 | 4 | `### 6-9 [DEFERRED -> tasks.md]`, one heading, no row |
    | review-20260627-154203 | 0 | NOT a findings file: a note that PR #13 needed no review |

    **The answer item 13 was waiting on: YES, open work is invisible.** At least
    5 files hold open findings with no `status:` row, so `/cepa:triage` and
    `/cepa:sweep` cannot see them. `032223` is the exception: its open findings
    have rows, so only its closed history is heading-only.
    Also reported: headings that cover a RANGE of findings; findings filed
    under the wrong section; frontmatter, footer and heading counts that
    disagree; and one `verify` state, which is not in the file-todos vocabulary.
    **Every one of these is a dpc-pro file departing from the `cepa:file-todos`
    spec, not a cepa defect** — the spec already requires one finding per
    heading with its own `status:` field. So the fix is in dpc-pro: first
    confirm each "open" finding against later dpc-pro PRs, then write the
    missing rows in spec form. cepa changes only if that work finds a shape the
    spec cannot express.
    severity: P3
    From the PR #85 proof run, 2026-10-06, dpc-pro `todos/` (206 files). Mostly
    a question about dpc-pro's FILES, so the deliverable here is a hand-off
    prompt, never a run in that repo.
    - **State in the heading, no status field at all:** `20260719-210914`
      (`### 1 [P2 applied] ...`) and `20260721-181500` (`### 1. [P1 · ...] —
      APPLIED`) count 0 rows against 15 and 11 headings. `20260718-pr27-reconcile`
      (0 vs 4) is likely the same. A third field shape, not a pattern bug —
      decide whether the spec admits it or `counter_convention:` covers it.
    - **Fewer rows than headings, cause unknown:** `08-01-060253` 9/10,
      `08-01-193000` 21/28, `09-01-032223` 6/12, `20260715-idempotency-pr20` 5/6.
    - **More rows than headings, pre-existing:** `08-28-141500` 26/22 under both
      checkers. Not caused by #85.
    - **21 files have no numbered headings** (no denominator), e.g.
      `08-20-115716`. #85's checker gives these a named MISS; it runs only in
      this repo's CI, so dpc-pro is not failing.
    **Proof-script artifact, not a pattern gap:** the #85 diff script's
    `body()` prints only lines after a CLOSED frontmatter, so a file with no
    frontmatter (`20260627-162353`) reads 0 rows. The pattern itself matches
    that file's `- **Agent:** ... · **Status:** done` line (tested, new=1).

L14. **Stop `/cepa:review` (and other dispatching commands) leaving `agent-*`
    worktrees behind.**
    status: completed
    **CLOSED 2026-10-21** — PR #88 (`8ebf28c`), v1.31.0, by `tab3@roles`.
    New `cepa:autonomy` §11, cited by every dispatching command: §11a gives a
    read-only agent NO worktree and opens its prompt with a `READ-ONLY:` line
    (no checkout, switch, worktree, fetch, stash, commit, push or detach; read
    at `<sha>` with `git show` / `git diff`); only lfg's parallel builders get a
    worktree. §11b cleans up after dispatch: removes an `agent-*` worktree only
    if this run's own agent calls made it, it did not exist before the run, it
    has no status line (ignored files included), and its HEAD and whole HEAD
    reflog are on origin; never `--force`. Report-only runs print
    `WOULD-REMOVE` and change no ref (§10f names the snapshot file as its one
    allowed write). Gated by `scripts/check-dispatch-isolation.sh` in CI.
    **Live test passed:** the PR's own 8 review agents and 3 plan-review agents
    left no `agent-*` worktree.
    **The real source of isolation on this machine:** the worker found Evan's
    global hook `~/.claude/hooks/require_worktree_isolation.py`. It refuses an
    agent dispatch that has neither `isolation: "worktree"` nor a `READ-ONLY:`
    line, and its message suggests isolation first. §11a's `READ-ONLY:` line
    satisfies it. The hook was not changed.
    **L14's site list was wrong:** sweep and resolve-pr dispatch no agents;
    compound, compound-refresh, task and lfg do.
    Merged as-is, taking the worker's decision 2 (leave the 2 open items and 4
    other deferred findings in
    `memory/tasks.d/2026-10-21-fix-roles-review-agent-worktrees.md`). Its
    decision 1, a CLAUDE.md rule, was not added on the branch: "a value filled
    from agent output never goes into a quoted shell string; read it through a
    quoted heredoc and check it inside the block."

L15. **Do read-only review agents write into the shared tree when they run code?**
    status: pending
    severity: P3
    owner: unassigned
    Filed 2026-10-21. A QUESTION, not a finding: nothing here has been measured.
    `cepa:autonomy` §11a (#88) gives a Reader agent no worktree and a
    `READ-ONLY:` brief that says "write files only under a `mktemp -d`
    directory outside the repo". That is an instruction, not a control —
    the exact weakness the header of Evan's global hook
    `~/.claude/hooks/require_worktree_isolation.py` names ("an instruction is
    not a control"; the shared-tree failure it guards fired 7 times, once as a
    false review result). The hook checks only that the `READ-ONLY:` line
    EXISTS; it does not stop a write.
    Readers do run code: #88's adversarial reviewer REPRODUCED a shell
    injection. Running the repo's own tests in place would write caches into
    the shared checkout (`__pycache__/`, `.pytest_cache/`, coverage files),
    and nothing stops it.
    **First measurement, 2026-10-22, NEGATIVE BUT BLIND:** coord@main took
    `git status --porcelain --ignored` of the integrity worktree at 14:05 and
    14:29 CDT, around PR #90's `/cepa:review` (findings file stamped 14:10:57).
    No new ignored or untracked path, and no `__pycache__`, `.pytest_cache`,
    `.coverage` or `*.pyc` anywhere in the worktree. The only change was the
    worker's own committed edit. **This cannot answer L15:** cepa's tests are
    shell scripts, so a review here has no pytest to run, and the shape L15
    asks about cannot appear (CLAUDE.md, "A clean corpus diff proves nothing
    about a shape the corpus does not hold"). It also cannot see a file
    written and removed between the two pictures. The real measurement needs
    a repo with Python tests, e.g. dpc-pro, as a hand-off.
    **Measure first:** run `/cepa:review` on a real PR and diff
    `git status --porcelain --ignored` of the shared checkout before and after.
    Only if it changes, decide: send code-running readers to isolation, or
    point their caches outside the repo (e.g. `PYTHONDONTWRITEBYTECODE=1`,
    `-p no:cacheprovider`), and say which in §11a.
    **Decided 2026-10-21: do NOT weaken the hook.** coord@main first proposed
    re-ordering its refusal message to suggest `READ-ONLY:` before isolation,
    to reduce leftover worktrees. Withdrawn after reading the hook: it would
    trade disk clutter (all leftovers were clean) for unprotected writes to
    the shared tree, in every repo. #88 already fixed leftovers at the source.

L16. **`/cepa:review` and `/cepa:plan-review` write findings files their own
    checker rejects.**
    status: completed
    **CLOSED 2026-10-22** — PR #90 (`2d02c5a`), v1.33.0, by `tab3@integrity`.
    The counting rule ships ONCE in the plugin as
    `plugins/cepa/scripts/check-findings-file.sh`; `scripts/check-residual-
    integrity.sh` sources it, and the file-todos spec points at it. review,
    plan-review, resolve-pr, lfg, triage, sweep and task run the spec's new
    `## Self-check` after their last findings-file write and before the commit.
    On a mismatch a writer may repair ONCE by rebuilding counters from the
    findings; it never deletes a finding or changes a status; a second mismatch
    is a failed self-check; no plugin copy found -> "unavailable", never a pass.
    The todos/ scan and shard checks stay repo-only.
    Verified by coord@main after merge, from a scratch repo outside cepa, with
    the LOADED 1.33.0 copy: an off-spec file exits 1 naming the problem, a
    correct file exits 0.
    Merged as-is, accepting the worker's decisions 1 (keep plan-review fixes
    4–7 and 9 of `todos/review-2026-10-22-134226.md`) and 3 (keep triage's added
    grants). Its decision 2 stays open: finding 28 — `Bash(bash:*)` may not
    cover the multi-line Self-check block, so an UNATTENDED run could stop at a
    permission prompt; measure before relying on it. 5 deferred findings in
    `memory/tasks.d/2026-10-22-fix-integrity-producer-self-check.md`.
    **Unblocks L13:** dpc-pro can clean its 6 new files once its sessions run
    1.33.0 (new sessions load it).

---

## How this list is used

When the user asks "where am I" or opens a new session, read this file first.
Report the open items by their original numbers with the closed ones struck
through. Recommend the next item by number.

The user's stated constraint: they lose track across many tabs, and want to be
reminded when it is time to start the next item.

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
   status: completed
   owner: none
   severity: P2
   **CLOSED 2026-10-22 without code — done by #90.** L4 wanted a doc-prescribed
   grep pattern tested against its fixture AND a corpus diff. #90 moved the
   file-todos counting grep into the shipped
   `plugins/cepa/scripts/check-findings-file.sh`, and
   `scripts/check-findings-file-controls.sh` runs it against
   `plugins/cepa/skills/file-todos/fixtures/status-spellings.md` in CI. #90 also
   ran the old-vs-new corpus diff by hand: 70 files, 0 changes.
   Measured by coord@main on origin/main, from a script file (fenced-block
   `grep -[Eco]` lines per .md under plugins/cepa): only 3 remain —
   `handoff.md:616-617`, an example comparing two version strings, and
   `review.md:495`, which reads one `model:` line. Neither counts rows, so a
   checker built as L4 describes would have 0 targets.
   Not built: a preventive rule ("a new counting grep in plugin docs must live
   in shipped code or name a fixture"). File a new item if one ever appears.

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
   status: completed
   owner: none
   **CLOSED 2026-10-22** — PR #91 (`14dd48a`), by `tab4@roles`.
   `scripts/check-anchor-counts.sh`, its own workflow `anchor-counts.yml`:
   leg 0 MISS when the scan finds no files or headings; leg 1 MISS on a
   `(N)` count in a heading; leg 2 MISS on an in-page link whose fragment
   matches no heading; leg 3 WARN only on a working link whose fragment
   carries a number. CLAUDE.md's "Nothing enforces this rule today" is now a
   pointer. Preventive: 0 count-bearing headings on main. Merged after the
   three checks (update -> `d4556a3`, all 3 workflows green). Repo tooling
   only, no version bump.
   **coord@main DECLINED the worker's decision 1** (write an "enclosing guard"
   exception into CLAUDE.md's "Adding a leg to ANY checker" paragraph). That
   exception — ignore a shared kill when another guard's kill set contains
   this one's — is the exact shape of the 2g incident the rule records: a
   later leg caught leg 1's only case, so removing leg 1 killed nothing.
   CLAUDE.md's own remedy applies instead: assert the exact finding set. The
   controls assert rc, MISS count and text, so a unique kill is reachable;
   a guard whose removal leaves the output byte-identical has no observable
   effect, and needs either a case only it decides or deletion.
   **Residual (P3):** `scripts/check-anchor-counts-controls.sh` implements
   that containment exception in its own uniqueness check (~line 293). Replace
   it with inner-only cases or remove the redundant guards. Decision 2 (README
   mention) declined as optional. 2 deferred findings in
   `memory/tasks.d/2026-10-22-feat-roles-anchor-count-checker.md`.

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
    status: completed
    **CLOSED 2026-10-27, PROVEN:** the first scheduled run after #89, run
    40327510023 (2026-10-26), passed and classified 98 of 98; slowest shard
    45 min of its 120-min limit (38%, under the 60% alarm). Issue #61 closed
    with that evidence. The record below is kept as written.
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
    status: completed
    **CLOSED 2026-10-22, in dpc-pro** (reported by dpc-pro's coord@main; not
    re-measured here). dpc-pro L33 (PR #258, `9ccfd55e`) fixed the 8 old files;
    dpc-pro L39 (PR #262, `ce647150`) fixed the 6 files written 2026-10-21,
    which now exit 0 under the shipped `check-findings-file.sh`. Whole-tree
    MISS 249 -> 240; the remaining 240 are dpc-pro's own older files.
    Its follow-up question became L17.
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
    status: completed
    **CLOSED 2026-10-30 as NOT OBSERVED** (operator's decision). Two
    measurements, both negative and both blind (below): cepa's tests are shell,
    and dpc-pro isolates its readers and forbids them to run tests. The risk
    stays possible only in a repo that does neither. Recorded for a future
    reader: dpc-pro's pytest runs in a container that bind-mounts the stack's
    checkout, so isolation alone does not stop a reader's cache writes there.
    Reopen if a repo with in-place readers and Python tests shows the shape.
    severity: P3
    owner: unassigned
    **SENT 2026-10-30 via Orca** (operator's choice) to dpc-pro's coord@main,
    terminal `term_fed6b6e2-e810-4d40-ab6c-d07b9a0befd2` (the one live terminal
    in dpc-pro's main-checkout workspace), message `msg_c6d6a90bcae4`, type
    `handoff`. Orca warned the mailbox is terminal-only: not durable if that
    terminal closes before it reads it. The request: around its NEXT ordinary
    /cepa:review, snapshot `git status --porcelain --ignored` before and after,
    list new `__pycache__`/`.pytest_cache`/`.coverage`/`*.pyc`, and report back
    to cepa's coord@main (`term_8e8ae1c2-08ac-4b2c-b06f-c41e0011ad3c`) or by
    paste. **Acknowledged 16:47 UTC** by dpc-pro's coord@main: it runs no
    reviews itself, so it forwarded the steps to `tab20@todos-verify`, whose
    next /cepa:review (its L77 PR, branch `feat/todos-verify/org-billing-pause`)
    runs in the linked worktree `.claude/worktrees/todos-verify` — the checkout
    a reader would write into. tab20 reports directly; expected in hours.
    **Second measurement, 2026-10-30, NEGATIVE BUT BLIND** (relayed from
    tab20@todos-verify, message `msg_3513cdee2484`; not re-measured here —
    that would mean running in dpc-pro): dpc-pro PR #291 at `69c36aa8`, cepa
    1.35.0, window 17:32:33-17:40:45 UTC. `git status --porcelain --ignored`
    before/after: no change; no new `__pycache__`/`.pytest_cache`/`.coverage`/
    `*.pyc`; 0 agent worktrees left. It cannot answer L15, for two reasons
    tab20 gave: (1) dpc-pro's CLAUDE.md requires `isolation: "worktree"` for
    review agents, and project instructions outrank the plugin, so no reader
    ran in the shared checkout; (2) every brief also said "do NOT run pytest,
    docker or manage.py", and no agent ran code. **New fact:** dpc-pro's
    pytest runs in a container that bind-mounts the stack's checkout, so a
    reader in ANY worktree that runs `docker compose exec backend pytest`
    writes caches into that mounted checkout — isolation alone would not stop
    it. Decision pending: close as not observed, or build a deliberate probe.
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

L17. **The self-check does not require the spec's field names.**
    status: completed
    **CLOSED 2026-10-27** — PR #92 (`696ddbb`), v1.34.0, by `tab4@integrity`
    then `tab5@integrity`. Every `### N` finding must carry the 8 required
    fields. The writer's self-check takes `--own`: a finding the run CREATED,
    or whose fields other than `status`/`resolved` it edited, MISSes when
    incomplete; any other finding WARNs and the run does not fail. The
    no-invention repairs (rename a stand-in, move a row up, copy a heading
    title into `title:`) do not make a finding own — the worker's addition,
    kept by coord@main, because otherwise a repair would expose a finding's
    other gaps and punish the repair. The repo checker stays strict.
    coord@main's first wording ("wrote or changed") was wrong: a status update
    is a change, so triage on old files still failed; corrected on the branch.
    Verified after merge from a scratch repo with the LOADED 1.34.0 copy: an
    incomplete finding with `--own all` exits 1 (MISS); with `--own none`
    exits 0 (WARN); with no `--own`, exits 1.
    Finding 19 accepted as a NAMED exception for one pass-through path, not a
    rule; finding 18 stays filed. dpc-pro's 41 files no longer block its
    triage or sweep, but its whole-tree check still reports them.
    The record below is kept as written.
    severity: P2
    owner: integrity (`tab4@integrity`). PR #92, head `6209447`, opened
    2026-10-22. **HELD by coord@main before merge**, on the worker's own
    recommendation: findings files in dpc-pro written before 2026-07-10 lack
    `confidence` and `action_class` (they became required that day), and a
    writer may never invent a value for an older finding — so after merge,
    every triage or sweep run touching one would report a failed self-check.
    A read-only dpc-pro probe (old vs new check, per file) measures that first;
    coord@main ran it here: 71 files, 1 change (`054748` ### 8, fixed on the
    branch), matching the worker. Then one follow-up on the branch: the
    old-file rule the measurement calls for, plus the worker's decision 2
    (a CLAUDE.md line: a sourced file never uses `printf … | grep -q`; under
    a caller's `pipefail`, SIGPIPE makes it a silent skip — shipped here and
    found only by review), which coord@main accepted.
    **dpc-pro measurement, 2026-10-22** (relayed; read-only probe, old check
    @ `3acefe4` vs new @ `6209447`): files=232, changed=41, ~543 new MISS,
    lost=0 (no regression). 21 files go 0 -> fail; 20 gain MISS lines.
    By kind: missing `title` 437, `action_class` 298, `file` 187, `category`
    167, `severity` 90, `confidence` 84, `agent` 51; stand-ins `class:` for
    `action_class:` 138, `anchor:` for `file:` 27, `summary:` for `title:` 27
    (the last two only in the two 2026-10-21 files); a field below a blank
    line 38 (two files). **The worker's hypothesis was wrong:** NO file before
    2026-07-10 lacks confidence and action_class; the 41 files date 07-15 to
    10-21. Renames and moved rows (230 lines) are repairable without inventing
    a value; titles are probably in the headings (shape seen in L13's probe:
    `### 1 [P2 applied] <title>`), so moving them invents nothing, but that is
    not proven for every file; the other missing fields cannot be repaired.
    **Consequence if merged strict:** triage and sweep change old files, so
    every run touching one of the 41 would fail its self-check in dpc-pro.
    **Also:** dpc-pro's `ce647150` (L39, #262) says its two 2026-10-21 files
    "pass cepa's checker" — true for the old check only; under #92 both fail
    on the stand-ins.
    Filed 2026-10-22 from dpc-pro's coord@main (relayed): two plan-review
    findings files there use row fields `class`, `anchor` and `summary` instead
    of the spec's `action_class`, `file` and `title`, and both PASS
    `check-findings-file.sh`.
    **Measured here 2026-10-22:** no cepa file prescribes those names. The
    persona return format (`plan-review/references/subagent-template.md`) is
    title, severity, section, finding_type, autofix, confidence,
    why_it_matters, evidence, suggested_fix; the plan-review skill's table
    (SKILL.md:140-147) maps them onto `action_class`, `file`, `lines`. "Anchor"
    appears only as the name of a confidence level. So the writing session
    invented the names, and nothing caught it: #90's check counts status and
    severity rows but never requires the spec's REQUIRED fields
    (`## Finding Fields`: status, severity, agent, category, confidence,
    action_class, file, title).
    **Answer given to dpc-pro:** emit the standard names; the spec does NOT
    get a second, plan-review row shape (repo convention: the file-todos spec
    is the single canonical spec — never invent variants).
    **Consequence today:** `/cepa:triage` decides auto-apply by
    `action_class`, so findings without it are not classified as intended.
    **Fix to plan:** make the shipped check require each finding's required
    fields, with the old-vs-new corpus diff over this repo's todos/ (and a
    dpc-pro hand-off diff) before it becomes a MISS — older files may lack
    fields legitimately (counter_convention, superseded formats).

L18. **Revisit the write-back-gap decision — its second instance happened.**
    status: completed
    **CLOSED 2026-10-30** — PR #93 (`c8bb309`), merged by coord@integrity after
    the three checks (update-branch head `cf94218`, 6/6 green), built by
    `tab6@integrity`. `scripts/check-writeback-gap.sh` + controls, gated in
    `writeback-gap.yml`: a PR body citing a `todos/*.md` file that holds
    `status: deferred` findings WARNs (annotation, no fail); an unreadable
    input (fetch failure, bad ref, unreadable file, unclosed fence) MISSes.
    Sources `check-findings-file.sh` for the status pattern. Repo tooling only:
    no version bump, no plugin hops.
    Controls: #17's body flags `### 1-4` at `86332d8^` and `### 2` only at
    `86332d8`. Replay (worker's, `bash scripts/check-writeback-gap.sh --replay`):
    89 bodies, 51 citations, 0 MISS, 32 WARN, 22 PRs flag — mostly a PR citing
    its own review file with by-design deferrals, so the signal is noisy.
    Decisions accepted: (1) keep file-level WARNs as built, judge signal after
    some weeks; marking "this PR's own review file" is the named refinement if
    noise hides a real case. (2) P3s 15/16 (API retry, concurrency group) stay
    filed in `todos/review-2026-10-27-190245.md`; 7 P3s deferred in total, also in
    `memory/tasks.d/2026-10-27-feat-integrity-writeback-gap-check.md`.
    Not done by the worker: `/cepa:plan-review` before build (plan is local).
    severity: P2
    owner: integrity (`tab6@integrity`, branch `feat/integrity/writeback-gap-check`)
    **DECIDED 2026-10-27 by the operator: build (b), at FILE level.** Evidence
    (coord@main): PR #17's body cites `todos/review-2026-07-12-115234.md` by
    path and says "4 policy decisions resolved by you", but never gives finding
    numbers — so a file-level match flags the #79 instance and a finding-level
    match misses it. Probe:
    `gh pr view 17 --json body --jq .body | grep -nE '115234|finding *#?[0-9]|P1'`.
    Cost: file-level reports legitimately-open findings too (#2 there stays
    deferred on purpose), so the check names them instead of asserting a gap;
    `main` is unprotected, so red reports and does not block. Controls the
    worker was briefed with: #17's body against `86332d8^` MUST flag; a body
    citing a file with 0 deferred findings must not; replay over all merged PRs
    before merge, probe beside every count. Repo tooling only, no manifest bump.
    Filed 2026-10-27. `memory/tasks.d/2026-09-25-main.md` (~lines 80-100)
    decided option (c) on 2026-09-25 — accept the gap where a decided or
    fixed finding keeps `status: deferred`, and reconcile by hand — and said
    a second instance means revisit, preferring (b): a CI check that fails
    when a merged PR body cites a finding still marked `deferred` (runs on
    every push; `main` is unprotected, so it reports without blocking).
    **The second instance:** PR #79 (`86332d8`). The four OB1 P1 findings
    showed as open for ~10 weeks. All four had been decided on 2026-07-12;
    three (#1, #3, #4) were therefore falsely open and were closed by #79.
    The fourth (#2) correctly stayed `deferred`: its decision requires an
    OpenRouter zero-retention verification that has no record.
    So (c)'s frequency argument no longer holds. Decide (b) vs (a) vs keep
    (c), then build if chosen.

L19. **OPTIONAL: dpc-pro's 41-file findings cleanup.**
    status: completed
    **CLOSED 2026-10-27 in dpc-pro** — its PR #283, merged into `dev` as
    `b9290a21` at 20:30 UTC (verified here by `gh pr view 283 -R <owner>/dpc-pro`).
    Reported by dpc-pro's coord@main (relayed; not re-measured here — that
    would mean running in dpc-pro's checkout): mechanical only, 204 renames,
    38 row moves, 294 heading titles copied into `title:`, 31 files.
    `^MISS` on todos/review-*.md with the 1.34.0 checker: 805 -> 627.
    Left (needs a value not in the file): category 167, file 160,
    action_class 160, title 127, severity 90, confidence 84, agent 51.
    Cross-check against the 2026-10-22 counts above: action_class 298-138=160
    and file 187-27=160 match; row moves 38 match. Two small gaps, unexplained
    and non-blocking: renames 204 vs 192 expected (138+27+27), and title 127 vs
    116 expected (437-294-27). Nothing further is owed in this repo.
    severity: P3
    owner: dpc-pro (hand-off only; nothing is owed in this repo)
    Filed 2026-10-27. After #92 (v1.34.0) these files no longer block dpc-pro's
    triage or sweep, but its whole-tree check still reports them. The
    paste-ready prompt for dpc-pro's coordinator, verbatim as coord@main wrote
    it on 2026-10-27 (not yet sent):

````markdown
From cepa's coord@main — an OPTIONAL cleanup item, now unblocked.

cepa PR #92 merged as 696ddbb (v1.34.0). Every `### N` finding must now carry
the 8 required fields (status, severity, agent, category, confidence,
action_class, file, title). A writer's self-check scopes that to the
findings its own run creates or edits, so your 41 older files no longer
fail triage or sweep. The whole-tree check still reports them.

Your read-only run on 2026-10-22 counted, across 41 of 232 files:
  stand-ins: `class:` for `action_class:` 138, `anchor:` for `file:` 27,
    `summary:` for `title:` 27 (the last two only in the two 2026-10-21 files)
  a field below a blank line: 38 (two files)
  missing: title 437, action_class 298, file 187, category 167,
    severity 90, confidence 84, agent 51

1. Mechanical, no value invented: rename the stand-ins, move rows up above
   the blank line, and copy a title that sits in the heading
   (`### 1 [P2 applied] <title>`) into a `title:` row.
2. Everything else needs a value that is not in the file. Do NOT invent it.
   Leave those findings as they are, or close them by a human decision.

Check before and after, from the plugin copy (new sessions load 1.34.0):

```bash
bash ~/.claude/plugins/cache/cepa/cepa/1.34.0/scripts/check-findings-file.sh todos/review-*.md 2>&1 | grep -c '^MISS'
```

Report the before and after counts to cepa's coord@main.
````

L20. **Decide whether to remove worktree `.claude/worktrees/agent-a457670e5009ffa76`.**
    status: completed
    **CLOSED 2026-10-27 — removed by coord@main** on the operator's choice.
    Re-measured just before: 0 status lines incl. ignored, HEAD `a7d7b55`, 2.8M;
    branch `worktree-agent-a457670e5009ffa76` at `0849cea`, 0 commits not on any
    remote (`git log --oneline <branch> --not --remotes | wc -l`). Ran
    `git worktree remove` then `git branch -D`. Lost: only the superseded
    `a7d7b55` draft described below.
    severity: P3
    owner: coord@main
    Filed 2026-10-27. Detached at `a7d7b55` ("fix(compound): mint the payload
    path per run — close residual 2j", 2026-10-03), an early draft of #81's
    2j fix; #81 merged as `17271ee`. Clean (0 status lines incl. ignored),
    2.8M. `a7d7b55` is NOT on origin, so #88's cleanup rule and coord@main's
    own rule both refuse an automatic removal. Measured 2026-10-22: the 11
    lines of `compound.md` that `a7d7b55` added and #81 lacks are all
    superseded on main — the plain `printf ... > "$PTR"` became
    `( set -C; printf ... > "$PTR" )`, and the final `rm -f` list became a
    `trap ... EXIT` with the same files; the shard lines it added are all in
    #81. Its branch `worktree-agent-a457670e5009ffa76` (at `0849cea`) has 0
    commits not on origin. Removing it loses only that superseded draft.
    Earlier the session said this was "filed"; it had been mentioned in L14's
    entry, and that line was lost when L14 was rewritten on close — this item
    is its first durable record.


L21. **Thin Orca adapter: when Orca is present, cepa routes hand-offs and
    dispatch through it.**
    status: completed
    severity: P2
    owner: roles (`tab5@roles`, then `tab6@roles`)
    **CLOSED 2026-10-30** — PR #94 (`0ce16a6`), v1.35.0. Dispatched through
    Orca itself (Run `run_bf28fea0ea31`), coord@main acting as coord@roles by
    the operator's instruction; both workers released after accepted
    settlements. `cepa:autonomy` §12 (§12a detection, §12b five rules, §12c
    relay clause), cited by handoff/task/lfg; `scripts/check-orca-detection.sh`
    (48/48) + controls (37/37, 89 s locally; 13m14s before the follow-up) in
    `residual-integrity.yml`. Operator decisions applied in the follow-up:
    (1) a hand-off is sent AND printed, first line
    `Sent to coord@main via Orca — do not paste.`; (2) a valid
    `ORCA_CLI_COMMAND` is probed, bounded 3 s + 0.5 s kill — 0.5 s was first
    chosen, but the real CLI takes 0.46-0.62 s under WSL (worker: 5/20 false
    absents; coord@main: 8 runs 0.475-0.621 s), so the operator raised it.
    First head's CI was CANCELLED (run 41072902545, 10-min job timeout in the
    controls step); fixed without raising the timeout — the tests swap only the
    two bound lines, and a BOUNDS leg pins the shipped values. Pre-merge: 6/6 CI
    green on `2def4e5`, model pins 0 MISS + 109/109 controls, fenced-block 0
    MISS + 31/31, anchor counts 0 MISS. Plugin hops run; freshness rc=0 at
    `0ce16a6`. Residual: L22.
    Filed 2026-10-30 from the operator's brief (kept verbatim in the worker
    prompt). Orca already spawns, makes worktrees and messages; cepa decides
    only when and how. Detection: `ORCA_CLI_COMMAND` set, or
    `<cli> status --json` returns `"ok": true`; resolve the CLI as Orca's
    orchestration skill does (never bare `orca` on Linux). Five rules: hand-offs
    travel by Orca with a paste fallback; a coord dispatches workers by Orca and
    picks placement by cepa's rules; every worker branches `<type>/<wt>/<desc>`
    first and ends with the Handoff block as its `worker_done` body; workers
    send decisions by Orca ask; a coord waits with Orca's check --wait. With
    Orca absent, cepa is unchanged. One owner location read by /cepa:handoff,
    /cepa:task and /cepa:lfg; syntax from `<cli> skills get orchestration`,
    never hard-coded flags; tests or a dry-run check for detection. PR, no
    merge.
    **Measured here 2026-10-30:** this machine runs Orca 1.4.244 under WSL;
    `ORCA_CLI_COMMAND=orca-ide` is set in coord@main's own session and
    `orca-ide status --json` returns `"ok": true`. Plugin at 1.34.0; autonomy
    ends at §11; `handoff.md` declares `allowed-tools` with no `orca-ide` grant.
    **coord@main's added constraints (in the prompt):** cite once (autonomy is
    the natural owner, as a new section — no new skill, so no count change);
    allowed-tools must cover every `orca-ide` verb; Orca messages are relayed
    content (autonomy §7 clause at the relay point); an Orca child worktree
    must still let the branch carry `/<wt>/` (global rule against tools that
    name the directory after a branch); manifests bump together.


L22. **§12a reads Orca absent on stock macOS (no `timeout` command).**
    status: deferred
    severity: P3
    owner: unassigned
    Filed 2026-10-30 from PR #94's follow-up review (finding 3 of
    `todos/review-2026-10-30-152000.md`). The probe needs `timeout`; stock macOS
    has none, so a live Orca terminal there reads absent and behaves as before
    (safe, but Orca routing is off). §12a states the limit. Fix candidates:
    `gtimeout`, or bound the probe in python3. Operator chose to defer it: this
    machine is WSL and no macOS session runs cepa today.


L23. **Orca adapter: name each session `<repo> · <role>@<wt>`.**
    status: completed
    severity: P3
    owner: roles (`tab7@roles`, dispatched via Orca 2026-10-30)
    **CLOSED 2026-10-30** — PR #96 (`e7eacfe`), v1.36.0. §12b rule 6: a
    session titles its own tab via `ORCA_TERMINAL_HANDLE` (verified equal to
    coord@main's real handle), a coordinator titles each worker's tab after
    `worker-start`; a lost handle renames nothing (fail-closed). Pre-merge: CI
    green on `46f4d1c`, orca checks 76/76 + controls 67/67, model pins and
    anchor counts 0 MISS, fenced-block 0 MISS. Two branch commits carried a
    forbidden `Co-Authored-By` trailer; squashed with an empty body, so `main`
    has none (0 lines in `e7eacfe`). Plugin hops run; freshness rc=0. 4 P3s
    deferred in `memory/tasks.d/2026-10-30-feat-roles-orca-session-titles.md`.
    Filed 2026-10-30 from the operator's instruction: "Name each session
    <repo> · <role>@<wt>." Scope set by coord@main: the Orca tab title only
    (`orca-ide terminal rename --terminal <handle> --title <text>`), set when
    §12a reads Orca present — by each session for its own tab, and by a
    coordinator for each worker it starts. Today a title is just
    `coord@main` (dpc-pro's coordinator tab), which cannot tell repos apart.
    The prompt's line-1 identity (`You are <session>@<wt>.`) does NOT change:
    the operator's global CLAUDE.md defines it and §10a parses it. A title is
    for humans only; §12b's never-address-by-title rule stands.


L24. **Orca adapter rule 7: how a turn ends under Orca.**
    status: completed
    severity: P2
    owner: roles (`tab8@roles`, dispatched via Orca 2026-10-30)
    **CLOSED 2026-10-30** — PR #98 (`8ea0a3a`), v1.37.0, merged on the
    operator's AskUserQuestion answer ("Merge now, follow up"). Pre-merge: CI
    4/4 green on `518cd80`, turn-endings checker 59/59 + controls 40/40, orca
    detection 76/76, model pins/anchor counts 0 MISS, 0 co-author trailers.
    Plugin hops run; freshness rc=0. 7 P3s in
    `memory/tasks.d/2026-10-30-feat-roles-orca-turn-endings.md`. Follow-ups:
    L25 (review/resolve-pr citations), L26 (plan §10 probe + rollout).
    Filed 2026-10-30. Plan approved by the operator (AskUserQuestion, "Approve
    as written"): `docs/plans/2026-10-30-session-endings-under-orca.md` on PR
    #97 (branch `docs/main/session-endings`, plan only, not merged). Build:
    cepa `autonomy` §12b rule 7 + the §6 pointer + rule 1 send-scope change +
    one-line citations in handoff/triage/plan-review/compound/compound-refresh/
    setup/sweep + a citation checker; plugin 1.37.0. NOT in this item: the
    global CLAUDE.md edits and the farmtender-laravel/contexthub edits (plan
    §8) — they follow only after the plan §10 probe test passes here.
    Operator first chose (2026-10-30) to leave `.env`/`.env.local` in
    `.worktreeinclude` in artist360, dpc-insider-www, dpc-pro-www,
    farmtender-laravel (all env files gitignored, untracked, 0 commits ever).
    **SUPERSEDED 2026-10-31 by the operator: no `.worktreeinclude` anywhere,
    and never an env or secret file in one — see L32.**


L25. **Cite §12b rule 7 in `review.md` and `resolve-pr.md`.**
    status: completed
    **CLOSED 2026-10-30** — PR #99 (`fc741b7`), v1.37.1, on the operator's
    AskUserQuestion answer. CI 4/4 green on `37f8e85`; turn-endings 65/65 +
    controls 44/44; 0 co-author trailers; hops run, freshness rc=0. Its 4 P3s
    (`todos/review-2026-10-30-181500.md`, left `pending`) go to L27: P3 1
    applied there, P3 2-4 deferred.
    severity: P3
    owner: roles (`tab9@roles`, dispatched via Orca 2026-10-30)
    Residual finding 2 of PR #98: rule 7 does not reach these two commands'
    interactive endings. Add the one-line citation and extend
    `scripts/check-orca-turn-endings.sh` to cover them.

L26. **Plan §10 probe test of rule 7, then rollout.**
    status: completed
    CLOSED 2026-10-31: the operator merged contexthub PR #98 (verified
    `gh pr view 98 -R evanemerson/contexthub` → MERGED 14:37:10Z,
    `8e4fe74`). Both hand-offs (farmtender-laravel #80, contexthub #98) landed.
    severity: P2
    owner: coord@main
    Throwaway Haiku sessions in `.claude/worktrees/integrity` on cepa 1.37.0,
    one per kind (Nobody / The operator / Delivery to a stub), read from
    `orca-ide worktree ps --agent-wait --json`; plus a question sent to an
    IDLE coordinator (PR #98 residual finding 6 — does it stall?). Only after
    it passes: the global CLAUDE.md edits and the farmtender-laravel /
    contexthub hand-offs in plan §8.
    **ROLLOUT 2026-10-31** (operator: "Apply and send"): global
    `~/.claude/CLAUDE.md` edited with the reviewed 5-part diff (byte-identical
    to the draft; backup `~/.claude/CLAUDE.md.bak-2026-10-31-rule7`). Hand-offs
    sent via Orca to each repo's main-checkout terminal: farmtender-laravel
    `msg_e9542ddacda0` (nudge skipped once on a `worktree ps` timeout, then
    sent), contexthub `msg_9f46605f4776` (nudged). Waiting on their PR numbers.
    farmtender-laravel: DONE — PR #80 merged as `79a4311` (verified via
    `gh api repos/Halyard-Digital/farmtender-laravel/pulls/80`); its reply
    `msg_1b28469a3410` (12:11 UTC) sat unread in coord@main's inbox (see L29,
    RC5). contexthub: replied `msg_71145c7f2edc` (12:19 UTC) — PR #98
    (evanemerson/contexthub, branch `chore/main/claude-md-rule7`, head
    `8bd2204`, OPEN, MERGEABLE; diff verified: line 947 exactly as sent). Its
    merge was blocked by the auto-mode permission check, so the OPERATOR
    merges it. L26 closes when #98 merges.
    **Probe run 2026-10-30 (17:07-17:10 CDT, cepa 1.37.0, Haiku 4.5,
    terminal surface; states from `worktree ps --agent-wait`):**
    - A (Nobody): PASS — `done`; first line `Needed from you: nothing`; no
      options.
    - B (The operator): PASS — `waiting`/`AskUserQuestion` → NEEDS YOU; first
      line `Needed from you: choose a codename…`; 2 options, pick first as
      "Heron (Recommended)"; no text options.
    - C (Delivery to a coordinator): PARTIAL — the message reached the stub's
      mailbox (`msg_4dc0f5a2675b`) and the ending listed `Sent: … (<id>)`, but
      (1) its first line was `Needed from you: the coordinator's answer…`
      (should be `nothing`: the decision is the coordinator's), and (2) it sent
      `--type status`, not a question.
    - Idle recipient (PR #98 finding 6): CONFIRMED STALL — the stub stayed
      `done` with the message unread; nothing woke it. Run coordinators get an
      Orca "You have 1 orchestration message" prompt; a plain session does not.
    **Operator decisions (AskUserQuestion, 2026-10-30):** wake path = "Send,
    then nudge"; rollout = "Fix, re-probe, then roll out" → L27, then re-probe
    C + an idle recipient, then the plan §8 edits.
    **Re-probe 2026-10-31 00:26-00:37 UTC (cepa 1.37.2, Haiku, terminal):**
    - C1 → idle stub: PASS — first line `nothing`, `--type question` sent,
      guarded nudge fired, and the idle stub WOKE and quoted the subject.
    - C2c → stub with an open AskUserQuestion: script PASS (`Orca nudge
      skipped: the target is waiting`; the question stayed unanswered), but
      the session wrote `Needed from you: nothing` instead of the operator
      line rule 1 requires after a skipped nudge (model miss).
    - Busy-target path: not exercised live (the busy runs hit the WSL error
      below); covered by stub tests only.
    - **New finding:** concurrent `orca-ide` calls from several WSL sessions
      fail intermittently with `<3>WSL … UtilAcceptVsock:273: accept4 failed
      110` (WSL→Windows interop timeout). It made §12a read absent (C2, C3b)
      and a send fail (C2b). cepa fell back safely each time (paste block, no
      nudge), but the `Needed from you` line was not first in those endings.
    Proposed follow-up: the nudge script prints the exact first line on a
    skip, and orca-ide calls retry once on the vsock error.


L27. **Rule 7 fixes from the L26 probe.**
    status: completed
    **CLOSED 2026-10-30** — PR #100 (`d9fd9b5`), v1.37.2, merged on the
    operator's "Fix busy-target, then merge" (tab10 → tab11 → tab12). Final
    gates: CI 4/4 green on `bbe4b32`; turn-endings 124/124 + 89/89; nudge
    44/44 + 48/48; orca detection 76/76; 0 co-author trailers. Hops run,
    freshness rc=0.
    severity: P2
    owner: roles (`tab10@roles`, then `tab11@roles`, via Orca 2026-10-30)
    PR #100 (head `f82e2d8`, v1.37.2) passed every pre-merge check, but review
    finding 3 showed the nudge's Enter can answer an open AskUserQuestion in
    the recipient (L26 probe B's screen: "Enter to select", Recommended
    highlighted). Operator chose (AskUserQuestion) "Fix on #100 first":
    tab11 adds a state-guarded nudge (only a `done` target), the reply-path
    nudge, and a checked `orca-nudge.sh` with a narrow grant.
    tab11 delivered (#100 head `2219332`, all gates green). Operator decisions
    (AskUserQuestion, 2026-10-30): busy target = "Wait briefly, then tell me"
    (re-check up to 2 min, then an operator line); half-typed draft = "Accept,
    state it"; merge = "Fix busy-target, then merge" → `tab12@roles` on #100.
    1. First line names the operator: `Needed from you: nothing` means the
       operator, so a decision for a coordinator is `nothing` (probe C wrote
       "the coordinator's answer").
    2. A coordinator decision is sent with the question message type, not
       `status` (probe C sent `status`).
    3. Wake path (operator: "Send, then nudge"): after `orchestration send` to a
       session that is not a Run coordinator, the sender types one line into the
       recipient's terminal with `terminal send --enter`: `You have 1
       orchestration message. Run <cli> orchestration check --peek --json`.
       Same shape Orca uses for Run coordinators. Grant the verb where a
       command declares allowed-tools; cover it in the checker.
    Then coord@main re-runs probe C and an idle-recipient probe (L26).


L28. **Rule 7 hardening from the L26 re-probe.**
    status: completed
    **CLOSED 2026-10-31** — PR #101 (`f8644f9`), v1.37.3, merged on the
    operator's explicit AskUserQuestion approval (the auto-mode classifier
    blocked a merge read from "Small fix, then roll out"). CI 4/4 green on
    `5986a70`; detection 87/87 + 78/78, turn-endings 127/127 + 92/92, nudge
    63/63 + 62/62. residual-integrity job 7m05s of a 10 min bound. Hops run,
    freshness rc=0. Orca is now 1.4.245; re-measured: an open AskUserQuestion
    still reads `waiting` (NEEDS YOU). 7 deferred findings in
    `memory/tasks.d/2026-10-31-fix-roles-rule7-hardening.md` (incl. the
    handle-not-name ending line and a possible duplicate after a send retry).
    severity: P2
    owner: roles (`tab13@roles`, dispatched via Orca 2026-10-31)
    Operator chose (AskUserQuestion) "Small fix, then roll out". (1)
    `orca-nudge.sh` prints the exact ending first line on a skip
    (`Needed from you: tell <session> to check its Orca inbox`) so the
    session copies it (C2c wrote `nothing`). (2) An `orca-ide` call retries
    once on the WSL interop error `UtilAcceptVsock … accept4 failed 110`
    (seen in §12a and `orchestration send` under concurrency). Then:
    operator approves the global CLAUDE.md diff; hand-offs to
    farmtender-laravel and contexthub (plan §8).


L29. **Orca-cepa delivery gaps seen in live sessions (operator report, 2026-10-31).**
    status: completed
    CLOSED 2026-11-01 with L30: RC1/RC5 by #102, RC2/RC3 by 1.37.2+ and rule
    7, RC4 by the reboot (see L30 item 3). The first live loop after the
    restart is the test; a gap it finds is a NEW item, not a reopen.
    severity: P1
    owner: coord@main (diagnosis); fix items below
    Operator report with 8 screenshots: artist360 coord@main sent
    coord@merch-builder-v2 L65; it started tab23; tab23 finished (PR #830,
    Handoff `done`) but never reported back, so coord@merch-builder-v2 and
    coord@main both stalled until the operator relayed it by hand. Same shape
    for tab17 (PR #828 → coord@feat-u3b-supply-missing-hexes: "paste it here
    or tell me it is done") and tab1@feat-streaming-tier-fee-columns (PR #835
    → its coord: "Tell me when tab1 ends"). Measured 2026-10-31 07:30 CDT via
    `orca-ide worktree ps --agent-wait` (read-only; nothing run in artist360).
    Root causes, each with its evidence and whether the current fix covers it:
    - RC1 (NOT covered). A worker started outside an Orca Run (`agent launch`
      or a pasted prompt) has no channel back: no Dispatch → no `worker_done`,
      and no coordinator handle → rule 7's delivery has no target. The worker
      prompts (tab23, tab17, tab1) say "End with the Handoff block… stop", with
      no send step. The global CLAUDE.md recommended `agent launch` for new
      workers until 2026-10-31. Fix → L30.
    - RC2 (covered for new senders, 1.37.2+). An idle recipient is never told
      a message arrived (L26). Guarded nudge, verified C1.
    - RC3 (covered for new sessions). Decisions written as text land in DONE
      (coord@merch-builder-v2 D1/D3, helm, dpc-insider-www, artist360-docs…).
      Rule 7 + the global CLAUDE.md edit.
    - RC4 (operational). Long-lived sessions keep the rules they started with:
      most coordinators are 7-22 h old (cepa ≤1.36, pre-Orca global rules), so
      none of RC2/RC3's fixes reach them until restarted. farmtender's
      coordinator replied without a nudge for this reason.
    - RC5 (NOT covered). Orca's own prompt to a Run coordinator is
      best-effort: coord@main got no prompt for `msg_1b28469a3410`, which
      arrived while it was busy (12:11 UTC). Fix → L30: a session that awaits
      replies peeks its inbox at the start and end of every turn.
    Relayed for the operator 2026-10-31 (AskUserQuestion "Send both via
    Orca"): coord@feat-u3b `msg_b01c84b854c5` (tab17 / PR #828, OPEN,
    MERGEABLE, cf2a7909, CI 2/2) and coord@feat-streaming `msg_24495d0d4d5a`
    (tab1 / PR #835, OPEN, MERGEABLE, 11765e1e, CI 2/2); both nudged.
    Result: coord@feat-u3b merged #828 (`e6974d33`, verified MERGED
    12:40:33Z) and reported `merged #828` to cepa's coord@main
    (`msg_b80d9f1e0555`), not to artist360's coord@main, because cepa sent
    the relay. Forwarded to artist360 coord@main (`term_e83d28c6…`) as
    `msg_a53a0e4dab21`, nudged; told coord@feat-streaming to report #835 to
    artist360 coord@main (`msg_29702fe9ea54`). Lesson: a relay must name the
    coordinator the result goes to.
    Also seen: tab23's input box holds an unsent draft ("1 and 3") — exactly
    the half-typed-draft risk accepted in L28; a nudge there would submit it.

L30. **Close RC1 and RC5: every worker reports back; awaiting sessions peek.**
    status: completed
    Item 3 DONE 2026-11-01: the operator rebooted the machine, which ended
    every session started before cepa 1.44.0, and ran `/cepa:handoff` in
    every repo first. Measured after the reboot by coord@main:
    `orca-ide terminal list` showed 1 terminal (this one); `worktree ps`
    showed every other agent row `done` with 0 live terminals. New sessions
    load cepa 1.44.0 (freshness rc=0), Claude Code 2.1.316, Orca 1.4.245.
    Items 1-2 DONE 2026-10-31 — PR #102 (`5b71315`), v1.38.0, merged on the
    operator's AskUserQuestion approval: worker-start default, `Report to:`
    line 2 for any other worker (the Handoff block is sent, never only
    printed), rule 8 inbox peek. Gates: turn-endings 177/177 + 141/141,
    detection 87/87, nudge 63/63, CI green; hops run, freshness rc=0. Global
    `~/.claude/CLAUDE.md` updated with #102's PR-body text, word for word
    (backup `~/.claude/CLAUDE.md.bak-2026-10-31-l30`). 5 P3s in
    `memory/tasks.d/2026-10-31-fix-roles-worker-report-channel.md`.
    Item 3 OPEN, owner: the OPERATOR (said 2026-10-31 "i will do this"). The
    operator restarts long-lived coordinators so they load
    cepa 1.38.0 and the new global rules. Measured 2026-10-31 via
    `orca-ide worktree ps --agent-wait` (pane keys): artist360 coord@main
    `c633d177` (after the #828 deploy), coord@merch-builder-v2 `cbaf5131`
    (after #830 merges), coord@feat-streaming `69b69991` (close after
    `merged #835`); contexthub coord@main `5c0a0d22` (after #98 merges);
    farmtender-laravel coord@main `285e566c` (now, or close);
    dpc-insider-www coord@main `297bb8ba` (next use); compound-engineering
    coord@main (this one, started on cepa 1.34.0) at its session end. Close:
    dpc-pro old coord `01982ec7` (a new coord@main `33f48d50` runs). How: in
    the tab, `/cepa:handoff` (operator-only) → end the session → new Claude
    tab in the same worktree with the emitted prompt.
    severity: P1
    owner: roles (`tab14@roles`, dispatched via Orca 2026-10-31 on the
    operator's AskUserQuestion "Yes, dispatch a worker"; cepa 1.38.0)
    1. A coordinator dispatches workers with `worker-start` on a Run (rule 2)
       by default, so `worker_done` and `ask` reach it. When it must use
       `agent launch` or a pasted prompt, line 2 of the worker prompt is
       `Report to: <coordinator's ORCA_TERMINAL_HANDLE>`; rule 7 treats that
       as an operator-given target, so the worker sends its Handoff block
       there and nudges.
    2. A session that has sent a message expecting a reply peeks its inbox
       (`check --peek`) at the start and end of every turn until the reply
       arrives, because Orca's prompt is best-effort.
    3. Restart long-lived coordinators after the current merges (RC4).


L31. **`residual-integrity` CI job is close to its 10-minute bound.**
    status: completed
    CLOSED 2026-10-31: PR #104 merged (`c3ee641`, operator's AskUserQuestion
    "Merge #104"). One job → three parallel jobs: check 1m45s, orca-detection
    3m19s, orca-nudge 3m31s (hosted run 41211871504), each bound 10 min. CI
    4/4 green on the updated head `01c548c`. 0 P1/P2; P3s in
    `todos/review-2026-10-31-145500.md`. `roles` parked at origin/main.
    severity: P2
    owner: roles (`tab15@roles`, dispatched 2026-10-31 via Orca `worker-start`
    on Run `run_bf28fea0ea31`, task `task_f63bbbbc6b01`, dispatch
    `ctx_813384df2daa`; operator's AskUserQuestion "L31 via tab15@roles")
    Measured 2026-10-31: the last 5 runs on `main` took 7m42s-8m58s
    (`gh run list --branch main --workflow residual-integrity.yml`); PR #102's
    run took 8m59s. Today's Orca checkers (detection, turn-endings, nudge and
    their controls) added most of it. Split the job (precedent: L11 split the
    mutation sweep into shards) before the next leg tips it over; a cancelled
    job reads as a red check on every PR.


L32. **Remove `.worktreeinclude` from every repo (operator rule, 2026-10-31).**
    status: completed
    CLOSED 2026-10-31. artist360 replied `msg_372b25c87bca` (Run
    `run_bf28fea0ea31`): PR #840 MERGED (`709d5b5`) into `dev`. Verified via
    `gh api repos/evanemerson/artist-360/contents/.worktreeinclude?ref=dev`
    → 404. Still present on artist360 `main` (its default branch) until that
    repo's normal `dev`→`main` ship; nothing more is owed from cepa.
    severity: P2
    owner: coord@main (this repo); each repo's coord@main (hand-offs)
    Operator: "i do not want to use .worktreeinclude and do not want to
    include .env/.env.local in .worktreeinclude." Rule added to the global
    `~/.claude/CLAUDE.md` (Orca section, "Never use `.worktreeinclude`";
    backup `~/.claude/CLAUDE.md.bak-2026-10-31-worktreeinclude`).
    Measured 2026-10-31 (main checkouts, `cat <repo>/.worktreeinclude`):
    - compound-engineering: `cepa.local.md` → DONE, PR #103 merged
      (`7cc5027`, CI 4/4 green).
    Hand-offs sent 2026-10-31 via Orca (operator: "Send all five"), each with
    `Report to: term_8e8ae1c2…` (cepa coord@main) — waiting on replies:
    - farmtender-laravel PR #79 — DONE on the branch: `.worktreeinclude`
      removed (`dd48f88`); verified 0 such files in the PR, none on the
      default branch. #79 stays OPEN for the operator's merge (its original
      instruction was do-not-merge). Reply `msg_32a05902e22e`.
    - artist360 (`.env`, `.env.local`; after its deploy work) —
      `msg_e48462d6c133`, NOT nudged: `worktree ps` hit the WSL vsock error
      twice → operator tells it to check its inbox.
    - dpc-insider-www — DONE: PR #458 merged (`4cf4cf6`), file deleted;
      verified absent on the default branch. Reply `msg_fa62fad215be`.
    - artist360-docs — DONE: PR #5 merged (`4510c05`), file deleted;
      verified absent. Reply `msg_47b9e080e72d`.
    - kcprimetime — DONE on the branch: PR #30 (head `995468b`) no longer
      adds it; it was never on the default branch (verified 404). #30 stays
      OPEN for the operator's merge. Reply `msg_814ed9df7473`.
    Remaining: none (artist360 closed above).
    - Already gone from main checkouts: ci-ops-self-hosted, hillberry-app,
      youtube, dpc-pro-www (their sessions were told to remove it).
    No env file is or ever was in git in any of these (L24 measurement).


L33. **A send that stores nothing is reported "sent", and the nudge still fires.**
    status: completed
    CLOSED 2026-10-31 — PR #105 merged `cb608d4` (v1.39.0) on the
    operator's AskUserQuestion "Merge when green": head check 366704f =
    Handoff `Head:`, branch already contained main, CI 9/9 green; `roles`
    parked at cb608d4, branch deleted; plugin hops run, 1.38.0 → 1.39.0,
    freshness rc=0. `plugins/cepa/scripts/orca-send.sh` counts a send only
    on `"ok": true` + `result.message.id` (`msg_…`) + an inbox re-read, else
    prints `Orca send failed: no message stored`, exits 5, no nudge.
    Measured root cause (worker's probes): Orca refuses `worker_done`,
    `escalation` and `ask` from a sender with no Dispatch (exit 1,
    `"ok": false`) while the refusal still carries a top-level `"id"`; a
    ~32 KB command line fails on WSL with empty stdout. The D6 `question`
    loss is unproven. Residuals (2 P2: `orchestration reply` and dispatched
    `worker_done` not yet mechanized; 7 P3s) in
    `memory/tasks.d/2026-10-31-fix-roles-orca-send-verify.md`. Global
    `~/.claude/CLAUDE.md` "A session that is already running" bullet now
    routes sends through `orca-send.sh` (operator approved via
    AskUserQuestion; backup `~/.claude/CLAUDE.md.bak-2026-10-31-l33`).
    severity: P1
    owner: roles (`tab16@roles`, dispatched via Orca 2026-10-31 on the
      operator's "dispatch a worker for it now": `worker-start` on Run
      `run_bf28fea0ea31`, task `task_274fcd5c69b6`, dispatch
      `ctx_a6fe62d18144`, terminal `term_00c2e1ba…`, claude-opus-5-5)
    Source: artist360 tab24@merch-builder-v2 (L66), message
    `msg_6d1566506a61`, 2026-10-31 17:33Z, relaying the operator's request:
    "put it in the scripts orca nudge SH file in cepa ... have CEPA do deep
    research on all repos and work so it can get to the root of the problem
    and plan the best solution so that messages are never missed."
    Relayed claims (UNVERIFIED here; the worker's own report): 4 sends to a
    legacy `term_` handle (run_unbound) — 2 stored, 2 (`--type question`,
    `--type worker_done`) left no inbox row. The worker counted them sent by
    grepping `"id"`, which matches the response envelope id, not
    `result.message.id` (`msg_…`). `orca-nudge.sh` printed `Orca nudge sent`
    after the empty send, so the coordinator woke to nothing new and told the
    operator no Handoff block had arrived. This is RC6 of L29's class: a
    worker reports back, but the report is never stored.
    1. `orca-nudge.sh` (or a sibling `orca-send.sh` it requires): run the
       send, require `result.message.id` = `msg_…`, re-read the recipient's
       inbox for that id, and print `Orca send failed: no message stored`
       with NO nudge when either check fails. Gate it in
       `check-orca-nudge.sh` + controls.
    2. Root cause: why did those two sends store nothing? Hypotheses from the
       relay: `worker_done`/`question` refused for a run_unbound legacy
       recipient; a WSL `UtilAcceptVsock` error swallowed by a pipe; a
       rejection in `result.warnings`/`ok` never read. Evidence: the
       artist360 memory note `feedback_orca_send_verify_message_id.md`
       (~/.claude/projects, read-only), L26/L29, `orchestration inbox` rows
       (`delivered_at` null on every row the worker saw). Other repos are
       read-only: research through Orca's API and ~/.claude, never their
       checkouts.
    3. §12b rule 1's "a send counts only when it prints a message id" names
       the field: `result.message.id`.

L34. **Nobody but the sender sees `Orca send failed`; a hung session is invisible.**
    status: completed
    CLOSED 2026-10-31 — PR #109 merged `e5af78e` (v1.42.0). tab20@roles
    resolved the manifest-only conflict with #108 (kept 1.42.0); head e0490d5
    = Handoff `Head:`, CI 9/9 green; main had gained only this punch-list
    file since the PR's base, so no second update. `roles` parked, branch
    deleted, tabs closed (absent from `terminal list`); hops run 1.41.1 →
    1.42.0, freshness rc=0. Global `~/.claude/CLAUDE.md` gained the "A
    coordinator runs the health check beside each peek" bullet (backup
    `~/.claude/CLAUDE.md.bak-2026-10-31-l34`). First live run from
    coord@main: `ORCA health: ok — Run run_bf28fea0ea31 checked (inbox
    window full: questions older than 200 rows not read)`. Residuals: 12
    P3-level items in
    `memory/tasks.d/2026-10-31-feat-roles-orca-failure-alerts.md`; the idle
    case is L40.
    severity: P1
    owner: roles (`tab19@roles`, dispatched via Orca 2026-10-31 on the
      operator's AskUserQuestion "L34 + L39 now": task `task_11bd7e7a46fd`,
      dispatch `ctx_05945c512f52`)
    Operator, 2026-10-31: "when [orca-send.sh] prints Orca send failed: no
    message stored what reads that? how do i know a session is hung? i need
    to know to check it so i can fix it."
    Today exit 5 lands only in the sending agent's own Bash output. If that
    agent then ends its turn (or misreads it), nothing tells the operator or
    the recipient. Same gap for a worker that stops sending heartbeats or a
    coordinator awaiting a reply that never comes.
    1. Decide the alert surface: Orca escalation to the Run coordinator, an
       Orca notification / NEEDS YOU entry, a durable failure log the
       coordinator's per-turn peek reads, or several.
    2. Define "hung": missed heartbeats past N minutes, a dispatch with no
       `worker_done` after its timeout, an awaited reply older than N.
       Measure what Orca already exposes (`worktree ps --agent-wait`,
       dispatch state, heartbeat rows) before building anything.
    3. Make `orca-send.sh` exit 5 trigger that surface, and gate it.

    2026-10-31 progress: tab19@roles opened PR #109 (v1.42.0, head dacbfe8,
    CI green): `orca-send.sh` exit 4/5 writes an alert file; new
    `orca-health.sh`, run by a coordinator beside each rule 8 peek, raises
    `ORCA alert:` lines (failed sends; exited/waiting workers; stale = no
    heartbeat 30 min; long = 180 min; unanswered questions; unreadable Orca
    state). Measured: Orca's liveness never reads heartbeats. Operator chose
    "Merge + CLAUDE.md + L40". After #108 merged, #109 conflicted on the
    manifest version lines only; follow-up `tab20@roles` (task
    `task_4fb2f25f9e3e`) resolves it.
L35. **Root-cause hardening: can this class of silent loss happen anywhere else?**
    status: completed
    CLOSED 2026-10-31 — PR #106 merged `c51064f` (v1.41.0). tab18@roles
    (same branch) fixed the CI timeout: 99 mutants each ran all 154 cases
    and the stub started python3 per call; now each mutant runs only the
    half that can see it (a new control proves the halves partition the
    cases) and the stub is bash — controls 5m28s → 1m33s, job >10m → 2m38s.
    Merged `main` (#107) and re-bumped both manifests to 1.41.0. Head check
    0644bc4 = Handoff `Head:`, branch contained main, CI 9/9 green; `roles`
    parked at c51064f, branch deleted, tabs closed (absent from
    `terminal list`); hops run 1.40.0 → 1.41.0, freshness rc=0. Global
    `~/.claude/CLAUDE.md`: worker Handoff sends through `orca-send.sh …
    worker_done` / `orca-send.sh`, plus "a closed terminal is proven by its
    absence from `terminal list`" (backup
    `~/.claude/CLAUDE.md.bak-2026-10-31-l35`). Residuals (#19/#21 → L38, a
    worker-start proof P2, 10 review P3s) in
    `memory/tasks.d/2026-10-31-fix-roles-orca-loss-audit.md`. L34 input is
    in #106's PR body. Seen once: `check-anchor-counts-controls.sh:222`
    `printf | grep -q` broken pipe (SIGPIPE flake class) → L39.
    severity: P1
    owner: roles (`tab17@roles`, dispatched via Orca 2026-10-31 on the
      operator's AskUserQuestion "L35 + L36 now": Run `run_bf28fea0ea31`,
      task `task_a696894b9fb4`, dispatch `ctx_b1afb520c506`, claude-opus-5-5)
    Operator, 2026-10-31: "is there anything else we need to research or do
    to ensure the root cause doesn't cause this again or cause another type
    of error like this?"
    L33 found two loss modes: an Orca refusal that still carries a top-level
    `"id"`, and a ~32 KB WSL command line that fails with empty stdout. Audit
    every place cepa (and the global CLAUDE.md) reads an `orca-ide` result:
    dispatch (`worker-start`), `reply`, `ask`, `worker_done`, `check --ack`,
    `terminal close`, `agent launch`. For each: what proves success, what a
    refusal looks like, and whether a probe-style empty stdout reads as
    success. Includes L33's 2 P2 residuals (`orchestration reply` and
    dispatched `worker_done` not mechanized) and the unproven D6 `question`
    loss. Output: a table of every path with its proof, plus fixes or filed
    residuals.
    2026-10-31 progress: tab17@roles opened PR #106 (v1.40.0, head
    945247f, Handoff `done`); operator approved "Merge + L38 + CLAUDE.md".
    After `gh pr update-branch 106` (head 40036f1) the `orca-nudge` job hit
    its 10-minute bound inside `check-orca-nudge-controls.sh` (run
    41234402058; suite 154/154 passed first). Follow-up dispatched to
    `tab18@roles` on the same branch: task `task_5626f99fa50c`, dispatch
    `ctx_6e87ff5d779c`. #106 merges when CI is green on tab18's head.

L36. **Triage L33's open residuals and recommend fixes.**
    status: completed
    CLOSED 2026-10-31 — tab1@integrity ran `/cepa:triage` (batch): all 7
    deferred findings are `action_class: judgment`, so none auto-applied; no
    PR (branch created with 0 commits, deleted; worktree parked at f97f6f0 —
    verified). Operator accepted every recommendation (AskUserQuestion
    "Accept all"):
    - #19, #20, #21, #24 → folded into L35; sent to tab17@roles as
      `msg_67bd4cb9c080` (via `orca-send.sh`, stored in dispatch
      `ctx_b1afb520c506`'s mailbox).
    - #22 (send-branch gate cases) → after L35 merges, on the final
      `orca-send.sh`. Owner: whoever closes L35 dispatches it.
    - #18 (byte cap vs WSL escaping) → won't fix: it fails loudly (exit 5,
      `Orca send failed`), no silent loss.
    - #23 (raw `orchestration send` grant) → won't fix until L35's checked
      `worker_done` wrapper exists; reopen then.
    #18 and #23 stay `status: deferred` in `todos/review-2026-10-31-184500.md`
    with this entry as the decision record (a human-triage `skipped` would
    remove them from the file; the evidence is worth keeping).
    severity: P2
    owner: integrity (`tab1@integrity`, dispatched via Orca 2026-10-31 on the
      same answer: task `task_cae146baf33d`, dispatch `ctx_6e30ef942095`;
      P3s only, the 2 P2s go to L35)
    Operator, 2026-10-31: "we need to run a /cepa:triage on the work still
    open. make recommendations on what to fix."
    Scope: `todos/review-2026-10-31-184500.md` (7 findings `status:
    deferred`, #18-#24, measured `grep -c 'status: deferred'` → 7) and the
    sections of `memory/tasks.d/2026-10-31-fix-roles-orca-send-verify.md`.
    Run `/cepa:triage`, apply safe verified fixes, and report a
    recommendation for each remaining item. Overlaps L35 on the 2 P2s:
    whichever runs first owns them.

L37. **Session names: rule 6 does not stick, and the naming scheme itself is in question.**
    status: completed
    CLOSED 2026-10-31 — PR #107 merged `cd40fdb` (v1.40.0) on the operator's
    AskUserQuestion "Merge #107 first": head check 6ace5bb = Handoff `Head:`,
    update-branch → 5df993d, CI 9/9 green; `integrity` parked at cd40fdb,
    branch deleted, tab closed; plugin hops run 1.39.0 → 1.40.0, freshness
    rc=0. Measured (tab2's probes + operator's eyes): the tab strip shows
    `terminal rename` (rule 6 always worked); the Agent Dashboard card shows
    Claude Code's session name/topic; `terminal show`/`list` report the
    program's OSC title, which is why the rename looked lost;
    `worker-start --display-name` names a new worktree only. Scheme: tab =
    `<repo> · <role>@<wt>`, card = Claude's topic (never `/rename` or
    `--name`), coordinators name their own tab on turn 1, keep `tabN`.
    Global `~/.claude/CLAUDE.md` "Your name" gained #107's text (backup
    `~/.claude/CLAUDE.md.bak-2026-10-31-l37`). 2 P3s in
    `memory/tasks.d/2026-10-31-fix-integrity-session-names.md`.
    Version clash: #106 (L35) also claimed 1.40.0; tab18@roles told to
    re-bump it to 1.41.0 (`msg_3f6c177179ca`).
    severity: P1
    owner: integrity (`tab2@integrity`, task `task_6c1cc3b554b2`, dispatch
      `ctx_356b8089190f`; dispatched via Orca 2026-10-31 on the
      operator's AskUserQuestion "file and dispatch")
    Measured 2026-10-31 by coord@main: `orca-ide terminal rename --terminal
    $ORCA_TERMINAL_HANDLE --title "compound-engineering · coord@main"`
    returned `"ok": true`, but `terminal show` still reported the title
    Claude Code set itself ("Coord@main L31 punch-list handoff").
    `worker-start --display-name "tab16@roles L33 send verify"` did not show
    either: `terminal list` showed "Orca send loss audit L35"-style Claude
    titles. Coordinators (this one included) also skipped rule 6's rename.
    Operator, 2026-10-31: "research the best names for these. with orca,
    maybe claude code's own name is better so i can see what's going on. i
    don't have to do the old copy/paste orchestration with orca, so this is
    an adjustment."
    1. Measure which name each Orca surface shows (tab strip, Agent
       Dashboard card, `terminal list` title, worktree sidebar) and which
       setting drives each (`terminal rename`, `worker-start
       --display-name`, Claude Code's own session title / `/rename`, OSC
       title escapes).
    2. Recommend a scheme. The operator must be able to tell at a glance:
       repo, worktree, role (coordinator or worker), and what it is doing.
       Weigh: Claude's own topic title; `<repo> · <role>@<wt>`; a mix (e.g.
       role@wt in one surface, topic in another); and whether `tabN`
       numbering still earns its keep now that prompts are not pasted.
    3. Implement the chosen scheme in rule 6 (and the global
       `~/.claude/CLAUDE.md` naming text, as a proposed diff in the PR body —
       the operator's file), with a gate if one fits.

L38. **Send block: move its 4 arguments onto stdin, and name the session in the ending line.**
    status: completed
    CLOSED 2026-10-31 — PR #110 merged `512a1b3` (v1.43.0) on the operator's
    AskUserQuestion "Merge, file 2 follow-ups". `orca-send.sh` takes no
    arguments: cli/target/type/nudge (or outcome/task) are field lines on
    the quoted heredoc, plus an optional `session:` named in every ending
    line (#19, #21); gate cases + mutants for the send branches (#22). Head
    7c92e58 = Handoff `Head:`, CI 9/9 green, main had gained only this file
    since the PR's base. `roles` parked, branch deleted, tab closed (absent
    from `terminal list`); hops 1.42.0 → 1.43.0, freshness rc=0. Global
    `~/.claude/CLAUDE.md` line 97 now names the `orca-send.sh` block
    (`type: worker_done`) (backup `~/.claude/CLAUDE.md.bak-2026-10-31-l38`).
    BREAKING for live sessions: a session that loaded the old rule 1 block
    has its sends refused (exit 4, loud, alert) until it restarts — another
    reason for L30 item 3. 4 deferred review findings in the branch's
    residual shard; two became L41 and L42.
    severity: P3
    owner: roles (`tab21@roles`, dispatched via Orca 2026-10-31 on the
      operator's AskUserQuestion "L38 on a new Run": NEW Run
      `run_5682a0ed1455` (the old Run `run_bf28fea0ea31` passed orca-health's
      200-row inbox window), task `task_749799c20601`, dispatch
      `ctx_930f0be28047`)
    L36 findings #19 and #21 (`todos/review-2026-10-31-184500.md`), split
    out of L35 by tab17@roles because they change the interface of the send
    block every session runs; operator chose "new item" (AskUserQuestion
    "Merge + L38 + CLAUDE.md", 2026-10-31).
    - #19: four model-filled values (cli, target, type, nudge) sit in double
      quotes on the block's command line, against the repo rule "a value
      filled from agent output never goes inside a quoted shell string".
    - #21: `orca-send.sh`'s ending line names a terminal handle, not a
      session. Add an optional session-name argument.
    Then #22 (send-branch gate cases, L36) on the final interface.

L39. **`check-anchor-counts-controls.sh:222` uses `printf | grep -q` (SIGPIPE flake).**
    status: completed
    CLOSED 2026-10-31 — PR #108 merged `8d71f58` (v1.41.1) on the operator's
    AskUserQuestion "Merge when green": head 787e6b1 = Handoff `Head:`,
    update-branch → c736524, CI green; `integrity` parked, branch deleted,
    tab closed. 47 `printf … | grep -q|-m` sites → here-strings in 11 files
    (probe and per-line safety in the PR body; repro under pipefail with
    300 KB input: pipe 50/50 false negatives, here-string 0/50). 3 P3s left
    filed in `memory/tasks.d/2026-10-31-fix-integrity-sigpipe-grep.md`
    (operator accepted the worker's "leave as filed").
    severity: P3
    owner: integrity (`tab3@integrity`, same answer: task
      `task_a5b0bdadb920`, dispatch `ctx_ed2467ee38dd`)
    Seen once on PR #106 commit 272e330 (anchor-counts job failed with a
    broken pipe at line 222; passed on 65088f5 and 0644bc4; #106 did not
    touch the file). The repo's CLAUDE.md names this class: under
    `pipefail`, `grep -q` exits on its first match and `printf` takes
    SIGPIPE. Fix: a here-string (`grep -q … <<<"$x"`), then sweep `scripts/`
    for other `printf … | grep -q` sites (state the probe command).

L40. **Run the health check while every coordinator is idle (Orca automation).**
    status: deferred
    DEFERRED 2026-11-01 by the operator in tab24@roles ("ignore it for now.
    defer it."). PR #114 merged `0a4adc7`: design, reasons, measured Orca
    automation facts and the revisit trigger are in
    `memory/tasks.d/2026-11-01-design-roles-orca-watcher.md`. roles parked,
    branch deleted, tab24 closed (absent from `terminal list`).
    severity: P2
    owner: roles (`tab24@roles`, design only: brainstorm with the operator in
      its tab, operator's request 2026-11-01; task `task_22ff60b22cce`,
      dispatch `ctx_1d6b60999200`, branch `docs/roles/l40-watcher-design`).
      No automation is created until the operator approves a build.
    From L34 (PR #109, residual P2; operator chose to file it, 2026-10-31).
    `orca-health.sh` runs only when a coordinator takes a turn (beside its
    rule 8 peek). When every coordinator is idle, a failed send or a hung
    worker raises nothing. Proposal: an Orca automation runs the check on a
    schedule and raises the alert where the operator sees it. Needs a
    `--precheck` measurement first, and the operator's approval before any
    automation is created.

    Seen 2026-10-31 21:07-21:09 CDT (input for L40's design): the retired
    coord@main's `relay.py` (scratchpad of session c1f435ce, PID 1782286,
    started 10:14 CDT on the operator's instruction) outlived its exited tab
    and began draining and acking coord@main's NEW Run inbox, then re-sending
    each message to coord@main as "Fwd (old coord@main)". It looped on its own
    forwards (3 levels). Only heartbeats were affected (relay.log: 3 SENT, all
    `alive`). Stopped with `kill` on the operator's AskUserQuestion "Stop it
    now". Lesson: a background poller started by a session must stop when
    that session's tab exits, and must never consume another session's
    mailbox; any L40 automation needs both guards.
    Also measured: orca-health's "inbox window full" warning is global, not
    per Run (`orchestration inbox` lists the newest 200 rows across all
    recipients), so a fresh Run does not clear it.
L41. **A body line that is exactly `CEPA_BODY` ends the send heredoc early.**
    status: completed
    CLOSED 2026-11-01 — PR #112 merged `447409a` (v1.44.0) after #111, on
    the operator's "Merge after #111". tab5@integrity merged main: the FILE
    mutants joined SEND_MUTANTS; the 3 BLOCK mutants became a fourth part
    ("skill"), one per shard. Head 74ec68e = Handoff `Head:`, branch
    contained main, CI 11/11 green (hosted orca-nudge 3m53s / 3m04s /
    3m36s). `integrity` parked, branch deleted, tabs closed (absent from
    `terminal list`); hops 1.43.0 → 1.44.0, freshness rc=0. BREAKING for
    live sessions again: a 1.43.0-style block (message in the heredoc) is
    refused with exit 4 + alert until the session restarts (L30 item 3).
    4 P3s filed in
    `memory/tasks.d/2026-10-31-fix-integrity-send-heredoc-delimiter.md`.
    severity: P2
    owner: integrity (`tab4@integrity`, dispatched via Orca 2026-10-31 on the
      operator's AskUserQuestion "L42 + L41 now": Run `run_5682a0ed1455`,
      task `task_8c98da002128`, dispatch `ctx_906a7a441d05`; merges after L42)
    PR #110 review finding #3 (deferred; operator chose a follow-up item,
    2026-10-31). The send block is a quoted heredoc ending at `CEPA_BODY`.
    A message line that is exactly `CEPA_BODY` closes it, and the lines
    after it run as shell commands. Rule 1 tells the session to indent such
    a line, but nothing enforces it. Options from the worker: a per-send
    random delimiter, or a `file:` field that reads the body from a file.
    Changes the block again: ship it with a restart note like #110's.

    2026-11-01 progress: tab4@integrity opened PR #112 (v1.44.0, head
    c8df2c6): the message moves to a file the session writes with Write;
    the heredoc (`CEPA_FIELDS`) holds field lines only; `orca-send.sh`
    reads and removes the file; a 1.43.0-style block is refused (exit 4 +
    alert). Operator chose "Merge after #111" (one restart for both); 4 P3s
    stay filed in `memory/tasks.d/2026-10-31-fix-integrity-send-heredoc-delimiter.md`.
    After #111 merged, #112 conflicted in `scripts/check-orca-nudge-controls.sh`
    only; follow-up `tab5@integrity` (task `task_f248faa5f88c`) merges main
    and places the new mutants into the shards.
L42. **Shard `check-orca-nudge-controls.sh` before the next mutant batch.**
    status: completed
    CLOSED 2026-11-01 — PR #111 merged `16dcd7c` (operator's "Merge after
    #111"). `check-orca-nudge-controls.sh --shard I/N`; one `orca-nudge` job
    → three parallel jobs. Hosted: 7m12s-7m58s (72-80% of the 10-min bound)
    → 3m01s / 2m39s / 2m41s on ee22cbb; all 170 mutants keep exact MISS
    sets; new controls fail if a shard job is dropped, merged or disabled.
    Head ee22cbb = Handoff `Head:`, CI 11/11 green; main had gained only
    this file since the base. `roles` parked, branch deleted, tab closed
    (absent from `terminal list`). CI-only change: no plugin bump. 2 P3s
    filed in `memory/tasks.d/2026-10-31-ci-roles-shard-nudge-controls.md`.
    severity: P2
    owner: roles (`tab22@roles`, same answer: task `task_2a01e7309411`,
      dispatch `ctx_cbc5fb1545b3`)
    After #110 the hosted `orca-nudge` job takes 7m24s of its 10-minute
    bound (main was 4-5m). #106 already split each mutant to the half of the
    check that can see it; the next step is two jobs (the L31 pattern), each
    with headroom. Measure per-part times first and state them.

L43. **Orca chat UI shows an old message below new ones, so live output moves up.**
    status: pending
    severity: P2
    owner: unassigned — an Orca app defect, not cepa code. The fix goes to
      Orca's maintainers as a hand-off; this repo only records it.
    Operator report, 2026-11-01 ~06:50 CST, with two screenshots
    (`Screenshot 2026-11-01 065042.png` and `065113.png` in the operator's
    Windows Pictures/Screenshots). "This has happened several times."
    Seen: the same coord@main session in two views. The terminal (Claude Code
    TUI) view is in order: the session ends with the pasted handoff, then
    `Baked for 1m 34s · done 6:05 AM`. The chat UI view shows that handoff,
    then BELOW it a user message from the PREVIOUS coord@main session (the
    2026-10-31 L34 question, "when script … prints Orca send failed …"), then
    `Worked for 1m 33s`. So an older message renders after a newer one, and
    the live turn is pushed up off the bottom of the chat.
    Not measured: how the chat UI builds its message list. Unverified
    guess: it merges two sessions' transcripts for one tab, or orders by
    something other than time. Next step: reproduce on a probe tab (resume
    or replace a session in one tab, then compare the two views), then hand
    the repro to Orca's maintainers.
    Also seen in the same screenshots (record only): the sidebar still lists
    the retired coord@main tab ("Needed from you: close this tab…"), and the
    worktree rows still show deleted branch names
    (`fix/integrity/sigpipe-grep`, `refactor/roles/send-block-stdin`) for
    worktrees that are parked detached.
    Also seen 2026-11-01 (record only): before the reboot the Agent
    Dashboard showed "0 total" while `worktree ps` listed 13 Claude agents.
    After the reboot `worktree ps` still lists 11 agent rows `done` with 0
    live terminals (ghost rows from ended sessions).

L45. **A restarted coordinator does not re-bind its Run, so Orca prompts a dead terminal.**
    status: completed
    CLOSED 2026-11-01 — PR #113 merged `83cc1f9` (1.45.0), on the operator's
    AskUserQuestion "Merge #113". `orca-rebind.sh` + §12b rule 2 first-turn
    re-bind; rule 8 `unbound` alert; `/cepa:handoff` emits `Orca Run:`. Head
    7d48764 = Handoff `Head:`, CI 10/10 green; main had gained only this file
    since the base. `roles` parked, branch deleted, tab23 closed; both hops
    run, freshness rc=0 (loaded copy v1.45.0 contains 83cc1f9). Not yet run
    against a live Run (Orca has no Run-close verb, so no probe Run): the
    next coordinator restart is its first live test. 11 deferred findings
    (P2 10-12: rule 2 block has no gate, re-bind race, no ownership check
    for a `run:`-only Run) in
    `memory/tasks.d/2026-11-01-fix-roles-run-rebind-on-restart.md`.
    severity: P1
    owner: roles (`tab23@roles`, dispatched via Orca 2026-11-01 on the
      operator's AskUserQuestion "Fix L45 first": task `task_37b4876306f2`,
      dispatch `ctx_c7311cef9512`, branch `fix/roles/run-rebind-on-restart`).
      Other repos' sessions wait until this merges and both plugin hops run.
    Measured 2026-11-01 by coord@main after the reboot: `run-current` showed
    `run_5682a0ed1455` with `coordinator_handle` = the dead pre-reboot
    terminal `term_07815dfe…`. `orchestration run-use --id
    run_5682a0ed1455` moved it to the new terminal `term_cccc2ae8…`
    (`consumer_generation` 2 → 3). Until then, Orca's prompt for a
    `worker_done` or `ask` goes to a terminal that no longer exists.
    Probe: `grep -rn -iE 'run-use|run-current' plugins/cepa/` matches only
    `orca-health.sh` (it reads `run-current`); no command or §12b rule tells
    a coordinator to run `run-use`, and `/cepa:handoff` does not carry the
    Run id. This repo's own handoff had the step only because its author
    wrote it by hand.
    Same class: every terminal handle written in a handoff (`Report to:`,
    another coordinator's handle) is dead after a restart.
    Fix shape: §12b rule 2 (or 8) — a coordinator that has a Run runs
    `run-use` on its first turn and checks `coordinator_handle` equals
    `ORCA_TERMINAL_HANDLE`; `/cepa:handoff` emits the Run id and that step,
    and marks any handle it prints as valid only until the terminal closes.

L44. **WISHLIST: make Orca's chat UI work more like the Claude Code VS Code chat UI.**
    status: deferred
    severity: P3
    owner: unassigned — after the coordinator/worker loop works end to end
      (operator, 2026-11-01: "let's get everything working together first").
    Operator, 2026-11-01: "i love that chatui. is it possible to take
    elements of that and build them into orca's chatui?" Reference: the VS
    Code extension `Anthropic.claude-code`.
    Feasible only as design ideas: list the UX elements the operator values,
    and propose them to Orca as feature requests. Do not copy the extension's
    code or assets: it is Anthropic's, under its own license. Whether Orca
    takes outside changes is not measured. First step when this opens: the
    operator names the 3-5 elements that matter most.

L46. **Harden the rename and re-bind blocks: four P2s from #110 and #113.**
    status: pending
    2026-11-01: tab25 reported done on PR #116 (fe32bbc, 1.46.0, CI 10/10,
    review 23 findings / 17 applied). Re-opened on the branch by two
    coord@main messages: msg_5f9c440d11a0 (merge main after #117, re-bump)
    and msg_50d5f27fc0ad (scope fix, operator's AskUserQuestion "Fix in
    #116 first"). CORRECTION (same day): coord@main's "server-wide"
    claim was WRONG — its three probes all ran in its own pane and varied
    only cwd and ORCA_TERMINAL_HANDLE, which Orca does not use to name the
    caller. tab25 measured from another pane: `run-current --json` returns
    `"run": null`, and `--from` with an invented handle returns
    `stable_pane_required`. run-current is PER PANE. (A restored tab keeps
    its pane, which is why L45 saw the old dead handle.) Decision relayed to
    tab25 as option 1 (reply msg_7993bc7c8736): a Run held elsewhere is
    never re-bound without a matching `run:` or `confirm:`; a run-current
    Run held by this terminal counts as named; rule 2 keeps the run-create
    id as the named Run. Lesson: a probe that varies inputs the system does
    not read proves nothing about scope (repo CLAUDE.md, absence claims).
    severity: P2
    owner: roles (`tab25@roles`, dispatched via Orca 2026-11-01 on the
      operator's AskUserQuestion "One worker for the 4 P2s": task
      `task_5bd477f61f8b`, dispatch `ctx_a418f891de98`, branch
      `fix/roles/rename-rebind-hardening`)
    1. Rule 6 rename block runs `<cli>` unchecked and unquoted
       (`memory/tasks.d/2026-10-31-refactor-roles-send-block-stdin.md` line 11,
       security-sentinel: `orca-ide;touch${IFS}/tmp/x` runs the touch).
    2-4. #113 findings 10, 11, 12
       (`memory/tasks.d/2026-11-01-fix-roles-run-rebind-on-restart.md` lines
       5-7): no gate runs the rule 2 re-bind block; two re-binders can both
       print `done`; a `run:`-only Run is taken with no ownership check.

L47. **Too many send blocks are refused: 4 of the first sends after the reboot.**
    status: pending
    severity: P2
    owner: unassigned — after L46 merges (same files: §12b rule 1, the
      send script and `check-orca-nudge.sh`)
    Measured 2026-11-01 by coord@main from the alert files in
    `~/.local/state/cepa/orca-alerts/` (written 16:34-16:42 UTC) and the
    senders' terminals (Orca `terminal read`, read only). Sessions started on
    cepa 1.45.0 had 4 refused sends in 8 minutes:
    - helm `term_35229546…`: message file named `msg-takeover.txt`, not
      `cepa-send-<name>.txt`.
    - dpc-pro `term_ac4053b1…` (3): a wrong file name; a file the script had
      already read and removed, so it was gone at the retry ("not a regular
      file this user owns"); and `nudge: nudge` for a `dispatch:` target
      ("only a term_ handle is nudged").
    Each sender retried, got `Orca send stored`, and acked its alert. So the
    guard worked: nothing was lost, and nothing ran. But each refusal costs a
    turn and an alert. Fix candidates: a `run:`/`dispatch:` target with
    `nudge` is sent as no-nudge, not refused (Orca already delivers it);
    rule 1 shows the exact Write path for the message file; the refusal
    message for a missing file says that the script removes a file once it
    reads it, so a retry needs a new file. Keep the security checks.
    Also (L48 D3, operator "Accept all"): drop `orca-health.sh`'s
    pre-1.43.0 and pre-1.44.0 REASONS groups (review-2026-10-31-233000 #10).

L48. **Triage the open P3 backlog (recent shards and older open todos).**
    status: completed
    CLOSED 2026-11-01 — PR #115 merged `160e03d` (operator's AskUserQuestion
    "Merge when green"). 1 finding applied, 15 closed with evidence, ~50 left
    for after L46, decisions D1-D10 accepted as recommended ("Accept all")
    and filed as L49-L53 (+ D3 into L47). Head b397bf2 = Handoff `Head:`, CI
    10/10 green; main had gained only this file since the base. No plugin
    change. integrity parked, branch deleted, tab6 closed (absent from
    `terminal list`). Record: `memory/tasks.d/2026-11-01-chore-integrity-p3-backlog-triage.md`.
    severity: P3
    owner: integrity (`tab6@integrity`, dispatched via Orca 2026-11-01 on the
      operator's AskUserQuestion "Triage the P3 backlog": task
      `task_975fa81c480b`, dispatch `ctx_191959f15dc1`, branch
      `chore/integrity/p3-backlog-triage`)
    Scope: open `- [ ] P3` lines in `memory/tasks.d/2026-10-3*.md` and
    `2026-11-*.md` (60 by `grep -cE '^\s*- \[ \] P3'`, before the run) and the
    open findings in 6 `todos/` files (`grep -lE 'status:\s*(pending|ready)'
    todos/*.md`). Skips L46's two shards and files, and L47. Safe fixes
    applied; the rest comes back as one decision table for the operator.

L49. **Small cleanup batch from the L48 triage: D1, D2, D6, D9 and #115 review 4 and 6.**
    status: completed
    CLOSED 2026-11-01 — PR #117 merged `882a7b2` (1.45.1), on the operator's
    AskUserQuestion "Merge when green". Head bd68adf = Handoff `Head:`, CI
    10/10 green; main had gained only this file since the base. integrity
    parked, branch deleted, tab7 closed (absent from `terminal list`); both
    hops run, freshness rc=0 (loaded copy contains 882a7b2). Review: 5 P3,
    4 applied, 1 deferred (no control pins first-match `q`). Shard:
    `memory/tasks.d/2026-11-01-chore-integrity-l48-cleanup-batch.md`.
    severity: P3
    owner: integrity (`tab7@integrity`, dispatched via Orca 2026-11-01:
      task `task_bb4fd07dec6c`, dispatch `ctx_eaaae10c4e7c`, branch
      `chore/integrity/l48-cleanup-batch`)
    Operator accepted all of L48's recommendations, 2026-11-01. Items in
    `memory/tasks.d/2026-11-01-chore-integrity-p3-backlog-triage.md`: D1 turn-endings checker (POINTER outside fences; `--enter` in rule
    7's guard — patch already tested by tab6); D2 close six findings with no
    change (status only); D6 `check-findings-file.sh` `sed …p | head -1` →
    `sed -n '…{p;q}'` (patch bump), accept #3; D9 fix the dangling PR #107
    pointer in the session-names shard; #115 review findings 4 and 6 (two
    one-line wording fixes). Must not touch L46 files.

L50. **`sweep.md` puts model-filled values in single quotes (L48 D5).**
    status: pending
    severity: P3
    owner: unassigned (its own worker)
    review-2026-10-31-230000 #5, judgment 80. The repo rule: such a value is
    read through a quoted heredoc and checked inside the block. See `memory/tasks.d/2026-11-01-chore-integrity-p3-backlog-triage.md`.

L51. **Record the "flip the shard line in the same commit" rule (L48 D8).**
    status: pending
    severity: P3
    owner: unassigned (via `/cepa:compound`)
    review-2026-10-30-192000 #16. L48 measured 7 shard lines that lagged
    findings or punch-list items already closed. See `memory/tasks.d/2026-11-01-chore-integrity-p3-backlog-triage.md`.

L52. **Detection-gate control gaps (L48 D7) — after L46.**
    status: pending
    severity: P3
    owner: unassigned (a test-only worker, after L46 merges)
    152000 #11, session-names finding 12, hostile `json.py` fixture (094500
    #24 + 125030 #15; #15 also covers the rule 6 block). See `memory/tasks.d/2026-11-01-chore-integrity-p3-backlog-triage.md`.

L53. **`orca-health.sh` hardening batch (L48 D4) — after L47.**
    status: deferred
    severity: P3
    owner: unassigned (one worker after L47 merges)
    review-2026-10-31-214500 #21 #23 #24 #29 #31 #32, review-2026-10-31-230000
    #7. See `memory/tasks.d/2026-11-01-chore-integrity-p3-backlog-triage.md`.

L54. **Two reviews in the same second write one findings file; the second overwrites the first.**
    status: pending
    severity: P2
    owner: unassigned
    From L49 (tab7@integrity, operator chose to file it 2026-11-01).
    Findings files are named `todos/review-YYYY-MM-DD-HHMMSS.md`. PR #108
    (`8d71f58`) replaced PR #107's `todos/review-2026-10-31-213000.md`
    (`cd40fdb`), so PR #107's 13 findings exist only in git history. This
    is the shared-sink rule (repo CLAUDE.md "Shared sinks are sharded or
    serialized"): the path needs a per-run component (branch slug or PR
    number) composed with autonomy §5 `slug(x)`, and every reader of
    `todos/review-*.md` must accept the new name. Source line:
    `memory/tasks.d/2026-11-01-chore-integrity-l48-cleanup-batch.md` line 11.

---

## How this list is used

When the user asks "where am I" or opens a new session, read this file first.
Report the open items by their original numbers with the closed ones struck
through. Recommend the next item by number.

The user's stated constraint: they lose track across many tabs, and want to be
reminded when it is time to start the next item.

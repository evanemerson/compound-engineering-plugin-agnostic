# Residuals — feat/runner-runtime-detector

## 2026-08-07 — `/cepa:plan-review` blocked the build

Plan: `docs/plans/2026-08-06-runner-runtime-detector.md` (local; `docs/` is
gitignored). Findings: `todos/review-2026-08-07-030542.md` — 11 findings,
6 P1 / 4 P2 / 1 P3, six personas, none failed, none dropped below anchor.

**No code was written.** Two personas independently challenged the plan's
central premise; the challenge was then verified directly, not relayed, and it
holds. Nothing was applied to the plan — findings 1 and 2 invalidate the design
the rest of the fixes would have polished.

### The finding that stopped it

**GitHub's runner already emits the warning.** Verified against the GitHub
Changelog, "Deprecation of Node 20 on GitHub Actions runners" (2025-09-19),
carrying the same 2026-09-16 removal date the plan cites:

> Node.js 20 actions are deprecated. ... The following actions are running on
> Node.js 20 and may not work as expected: `actions/checkout@v4`, ...

The annotation names the offending action. The same mechanism ran for the
Node 16 → 20 transition in 2023. Runners default to Node 24 from 2026-06-16.

This repo's workflows have been running throughout — `model-pins.yml` on every
PR and push, `mutation-sweep.yml` weekly — pinned to `actions/checkout` v4.4.0.
So the warning naming this exact action was almost certainly sitting in this
repo's own run logs for months before a human asked about it by name.

**So the P2's premise was wrong, and mine inherited it.** The residual said
"nothing fails, warns, or notices". GitHub warns and notices. What was missing
was an **observer** — which is the identical finding this repo already closed
one layer up, when the weekly sweep's failure had no named observer and got one
(`permissions: issues: write` plus an issue-filing step).

The plan proposed to reconstruct a fact the platform publishes: an annotation
convention on every pin, a policy table of runtimes and removal dates, a
self-expiry bound, an upstream fetch job, and a controls suite for all of it.
Every one of those pieces exists to re-derive `runs.using`. None is needed if
the run's own annotations are read instead.

**This is the defect class the plan was written to close, committed by the plan.**
A detector is not exempt from the class it detects — third time on record in
this repo.

### The other P1s

- **The precedent citation was reversed.** The plan justified its second-list
  design by citing the operator as having "accepted a tracked known-gaps list".
  `memory/tasks.d/2026-08-01-feat-mutation-sweep-harness.md:58` records the
  opposite: option (b), land the fixes first, chosen **rather than** add that
  list. Verified at the cited line. Authority borrowed from a decision that
  went the other way, for the single choice it rejected — the autonomy-7
  laundering shape arriving through a misremembered precedent rather than a
  hostile one, which is the harder case because nothing looks adversarial.
- **The Verification Contract asserted a state the tree is not in** ("0 MISS on
  the current tree", "the tree's real `node24` annotation"). No pin carries the
  annotation; no unit added it. Caught independently by coherence and
  feasibility.
- **Discovery required the annotation it was supposed to detect the absence of** —
  the fail-closed rule sits three lines below the pattern that forecloses it.
- **MISS for a whole escalation window reddens every unrelated PR**, against
  autonomy 9f's own recorded reasoning that failing unrelated PRs is how a
  signal gets routed around.
- **The renovate/dependabot decision was never weighed**, though the 2026-08-06
  shard's own P3 records the deferral as having cost a real deadline's margin.

### Open — the operator's call before any build resumes

- [x] ~~P1 — **redesign to observe the runner's own annotations**, or keep the
  reconstruct-the-fact design with findings 3/4/5/8/9/10 applied.~~
  **Operator chose observe, 2026-08-07.** Shipped as the `runtime-deprecation`
  job in `model-pins.yml`; plan
  `docs/plans/2026-08-07-runtime-deprecation-observer.md`, second review
  `todos/review-2026-08-07-054748.md` (7 findings, 6 applied, no judgment-class
  P1 — revise-and-continue, unlike the first).

  Two things the second panel caught that would have shipped broken:

  - **The observer's first act would have been a false positive.** Selecting
    each workflow's newest completed run on main, with no tip check, resolves
    `changelog` to the PR #39 merge and `mutation-sweep` to a 2026-08-03 commit
    — both *before* PR #40 fixed the pin, both still carrying the old node20
    annotation. Fixed by comparing `head_sha` to the branch tip and routing a
    mismatch to UNVERIFIED. Verified against the live API.
  - **Warn-forever is the same no-observer failure one layer up.** The first cut
    quoted the earlier finding 5 to drop the MISS entirely and never re-added
    its second stage. Now escalates to MISS once the tracking issue has been
    open past `ESCALATE_AFTER_DAYS` — clocked on the issue's own `created_at`,
    deliberately **not** a countdown to a hardcoded removal date, which would
    reintroduce the policy table the redesign deleted.

  And one the panel did not catch, found by running the code: the
  escape-hatch guard's `grep` pattern was a literal inside the file it scans, so
  it matched **its own source** and was permanently red on a clean tree. Fourth
  instance on record of a detector falling to the class it detects — inside the
  PR whose plan cites that very defect as the thing it avoids by construction.
  The needle is now assembled at run time.

- [ ] P1 — **reopen the renovate/dependabot decision, or record it as declined
  again with the new cost evidence.** Twice deferred; the standing reason
  (`main` is unprotected, so an unattended bot opening PRs against it is a
  larger decision than a tooling PR should make) is unchanged, but this incident
  is the second data point against it and the deferral now has a measured price.

- [x] ~~P2 — **`FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true`** is a runner opt-in that
  forces the newer runtime today. Worth setting as a forward-compatibility probe
  independent of any detector?~~ **Resolved 2026-08-07 as obsolete — deliberately
  NOT set.** The runner has defaulted to Node 24 since 2026-06-16, so the
  variable is a no-op. From the same log line that named it:

      Node 20 is being deprecated. This workflow is running with Node 24 by
      default. If you need to temporarily use Node 20, you can set the
      ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION=true environment variable.

  The 2025-09-19 changelog's advice was correct when written and the platform
  moved past it — setting it now would be cargo-cult. **The variable that still
  bites is the opposite one**, and it is the genuinely useful guard: setting
  `ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION=true` forces workflows *back* onto the
  dying runtime and silences the very warning the observer reads, which would
  read as a clean pass. A step under `check` now refuses it — proven green → red
  → green by planting it. Stated scope: it sees only the literal committed under
  `.github/`, not a repo-level Actions variable set in the web UI nor one
  exported at runtime via `$GITHUB_ENV`.

- [ ] P2 — **pin the match to a historical fixture instead of a generic shape?**
  (second review, finding 8, conf 50.) The structural match
  (`Node.js <N> is deprecated`) is assumed to survive the next runtime cycle's
  wording. A literal historical fixture would be provably not self-updating but
  detectably stale via the committed tests. Trades a known maintenance cost
  against an unmeasured false-negative risk.

- [ ] P3 — **re-verify the match against GitHub's wording at the next Node
  deprecation announcement** (second review, finding 3). The annotation is
  undocumented text, and the node20 warning stops entirely once removal
  completes on 2026-09-16 — a permanent clean pass after that is *correct* until
  node24 starts dying, and *wrong* if the next cycle's phrasing differs. The
  coverage counters cannot tell those apart. This is the one place the design
  can go quietly stale.

- [ ] P3 — **the `# vX.Y.Z` tag comment has no verification either** and is as
  human-entered as anything proposed here. Recorded so the asymmetry is a
  decision rather than an oversight.

### Worth keeping from the blocked plan

Not everything here dies with the premise. These survive any redesign:

- The zero-coverage-floor placement argument: a floor whose scan root includes
  the checker's own file can only fire if the file is deleted, which is the live
  open defect in `check-model-pins.sh` leg 4. A new checker under `scripts/`
  scanning `.github/workflows/` avoids it by construction.
- The `set -e` arithmetic trap: parse into a variable and gate **before** any
  `$(( ))`, because `set -e` does not abort on an arithmetic error inside an
  assignment and the reassuring branch is what follows.
- The job-isolation boundary: a token-holding job runs no repo script and checks
  nothing out, because `$GITHUB_PATH` is prepended for every later step in the
  same job.
- Any repo-derived value reaching an argument position is validated first, and
  `^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$` is **not** sufficient — it admits `.` and
  `..` as whole path components.

### A fifth instance, found by reading the job's own hosted output

The first hosted run printed `read 0 annotation(s)` — true, and it exposed a
silent-pass path in the line that produced it:

    msgs=$(api ".../check-runs/$cr/annotations" --jq '.[].message') || continue

A failed annotations call and a check-run with no annotations both leave `msgs`
empty, so `|| continue` collapsed them. An API refusal printed the identical
summary line to a genuinely clean scan — inside the job whose own header says
*"'found nothing' and 'looked at nothing' are otherwise indistinguishable"* and
*"every failure path exits 0 AFTER emitting a warning."*

Fixed: failure is distinguished from empty, counted as `unread`, reported in the
summary, and a pass with `unread > 0` is announced as **QUALIFIED, not clean**.
Regression case added to the extract-and-run harness (now 9).

Worth recording plainly: across this one branch the class landed **five** times —
the reconstruct-the-fact premise, the tip-check omission, warn-with-no-escalation,
the guard matching its own source, and this. Four were caught by review or by
running the code; the count is the point, not any one instance.

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

- [ ] P1 — **redesign to observe the runner's own annotations**, or keep the
  reconstruct-the-fact design with findings 3/4/5/8/9/10 applied. The evidence
  favours observing: authoritative (it is what actually executes the action),
  self-updating for node24 → node28 with no edit here, no annotation convention,
  no second list, no self-expiry. The remaining real gap is narrow and matches a
  shape this repo has already built once — GitHub *warns* but never *fails*, and
  a warning in a job log has no observer.

- [ ] P1 — **reopen the renovate/dependabot decision, or record it as declined
  again with the new cost evidence.** Twice deferred; the standing reason
  (`main` is unprotected, so an unattended bot opening PRs against it is a
  larger decision than a tooling PR should make) is unchanged, but this incident
  is the second data point against it and the deferral now has a measured price.

- [ ] P2 — **`FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true`** is a runner opt-in that
  forces the newer runtime today. Worth setting as a forward-compatibility probe
  independent of any detector? It surfaces breakage on this repo's schedule
  rather than GitHub's.

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

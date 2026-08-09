# Residuals — chore/checkout-node24-bump (PR #40)

## 2026-08-06

- [x] ~~**P2 — the runner's JS runtime is a dependency this repo had no watcher for,
  and still only half has one.**~~ `actions/checkout` was pinned at a `node20`
  major with ~6 weeks left before GitHub removes Node 20 from the runner
  (2026-09-16). Nothing in `memory/`, `todos/` or `.github/` mentioned it —
  `grep -rni "node ?20\|node24\|deprecat"` returned zero hits before this PR.
  It was found only because a human asked about it by name, which is the same
  no-observer shape `mutation-sweep.yml`'s freshness detector exists to fix one
  layer up. What landed is documentation (`model-pins.yml` now states the
  runtime constraint and how to read a candidate's `runs.using`) — a note for
  whoever next opens that file, not a detector. **Nothing fails, warns, or
  notices when v7's runtime is deprecated in turn.** The next occurrence is
  found the same way this one was: by luck.

  **Closed 2026-08-07** by the `runtime-deprecation` job in `model-pins.yml`.
  **This finding's own diagnosis was wrong, and the correction is the durable
  part.** "Nothing warns or notices" is false: the runner already emits

      ##[warning]Node.js 20 is deprecated. The following actions target
      Node.js 20 but are being forced to run on Node.js 24:
      actions/checkout@11d5960a326750d5838078e36cf38b85af677262

  naming the action **by its pinned SHA**. Verified in this repo's own history
  at run 30867814226 (2026-08-04, two days before the bump) — so the warning was
  sitting in these logs for months. The gap was never a missing signal; it was
  an **authoritative signal with no observer**, which is the same finding this
  repo closed one layer up for the weekly sweep.

  The first design (`docs/plans/2026-08-06-runner-runtime-detector.md`) took
  this bullet at its word and proposed to *reconstruct* the runtime: an
  annotation on every pin, a policy table of removal dates, a self-expiry bound,
  an upstream fetch job, and a controls suite. A six-persona panel blocked it
  (`todos/review-2026-08-07-030542.md`). What shipped instead reads the
  annotation GitHub already publishes — no policy table, no removal dates, no
  annotation convention, no second list, and it updates itself for the next
  runtime cycle.

  Note for the next reader of this file: the P3 below proposed comparing
  "against the runtime, or against the newest major". Both were still
  reconstruction. The answer was to stop deriving and start observing.

- [x] ~~**P3 — the renovate/dependabot question is still open, and this PR is the
  second data point for it, not a resolution.**~~ **SETTLED 2026-08-09 —
  ADOPTED**, in PR `chore/adopt-dependabot`. Reasoning is recorded once in
  `memory/tasks.d/2026-08-06-feat-runner-runtime-detector.md`; do not restate it
  here. The one thing this bullet got right and is worth carrying: its stated
  constraint — *compare against the runtime, or the newest major, not the pinned
  line's own tag* — is what disqualified the WARN-only substitute and is
  satisfied by Dependabot comparing against the newest release. Originally:
  Deferred in
  `memory/tasks.d/2026-07-30-fix-cite-trunk-ladder-once.md` on the reasoning
  that `main` is unprotected, so an unattended bot opening PRs against it is
  too large a decision for a pinning PR. That reasoning is unchanged and the
  question was deliberately left alone here. What changed is the evidence: the
  predicted failure mode ("a pinned action with no auto-bump is easy to
  forget") occurred, on three sites at once, and cost a real deadline's worth
  of margin. The WARN-only substitute floated there — a check flagging when a
  pinned SHA has fallen behind its upstream tag — would **not** have caught
  this one: v4.4.0 was the newest release on its own line, so a
  behind-its-tag check reads green while the runtime underneath goes EOL.
  Whatever settles this has to compare against the runtime, or against the
  newest major, not against the pinned line's own tag.

- [ ] **P3 — the `v4.5.0` in each bump-recipe example was live documentation rot.**
  Two workflows told a future bumper to run
  `gh api .../git/refs/tags/v4.5.0`, i.e. to pin the very line being
  deprecated. Now `v7.0.2`. The general shape — an illustrative version number
  inside a copy-pasteable command ages into a wrong instruction — has no guard,
  and this repo has three such examples. Cheap partial remedy if it recurs:
  make the examples use a placeholder that cannot be pasted successfully.

  **Still open, and worse in consequence as of 2026-08-09** now that bumping is
  automated. What Dependabot does and does not touch, and why the manual recipe
  stays load-bearing, is stated once in `.github/workflows/model-pins.yml`'s
  header — read it there. Unchanged in kind, so this stays open here rather than
  being folded into the adoption.

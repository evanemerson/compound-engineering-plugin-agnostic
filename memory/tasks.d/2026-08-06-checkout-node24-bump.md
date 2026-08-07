# Residuals — chore/checkout-node24-bump (PR #40)

## 2026-08-06

- **P2 — the runner's JS runtime is a dependency this repo had no watcher for,
  and still only half has one.** `actions/checkout` was pinned at a `node20`
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

- **P3 — the renovate/dependabot question is still open, and this PR is the
  second data point for it, not a resolution.** Deferred in
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

- **P3 — the `v4.5.0` in each bump-recipe example was live documentation rot.**
  Two workflows told a future bumper to run
  `gh api .../git/refs/tags/v4.5.0`, i.e. to pin the very line being
  deprecated. Now `v7.0.2`. The general shape — an illustrative version number
  inside a copy-pasteable command ages into a wrong instruction — has no guard,
  and this repo has three such examples. Cheap partial remedy if it recurs:
  make the examples use a placeholder that cannot be pasted successfully.

# Residuals — feat/derive-changelog-on-release (PR #39)

## 2026-08-06

- **P3 — `.github/workflows/changelog.yml` pushes directly to an unprotected
  `main`.** If branch protection is ever enabled, this job needs either a
  `github-actions[bot]` bypass allowance or a PR-based flow. It now fails with a
  message that names protection explicitly rather than blaming a push race, so
  the failure is self-diagnosing — but it still fails, and every release event
  after that point leaves `CHANGELOG.md` stale until someone acts.
  Source: `todos/review-2026-08-06-151255.md` finding 18. Recorded here rather
  than left in the PR body per
  `docs/solutions/logic-errors/durable-record-promises-need-a-named-sink-in-every-phase.md`.
  Interacts with the standing "turn on branch protection for main" item — do
  these two together or the first release after protection breaks the changelog.

- **P3 — a second pinned action now depends on manual SHA bumping.**
  `changelog.yml` pins `actions/checkout@11d5960a...  # v4.4.0`, the same SHA as
  both sibling workflows. Correct as pinned, but it widens the premise of the
  deferred renovate/dependabot question in
  `memory/tasks.d/2026-07-30-fix-cite-trunk-ladder-once.md` — that open item now
  covers three sites, not two. No action required; noted so the count is right
  when that question is revisited.
  Source: `todos/review-2026-08-06-151255.md` finding 19.

- **P3 — `CHANGELOG.md` becomes an autonomy-§7 relay point the moment anything
  reads it into a prompt.** Nothing does today (`grep -rln "CHANGELOG.md"` finds
  only the generator, the workflow, and `CLAUDE.md`), so no clause is needed yet.
  The next PR that wires a reader — `document-release`, `compound-refresh`, or
  similar — must derive its own untrusted-data clause at that site rather than
  inheriting an assumption from this one. The file carries merged PR titles
  verbatim, which any PR author can seed.
  Source: `todos/review-2026-08-06-151255.md` finding 20.

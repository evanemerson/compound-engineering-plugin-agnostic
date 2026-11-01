# Residuals — chore/integrity/l48-cleanup-batch (punch-list L49, PR #117)

## Deferred from /cepa:review of PR #117 (2026-11-01)

Canonical findings: `todos/review-2026-11-01-112201.md` (finding 4).

- [ ] P3 — No control pins first-match in the `{s//…/p;q;}` captures: dropping `q` stays green in `check-findings-file-controls.sh` and `run-mutation-sweep.sh --selftest` — `plugins/cepa/scripts/check-findings-file.sh`, `scripts/run-mutation-sweep.sh:533-536` (finding 4).

## Found while doing L49 (D9)

- [ ] P3 — Findings files are named by second (`todos/review-YYYY-MM-DD-HHMMSS.md`), so two concurrent reviews can pick one path. PR #108 (`8d71f58`) replaced PR #107's `todos/review-2026-10-31-213000.md` (`cd40fdb`) this way, and PR #107's 13 findings now exist only in git history. This is the shared-sink class in CLAUDE.md ("Shared sinks are sharded or serialized"). Fix: add the branch slug to the name, or refuse to overwrite an existing path — `plugins/cepa/commands/review.md` Step 5. Probe: `git log --oneline --follow -- todos/review-2026-10-31-213000.md`.

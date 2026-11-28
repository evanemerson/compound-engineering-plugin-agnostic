# Residuals — fix/integrity/session-names (punch-list L37)

## Deferred from /cepa:review of PR #107 (2026-10-31)

Canonical findings: PR #107's `todos/review-2026-10-31-213000.md` (findings 12, 13),
now only in git history: `git show cd40fdb:todos/review-2026-10-31-213000.md`.
PR #108 (`8d71f58`) wrote its own review to the same path and replaced it, so the
file at that path today is PR #108's (`scope: pr:#108`). No `todos/` file holds
`scope: pr:#107` (probe: `grep -lE '^scope: pr:#?107' todos/*.md` prints nothing).
Corrected 2026-11-01 (L49, L48 D9).

- [x] P3 — The two line-hit TITLE-SURFACES controls accept any `TITLE-SURFACES:` MISS as a kill; let a control name a killer substring — `scripts/check-orca-detection-controls.sh` `mutate()` (finding 12). Resolved 2026-11-27 on test/formulation/detection-gate-controls (punch-list L52): a killer may be a (leg, substring) pair; all five TITLE-SURFACES controls name theirs and are in EXACT.
- [ ] P3 — PR #96 findings 12 and 15 still apply to the unchanged rule 6 rename block; tracked in `2026-10-30-feat-roles-orca-session-titles.md`, not duplicated here (finding 13). Finding 15's `json.py` half landed 2026-11-27 (punch-list L52); its finding 21 half is open.

## Owed by the operator

- [ ] The coordinator first-turn rename (§12b rule 6, When) reaches a coordinator that runs no cepa command only through `~/.claude/CLAUDE.md`. The proposed diff is in PR #107's body; until it is applied, that sentence has no trigger.

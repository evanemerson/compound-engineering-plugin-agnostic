# Residuals — feat/roles/orca-session-titles (punch-list L23)

## Deferred from /cepa:review of PR #96 (2026-10-30)

Canonical findings: `todos/review-2026-10-30-125030.md` (findings 12, 13, 15, 16).

- [ ] P3 — A missing `timeout`, `python3` or CLI prints a misleading rename failure reason; §12a gates all three first — `plugins/cepa/skills/autonomy/SKILL.md` §12b rule 6 (finding 12).
- [ ] P3 — `title-rename-hangs` and `env-stale-hangs` share a 1.2 s bound that may flake on a loaded runner — `scripts/check-orca-detection.sh` (finding 13).
- [ ] P3 — PR #94 findings 21 (one merged failure reason) and 24 (no hostile `json.py` fixture) apply to the rule 6 block too; fix both blocks together — `plugins/cepa/skills/autonomy/SKILL.md` §12a and §12b rule 6 (finding 15).
- [ ] P3 — Controls run time roughly doubled; record the hosted duration if above about 4 minutes — `.github/workflows/residual-integrity.yml` (finding 16).

## Proposed CLAUDE.md rule (learning, PR #96)

- [ ] A placeholder in a block an agent fills in must fail closed. Rule 6's handle slot first shipped as `self`, a valid value, so a coordinator that forgot to put in the worker's handle renamed its own tab and reported success. Use a placeholder the block's own check rejects (`<handle-or-self>`), and test the block with the placeholder left in place.

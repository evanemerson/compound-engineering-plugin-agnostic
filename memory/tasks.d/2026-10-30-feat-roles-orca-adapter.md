# Residuals — feat/roles/orca-adapter (punch-list L21)

## Deferred from /cepa:review of PR #94 (2026-10-30)

Canonical findings: `todos/review-2026-10-30-094500.md` (findings 21, 22, 23, 24, 25).

- [ ] P3 — The §12a probe's failure reason carries no exit code or stderr; timeout, kill and error print one line — `plugins/cepa/skills/autonomy/SKILL.md` §12a (finding 21).
- [ ] P3 — `check-model-pins.sh` does not see an Orca `worker-start` as a dispatch; §12b rule 2's model requirement is unenforced — `scripts/check-model-pins.sh` (finding 22).
- [ ] P3 — A stale `ORCA_CLI_COMMAND` (tmux/nohup shell after Orca closed) reads present with no probe; operator call against the brief's no-probe rule — `plugins/cepa/skills/autonomy/SKILL.md` §12a (finding 23).
- [ ] P3 — No fixture plants a hostile `json.py`; dropping `python3 -I` survives — `scripts/check-orca-detection.sh` (finding 24).
- [ ] P3 — Unmeasured: does `status --json` keep `"ok": true` when the Orca app is closed? — `plugins/cepa/skills/autonomy/SKILL.md` §12a (finding 25).

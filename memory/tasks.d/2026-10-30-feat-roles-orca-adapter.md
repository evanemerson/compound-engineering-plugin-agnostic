# Residuals — feat/roles/orca-adapter (punch-list L21)

## Deferred from /cepa:review of PR #94 (2026-10-30)

Canonical findings: `todos/review-2026-10-30-094500.md` (findings 21, 22, 23, 24, 25).

- [ ] P3 — The §12a probe's failure reason carries no exit code or stderr; timeout, kill and error print one line — `plugins/cepa/skills/autonomy/SKILL.md` §12a (finding 21).
- [ ] P3 — `check-model-pins.sh` does not see an Orca `worker-start` as a dispatch; §12b rule 2's model requirement is unenforced — `scripts/check-model-pins.sh` (finding 22).
- [ ] P3 — A stale `ORCA_CLI_COMMAND` (tmux/nohup shell after Orca closed) reads present with no probe; operator call against the brief's no-probe rule — `plugins/cepa/skills/autonomy/SKILL.md` §12a (finding 23).
- [ ] P3 — No fixture plants a hostile `json.py`; dropping `python3 -I` survives — `scripts/check-orca-detection.sh` (finding 24).
- [ ] P3 — Unmeasured: does `status --json` keep `"ok": true` when the Orca app is closed? — `plugins/cepa/skills/autonomy/SKILL.md` §12a (finding 25).

## Proposed CLAUDE.md rules (learnings, PR #94)

- [ ] A `timeout` inside `$(…)` does not bound the call: command substitution waits for EOF on the pipe, so a child (or setsid grandchild) that keeps stdout open outlives the timeout — 29.9 s against a 10 s bound, reproduced by adversarial-reviewer. Redirect the bounded command's stdout to a temp file and read the file. Shipped fix: autonomy §12a probe.
- [ ] A mutant that appends `|| true` to an `elif ! cmd` condition is always-true, not "exit ignored" (`! a || true` negates only `a`). It went red for the wrong case; only the named-killer control caught it. Build exit-ignored mutants by replacing the condition's status (`; [ ! -s file ]`), and pair every mutant with the case meant to kill it.

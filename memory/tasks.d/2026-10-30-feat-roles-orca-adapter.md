# Residuals — feat/roles/orca-adapter (punch-list L21)

## Deferred from /cepa:review of PR #94 (2026-10-30)

Canonical findings: `todos/review-2026-10-30-094500.md` (findings 21, 22, 24, 25 open; 23 completed).

- [ ] P3 — The §12a probe's failure reason carries no exit code or stderr; timeout, kill and error print one line — `plugins/cepa/skills/autonomy/SKILL.md` §12a (finding 21).
- [ ] P3 — `check-model-pins.sh` does not see an Orca `worker-start` as a dispatch; §12b rule 2's model requirement is unenforced — `scripts/check-model-pins.sh` (finding 22).
- [x] P3 — A stale `ORCA_CLI_COMMAND` (tmux/nohup shell after Orca closed) reads present with no probe — `plugins/cepa/skills/autonomy/SKILL.md` §12a (finding 23). Resolved 2026-10-30 on feat/roles/orca-adapter (PR #94): operator chose a probe on that path, bounded at 3 s + 0.5 s kill; finding 23 is `completed`.
- [ ] P3 — No fixture plants a hostile `json.py`; dropping `python3 -I` survives — `scripts/check-orca-detection.sh` (finding 24).
- [ ] P3 — Unmeasured: does `status --json` keep `"ok": true` when the Orca app is closed? — `plugins/cepa/skills/autonomy/SKILL.md` §12a (finding 25).

## Deferred from /cepa:review of PR #94 follow-up f8d33c5 (2026-10-30)

Canonical findings: `todos/review-2026-10-30-152000.md` (findings 3, 7, 9, 11).

- [ ] P2 — On stock macOS (no `timeout`) a valid `ORCA_CLI_COMMAND` reads absent; limit stated in §12a, fallback (`gtimeout` or a python3-bounded probe) not built — `plugins/cepa/skills/autonomy/SKILL.md` §12a (finding 3).
- [ ] P3 — Probe failure reason covers stale CLI, timeout and crash alike; tracked as finding 21 above — `plugins/cepa/skills/autonomy/SKILL.md` §12a (finding 7).
- [x] P3 — Punch-list L21 text predates the probe and send-and-print decisions; coord@main owns it — `memory/tasks.d/2026-10-02-punch-list.md` L21 (finding 9). Closed 2026-11-01 by triage: L21 CLOSED (PR #94).
- [ ] P3 — `env-stale-not-ok`, `env-bare-orca-darwin`, `setsid-grandchild-holds-stdout` have no control naming them — `scripts/check-orca-detection-controls.sh` (finding 11).

## Proposed CLAUDE.md rules (learnings, PR #94)

- [ ] A `timeout` inside `$(…)` does not bound the call: command substitution waits for EOF on the pipe, so a child (or setsid grandchild) that keeps stdout open outlives the timeout — 29.9 s against a 10 s bound, reproduced by adversarial-reviewer. Redirect the bounded command's stdout to a temp file and read the file. Shipped fix: autonomy §12a probe.
- [ ] A mutant that appends `|| true` to an `elif ! cmd` condition is always-true, not "exit ignored" (`! a || true` negates only `a`). It went red for the wrong case; only the named-killer control caught it. Build exit-ignored mutants by replacing the condition's status (`; [ ! -s file ]`), and pair every mutant with the case meant to kill it.

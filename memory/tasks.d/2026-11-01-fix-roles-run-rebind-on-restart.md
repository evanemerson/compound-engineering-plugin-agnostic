# Residuals — fix/roles/run-rebind-on-restart (L45)

## 2026-11-01 — /cepa:review of #113 (todos/review-2026-11-01-083310.md)

- [x] CLOSED in PR #116 (L46, 1.46.0) — P2 — `scripts/check-orca-nudge.sh` BLOCK leg — no leg runs §12b rule 2's re-bind block (finding 10). Fix: a RULE2BLOCK leg that extracts the fence holding `orca-rebind.sh" <<`, fills it, runs it against the stub with and without `run:` and with the script absent; SKILL_MUTANTS for it.
- [x] CLOSED in PR #116 (L46, 1.46.0) — P2 — `plugins/cepa/scripts/orca-rebind.sh` run-use — two simultaneous re-binders can both print `done` (finding 11). Fix: count `done` only when `consumer_generation` rose by exactly 1, or measure `run-use --from <holder>` as a compare-and-swap.
- [x] CLOSED in PR #116 (L46, 1.46.0) — P2 — `plugins/cepa/scripts/orca-rebind.sh` run-show path — a Run named only by the `run:` field is taken with no ownership check (finding 12). Fix: ask on that path unless Orca exposes a repo or worktree field that matches this checkout; measure `run-show` first.
- [ ] P3 — `plugins/cepa/scripts/orca-health.sh` unbound alert and `orca-rebind.sh` reader — a null or absent `coordinator_handle` is silent in health and exits 3 in the re-bind (finding 13).
- [ ] P3 — `plugins/cepa/scripts/orca-health.sh` unbound alert — fires hourly for a live holder the re-bind will never take (finding 14).
- [ ] P3 — `plugins/cepa/skills/autonomy/SKILL.md` §12b rule 2 block — the skipped branch prints no `Ending first line:`; a stale loaded copy is its likely cause (finding 15).
- [ ] P3 — `plugins/cepa/scripts/orca-rebind.sh` cepa_rb_orca — Orca's stderr and a timeout's real exit code are discarded (finding 16).
- [ ] P3 — `plugins/cepa/scripts/orca-rebind.sh` cepa_rb_orca — no 90-second start gate or wedge stop; run-use not retried on the pre-delivery vsock error (finding 17).
- [ ] P3 — `scripts/check-orca-nudge.sh` REBIND leg — untested branches: run-show fail/shape, re-read shape, three retry flags, the vsock `&&`, cli arms, missing tools, `run` twice, bound-here with a `run:` field (finding 18).
- [ ] P3 — `plugins/cepa/commands/handoff.md` allowed-tools — the `run-current` grant names `orca-ide` only, as every Orca grant does (finding 19).
- [ ] P3 — `memory/tasks.d/2026-10-02-punch-list.md` L45 — close it after merge and the two plugin-refresh hops (coord@main is the only writer) (finding 20).

## 2026-11-01 — tab25@roles, L46 (PR #116)

- Measured for findings 11 and 12 (Orca 1.4.245, read only): `run-use --from` has no help text and is the caller's handle on `run-current` and `send`, so it is not a compare-and-swap. `run-show --json` has no repo or worktree field (`id, objective, coordinator_handle, consumer_generation, legacy, created_at, updated_at`). Probe: `orca-ide orchestration run-show --id <run> --json`.
- [ ] P3 — `plugins/cepa/scripts/orca-rebind.sh` — `run-current`'s shape with a bound Run is unmeasured (a worker gets `"run": null`), so the holder and generation are read from `run-show`: three more reads than #113 on the common path (before, recheck before `run-use`, after), two on the `run:`-only path; worst case 153 s → about 225 s. The before-read's generation is what makes the +1 proof possible, so a coordinator may drop a read only if `run-current --json` carries both `coordinator_handle` and `consumer_generation` (measure it once).

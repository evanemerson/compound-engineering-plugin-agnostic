# Residuals — fix/roles/orca-loss-audit (L35)

The measured audit table is in
`memory/tasks.d/2026-10-31-fix-roles-orca-send-verify.md` (section "L35
audit").

## 2026-10-31 — gaps the audit found, not fixed here
- P2 — `worker-start` has no stated proof. Success is `"ok": true` with
  `result.dispatch.id` `ctx_…`; a `--spec` near 32 KB, or the vsock error,
  prints nothing, so a coordinator cannot tell whether a worker started and may
  start a second one in the same checkout. Next: pass a caller `--retry-request
  <uuid>`, require the `ctx_` id, and on no result run `request-show
  --request <uuid>` — plugins/cepa/skills/autonomy/SKILL.md §12b rule 2
- P3 — Rule 8's no-bound-Run drain (process the peek, then mark read) is prose
  only. A script would make it the one checked form — plugins/cepa/skills/autonomy/SKILL.md §12b rule 8
- P3 — Rule 4's `ask` result test (exit 0, `timedOut` false, `answer`
  non-null; resume on timeout) is prose only — plugins/cepa/skills/autonomy/SKILL.md §12b rule 4
- P3 — L36 findings #19 and #21 (`todos/review-2026-10-31-184500.md`), folded
  into L35 by coord@main and split back out: move `<cli>`/`<target>`/`<type>`/
  `<nudge>` off the block's quoted command line onto stdin (#19), and give the
  script an optional session name for its ending line (#21). Both change the
  stdin interface of the block every session runs, so they are one PR of their
  own, gated by new STORE/SENDREF cases — plugins/cepa/scripts/orca-send.sh,
  plugins/cepa/skills/autonomy/SKILL.md §12b rule 1 block
- P3 — The global `~/.claude/CLAUDE.md` Orca section tells a worker to send its
  Handoff block as the `worker_done` body, and says a probe terminal is closed;
  it should name `orca-send.sh … worker_done` (rule 3) and prove a close by
  absence from `terminal list` (`terminal close` returns `"ok": true` for an
  already-closed handle) — operator
- P3 — A heartbeat is accepted after its dispatch settled (`"ok": true`), so
  "heartbeat stored" does not prove a live worker. Input for L34's "hung"
  definition, which should key on dispatch state (`worker-show`) — L34

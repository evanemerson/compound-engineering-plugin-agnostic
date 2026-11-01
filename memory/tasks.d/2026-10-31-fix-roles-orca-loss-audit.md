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
- CLOSED in PR #110 (L38, 1.43.0) — P3 — L36 findings #19 and #21 (`todos/review-2026-10-31-184500.md`), folded
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

## 2026-10-31 — /cepa:review deferred findings (PR #106, todos/review-2026-10-31-192000.md)
- P3 — The reply's nudge target comes from Orca's own `to_handle` (finding 11): Nudge only when `to_handle` equals the question row's `from_handle` in the re-read. — plugins/cepa/scripts/orca-send.sh reply nudge target
- P3 — `ask --resume <result.messageId>` names no shape check (finding 12): Say: only a `msg_[0-9a-f]{6,32}` id, passed as a quoted argument. — plugins/cepa/skills/autonomy/SKILL.md §12b rule 4
- P3 — No mutant makes the two tries' request ids differ (finding 13): Add a mutant that makes a new id per try. — scripts/check-orca-nudge-controls.sh retry request-id checks
- P3 — The thread check may reject a valid reply to a reply (finding 14): Probe a reply to a reply and loosen the check if needed. — plugins/cepa/scripts/orca-send.sh verdict thread check
- P3 — A rerun after a timed-out reply that stored gets `answer_conflict`, read as not stored (finding 15): Read `answer_conflict` as already answered, or `request-show` the first request id after a timeout. — plugins/cepa/scripts/orca-send.sh reply after a timeout
- P3 — The ending-line variants are not all listed (finding 16): List the variants in the header and rule 1. — plugins/cepa/scripts/orca-send.sh header ending-line text; SKILL.md §12b rule 1
- P3 — The two D6 candidate lists differ (finding 17): Point the first section at the L35 D6 paragraph. — memory/tasks.d/2026-10-31-fix-roles-orca-send-verify.md D6 sections
- P3 — Closed residuals keep present-tense text (finding 18): Prefix the old text with "Was:". — memory/tasks.d/2026-10-31-fix-roles-orca-send-verify.md closed residuals
- P3 — Rule 1 restates the retry rule its script header owns (finding 19): Cite the header; keep only the 6-minute tool timeout. — plugins/cepa/skills/autonomy/SKILL.md §12b rule 1 retry paragraph
- P3 — The gate's stated limit names one script's date and verb (finding 20): Name which script each limit is about. — scripts/check-orca-nudge.sh STATED LIMITS

# Residuals — 2026-11-28 (fix/formulation/dispatch-reroute-delivered, punch-list L105)

## 2026-11-28 — build

The fix: a `term_` send that Orca stores for `dispatch:<ctx>` is counted as
delivered (exit 0, "Orca nudge not needed") only when one bounded
`orchestration worker-show --dispatch <ctx> --json --full` names that
Dispatch `dispatched`, with the target as both `dispatch.assigneeHandle` and
`terminal.handle`.

Shape measured here (read only, Orca 1.4.280, this worker's own Dispatch
ctx_a6ec452b7e3a): `result.terminal` is an OBJECT whose `handle` is the
terminal. The sender's wording in L105 item D2 (`result.terminal == target`) would never
match, so the script reads `result.terminal.handle`. A case pins the bare
string shape as a skip.

- [ ] **P3 — A host (`on:`) send re-routed to the worker's own Dispatch still
  skips.** Nobody has measured whether a host Orca prompts a Dispatch mailbox,
  or what `worker-show --environment` returns for one. Measure it on a host
  worker, then extend THE OWN DISPATCH with `--environment`.
  `file: plugins/cepa/scripts/orca-send.sh` · `action_class: judgment` ·
  `confidence: 60`
- [ ] **P3 — Only `status: dispatched` counts.** That is the one live status
  measured. If Orca prompts a Dispatch mailbox in another live status, that
  send still skips with exit 1. The skip is the safe direction: the operator
  is asked once, and no mail is lost. Measure it when orca-lab re-measures L105.
  `file: plugins/cepa/scripts/orca-send.sh` · `action_class: judgment` ·
  `confidence: 60`
- [ ] **P3 — orca-lab re-measures the fix on the next release (L105).** The
  claim that Orca prompts the worker comes from the sender's measurement. It
  was not measured here. `file: memory/tasks.d/2026-10-02-punch-list.md` ·
  `action_class: judgment` · `confidence: 80`

## 2026-11-28 — /cepa:review on PR #154

Six readers ran (reliability, security, previous-comments, silent-failure,
test coverage, comments); no P1. Applied in the PR: the re-route proof now
requires a `ctx_` Dispatch id (security + reliability, corroborated), the
header and inline comment name THE VSOCK RETRY and where THE OWN DISPATCH
lives, a `terminal: null` case, and a case plus mutant for a non-`ctx_` id.
Findings file: `todos/` (this run's review file).

- [ ] **P2 — A re-route skip writes no `nudge_skipped` alert (older gap; now
  also reached by a failed own-Dispatch read).** The header says every nudge
  skip but one on the target's own row writes an alert; the
  `stored for another handle` skip (and the chat and downgraded skips) write
  none. A session that drops its ending line leaves the mail unread with no
  orca-health.sh trace. Fix needs a reason in orca-health.sh's REASONS list,
  which this lane must not edit (tab54 owns it now): either add the alert and
  the reason together, or change the header to name these skips as alert-free.
  `file: plugins/cepa/scripts/orca-send.sh` · `action_class: judgment` ·
  `confidence: 80`
- [ ] **P3 — The skip line does not say why the own-Dispatch proof failed**
  (read failed, timed out, not dispatched, another terminal). An operator sees
  one line for four causes. `file: plugins/cepa/scripts/orca-send.sh` ·
  `action_class: judgment` · `confidence: 70`
- [ ] **P3 — `dispatched` is read after the send, not at store time.** A
  worker that ends between the store and the read, or a `dispatched` row whose
  terminal has exited, gives "not needed" for mail nobody is prompted about.
  The window is small. Orca's worker-show also carries `projection.liveness`
  (measured `verdict: live` here); requiring it would close most of the gap.
  `file: plugins/cepa/scripts/orca-send.sh` · `action_class: judgment` ·
  `confidence: 40`

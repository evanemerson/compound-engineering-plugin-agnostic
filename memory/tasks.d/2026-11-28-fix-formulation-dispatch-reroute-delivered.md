# Residuals — 2026-11-28 (fix/formulation/dispatch-reroute-delivered, punch-list L105)

## 2026-11-28 — build

The fix: a `term_` send that Orca stores for `dispatch:<ctx>` is counted as
delivered (exit 0, "Orca nudge not needed") only when one bounded
`orchestration worker-show --dispatch <ctx> --json --full` names that
Dispatch `dispatched`, with the target as both `dispatch.assigneeHandle` and
`terminal.handle`.

Shape measured here (read only, Orca 1.4.280, this worker's own Dispatch
ctx_a6ec452b7e3a): `result.terminal` is an OBJECT whose `handle` is the
terminal. The sender's D2 wording (`result.terminal == target`) would never
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

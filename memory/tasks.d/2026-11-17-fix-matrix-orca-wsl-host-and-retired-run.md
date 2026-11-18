# Residuals — fix/matrix/orca-wsl-host-and-retired-run (punch-list L89, L92)

Worker: tab43@matrix (task_cabafd3d433b). coord@main owns the punch list; this
shard holds what this branch did not close.

## Undone items (2026-11-17)

1. [P2] L89 a, b: not sent live by cepa. A real `on:` send or a `dispatch:`
   send to a finished `--keep-open` host worker writes into a live session
   (and b starts a follow-up dispatch), so this branch measured only the
   reads (`inbox --environment` with the id and with the name). orca-lab can
   re-measure both on its live host with this PR (coord@main's offer,
   2026-11-17).
2. [P3] L89 b: orca-lab's report lists the follow-up reply's keys, not the
   value of `followUpOf`. orca-send.sh accepts `ctx_…` or `dispatch:ctx_…`
   equal to the target; any other form falls to the read-back and exit 5.
3. [P3] L92: run-show's answer for a Run that maintenance DELETED is not
   measured. The script keys on `run_not_found`, measured on Orca 1.4.262 for
   an id that never existed (`run-show --id run_cepaprobe0000 --json
   --full`: exit 1, `"ok": false`). Orca has no verb that deletes a Run, so
   no throwaway Run could be aged.
4. [P2] L89 e (shard 2026-11-16 item 3b): `orca-lane.sh create` and `name`
   for a repo added on a host are not supported. The host's `repo list
   --environment` row has its own id and null `connectionId`/`hostId`.
5. [P3] L89 c: `rm` reads at most one Orca WSL host (10-minute budget); a
   second WSL host keeps the lane with a reason that says so.
6. [P3] L89 f, g: with stablyai/orca#43869 open, no rule 8 alert covers a
   host worker (exited, long, failed): `orca-health.sh` skips its row. Revisit
   when #43869 is fixed.

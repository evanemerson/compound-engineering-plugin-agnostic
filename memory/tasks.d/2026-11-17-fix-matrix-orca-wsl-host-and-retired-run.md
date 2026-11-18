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

## Deferred from the PR #142 review (2026-11-17)

Findings file: todos/review-2026-11-17-213659-fix-matrix-orca-wsl-host-and-retired-run.md

7. [P2] #13 orca-send.sh follow-up success has no re-read; add `worker-show --dispatch <new>` once its shape for a host follow-up is measured.
8. [P2] #14 orca-rebind.sh reads `run_not_found` on this machine's Orca only (fine while a coordinator's Run lives where it runs).
9. [P2] #15 orca-health.sh: a note or alert for skipped host dispatches, keyed on `workerState`/`dispatchStatus`.
10. [P3] #17 test gaps: hostread `"local" in cov`; hostagents count, limit, hostIds and agents checks; wslenvs runtimeId fallback; rebind with two WSL hosts; `startswith(me + " on ")`.
11. [P3] #18 coord@main: record L89 as partly closed and point the 2026-11-16 shard items 1, 2, 3, 3b, 5 here.
12. [P3] #19 orca-lane.sh: name an invalid runtimeId in the kept line.

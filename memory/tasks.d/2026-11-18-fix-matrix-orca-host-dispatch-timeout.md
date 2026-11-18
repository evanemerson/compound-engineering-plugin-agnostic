# Residuals — fix/matrix/orca-host-dispatch-timeout (punch-list L93)

Worker: tab46@matrix (task_2685f8f7d33b). coord@main owns the punch list; this
shard holds what this branch did not close.

Source: orca-lab coord@main, msg_9dce386e6069 (Orca 1.4.262, cepa 1.60.0, a
coord@main running ON the WSL host). Sender report (§12c): the two timed-out
`dispatch:` sends and the empty host `environment list` were not re-run here.
Re-measured here, read only from a `\\wsl.localhost` lane of the Windows Orca
(Orca 1.4.262, 2026-11-18): `orchestration worker-list --environment
wsl:ubuntu-24.04 --limit 100 --json --full` (18 rows, newest first) and
`worker-show --environment wsl:ubuntu-24.04 --dispatch <id> --json --full` for
each dispatch of the chain ctx_c272e2d7007f → ctx_1287f768472b →
ctx_584bcded077a: only the newest row carries `resource`, with
`ownerDispatchId` = itself and `originDispatchId` = the chain's first.

## Undone items (2026-11-18)

1. [P2] L93 1: not re-run live. A live `dispatch:` send writes into a session
   this worker did not start. orca-lab can re-measure on its host after merge:
   a send to a `done --keep-open` worker should now exit 0, either at once
   (60 s bound) or with `found by a re-read`.
2. [P3] L93 1: the moment a follow-up takes the terminal resource over is not
   measured. If the host Orca moves `ownerDispatchId` only after the CLI
   answers, the re-read right after a timeout still sees the old owner and
   exits 5 (safe, but a false failure). orca-lab's re-measure shows which.
3. [P3] L93 1: the 60 s bound is a chosen margin, not a measured start time.
   If orca-lab still sees exit 124, record how long the send takes.
4. [P3] L93 1: a follow-up that another sender starts on the same worker
   between the owner read before the send and the re-read passes as this
   send's. Accepted: one coordinator owns a worker (§10). (The first cut used
   a 120 s `createdAt` window; PR #144 review found it took an EARLIER send's
   follow-up as this one, so the re-read now compares the owner before and
   after the send.)
5. [P3] L93 2: documented only (§12b rule 1). `orca-send.sh` does not name the
   host-to-Windows case on `terminal_not_found`: from a host it cannot prove
   the target is a Windows terminal.
6. [P3] L93 3 (scope added by coord@main, msg_144b2a96cb4e; orca-lab
   msg_201730c8762e, sender report): `orca-lane.sh` now names a WSL-host-only
   repo. Not run live: the stub gives the host `repo list --environment` row
   the shape L89 e measured (Linux path, null connectionId/hostId).
   orca-lab can re-run a Windows-side lane command for orca-chat-scratch.
7. [P3] Every plain `dispatch:` send now makes 3 Orca reads before it (the
   terminal's owner), up to 102 s when Orca is slow (TIME BUDGET). Only a
   failed call uses them.

## Open items of the 2026-11-17 shard this branch touches

memory/tasks.d/2026-11-17-fix-matrix-orca-wsl-host-and-retired-run.md:
- Items 7 and PR #143 item 7 (FOLLOWUP and CHAIN never read the new
  dispatch): still open on those paths. Only the new re-read (a failed call)
  reads the new dispatch (`worker-show --dispatch <new>`).
- PR #143 items 3 and 5 (hop cap 8): unchanged. The re-read walks from the
  old owner, so a long chain still exits 5.
- PR #143 items 8, 9 and 10: still open. The re-read names its failed step
  in the exit 5 reason, but the FOLLOWUP and CHAIN reasons are unchanged; a
  host-created follow-up's home record is still not measured; a timed-out
  hop read and a flag-shaped `server.environmentId` still have no case.
- Items 5 and 6 (`rm` reads one WSL host; host-worker alerts): untouched.

## Deferred from the PR #144 review (2026-11-18)

Findings file: todos/review-2026-11-18-121459-fix-matrix-orca-host-dispatch-timeout.md

8. [P2] #2 check-orca-nudge.sh: the 60 s bound is checked only against a
   `term_` send; add timeout-log cases for a `coord:` and a `worker_done` send.
9. [P3] #12 check-orca-lane.sh: `cepa_ln_hostrepo`'s 5 s bound and no-retry
   are not asserted; log them in the lane stub.

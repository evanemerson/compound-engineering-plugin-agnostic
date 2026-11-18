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
   answers, a re-read right after a timeout finds the old owner and exits 5
   (safe, but a false failure). orca-lab's re-measure shows which.
3. [P3] L93 1: the 60 s bound is a chosen margin, not a measured start time.
   If orca-lab still sees exit 124, record how long the send takes.
4. [P3] L93 1: a follow-up that another sender starts on the same worker
   inside the 120 s window passes as this send's. Accepted: one coordinator
   owns a worker (§10).
5. [P3] L93 2: documented only (§12b rule 1). `orca-send.sh` does not name the
   host-to-Windows case on `terminal_not_found`: from a host it cannot prove
   the target is a Windows terminal.
6. [P3] L93 3 (scope added by coord@main, msg_144b2a96cb4e; orca-lab
   msg_201730c8762e, sender report): `orca-lane.sh` now names a WSL-host-only
   repo. Not run live: the stub gives the host `repo list --environment` row
   the shape L89 e measured (Linux path, null connectionId/hostId).
   orca-lab can re-run a Windows-side lane command for orca-chat-scratch.

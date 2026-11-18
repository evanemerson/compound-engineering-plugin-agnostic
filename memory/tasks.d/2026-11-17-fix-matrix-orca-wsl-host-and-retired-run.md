# Residuals — fix/matrix/orca-wsl-host-and-retired-run (punch-list L89, L92)

Worker: tab43@matrix (task_cabafd3d433b). coord@main owns the punch list; this
shard holds what this branch did not close.

## Undone items (2026-11-17)

1. [P2] **CLOSED 2026-11-18 by fix/matrix/orca-host-send-gaps (tab44@matrix)**
   as measured: orca-lab sent both live on 1.60.0 (msg_6a0b36ef91b6, sender
   report), and that branch fixes the two gaps it found. Still not sent live
   by cepa (that branch's item 1, below). Was: L89 a, b: not sent live by cepa. A real `on:` send or a `dispatch:`
   send to a finished `--keep-open` host worker writes into a live session
   (and b starts a follow-up dispatch), so this branch measured only the
   reads (`inbox --environment` with the id and with the name). orca-lab can
   re-measure both on its live host with this PR (coord@main's offer,
   2026-11-17).
2. [P3] **CLOSED 2026-11-18 by fix/matrix/orca-host-send-gaps**: orca-lab's
   1.60.0 re-measure gives the value (a bare `ctx_…`, the newest dispatch of
   the chain); orca-send.sh now walks the chain (its header, THE FOLLOW-UP
   CHAIN). Was: L89 b: orca-lab's report lists the follow-up reply's keys, not the
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

## fix/matrix/orca-host-send-gaps (2026-11-18, tab44@matrix, task_62849e1debfb)

Closed here (orca-lab's 1.60.0 re-measure, msg_6a0b36ef91b6, sender report):
L89 a (a stored `on:` send exits 0, no operator ask), L89 b (a `followUpOf`
in the target's follow-up chain counts, proven by `worker-show`), L89 c/e
(`orca-lane.sh rm` names a host-side lane as not supported), and the release
note (§12b rule 3, "Release a follow-up chain by its newest dispatch").
Undone:

1. [P2] L89 a, b, c: not re-run live by cepa. A live `on:` or `dispatch:`
   send writes into a session this worker did not start, and a host lane
   needs `worktree create --environment`, which the brief ruled out. The
   reads were re-measured live (Orca 1.4.262, read only): host
   `worker-show` chains, home records of host dispatches, host `repo list`
   and `worktree list`. orca-lab can re-measure all three on its live host.
2. [P3] L89 e: the host's `worktree list --environment` listed only a main
   row (orca-chat-scratch), so a non-main host lane row is assumed to share
   its shape (`repoId`, Linux `path`, `isMainWorktree` false).
3. [P3] L89 b: a follow-up chain longer than 8 hops exits 5 (`not proven
   stored`); the longest measured chain is 4 dispatches (3 hops).
4. [P3] Release: no script finds a chain's newest dispatch; §12b rule 3 tells
   the coordinator to read `worker-show`. A helper could walk the chain.


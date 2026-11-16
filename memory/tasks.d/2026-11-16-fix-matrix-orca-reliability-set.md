# Residuals — fix/matrix/orca-reliability-set (punch-list L60, L74, L84, L85, L88)

Worker: tab38@matrix (task_632cd8534ebe). coord@main owns the punch list; this
shard holds what this branch did not close.

## Undone items (2026-11-16)

1. [P2] L88 item 2: the cause of the false exit 5 on a `dispatch:` send that
   Orca delivered as a follow-up dispatch is not found. The read-back (L84)
   now turns that shape into a stored send when the inbox holds the row. Not
   reproduced here: sending to a settled `--keep-open` worker starts a
   follow-up dispatch in someone's session. Measure it on orca-lab's WSL host:
   the raw `send --json --full` reply beside the script's output.
2. [P2] L88 item 1: `on:` is not measured on a live host worker (none was
   at hand). The argv follows `orchestration send --help` on Orca 1.4.259.
   Unmeasured: whether Orca stores the row in this machine's inbox with
   `to_handle` equal to the host `term_` handle (the re-read needs that), and
   whether a `dispatch:` target for a host worker needs `on:` at all.
3. [P2] L85: `orca-lane.sh rm` still refuses while a WSL host is added (now
   naming it). PR #138 review: a WSL host runs on this machine, so its agent
   can sit in the lane's directory with no local row, and the live-agent read
   stays strict. To lift it: read the WSL host's own `worktree ps
   --environment <id>` and match agents by path (the host path form is not
   measured).
3b. [P2] L85: `orca-lane.sh` for a repo added on a host (the item's extra
   question). Not implemented: every call would need `--environment`, the
   repo resolver reads only the local registration, and host paths differ.
   The script states this as a limit.
4. [P3] L85 item 3: check that worker specs tell workers to drain before
   `worker_done`, and that coordinators ack the follow-up dispatch. Not done.
5. [P3] L85: whether an Orca WSL host has an `environment list` row (the
   re-bind maps an omitted `runtime:<id>` to an environment by `runtimeId`
   or `id`). If it has none, the re-bind still asks, now naming the host.
6. [P3] L74: the replay of a drain under the same `--retry-request` was
   measured on one dispatch mailbox with one message (Orca 1.4.259). Not
   measured: a bound Run's mailbox, a batch of several, `check --wait`.
7. [P3] L60: the probe from the item ("one live worker, read the inbox,
   re-bind, read again": does `run-use` fence live dispatches?) was not run.
   It needs a live worker and a re-bind of a coordinator's Run.
8. [P3] L84 audit, verbs left without a read-back, and why:
   `terminal send` (the nudge): a terminal screen is not a record, and a
   false "nudge failed" costs one `tell <session>` line. `terminal rename`:
   idempotent, a rerun is safe. `terminal close`: already proven by absence
   from `terminal list`. `run-use`: `orca-rebind.sh` already re-reads
   `run-show` after it. `check --ack`: a no-op on Orca 1.4.246+, and an ack
   of a handled delivery is a no-op. `worktree create` / `rm`: #134.
   `worker-start`, `task-create`, `run-create`: no script runs them; §12b
   rule 2 now says to read `worker-list` / `run-list` before a rerun.
9. [P3] PR #138 review, test gaps: the 10-show cap on failed dispatches (and
   acked rows not counting), the highest-sequence pick of two matching rows,
   `on:` with a reply, two omitted hosts with the second live, two
   environments matching one host, two lane reads overwriting the note, and a
   PEEK pin on rule 8's replay sentence. Add a case and a mutant each.
10. [P3] PR #138 review: the read-back cannot tell this send from an identical
    one (same type, subject, body, recipient) stored in the same two minutes.
    A pre-send inbox read that excludes existing ids would close it.
11. [P3] PR #138 review: run `/cepa:compound` on "a host or scope relaxation
    needs a measured round trip before it fails open" (review caught two).
12. [P3] PR #138 review: rule 1's `on:` bullet restates details the
    orca-send.sh header owns; cut it to what a session does and cite.

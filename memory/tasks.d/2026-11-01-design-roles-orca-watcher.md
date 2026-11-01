# L40 design: Orca watcher for idle coordinators — DEFERRED

Date: 2026-11-01 · Session: tab24@roles · Punch-list item: L40
Status: **deferred by the operator.** No build. No automation created.

## Decision

The operator decided (2026-11-01, in the tab24@roles tab): "we'll come back
to it later maybe. ignore it for now. defer it."

coord@main owns the punch list. This doc does not edit it. coord@main can
park or close L40 and point to this file.

## Why it is deferred

1. **A watcher only helps if it reaches the operator sooner than the next
   look.** When the operator is away, no work moves. A hung worker or a failed
   send waits either way. When the operator comes back and types into a
   coordinator, that turn runs `orca-health.sh` (cepa `autonomy` §12b rule 8),
   and the alert shows then.
2. **The past misses did not need a watcher.** L29 (workers printed `done`
   and stopped), the unread dpc-pro inbox (2026-10-30), and the lost
   farmtender prompt (2026-10-31) were closed by stored sends
   (`orca-send.sh`), the guarded nudge, and the per-turn health check.
3. **The cost is real.** See the measured facts below. An Orca automation
   starts a paid agent on every alert. A shell watcher outside Orca is the
   same kind of process as the 2026-10-31 `relay.py`, and needs both of its
   guards, a lock, and tests.

## Trigger to revisit

Revisit L40 the first time the operator loses real time because an alert
waited while every coordinator was idle and the operator was looking at Orca.
Record that incident (time, what waited, how long) in the punch list. That
incident is the measured benefit this design does not have today.

## Measured facts (Orca 1.4.245, WSL, 2026-11-01) — keep for a later design

Probe: `orca-ide automations --help`, `orca-ide automations create --help`,
`orca-ide automations runs --help`, `orca-ide --help`,
`orca-ide automations list --json`. Help only; nothing was created.

- `orca-ide automations list --json` returned `"automations": []`.
- **An automation always starts an agent.** `create` requires `--prompt` and
  `--provider`. It cannot run only a shell command.
- **`--precheck <command>`** runs before each scheduled run. Exit 0 starts the
  agent. Any other exit, an error, or a timeout (default 60 s,
  `--precheck-timeout`) skips the run. A skip is logged as
  `skipped_precheck` in `orca automations runs`. So a precheck that exits
  non-zero when all is well costs zero LLM tokens on quiet runs.
- `orca automations run` and "Run now" bypass the precheck.
- **Schedule:** `--trigger` takes `hourly`, `daily`, `weekdays`, `weekly`, a
  5-field cron expression, or an RRULE. `--timezone` takes an IANA zone.
- **Directory:** `--workspace <selector>` runs in an existing worktree; without
  it, each run makes a new worktree (`--workspace-mode new-per-run`).
- **A flag without an agent:** `orca worktree set --worktree <sel> --comment
  "<text>" --unread` puts a note and an unread mark on a worktree in the
  sidebar.
- **`orca-health.sh` scope:** it reads the Run that `run-current` reports for
  its own terminal (`ORCA_TERMINAL_HANDLE`), and only its own worktree's alert
  files (the main checkout sees the whole repo's). An automation has no
  coordinator terminal, so as written it would see only file alerts. A
  machine-wide watcher needs a new reader over every live Run.

## Constraints any later design must keep

- **The two `relay.py` guards** (punch-list L40, 2026-10-31 incident): the
  watcher stops when its owner stops, and it never consumes another session's
  mailbox. It never sends, nudges, acks, or drains any inbox.
- **One copy only**, by a lock it checks before it runs.
- **Stored in and run from the cepa repo**, under the global CLAUDE.md
  carve-out: a program this repo owns may read other repos' state only when
  that is its documented purpose. Orca state is read through `orca-ide`,
  never from another repo's checkout.
- No LLM tokens on a quiet run.

## Open questions (for a later session, not for now)

1. Where the operator sees an alert: the worktree `--unread` mark, an agent
   session that shows under NEEDS YOU, or a file.
2. Once for the machine, or once per repo.
3. How often it runs (the help allows cron, so every 10 minutes is possible).
4. How it is turned off (`orca automations edit --disabled` or `remove`, if
   it is an automation).

## Build plan

None. No Implementation Units are written for a deferred item. A later
session writes them (`cepa:implementation-units`) after the operator answers
the open questions above.

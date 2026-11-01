# Residuals — feat/roles/orca-failure-alerts (L34)

The design, the measurements and the thresholds are in PR #109's body. The
alert sources and bounds are owned by `plugins/cepa/scripts/orca-health.sh`'s
header.

## 2026-10-31 — stated limits of the L34 alert, not closed here
- P2 — The health check runs only inside a coordinator turn, so an idle coordinator watches nothing (§12b rule 8 stated limit). Candidate: an `orca automations create --trigger <cron> --precheck <command>` that runs `orca-health.sh` while every coordinator is idle. Next: measure what `--precheck` gates, then ask the operator before creating a scheduled agent — plugins/cepa/skills/autonomy/SKILL.md §12b rule 8
- P3 — The proposed `~/.claude/CLAUDE.md` bullet (PR #109 body, "Proposed `~/.claude/CLAUDE.md` change") is not applied: a worker never edits that file — operator

## 2026-10-31 — /cepa:review deferred findings (PR #109, todos/review-2026-10-31-214500.md)
- P3 — Alert files, temp files and ack markers are never pruned (finding 21): Prune entries older than about 30 days at read time. — plugins/cepa/scripts/orca-health.sh alert directory
- P3 — A send that failed and then succeeded on a rerun still leaves its alert (finding 22): On a stored send, supersede earlier alert files with the same sender, target and type. — plugins/cepa/scripts/orca-send.sh cepa_send_alert
- P3 — The 30-minute stale bound fires on a worker blocked on a long job or in `check --wait` (finding 23): Let a worker declare an expected quiet period and honor it. — plugins/cepa/scripts/orca-health.sh HB_STALE
- P3 — WSL clock skew shifts every age; the space time format is assumed UTC (finding 24): Alert on an Orca time more than 2 minutes in the future; record a UTC proof. — plugins/cepa/scripts/orca-health.sh ts
- P3 — L34 still reads pending and unassigned in the punch list (finding 25): coord@main updates it when it checks PR #109. — memory/tasks.d/2026-10-02-punch-list.md L34 Closed 2026-11-01 by triage: L34 CLOSED (PR #109).
- P3 — The health block puts a model-filled `<cli>` inside a quoted shell string (finding 26): Add the health block to L38's scope. — plugins/cepa/skills/autonomy/SKILL.md §12b rule 8 block
- P3 — The ending-line variants are still not listed as one set (finding 27, extends finding 16 of todos/review-2026-10-31-192000.md): List every exit 4/5 shape, with the alert line. — plugins/cepa/scripts/orca-send.sh header; SKILL.md §12b rule 1
- P3 — A stored reply read as unproven now also raises an operator alert (finding 28, extends finding 15 of todos/review-2026-10-31-192000.md): Fix finding 15 first. — plugins/cepa/scripts/orca-send.sh reply thread check
- P3 — `timeout` may kill only the orca-ide wrapper (finding 29): Measure how orca-ide is installed; use a process group if needed. — plugins/cepa/scripts/orca-health.sh cepa_h_orca
- P3 — The alert repo field is the directory basename (finding 30): Record a hash of the common-dir path beside it. — plugins/cepa/scripts/orca-send.sh cepa_send_alert
- P3 — Only outcome `in_progress` is inspected (finding 31): Measure Orca's outcome vocabulary, then alert on any outcome not known to be terminal. — plugins/cepa/scripts/orca-health.sh in_progress filter
- P3 — Symlinks or a FIFO in an alert directory shared with other users (finding 32): Refuse a directory not owned by the user, or a symlink. — plugins/cepa/scripts/orca-health.sh alert directory

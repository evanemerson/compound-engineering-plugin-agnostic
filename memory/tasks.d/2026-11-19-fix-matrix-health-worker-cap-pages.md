# Residuals — fix/matrix/health-worker-cap-pages (punch-list L94, PR #146)

Worker: tab48@matrix (task_ee76712a436a). coord@main owns the punch list; this
shard holds what this branch did not close.

## Undone items (2026-11-19)

1. [P3] `plugins/cepa/scripts/orca-health.sh` WORKER-LIST PAGES: a Run past
   1000 dispatch rows raises `orca-unreadable:worker-pages:<hour>` every hour,
   even when nothing is live (the L94 symptom at ten times the size). Runs are
   never closed, so a long-lived coordinator Run grows toward it. Options:
   stop paging once a page holds only rows settled before the oldest live
   dispatch (needs Orca to promise newest-first order), or key the ack longer
   than one hour. Stated in the script header as a limit. (review finding 8)
2. [P3] `scripts/check-orca-nudge.sh` HEALTH pages: a later page that answers
   `ok: false`, a `workers` that is not a list, or a timeout on page 2 (which
   must stop the inbox read through `cepa_h_wedged`) has no case of its own;
   only a missing page file is tested. The exact count of 20 `worker-show`
   reads under the cap is not pinned by `calls_want` (pre-existing). (review
   finding 9)
3. [P3] Not re-measured on a Run of more than 100 rows: none was at hand on
   2026-11-19 (run_ce7a15d01f88 held 21 rows, run_5682a0ed1455 25; paging was
   forced with `--limit 5`). orca-lab re-measures on run_9239ee3a4180 when
   this ships and asked for a reply to `coord:orca-lab`.

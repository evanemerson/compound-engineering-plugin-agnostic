# Residuals — fix/roles/worker-report-channel (PR #102, L30)

## 2026-10-31 — /cepa:review deferred findings (todos/review-2026-10-31-125359.md)
- P3 — The `Report to:` bullet sits under "Placement follows cepa" — plugins/cepa/skills/autonomy/SKILL.md §12b rule 2 (finding 14)
- P3 — task.md and lfg.md citation lines are over-long — plugins/cepa/commands/task.md 5.4 Final Status (finding 15)
- P3 — Rule 8's Why names RC5 only, not the RC1 worker case — plugins/cepa/skills/autonomy/SKILL.md §12b rule 8 Why (finding 16)
- P3 — Rule 1/2 phrases are checked against the whole rule, not their bullet — scripts/check-orca-turn-endings.sh REPORT1_HAS, REPORT2_HAS (finding 17)
- P3 — Deferred #101 finding 9 (ending names a handle, not a session) now reaches every `Report to:` worker — plugins/cepa/scripts/orca-nudge.sh cepa_nudge_ending (finding 18)
- P3 — #101 finding 9 (ending names a handle, not a session) now also reaches every `Report to:` worker via rule 3 — plugins/cepa/scripts/orca-nudge.sh cepa_nudge_ending (re-filed note)

## 2026-10-31 — operational (not code)
- L30 item 3 (RC4): restart long-lived coordinators so they load 1.38.0 — coord@main
- Live probe owed: a `Report to:` worker under `agent launch`, and a rule 8 drain on a session with no bound Run — coord@main

# Residuals — fix/matrix/rebind-null-holder (tab49@matrix, L99 + L103 C3)

Filed by the worker; coord@main folds these into the punch list.

1. [P2] `orca-health.sh` reads a null holder as unreadable, and never alerts
   `unbound` for one. Probe: `grep -n coordinator_handle
   plugins/cepa/scripts/orca-health.sh` — line ~429 requires a `term_` handle
   from `run-current` (a null holder sets `run.fail`, so the check reports
   `unreadable:run-current`); line ~913 raises `unbound` only for a `term_`
   holder, so a Run whose holder is null raises nothing. Same root cause as
   L99, in the script L103 C4 changes. Not fixed here: C4's owner
   (formulation) decides what a bot coordinator's health check shows.
   — `plugins/cepa/scripts/orca-health.sh:429`, `:913`
2. [P3] `orca-send.sh:920` reads `coordinator_handle` while it resolves
   `coord:<repo>`; check how a null holder reads there when C2 lands
   (`coord:<repo>` → `bot:<repo>-bot`). Not measured here.
   — `plugins/cepa/scripts/orca-send.sh:920`
3. [P3] orca-lab re-measure after this release: "C3 rebind refuses a null
   Run it does not own" (L103's re-measure list). Expected now: without
   `confirm:`, `ORCA rebind: ask — <run> has no recorded holder …`, exit 1;
   with `run:` and `confirm:`, `done — <run> moved from no recorded holder`.

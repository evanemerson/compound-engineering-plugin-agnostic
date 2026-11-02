# Residuals — fix/roles/send-refusals (PR #122, punch-list L47)

## Undone Items from fix/roles/send-refusals (2026-11-01)
1. [P3] Drop `orca-health.sh`'s pre-1.51.0 REASONS group (`only a term_ handle is nudged`) in the next minor after 1.51.0 — fits L53's orca-health batch. `todos/review-2026-11-01-202929-fix-roles-send-refusals.md` #4.
2. [P3] coord@main: close L47 after the merge, and tick `memory/tasks.d/2026-10-31-fix-integrity-send-heredoc-delimiter.md` line 8 and `memory/tasks.d/2026-10-31-refactor-roles-send-block-stdin.md` line 15 (the pre-1.43.0/1.44.0 groups, dropped here). Same file, #5.
3. [P3] `orca-attention.sh` has the same file-handling shape (`the question file is not a regular file this user owns`). Its missing-file refusal could carry the same retry hint as orca-send.sh does now. Not in L47's scope.

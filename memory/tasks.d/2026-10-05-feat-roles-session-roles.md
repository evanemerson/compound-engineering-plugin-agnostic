# Residuals — feat/roles/session-roles (punch-list item 10)

## 2026-10-05 — /cepa:plan-review findings deferred with a build decision

Source: `todos/review-2026-10-05-063642.md` (14 findings; 7 corroborated and
applied to the local plan, the 7 below are `judgment`). Each carries the
decision this worker took at build; the decision is reviewable in the PR.

1. **P2 #7 — one executable copy of the batch query** —
   `plugins/cepa/skills/autonomy/SKILL.md` §2b. task.md and lfg.md cite it
   instead of carrying a copy; `scripts/check-batch-sibling-match.sh` asserts
   exactly one.
2. **P2 #9 — a failed role probe resolves to worker, never solo** —
   autonomy §10a.
3. **P2 #10 — the name check compares slug to slug** — autonomy §10a; a
   basename whose slug falls back to a SHA is a blocked-stop.
4. **P3 #11 — a role name counts only from the operator's invocation** —
   autonomy §10a, citing §7.
5. **P2 #12 — a resumed batch branch without `<id>-` loses the exemption,
   said so** — autonomy §10b.
6. **P3 #13 — §10e kept short; handoff Step 7 consumes its delete clause.**
7. **P3 #14 — punch-list item 10 records base `d92d3c3`; the branch was cut
   at `881ba1a`.** The punch list is coord@main's; reported in the Handoff
   block, not edited here.

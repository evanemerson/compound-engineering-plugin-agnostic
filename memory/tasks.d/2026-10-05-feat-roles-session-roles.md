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

## 2026-10-05 — /cepa:review PR #84 findings deferred to the operator

Source: `todos/review-2026-10-05-070257.md` (24 findings; #1-#4 and #22
applied, #23 skipped by precedent, the 18 below `judgment` or under the
confidence-75 bar). Numbers are the findings file's.

8. **P2 #5 — compound-refresh's worktree branch sentence cannot fire** —
   `plugins/cepa/commands/compound-refresh.md:509`. Add a detached-park bullet
   or state report-only.
9. **P2 #6 — worker overlap stop precedes the batch-sibling exemption** —
   autonomy §10c; `task.md` 1.1 vs `lfg.md` Step 1 disagree.
10. **P2 #7 — coord@main's `<type>/main/<desc>` branch belongs to no role** —
    autonomy §10b/§10c; a worktree named `main` collides too.
11. **P2 #8 — §10 never constrains a worktree coordinator** — autonomy §10.
12. **P2 #9 — worker merged-branch shape misplaced, still starts new work** —
    `plugins/cepa/commands/handoff.md:878`.
13. **P2 #10 — solo guard fails open when `git worktree list` fails** —
    autonomy §10a/§10c.
14. **P2 #11 — failed probe with a coordinator name; stop vs worker** —
    autonomy §10a.
15. **P2 #12 — solo's own resumed PR reads as not-owned** — autonomy §10c.
16. **P2 #13 — untracked files trip the solo dirty-tree guard** — autonomy §10a.
17. **P2 #14 — workers autostash on the shared stash stack** —
    `plugins/cepa/commands/lfg.md:85`.
18. **P2 #15 — resolve-pr/sweep gate ownership on author** —
    `plugins/cepa/commands/resolve-pr.md:58`, `sweep.md`.
19. **P2 #16 — §10 grows the autonomy skill (deferred layering #16 of
    2026-07-29 made worse)** — `plugins/cepa/skills/autonomy/SKILL.md:1`.
20. **P3 #17 — §6 "without restating" vs four pointers; file reports' tail** —
    autonomy §6.
21. **P3 #18 — branching recipe copies** — autonomy §8/§10b, `task.md` 1.5.
22. **P3 #19 — `<wt>` slug stated only in §10a; refresh `<scope>` unslugged** —
    autonomy §10b, `compound-refresh.md:509`.
23. **P3 #20 — worktree names that slug alike share ownership** — autonomy §10a.
24. **P3 #21 — mutant fixtures not unique per mutant** —
    `scripts/check-batch-sibling-match.sh`.
25. **P3 #24 — post_deploy choice for a worker; `unnamed@<wt>`; README script
    list; "every reply"** — `task.md:553`, autonomy §10d, `README.md`.

# Residuals — fix/roles/review-agent-worktrees (punch-list L14)

## 2026-10-21 — /cepa:plan-review findings deferred with a build decision

Source: `todos/review-2026-10-21-084444.md` (13 findings; 11 applied to the
local plan, the 2 below are `judgment`). Each carries the decision this worker
took at build; the decision is reviewable in the PR.

1. **P1 #2 — parallel builders' worktrees are always kept** — autonomy §11b
   keeps Evan's guard (HEAD reachable from an origin ref). An lfg Step 3
   builder's commits are integrated locally and squash-merged later, so they
   never reach an origin ref and §11b keeps the worktree. Removing those
   belongs to lfg's §2 integration step; not built here.
2. **P2 #11 — the Agent result's worktree field is unmeasured** — §11b takes
   candidate paths from completed Agent results, per the tool's documented
   behavior. Measuring it needs an isolated dispatch in this repo, which the
   brief forbids. A result that names no path removes nothing (`UNCLAIMED`).

## 2026-10-21 — found during the run, outside this branch

3. **The isolation hook is the likely leak source on this machine** —
   `~/.claude/hooks/require_worktree_isolation.py` denies every Agent dispatch
   that has neither `isolation: "worktree"` nor a `READ-ONLY:` prompt line,
   and its message lists isolation first for any agent that "may run a
   probe". It has no form for a sequential writer (task 3.2's builders). The
   hook is Evan's global file; this branch does not edit it.
4. **Re-measured dispatch sites (L14 asked; recorded so "checked" reads
   differently from "forgotten")** — sites = files that declare a dispatch
   tier: `grep -l -E "model: (sonnet|opus|haiku)|no model override|model-pin:"
   plugins/cepa/commands/*.md plugins/cepa/skills/*/SKILL.md` → compound,
   compound-refresh, lfg, plan-review, review, task, the plan-review skill,
   and autonomy (the home). sweep and resolve-pr dispatch no agent themselves;
   sweep runs other commands and resolve-pr only suggests `/cepa:review`.

## 2026-10-21 — /cepa:review PR #88 findings deferred

Source: `todos/review-2026-10-21-090921.md` (34 findings; 28 applied on this
branch, 1 skipped, the 5 below deferred). Numbers are the findings file's.

5. **P2 #14 — builder worktrees are always kept** — same as item 1; lfg's
   wording now says so plainly.
6. **P2 #16 — a mutant that only crashes would count as killed** — none does
   today (python-reviewer counted); a `bash -n` pre-check is the guard when a
   mutant is added.
7. **P3 #22 — allowed-tools and a multi-statement block** — unverified in
   headless mode; the §10f probe has the same open question.
8. **P3 #31 — SITES is a per-file substring test** — a per-dispatch placement
   check is not built.
9. **P3 #32 — TOOLS reads one frontmatter shape** — CRLF or a YAML list is not
   parsed; matches check-coord-write-guard.sh.

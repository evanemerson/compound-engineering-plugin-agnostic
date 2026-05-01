---
description: "Full compound engineering loop: git audit → research learnings → plan → build → review → compound (feed learnings back). Orchestrates existing skills end-to-end."
---

# cepa:task — Compound Engineering Loop

Orchestrate the complete compound engineering loop from idea to merged PR. Each cycle's learnings feed back into the system, making the next cycle better.

**The loop:** Plan → Work → Review → Compound

**Announce at start:** "I'm using cepa:task to run the compound engineering loop."

---

## Phase 1: Git Safety Audit + Context Gathering

**Purpose:** Never start new work in a confused git state. Gather all available context before planning. Local git state is not enough — branches sit "done" on GitHub without being merged, and main lags behind.

### 1.1 Open PR Audit (FIRST — before local checks)

Branching from a stale main while same-author PRs are still open re-introduces problems on every cycle: cross-cutting infra (templates, design tokens, config) added in a prior PR is missing from the new branch, migration sequences collide, and service-layer ripple from prior PRs creates merge conflicts later.

**Run this FIRST, before the local git status check:**

```bash
gh pr list --author @me --state open --json number,title,headRefName,baseRefName,mergeable,reviewDecision
```

For each open PR, surface it to the user as part of the status report (Section 1.3). Pay special attention to **same-feature-arc** PRs — branches whose `headRefName` shares a prefix or phase indicator with the requested task (e.g. user requests "Phase B2" and PR #83 is "Phase B1 …" — almost certainly should merge first).

**Treat any same-author open PR with overlapping scope as a blocker** — do not silently proceed. Present a numbered choice:
1. Merge PR #N first, then start this work
2. Explicitly proceed without merging — I know about the overlap and accept the risk
3. Abandon this task

If no open PRs exist, note that and continue.

### 1.2 Local Git State Audit

Run these checks:

```bash
git status
git branch --show-current
git stash list
git diff --staged --stat
git diff --stat
git log --branches --not --remotes --oneline --decorate | head -10
```

Check for:
- Staged but uncommitted changes
- Unstaged modifications
- Untracked files that look important (not in .gitignore)
- Unpushed commits on any branch
- Current branch assessment (on main = good, on feature branch = warn)

### 1.3 Present Combined Status Report

```
## Git Status

**Branch:** main (clean)
**Uncommitted changes:** none
**Unpushed branches:** feat/old-thing (3 commits ahead)
**Stashes:** 1 stash (2 days old)

## Open PRs (same-author)

- #83 feat/phase-b1-tag-design — open, mergeable, approved  ← OVERLAPS with requested "Phase B2" work
- #91 fix/celery-beat-import — open, mergeable, no review yet

Ready to proceed? [Y / address issues first]
```

**If local issues found:** Present numbered choices:
1. Stash current changes and proceed
2. Commit current changes first
3. Abandon current changes (confirm destructive action)
4. Stay on current branch and work here instead

**If overlapping PRs found:** Present the blocker choice from 1.1.

**Only proceed after git state is clean, on main, AND no unmerged same-feature-arc PRs (or the user explicitly accepted the risk).**

### 1.4 GitHub Issue Context

If the user provides a GitHub issue number (or the task description references one):

```bash
gh issue view <number>
gh issue view <number> --comments
```

Pull in:
- Issue body (requirements, acceptance criteria)
- Discussion comments (clarifications, edge cases)
- Linked PRs (prior attempts, related work)

Include this context in the planning phase.

### 1.5 Create Branch

```bash
git checkout main
git pull origin main
git checkout -b <prefix>/<descriptive-name>
```

Branch prefix selection:
- `feat/` — new feature or capability
- `fix/` — bug fix
- `refactor/` — code restructuring, no behavior change
- `chore/` — tooling, deps, config

Ask the user for a short description if not provided with the task. Construct the branch name automatically.

---

## Phase 2: Research + Design (PLAN)

**This is the Plan phase of the compound loop.** Research what we already know, then design the approach.

### 2.1 Surface Past Learnings

**Before brainstorming, search institutional knowledge:**

Dispatch the `learnings-researcher` agent with the task description. It searches:
- `docs/solutions/` — past problems and fixes
- `CLAUDE.md` — existing rules and patterns
- `memory/tasks.md` — deferred items from prior tasks

Present relevant findings to the user:
```
## Relevant Past Learnings

1. [database-issues/pgbouncer-transaction-mode.md] — PgBouncer can't run migrations directly
2. [runtime-errors/celery-beat-import.md] — Beat tasks must be importable or errors loop

These will be factored into the design.
```

If no relevant learnings found, say so and move on.

### 2.2 Design

**Delegate to:** `superpowers:brainstorming`

This skill will:
1. Explore project context (now enriched with past learnings + issue context)
2. Ask clarifying questions (one at a time)
3. Propose 2-3 approaches with trade-offs
4. Present design sections for approval
5. Save design doc to `docs/plans/YYYY-MM-DD-<topic>-design.md`
6. Hand off to `superpowers:writing-plans`

**Do not skip this phase.** Even "simple" tasks get a brief design pass.

---

## Phase 3: Plan + Build (WORK)

### 3.1 Implementation Plan

**Delegate to:** `superpowers:writing-plans`

This skill will:
1. Create detailed TDD implementation plan
2. Break into bite-sized tasks (2-5 minutes each)
3. Save to `docs/plans/YYYY-MM-DD-<feature-name>.md`
4. Offer execution choice (subagent-driven or parallel session)

**Commit the plan before starting implementation:**
```bash
git add docs/plans/
git commit -m "docs: add implementation plan for <feature>"
```

### 3.2 Build

**Delegate to:** `superpowers:subagent-driven-development` (default, same session) OR `superpowers:executing-plans` (parallel session)

Let the user choose. Default to subagent-driven for same-session execution.

These skills handle:
- Task-by-task implementation
- TDD (test first, then implement)
- Spec compliance review
- Code quality review
- Commits per task

---

## Phase 4: Ship + Review (REVIEW)

### 4.1 Final Verification

```bash
# Run full test suite
<project test command from CLAUDE.md or Makefile>

# Run linter
<project lint command from CLAUDE.md or Makefile>
```

If tests or lint fail, fix before proceeding.

### 4.2 Push and Create PR

```bash
git push -u origin <branch-name>

gh pr create --title "<concise title>" --body "$(cat <<'EOF'
## Summary
<2-3 bullet points from the design/plan>

## Changes
<list of key changes>

## Test plan
<verification steps>
EOF
)"
```

### 4.3 Auto-Review

Run `/cepa:review` if `cepa.local.md` exists in the project, otherwise fall back to `/pr-review-toolkit:review-pr`.

### 4.4 Auto-Fix Critical Issues

After review completes:
- **P1 / Critical findings:** Fix immediately. Commit, push. No questions asked.
- **P2 / Important findings:** Present as numbered choices for user to approve/skip.
- **P3 / Suggestions:** List for awareness. Ask if user wants to address any.

If using cepa:review, run `/cepa:triage` for the interactive flow on P2/P3.

---

## Phase 5: Compound (COMPOUND)

**This is where the magic happens.** Feed learnings back into the system so the next loop is better.

### 5.1 Capture Learnings (always runs)

After every task, capture what was learned. Scale the effort to the task size:

**For small tasks (bug fixes, config changes):**
Quick inline capture — no full compound doc needed:
- What went wrong / what was the fix?
- Any surprise or non-obvious behavior?
- Should a rule be added to prevent recurrence?

**For medium/large tasks (features, refactors):**
Run `/cepa:compound` with the full 5-agent documentation flow.

### 5.2 Auto-Propose System Updates

Based on learnings (from compound docs or inline capture), **immediately propose concrete updates** — don't defer to "run another command later":

**CLAUDE.md rules:**
If a prevention strategy was identified, draft the rule and present it:
```
## Proposed CLAUDE.md Update

Add to Critical Rules section:
> ### Celery Beat
> - All Beat-scheduled tasks must be importable functions. Verify with `python -c "from apps.x.tasks import y"` before adding to schedule.

Apply this rule?
1. Yes — add to CLAUDE.md now
2. Modify first
3. Skip
```

**Review agent rules:**
If a pattern should be caught by review agents, propose adding it to `cepa.local.md`.

**Test guards:**
If a class of bug could be caught by a test, note it for the next task's planning phase.

### 5.3 Save Undone Items

Any P2/P3 findings that were skipped, plus any deferred items from the plan:

Save to project memory at `memory/tasks.md`:
```markdown
## Undone Items from <branch-name> (<date>)
1. [P2] Description — `file.py:line`
2. [P3] Description — `file.py:line`
3. [deferred] Description from plan
```

### 5.4 Final Status

```
## Loop Complete

**PR:** #<number> — <title>
**Branch:** <branch-name>
**Findings:** X fixed, Y deferred (saved to memory/tasks.md)
**Learnings:** <summary of what was documented>
**System updates:** X rules added to CLAUDE.md, Y items deferred

Next steps:
1. Merge the PR on GitHub
2. Start next task (/cepa:task)
3. Address deferred items
```

---

## Resuming a Task

If the user invokes `/cepa:task` on an existing feature branch (not main):
1. Skip Phase 1 branch creation
2. Check for an existing plan in `docs/plans/`
3. If plan exists, ask where to resume (which phase/task)
4. If no plan, start from Phase 2 (design)

---

## Rules

- **Never skip the git safety audit** — this is the whole point of Phase 1
- **Always audit open PRs first** — `gh pr list --author @me --state open` runs before local checks. Same-feature-arc unmerged PRs are a blocker, not a warning
- **Never skip design** — even for "simple" tasks, run brainstorming (it can be brief)
- **Always research learnings before planning** — check docs/solutions/ and CLAUDE.md
- **Always commit the plan** before implementation starts
- **Auto-fix P1s** — don't ask, just fix critical issues
- **Numbered choices for everything else** — user picks the number, you execute
- **One task in progress at a time** — don't parallelize implementation tasks
- **Always run compound** — scale the effort (inline for small, full for large), but never skip
- **Propose system updates immediately** — don't defer CLAUDE.md/rule updates to later
- **Save undone items** — nothing gets lost between sessions
- **Pull GitHub issue context** — if an issue number is available, use it

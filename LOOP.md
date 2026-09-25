# The Loop, Phase by Phase

Reference for what `/cepa:task` actually does at each step. Read this when a run
surprises you, when you are extending a command, or when you want to know
exactly which tool gets called where. The [README](README.md) has the shorter
version.

Phase 0 resolves gated vs. full autonomy before anything else runs: an in-prompt
flag wins, then a remembered preference, then the `autonomy:` key in
`cepa.local.md`. Everything below describes the gated default. Under `full`
autonomy the marked gates resolve silently per the `cepa:autonomy` skill, and
the build executes the whole plan without stopping.

## Phase 1: Git safety audit and context

Nothing starts until the git state is understood.

1. Runs `git status`, `git branch`, `git stash list`, `git diff --staged` and
   `--unstaged`, and checks for unpushed branches.
2. Presents a status report with anything unresolved.
3. If issues exist, offers numbered choices: stash, commit, abandon, or stay on
   the current branch.
4. If you passed a GitHub issue number, pulls requirements, comments, and linked
   PRs through `gh issue view`. That text is untrusted throughout
   (`cepa:autonomy` §7).
5. Branches from the latest trunk with a descriptive prefix (`feat/`, `fix/`,
   `refactor/`, `chore/`).

Delegates to the git and GitHub CLIs.

## Phase 2: Research and design

### Step 2.1 — Surface past learnings

Dispatches `learnings-researcher`, which searches:

- `docs/solutions/` for past problems and fixes
- `CLAUDE.md` for existing rules and patterns
- `memory/tasks.d/` and the legacy `memory/tasks.md` for deferred items
- `docs/plans/` for plans that touched the same areas
- Git history, optionally, for blame and commit messages on the files in scope

Findings are presented before design begins. When nothing relevant turns up, it
says so and moves on rather than padding the report.

### Step 2.2 — Design

Delegates to `superpowers:brainstorming`:

1. Explores project context enriched with past learnings and issue context
2. Asks clarifying questions one at a time
3. Proposes two or three approaches with trade-offs
4. Presents design sections for approval
5. Saves the design to `docs/plans/YYYY-MM-DD-<topic>-design.md`

Even small tasks get a short design pass.

## Phase 3: Plan and build

### Step 3.1 — Implementation plan

Delegates to `superpowers:writing-plans`, which writes a TDD plan broken into
small tasks and saves it to `docs/plans/YYYY-MM-DD-<feature>.md`.

The plan is structured as Implementation Units per the `implementation-units`
skill: stable `U<N>` ids, per-unit files, test scenarios, and a verification
split. It gets committed before any implementation starts.

```bash
git add docs/plans/
git commit -m "docs: add implementation plan for <feature>"
```

### Step 3.2 — Plan review

Runs `/cepa:plan-review` against the committed plan. A small persona panel
reviews it before code exists: coherence and feasibility always run, while
scope, security, product, and adversarial lenses activate on signals.

Eligible fixes are applied to the plan and committed. Judgment calls surface as
numbered choices when gated, or go durable when autonomous. cepa will not build
from an unreviewed plan.

### Step 3.3 — Build

Delegates to `superpowers:subagent-driven-development` in the same session, or
`superpowers:executing-plans` in a parallel session. You choose which.

Either one handles task-by-task implementation with tests written first, spec
compliance review, code quality review, and a commit per task.

## Phase 4: Ship and review

### Step 4.1 — Verification

Runs the project's test suite and linter. Failures get fixed before anything
proceeds.

### Step 4.2 — Push and open the PR

```bash
git push -u origin <branch-name>
gh pr create --title "<concise title>" --body "<summary from design/plan>"
```

### Step 4.3 — Review

When `cepa.local.md` exists, runs `/cepa:review`, which dispatches up to 16
review agents in parallel:

- Eight roster cepa agents: security-sentinel, performance-oracle,
  python-reviewer, data-integrity-guardian, architecture-reviewer,
  schema-drift-detector, frontend-reviewer, deployment-verifier
- Three conditional cepa agents dispatched by diff signals:
  adversarial-reviewer, reliability-reviewer, previous-comments-reviewer
- Five pr-review-toolkit agents: silent-failure-hunter, pr-test-analyzer,
  comment-analyzer, type-design-analyzer, code-simplifier

`learnings-researcher` runs first and feeds its findings to every review agent
as additional context. Results are deduplicated and written to
`todos/review-YYYY-MM-DD-HHMMSS.md` with P1/P2/P3 severity and confidence
scores.

Without `cepa.local.md`, it falls back to `/pr-review-toolkit:review-pr`.

### Step 4.4 — Fix by severity

- P1 critical findings are fixed immediately, then committed and pushed.
- P2 important findings become numbered choices to approve or skip.
- P3 suggestions are listed for awareness.

When cepa's own review ran, `/cepa:triage interactive` handles P2 and P3 one at
a time. Batch mode, the default, auto-applies safe verified fixes instead. Under
`full` autonomy the auto-apply rubric handles everything and files residuals
durably.

## Phase 5: Compound

This phase always runs and is never skipped. It is what makes the next task
cheaper than this one.

### Step 5.1 — Capture learnings

Scaled to the size of the task.

Small work like bug fixes and config changes gets a quick inline capture: what
broke, what fixed it, what surprised you, whether a rule should exist.

Features and refactors run `/cepa:compound`, which spawns five parallel
sub-agents (context analyzer, solution extractor, related docs finder,
prevention strategist, category classifier), assembles a solution doc, and saves
it to `docs/solutions/<category>/<filename>.md` with bidirectional links back to
the plan that produced it.

### Step 5.2 — Propose system updates

Learnings turn into concrete proposals right away.

A prevention strategy becomes a drafted CLAUDE.md rule with numbered choices to
apply, modify, or skip. A pattern that review agents should catch becomes a
proposed addition to `cepa.local.md`. A bug class a test could catch gets noted
for the next planning phase.

### Step 5.3 — Save undone items

Skipped P2 and P3 findings and deferred plan items land in a per-run shard under
`memory/tasks.d/`, one file per date and branch, so parallel worktree runs never
conflict (`cepa:autonomy` §5). The legacy single-file `memory/tasks.md` is still
read but no longer written.

### Step 5.4 — Final status

```
## Loop Complete

PR: #<number> — <title>
Branch: <branch-name>
Findings: X fixed, Y deferred (saved to the memory/tasks.d/ shard)
Learnings: <summary of what was documented>
System updates: X rules added to CLAUDE.md, Y items deferred

Next steps:
1. Merge the PR on GitHub
2. Start next task (/cepa:task)
3. Address deferred items
```

## Resuming

Run `/cepa:task` on an existing feature branch and it adapts: branch creation is
skipped, `docs/plans/` is checked for an existing plan, and you are asked which
phase to resume at. With no plan found, it starts over at Phase 2.

# CEPA — Compound Engineering Plugin Agnostic

Every bug you fix, every feature you ship, every review finding you address — what if each one made the next task easier?

That's compound engineering. Instead of treating each unit of work as isolated, you capture what you learned — what broke, why, how you fixed it, how to prevent it — and feed it back into the system. The next time you start a task, the system searches those learnings and surfaces relevant past experience before you write a line of code. Over time, your codebase accumulates institutional knowledge that prevents repeated mistakes and accelerates new work.

CEPA is a [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin that orchestrates this loop. One command — `/cepa:task` — runs the complete cycle: audit your git state, research past learnings, brainstorm and plan, build with TDD, review with parallel agents (8 from cepa plus 3 from pr-review-toolkit), document what you learned, and propose system updates to prevent recurrence. It works with any framework — Django, Next.js, FastAPI, Rails, or anything else — by reading a single per-project configuration file (`cepa.local.md`) that tells every agent what stack, compliance rules, and conventions to use.

## The Loop

```
Plan → Work → Review → Compound
  ↑                        |
  └────── learnings ───────┘
```

Each cycle produces solution documents. The next cycle's planning phase searches those documents before you start. The more you use it, the smarter it gets.

---

## What's Included

### Commands (4)

| Command | What It Does |
|---|---|
| `/cepa:task` | Full compound engineering loop orchestrator — runs all 5 phases end-to-end |
| `/cepa:review` | Spawn review agents in parallel (8 cepa + 3 pr-review-toolkit), collect findings with P1/P2/P3 severity |
| `/cepa:triage` | Interactively approve/skip each finding from review, one at a time |
| `/cepa:compound` | Document a solved problem with 5 parallel sub-agents |

### Agents (9)

**Research:**

| Agent | What It Does |
|---|---|
| `learnings-researcher` | Search `docs/solutions/`, `CLAUDE.md`, `memory/tasks.md`, and plans for relevant past learnings |

**Review:**

| Agent | What It Does |
|---|---|
| `security-sentinel` | OWASP top 10, compliance (HIPAA/SOC2/PCI), auth patterns, data exposure, input validation, secrets scanning |
| `performance-oracle` | N+1 queries, missing indexes, caching, task queue, frontend perf |
| `python-reviewer` | Pythonic patterns, framework conventions, logging compliance, testing |
| `data-integrity-guardian` | Migration safety, transactions, referential integrity, encryption |
| `architecture-reviewer` | Module boundaries, service layers, URL conventions, task queue placement |
| `schema-drift-detector` | Model/migration/serializer/admin alignment, missing migrations, index consistency |
| `frontend-reviewer` | Race conditions, event listener lifecycle, polling conflicts, CSS consistency, template correctness |
| `deployment-verifier` | Container config, env vars, static assets, backwards compatibility, rollback |

### Skills (2)

| Skill | What It Does |
|---|---|
| `compound-docs` | Solution document format, 8-category taxonomy, plan-solution bidirectional linking |
| `file-todos` | YAML frontmatter format for review findings in `todos/` |

---

## Install

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and configured
- GitHub CLI (`gh`) installed for PR creation and issue context

### Step 1: Install cepa

```bash
# Register the cepa marketplace
claude /plugin marketplace add evanemerson/compound-engineering-plugin-agnostic

# Install the plugin
claude /plugin install cepa
```

### Step 2: Install superpowers (required)

[Superpowers](https://github.com/obra/superpowers) by Jesse Vincent provides the brainstorm, plan, and execute workflow that cepa delegates to in Phases 2 and 3.

```bash
# Register the superpowers marketplace
claude /plugin marketplace add obra/superpowers-marketplace

# Install the plugin
claude /plugin install superpowers
```

### Step 3: Install pr-review-toolkit (required)

During review, cepa spawns 3 additional agents from pr-review-toolkit alongside its own 8 review agents. This plugin is in the built-in `claude-plugins-official` marketplace — no marketplace registration needed.

```bash
claude /plugin install pr-review-toolkit
```

### Step 4: Install recommended plugins (optional)

```bash
claude /plugin install commit-commands      # /commit, /commit-push-pr
claude /plugin install claude-md-management # /revise-claude-md
claude /plugin install code-review          # GitHub PR review
```

### Shortcut

To install everything at once, run `scripts/setup.sh` from this repo:

```bash
bash <(curl -s https://raw.githubusercontent.com/evanemerson/compound-engineering-plugin-agnostic/main/scripts/setup.sh)
```

### Update

```bash
claude /plugin update cepa
```

---

## Quick Start

### 1. Create `cepa.local.md` in your project root

```markdown
# cepa Project Configuration

## Stack
- framework: Django 5.x
- frontend: HTMX, vanilla JS, Tailwind CSS
- database: PostgreSQL 18
- testing: pytest-django
- linting: ruff

## Review Agents (Active)
- security-sentinel
- performance-oracle
- python-reviewer
- data-integrity-guardian
- architecture-reviewer
- schema-drift-detector
- frontend-reviewer
- deployment-verifier
```

See [docs/CONFIGURATION.md](docs/CONFIGURATION.md) for the full reference with examples for Next.js, FastAPI, Rails, and more.

### 2. Create project directories

```bash
mkdir -p docs/brainstorms docs/plans docs/solutions todos
```

### 3. Run your first task

```
/cepa:task add user authentication to the portal
```

cepa will: audit your git state → search past learnings → brainstorm the approach → write a plan → build with TDD → push and create a PR → review with parallel agents → document what was learned → propose system updates.

You can also use each command independently:

- `/cepa:review` — just run the review agents on your current changes
- `/cepa:compound` — just document a solved problem
- `/cepa:triage` — just review findings from a previous `/cepa:review`

---

## The 5 Phases

When you run `/cepa:task`, it orchestrates the complete compound engineering loop across 5 phases. Here's exactly what happens in each one.

### Phase 1: Git Safety Audit + Context Gathering

**Purpose:** Never start new work in a confused git state.

1. Runs `git status`, `git branch`, `git stash list`, `git diff --staged/unstaged`, checks for unpushed branches
2. Presents a status report with any issues found
3. If issues exist, presents numbered choices: stash, commit, abandon, or stay on current branch
4. If a GitHub issue number is provided, pulls requirements, comments, and linked PRs via `gh issue view`
5. Creates a branch from latest main with a descriptive prefix (`feat/`, `fix/`, `refactor/`, `chore/`)

**Delegates to:** git CLI, GitHub CLI

### Phase 2: Research + Design (PLAN)

**Purpose:** Surface institutional knowledge, then design the approach.

**Step 2.1 — Surface Past Learnings**

Dispatches the `learnings-researcher` agent, which searches:
- `docs/solutions/` — past problems and fixes
- `CLAUDE.md` — existing rules and patterns
- `memory/tasks.md` — deferred items from prior tasks
- `docs/plans/` — plans that touched the same areas
- Git history (optional) — blame and commit messages for files being modified

Presents relevant findings before design begins so past mistakes aren't repeated. If no relevant learnings are found, says so and moves on.

**Step 2.2 — Design**

Delegates to `superpowers:brainstorming`, which:
1. Explores project context enriched with past learnings and issue context
2. Asks clarifying questions one at a time
3. Proposes 2-3 approaches with trade-offs
4. Presents design sections for approval
5. Saves design doc to `docs/plans/YYYY-MM-DD-<topic>-design.md`

Even "simple" tasks get a brief design pass.

### Phase 3: Plan + Build (WORK)

**Purpose:** Create an implementation plan, then execute it.

**Step 3.1 — Implementation Plan**

Delegates to `superpowers:writing-plans`, which:
1. Creates a detailed TDD implementation plan
2. Breaks work into bite-sized tasks (2-5 minutes each)
3. Saves to `docs/plans/YYYY-MM-DD-<feature-name>.md`

The plan is committed before implementation starts:
```bash
git add docs/plans/
git commit -m "docs: add implementation plan for <feature>"
```

**Step 3.2 — Build**

Delegates to `superpowers:subagent-driven-development` (same session, default) or `superpowers:executing-plans` (parallel session). The user chooses.

These skills handle task-by-task implementation with TDD (test first, then implement), spec compliance review, code quality review, and commits per task.

### Phase 4: Ship + Review (REVIEW)

**Purpose:** Verify, push, create PR, run automated review, fix critical issues.

**Step 4.1 — Final Verification**

Runs the project's test suite and linter. If either fails, fixes before proceeding.

**Step 4.2 — Push and Create PR**

```bash
git push -u origin <branch-name>
gh pr create --title "<concise title>" --body "<summary from design/plan>"
```

**Step 4.3 — Auto-Review**

If `cepa.local.md` exists in the project, runs `/cepa:review`, which spawns up to 11 agents in parallel:

- **8 cepa agents:** security-sentinel, performance-oracle, python-reviewer, data-integrity-guardian, architecture-reviewer, schema-drift-detector, frontend-reviewer, deployment-verifier
- **3 pr-review-toolkit agents:** silent-failure-hunter, pr-test-analyzer, code-simplifier

The `learnings-researcher` runs first and feeds its findings as additional context to all review agents. Findings are deduplicated and written to `todos/review-YYYY-MM-DD-HHMMSS.md` with P1/P2/P3 severity.

If `cepa.local.md` doesn't exist, falls back to `/pr-review-toolkit:review-pr`.

**Step 4.4 — Auto-Fix by Severity**

- **P1 (Critical):** Fixed immediately, no questions asked. Commit and push.
- **P2 (Important):** Presented as numbered choices for the user to approve or skip.
- **P3 (Suggestions):** Listed for awareness. User picks what to address.

If cepa:review was used, runs `/cepa:triage` for the interactive flow on P2/P3 findings.

### Phase 5: Compound (COMPOUND)

**Purpose:** Feed learnings back into the system. Always runs. Never skipped. This is where the magic happens.

**Step 5.1 — Capture Learnings** (scaled by task size)

- **Small tasks (bug fixes, config changes):** Quick inline capture — what went wrong, what was the fix, any surprises, should a rule be added?
- **Medium/large tasks (features, refactors):** Runs `/cepa:compound`, which spawns 5 parallel sub-agents (context analyzer, solution extractor, related docs finder, prevention strategist, category classifier). Assembles a solution doc and saves to `docs/solutions/<category>/<filename>.md` with bidirectional links to the originating plan.

**Step 5.2 — Auto-Propose System Updates**

Based on learnings, immediately proposes concrete updates:

- **CLAUDE.md rules:** If a prevention strategy was identified, drafts the rule and presents numbered choices (apply / modify / skip)
- **Review agent rules:** If a pattern should be caught by review agents, proposes adding it to `cepa.local.md`
- **Test guards:** If a class of bug could be caught by a test, notes it for the next task's planning phase

**Step 5.3 — Save Undone Items**

Skipped P2/P3 findings and deferred plan items are saved to `memory/tasks.md` so nothing gets lost between sessions.

**Step 5.4 — Final Status**

```
## Loop Complete

PR: #<number> — <title>
Branch: <branch-name>
Findings: X fixed, Y deferred (saved to memory/tasks.md)
Learnings: <summary of what was documented>
System updates: X rules added to CLAUDE.md, Y items deferred

Next steps:
1. Merge the PR on GitHub
2. Start next task (/cepa:task)
3. Address deferred items
```

### Resuming a Task

If you invoke `/cepa:task` on an existing feature branch (not main):
1. Skips branch creation
2. Checks for an existing plan in `docs/plans/`
3. If a plan exists, asks which phase to resume at
4. If no plan, starts from Phase 2 (design)

---

## Dependencies

CEPA delegates to companion plugins for planning, execution, and additional review agents. These must be installed separately.

| Plugin | Source | What cepa uses |
|---|---|---|
| **superpowers** | [obra/superpowers-marketplace](https://github.com/obra/superpowers) | `brainstorming`, `writing-plans`, `subagent-driven-development`, `executing-plans` skills |
| **pr-review-toolkit** | claude-plugins-official | `review-pr` command (fallback), `silent-failure-hunter`, `pr-test-analyzer`, `code-simplifier` agents |

Optional but recommended:

| Plugin | Source | What it provides |
|---|---|---|
| commit-commands | claude-plugins-official | `/commit`, `/commit-push-pr` |
| claude-md-management | claude-plugins-official | `/revise-claude-md` |
| code-review | claude-plugins-official | GitHub PR review with scored findings |

---

## Per-Project Configuration

Create `cepa.local.md` in your project root. Every agent reads it and adapts to your stack.

```markdown
# cepa Project Configuration

## Stack
- framework: Django 5.x
- frontend: HTMX, vanilla JS, Tailwind CSS
- database: PostgreSQL 18
- async: Celery + Redis
- containers: Docker Compose
- testing: pytest-django
- linting: ruff

## Compliance
- hipaa: true
- phi_fields: [body_encrypted, notes]
- audit_model: AuditLog

## Review Agents (Active)
- security-sentinel
- performance-oracle
- python-reviewer
- data-integrity-guardian
- architecture-reviewer
- schema-drift-detector
- frontend-reviewer
- deployment-verifier
```

For the full reference with examples for Next.js, FastAPI, Rails, and a section-by-section guide, see [docs/CONFIGURATION.md](docs/CONFIGURATION.md).

---

## Project Directory Structure

Create these directories in your project:

```
your-project/
├── cepa.local.md          # Per-project config (commit to git)
├── docs/
│   ├── brainstorms/       # Design brainstorm docs
│   ├── plans/             # Implementation plans
│   └── solutions/         # Solution docs (auto-categorized)
│       ├── build-errors/
│       ├── database-issues/
│       ├── runtime-errors/
│       ├── performance-issues/
│       ├── security-issues/
│       ├── ui-bugs/
│       ├── integration-issues/
│       └── logic-errors/
└── todos/                 # Review findings
```

Quick setup:
```bash
mkdir -p docs/brainstorms docs/plans docs/solutions todos
touch docs/brainstorms/.gitkeep docs/plans/.gitkeep docs/solutions/.gitkeep todos/.gitkeep
```

---

## Acknowledgments

This plugin is built on the ideas from [Compound Engineering](https://github.com/EveryInc/compound-engineering-plugin) by [Kieran Klaassen](https://github.com/kieranklaassen). His original plugin introduced the compound engineering workflow — the plan/work/review/compound loop, the parallel review agents, the solution documentation pattern, and the concept that each unit of work should make subsequent work easier. The agent architectures, review categories, and documentation format in CEPA are directly adapted from his work.

I came across the original plugin while working on a Django project and found that many of the agents were built around Ruby on Rails conventions — `schema.rb` drift detection, DHH-style code review, StandardRB linting, Hotwire/Turbo race conditions. Rather than fork and rewrite, I wanted an agnostic version where a single configuration file (`cepa.local.md`) could tell every agent what stack, compliance rules, and conventions to use. Same ideas, any framework.

I also wanted to lean on companion plugins for everything they already cover well — [Superpowers](https://github.com/obra/superpowers) for brainstorming, planning, execution, and TDD; the [official Anthropic plugins](https://github.com/anthropics/claude-plugins-official) for PR review, commits, and CLAUDE.md management — and only build custom agents for the gaps. CEPA handles the review-triage-document cycle and the orchestration loop. The companion plugins handle everything else. Together they cover the full compound engineering workflow without reinventing what already exists.

As for the name: **C**ompound **E**ngineering **P**lugin **A**gnostic. I needed something short enough that `/cepa:review` wouldn't wear out my keyboard, and descriptive enough that I'd remember what it stands for in six months.

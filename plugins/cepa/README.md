# cepa

Compound engineering plugin for Claude Code. Orchestrates the full engineering loop — Plan, Work, Review, Compound — with parallel review agents, solution documentation, and interactive triage.

## The Compound Engineering Loop

Every task follows the same cycle. Each cycle's learnings feed back into the system, making the next one better.

```
Plan → Work → Review → Compound
  ↑                        |
  └────── learnings ───────┘
```

### Phase 1: Git Safety Audit + Context Gathering
- Checks for uncommitted changes, unpushed branches, stashes, current branch state
- Presents numbered choices if issues found
- Pulls GitHub issue context via `gh issue view` when an issue number is provided
- Creates a properly-prefixed branch (`feat/`, `fix/`, `refactor/`, `chore/`)

### Phase 2: Research + Design (PLAN)
- Runs `learnings-researcher` agent to surface past solutions from `docs/solutions/`
- Delegates to `superpowers:brainstorming` for design exploration
- Delegates to `superpowers:writing-plans` for implementation planning
- Saves design docs to `docs/plans/`

### Phase 3: Plan + Build (WORK)
- Commits the plan before implementation starts
- Delegates to `superpowers:subagent-driven-development` (same session) or `superpowers:executing-plans` (parallel session)
- TDD-driven: test first, then implement
- Commits logical chunks as it goes

### Phase 4: Ship + Review (REVIEW)
- Pushes branch, creates PR via `gh pr create`
- Auto-runs `/cepa:review` (or `/pr-review-toolkit:review-pr` as fallback)
- P1/Critical findings: auto-fixed immediately
- P2/P3 findings: presented as numbered choices

### Phase 5: Compound (COMPOUND)
- **Always runs** — this is where the magic happens
- Small tasks: inline capture (what broke, what fixed it, any surprises)
- Large tasks: full `/cepa:compound` with 5 parallel documentation agents
- Auto-proposes CLAUDE.md rule updates when prevention strategies are identified
- Saves undone items to `memory/tasks.md` for the next session

## What's Included

### Commands (4)
| Command | Purpose |
|---|---|
| `/cepa:task` | Full compound engineering loop orchestrator (Plan → Work → Review → Compound) |
| `/cepa:review` | Run all active review agents in parallel, collect findings in `todos/` |
| `/cepa:triage` | Interactively approve/skip each finding from review |
| `/cepa:compound` | Document a solved problem with 5 parallel sub-agents |

### Research Agents (1)
| Agent | Purpose |
|---|---|
| `learnings-researcher` | Search `docs/solutions/` for relevant past learnings before new work |

### Review Agents (8)
| Agent | Purpose |
|---|---|
| `security-sentinel` | OWASP top 10, compliance checks, PHI/PII exposure |
| `performance-oracle` | N+1 queries, missing indexes, caching, frontend perf |
| `python-reviewer` | Pythonic patterns, framework conventions, logging |
| `data-integrity-guardian` | Migration safety, transactions, encryption |
| `architecture-reviewer` | Module boundaries, service layers, URL conventions |
| `schema-drift-detector` | Model/migration/serializer alignment |
| `frontend-reviewer` | Race conditions, event lifecycle, CSS consistency |
| `deployment-verifier` | Container config, env vars, rollback safety |

### Skills (2)
| Skill | Purpose |
|---|---|
| `compound-docs` | Solution document format, categories, plan-solution linking |
| `file-todos` | Structured YAML frontmatter format for review findings in `todos/` |

## Dependencies

This plugin delegates to skills from other installed plugins:

| Plugin | Skills Used |
|---|---|
| `superpowers` | `brainstorming`, `writing-plans`, `executing-plans`, `subagent-driven-development`, `finishing-a-development-branch`, `test-driven-development` |
| `pr-review-toolkit` | `review-pr` (fallback when `cepa.local.md` doesn't exist) |

## Framework-Agnostic

All agents read `cepa.local.md` from the project root. Configure your stack, compliance rules, and conventions there. Agents adapt automatically.

## Per-Project Setup

Create `cepa.local.md` in your project root:

```markdown
# cepa Project Configuration

## Stack
- framework: Django 5.x
- frontend: HTMX, vanilla JS, Tailwind CSS
- database: PostgreSQL 18
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

## Directory Structure

The plugin expects these directories in your project (create them):

```
docs/
├── brainstorms/    # Design brainstorm docs
├── plans/          # Implementation plans
└── solutions/      # Compound solution docs (auto-categorized)
todos/              # Review findings
```

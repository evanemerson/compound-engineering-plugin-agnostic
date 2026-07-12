# cepa

Compound engineering plugin for Claude Code. Orchestrates the full engineering loop — Plan, Work, Review, Compound — with parallel review agents, solution documentation, batch-first triage, and optional hands-off execution (autonomy contract + /cepa:lfg).

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
- P2/P3 findings: presented as numbered choices (gated mode); in `full` autonomy, safe verified fixes auto-apply and the rest are filed durably per the `autonomy` skill

### Phase 5: Compound (COMPOUND)
- **Always runs** — this is where the magic happens
- Small tasks: inline capture (what broke, what fixed it, any surprises)
- Large tasks: full `/cepa:compound` with 5 parallel documentation agents
- Auto-proposes CLAUDE.md rule updates when prevention strategies are identified
- Saves undone items to `memory/tasks.md` for the next session

## What's Included

### Commands (10)
| Command | Purpose |
|---|---|
| `/cepa:task` | Full compound engineering loop orchestrator (Plan → Work → Review → Compound), gated or autonomous |
| `/cepa:plan-review` | Persona-panel review of a plan before build; findings in the standard todos/ format (supports `mode:headless`) |
| `/cepa:sweep` | Scheduled residual sweep — drains the sinks through lfg runs and closes items everywhere they're filed (supports `mode:headless`) |
| `/cepa:resolve-pr` | Judge and resolve human PR review feedback per the autonomy rubric (supports `mode:headless`) |
| `/cepa:review` | Run all active review agents in parallel, collect findings in `todos/` (supports `mode:headless`) |
| `/cepa:triage` | Triage findings — batch auto-apply by default, `interactive` for one-at-a-time |
| `/cepa:compound` | Document a solved problem with 5 parallel sub-agents; seeds CONCEPTS.md (supports `mode:headless`) |
| `/cepa:compound-refresh` | Refresh `docs/solutions/` — update drifted learnings, consolidate overlap, prune dead docs, reconcile CONCEPTS.md (supports `mode:headless`) |
| `/cepa:lfg` | **BETA** — hands-off pipeline: build all, review-fix until clean, PR, CI-green loop, compound, one report |
| `/cepa:setup` | Project health check + scaffold/CI bootstrap (`fix` to apply) |

### Research Agents (1)
| Agent | Purpose |
|---|---|
| `learnings-researcher` | Search `docs/solutions/` for relevant past learnings before new work |

### Review Agents (11 — 8 roster + 3 conditional)
| Agent | Purpose |
|---|---|
| `security-sentinel` | OWASP top 10, compliance checks, PHI/PII exposure |
| `performance-oracle` | N+1 queries, missing indexes, caching, frontend perf |
| `python-reviewer` | Pythonic patterns, framework conventions, logging |
| `data-integrity-guardian` | Migration safety, transactions, encryption |
| `architecture-reviewer` | Module boundaries, service layers, URL conventions |
| `schema-drift-detector` | Model/migration/serializer alignment |
| `frontend-reviewer` | Race conditions, event lifecycle, CSS consistency |
| `deployment-verifier` | Container config, env vars — Go/No-Go verdict + rollback plan |

Conditional tier — dispatched by diff signals, no roster listing needed
(opt out with `- !agent-name`):

| Agent | Purpose |
|---|---|
| `adversarial-reviewer` | Failure-scenario construction on large/risky diffs (payments, auth, PHI, migrations) |
| `reliability-reviewer` | Retries, timeouts, idempotency, races on queue/webhook/transaction code |
| `previous-comments-reviewer` | Verifies prior review findings weren't lost or re-broken |

### Skills (8)
| Skill | Purpose |
|---|---|
| `compound-docs` | Solution document format (mandatory Detection sections), categories, plan-solution linking, CONCEPTS.md vocabulary map |
| `file-todos` | Structured YAML frontmatter format for review findings in `todos/`, with confidence + action-class scoring |
| `autonomy` | The autonomy contract shared by task/lfg/review/triage — gate resolution, execution (parallel safety, idempotency), evidence, auto-apply, residuals |
| `implementation-units` | Canonical plan-task format: stable `U<N>` ids, per-unit test scenarios, verification split |
| `plan-review` | Persona roster, activation signals, and synthesis rules for `/cepa:plan-review` |
| `pr-feedback` | Fetch model, six-verdict rubric, reply conventions, and vendored gh scripts for `/cepa:resolve-pr` |
| `grounding` | Optional graphify code-graph provider — availability checks, refresh, invocation discipline, consumer table; degrades to grep when absent |
| `brain` | Optional OB1 cross-repo memory provider (opt-in per repo) — recall/writeback over the Agent Memory API, evidence-only governance, PHI scrub, §7 relay; degrades to grep when absent |

## Dependencies

This plugin delegates to skills from other installed plugins:

| Plugin | Skills Used |
|---|---|
| `superpowers` | `brainstorming`, `writing-plans`, `executing-plans`, `subagent-driven-development`, `finishing-a-development-branch`, `test-driven-development` |
| `pr-review-toolkit` | `review-pr` (fallback), plus companion review agents: `silent-failure-hunter`, `pr-test-analyzer`, `comment-analyzer`, `type-design-analyzer`, `code-simplifier` |

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

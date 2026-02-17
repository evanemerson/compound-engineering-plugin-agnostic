# CEPA — Compound Engineering Plugin Agnostic

A framework-agnostic [Claude Code](https://claude.ai/code) plugin for compound engineering workflows. Run parallel review agents, document solved problems, and interactively triage findings — on any stack.

Every agent reads a single per-project configuration file (`cepa.local.md`) to adapt its checks to your framework, database, compliance requirements, and conventions. Switch from Django to Next.js? Change the config file, not the plugin.

## Install

```bash
# Register the marketplace (one-time per machine)
claude /plugin marketplace add https://github.com/evanemerson/compound-engineering-plugin-agnostic

# Install the plugin
claude /plugin install cepa
```

## Update

```bash
claude /plugin update cepa
```

---

## What's Included

### Research Agents (1)

| Agent | What It Does |
|---|---|
| `learnings-researcher` | Searches `docs/solutions/` for relevant past learnings before new work begins. This is the core compounding mechanism — without it, solution docs are written but never consulted. |

### Review Agents (8)

| Agent | What It Does |
|---|---|
| `security-sentinel` | OWASP top 10 adapted to your framework, compliance checks (HIPAA, SOC2, PCI), PHI/PII exposure in logs and API responses, auth pattern verification |
| `performance-oracle` | N+1 query detection for your ORM, missing indexes on filtered/ordered fields, task queue optimization, caching opportunities, frontend performance |
| `python-reviewer` | Pythonic patterns, framework conventions (Django fat models, FastAPI dependency injection), logging library compliance, error handling, testing patterns |
| `data-integrity-guardian` | Migration safety (reversibility, table locking, destructive ops), transaction boundaries, referential integrity, encryption compliance for PHI fields |
| `architecture-reviewer` | Module boundary violations, service layer consistency, template hierarchy, URL conventions, signal/event patterns, task queue placement |
| `schema-drift-detector` | Model vs migration state, missing migrations, index consistency, serializer/admin/form alignment, container vs host migration state |
| `frontend-reviewer` | Race conditions (HTMX, React, vanilla JS), event listener lifecycle, polling conflicts, CSS framework consistency, accessibility |
| `deployment-verifier` | Container config, pending migrations, static asset pipeline, environment variable completeness, backwards compatibility, rollback safety |

### Commands (3)

| Command | What It Does |
|---|---|
| `/cepa:review` | Runs `learnings-researcher` first, then spawns all active review agents in parallel on your current changes. Collects findings with P1/P2/P3 severity, deduplicates, and writes structured results to `todos/`. |
| `/cepa:compound` | Documents a solved problem using 5 parallel sub-agents (context analyzer, solution extractor, related docs finder, prevention strategist, category classifier). Creates a solution doc with bidirectional plan linking. |
| `/cepa:triage` | Interactive review of findings from `/cepa:review`. Presents each finding one at a time (P1 first). You approve, skip, or customize each one. |

### Skills (2)

| Skill | What It Does |
|---|---|
| `compound-docs` | Defines the solution document format: YAML frontmatter schema, 8 category taxonomy, writing guidelines, and bidirectional plan-solution linking rules. |
| `file-todos` | Defines the structured format for review findings in `todos/`: YAML frontmatter with summary counts, consistent finding fields, status lifecycle (pending/ready/skipped/completed). |

---

## Designed to Work With Official Plugins

CEPA handles the review-triage-document cycle. For the rest of the engineering workflow, use Claude's official plugins:

| Workflow Step | Official Plugin | Command |
|---|---|---|
| Brainstorm a feature | `superpowers` | `/brainstorm` |
| Write an implementation plan | `superpowers` | `/write-plan` |
| Execute the plan (TDD) | `superpowers` | `/execute-plan` |
| **Review changes** | **cepa** | **`/cepa:review`** |
| **Triage findings** | **cepa** | **`/cepa:triage`** |
| **Document what you learned** | **cepa** | **`/cepa:compound`** |
| Post review on GitHub PR | `code-review` | `/code-review` |
| Commit and create PR | `commit-commands` | `/commit-push-pr` |
| Update CLAUDE.md | `claude-md-management` | `/revise-claude-md` |

### Recommended Official Plugins

```bash
claude /plugin install superpowers          # Brainstorm, plan, execute, TDD, debugging
claude /plugin install code-review          # GitHub PR review with scored findings
claude /plugin install pr-review-toolkit    # 6 additional review agents
claude /plugin install commit-commands      # /commit, /commit-push-pr
claude /plugin install claude-md-management # /revise-claude-md
claude /plugin install security-guidance    # Security pattern hooks on file edits
claude /plugin install pyright-lsp          # Python type checking
claude /plugin install ralph-loop           # Iterative autonomous loops
```

---

## Per-Project Configuration: `cepa.local.md`

This is the file that makes everything agnostic. Create `cepa.local.md` in your project root and commit it to git. Every agent reads this file at the start of every review and adapts its checks accordingly.

### Full Reference

```markdown
# cepa Project Configuration

## Stack
- framework: <your framework>
- frontend: <your frontend libraries>
- bundler: <your build tool>
- database: <your database>
- async: <your task queue>
- containers: <your container platform>
- testing: <your test framework>
- linting: <your linter>

## Compliance
- hipaa: <true/false>
- phi_fields: [<list of encrypted model fields>]
- audit_model: <your audit log model>
- audit_function: <how to call audit logging>
- encryption_functions: [<list of encryption/decryption functions>]
- logging_library: <structlog, logging, winston, pino, etc.>

## Conventions
- context_banned_names: [<variable names that shadow framework builtins>]
- base_templates: [<list of base templates by audience>]
- service_layer: <true/false>
- docker_compose_file: <path to your dev compose file>

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

### Section-by-Section Guide

#### Stack

Tell agents what you're building with. Every field is optional — agents use what's relevant and ignore the rest.

**Django + HTMX project:**
```markdown
## Stack
- framework: Django 5.x
- frontend: HTMX, vanilla JS, Tailwind CSS
- bundler: Vite (django_vite)
- database: PostgreSQL 18
- async: Celery + Redis
- containers: Docker Compose
- testing: pytest-django
- linting: ruff
```

**Next.js project:**
```markdown
## Stack
- framework: Next.js 15
- frontend: React, TypeScript, Tailwind CSS
- bundler: Turbopack
- database: Supabase (PostgreSQL)
- async: Vercel Cron
- containers: none (Vercel)
- testing: vitest
- linting: eslint + prettier
```

**FastAPI project:**
```markdown
## Stack
- framework: FastAPI 0.110
- frontend: none (API only)
- database: PostgreSQL 16 (SQLAlchemy)
- async: native async (no task queue)
- containers: Docker Compose
- testing: pytest + httpx
- linting: ruff
```

**Rails project:**
```markdown
## Stack
- framework: Rails 8.0
- frontend: Hotwire (Turbo + Stimulus), Tailwind CSS
- bundler: esbuild
- database: PostgreSQL 17
- async: Sidekiq + Redis
- containers: Docker Compose
- testing: RSpec
- linting: StandardRB
```

How agents use this:
- `performance-oracle` checks for N+1 patterns specific to your ORM (`select_related` for Django, `includes` for Rails, `joinedload` for SQLAlchemy)
- `python-reviewer` adapts to your framework's conventions (fat models for Django, dependency injection for FastAPI)
- `frontend-reviewer` checks for race conditions specific to your frontend (HTMX swap conflicts, React stale closures, Turbo Stream issues)
- `deployment-verifier` checks container config if `containers` is set, skips it if not

#### Compliance

If your project handles sensitive data, configure compliance rules. Agents will enforce them during review.

**HIPAA-compliant healthcare app:**
```markdown
## Compliance
- hipaa: true
- phi_fields: [body_encrypted, notes, diagnosis, ssn]
- audit_model: AuditLog
- audit_function: AuditLog.log()
- encryption_functions: [encrypt_value, decrypt_value]
- logging_library: structlog
```

**SOC2 SaaS app:**
```markdown
## Compliance
- soc2: true
- pii_fields: [email, phone, address]
- audit_model: AuditTrail
- audit_function: AuditTrail.record()
- logging_library: winston
```

**No compliance requirements:**
Omit the section entirely. Agents will skip compliance checks.

How agents use this:
- `security-sentinel` verifies PHI/PII fields are encrypted, never logged, never sent to external services
- `data-integrity-guardian` checks that encryption functions are used on listed fields and that audit logging covers all PHI access
- `python-reviewer` ensures the configured logging library is used consistently

#### Conventions

Project-specific rules that don't fit into stack or compliance.

```markdown
## Conventions
- context_banned_names: [messages]
- base_templates: [base.html, portal/base_portal.html, admin/base_admin.html]
- service_layer: true (business logic in services/, not views)
- docker_compose_file: docker-compose.dev.yml
```

- `context_banned_names`: Variable names that shadow framework builtins. In Django, `context['messages']` shadows the messages framework. Agents will flag any use of these names.
- `base_templates`: Your template hierarchy. `architecture-reviewer` verifies new templates extend the correct base.
- `service_layer`: If true, `architecture-reviewer` enforces that business logic lives in `services/`, not in views or serializers.
- `docker_compose_file`: Which compose file to check. `deployment-verifier` and `schema-drift-detector` use this for container-related checks.

#### Review Agents (Active)

Control which agents run during `/cepa:review`. Comment out or remove agents you don't need.

**All agents (default):**
```markdown
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

**API-only project (no frontend):**
```markdown
## Review Agents (Active)
- security-sentinel
- performance-oracle
- python-reviewer
- data-integrity-guardian
- architecture-reviewer
- schema-drift-detector
- deployment-verifier
```

**Quick review (security + performance only):**
```markdown
## Review Agents (Active)
- security-sentinel
- performance-oracle
```

The `learnings-researcher` always runs regardless of this list — it's not a review agent, it's the knowledge retrieval step that feeds context to the others.

---

## Project Directory Structure

Create these directories in your project and commit them to git:

```
your-project/
├── cepa.local.md          # Per-project config (commit to git)
├── docs/
│   ├── brainstorms/       # Design brainstorm docs (from superpowers:/brainstorm)
│   ├── plans/             # Implementation plans (from superpowers:/write-plan)
│   └── solutions/         # Solution docs (from /cepa:compound)
│       ├── build-errors/
│       ├── database-issues/
│       ├── runtime-errors/
│       ├── performance-issues/
│       ├── security-issues/
│       ├── ui-bugs/
│       ├── integration-issues/
│       └── logic-errors/
└── todos/                 # Review findings (from /cepa:review)
```

Quick setup:
```bash
mkdir -p docs/brainstorms docs/plans docs/solutions todos
touch docs/brainstorms/.gitkeep docs/plans/.gitkeep docs/solutions/.gitkeep todos/.gitkeep
```

---

## The Compound Loop

The idea behind compound engineering is that each unit of work makes the next one easier:

```
1. Plan    ──→  superpowers:/write-plan
2. Work    ──→  superpowers:/execute-plan
3. Review  ──→  /cepa:review  →  /cepa:triage
4. Learn   ──→  /cepa:compound  (writes to docs/solutions/)
        │
        └──→  learnings-researcher reads docs/solutions/
              before the next unit of work starts
```

Step 4 feeds back into step 1. The `learnings-researcher` agent searches your solution docs at the start of every review, surfacing relevant past mistakes and patterns. Over time, the system accumulates institutional knowledge that prevents repeated errors.

---

## Acknowledgments

This plugin is built on the ideas from [Compound Engineering](https://github.com/EveryInc/compound-engineering-plugin) by [Kieran Klaassen](https://github.com/kieranklaassen). His original plugin introduced the compound engineering workflow — the plan/work/review/compound loop, the parallel review agents, the solution documentation pattern, and the concept that each unit of work should make subsequent work easier. The agent architectures, review categories, and documentation format in CEPA are directly adapted from his work.

I came across the original plugin while working on a Django project and found that many of the agents were built around Ruby on Rails conventions — `schema.rb` drift detection, DHH-style code review, StandardRB linting, Hotwire/Turbo race conditions. Rather than fork and rewrite, I wanted an agnostic version where a single configuration file (`cepa.local.md`) could tell every agent what stack, compliance rules, and conventions to use. Same ideas, any framework.

I also wanted to lean on Claude's official plugins (`superpowers`, `code-review`, `pr-review-toolkit`, `commit-commands`, etc.) for everything they already cover well — brainstorming, planning, execution, TDD, PR review — and only build custom agents for the gaps. CEPA handles the review-triage-document cycle. The official plugins handle everything else. Together they cover the full compound engineering workflow without reinventing what already exists.

As for the name: yes, it's another acronym. **C**ompound **E**ngineering **P**lugin **A**gnostic. I needed something short enough that `/cepa:review` wouldn't wear out my keyboard, and descriptive enough that I'd remember what it stands for in six months. If the acronym steps on any toes out there — sorry, I just really didn't want to type `/compound-engineering-plugin-agnostic:review` forty times a day.

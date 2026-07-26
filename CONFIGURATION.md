# cepa.local.md Configuration Reference

This is the file that makes cepa framework-agnostic. Create `cepa.local.md` in your project root and commit it to git. Every agent reads this file at the start of every review and adapts its checks accordingly.

## Full Reference

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

## Autonomy
- autonomy: <full/gated>

## Integrations
- qa: <skill to verify frontend changes in a browser, e.g. /qa>
- second_opinion: <skill for an independent review on high-risk diffs, e.g. /codex>
- post_deploy: <skill to verify production after merge, e.g. /canary>
- debugging: <skill for root-cause investigation, e.g. /investigate>
```

## Section-by-Section Guide

### Stack

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

### Compliance

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

### Conventions

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

### Review Agents (Active)

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

The `learnings-researcher` runs regardless of this list on a normal review — it's not a review agent, it's the knowledge retrieval step that feeds context to the others. (The one exception is a `cadence:weekly` run, which skips it — see below.)

**Conditional-tier agents** (`adversarial-reviewer`, `reliability-reviewer`,
`previous-comments-reviewer`) are NOT listed here — they dispatch
automatically when their diff signal fires (see the review command's
"Conditional tier" section). To disable one for a project, add an exclusion
line to this section:

```markdown
## Review Agents (Active)
- security-sentinel
- performance-oracle
- !adversarial-reviewer    # never dispatch in this project
```

**Removing a roster-tier agent:** delete or comment the line. The `!` prefix
only excludes conditional-tier agents — writing `- python-reviewer — not a
Python project` does NOT exclude it, it corrupts the agent name. `/cepa:setup`
flags names with trailing prose as unknown for exactly this reason.

### Review Agents (Weekly)

Optional second roster for the **debt tier** — agents whose findings are
accumulated debt rather than merge-blocking defects. Dispatched only by
`/cepa:review cadence:weekly`, never on a PR.

```markdown
## Review Agents (Weekly)
- code-simplifier
- comment-analyzer
- type-design-analyzer
```

Good candidates: `code-simplifier` (simplification opportunities),
`comment-analyzer` (comment rot), `type-design-analyzer` (already documented
as "use when new types/models are added" — it was never meant to be
unconditional).

Keep in `Active`, never here: `security-sentinel`, `data-integrity-guardian`,
`schema-drift-detector`, `deployment-verifier`, `silent-failure-hunter`.
These catch defects that cost far more to fix after merge, and
`deployment-verifier` additionally owns the `deploy_verdict` that
`/cepa:lfg` refuses to ship past.

**On a compliance project** (`hipaa: true` or declared `phi_fields`),
`security-sentinel` and `data-integrity-guardian` must stay in `Active` —
`/cepa:setup` enforces this, and `cepa:autonomy` §4's compliance carve-out
assumes they ran on the diff.

A weekly run reviews the last 7 days of main-branch commits, skips the
`learnings-researcher` and the conditional tier, and files findings to
`todos/review-weekly-*.md` as `status: deferred` — the state `/cepa:sweep`
drains. Schedule it staggered ahead of your sweep:

```bash
claude -p "/cepa:review cadence:weekly mode:headless"
```

If this section is missing or empty, `cadence:weekly` exits without
reviewing anything rather than falling back to the `Active` roster — and
records a dated one-liner in `memory/tasks.md` so the misconfiguration is
visible instead of looking like a quiet week. `/cepa:setup` also scans for
near-miss headings (`## Review Agents (weekly)`, `## Weekly Review Agents`),
since those read as "absent" to the parser and would fail-close a scheduled
run silently.

### Autonomy

Controls whether `/cepa:task` runs with interactive gates or hands-off. See
the `cepa:autonomy` skill for the full contract.

```markdown
## Autonomy
- autonomy: full
```

- `full` — the loop completes every plan task, auto-applies safe verified
  review fixes (mechanical/corroborated, confidence ≥ 75), files everything
  else durably to `memory/tasks.md` + the findings file + the PR body, and
  delivers one consolidated report. Destructive actions still gate.
- `gated` (default) — numbered choices and per-finding triage (`/cepa:triage interactive`), as before.

Resolution order (first match wins): an in-prompt request
(`auto` / `confirm:auto` / `confirm:ask`) → a remembered user preference
already in context → this key → default `gated`. `/cepa:lfg` is always
fully autonomous regardless of this key.

### Integrations

Optional stage providers for the loop. Each entry names a skill the loop
uses **when it is installed** — missing entries or uninstalled skills are
skipped silently, so the loop is complete without any of them.

```markdown
## Integrations
- qa: /qa                    # browser QA on frontend-touching diffs (review phase)
- second_opinion: /codex     # independent review on billing/auth/PHI diffs (review phase)
- post_deploy: /canary       # production verification after merge
- debugging: /investigate    # root-cause investigation entry point for bug tasks
```

How the loop uses them: `/cepa:review` Step 3 ("Integration Dispatch")
invokes `qa` when the diff touches templates/JS/CSS and `second_opinion`
when it touches payment, auth, or PHI-flagged paths — `/cepa:lfg` inherits
both through its review rounds; `/cepa:task` Phase 5.4 adds a `post_deploy`
next step after merge, and its Phase 2.1 routes bug-shaped tasks through
`debugging` before design. `second_opinion` adds review coverage only — it
never loosens the absolute compliance carve-out (compliance-sensitive
findings stay `judgment`).

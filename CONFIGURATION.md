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

The `learnings-researcher` always runs regardless of this list — it's not a review agent, it's the knowledge retrieval step that feeds context to the others.

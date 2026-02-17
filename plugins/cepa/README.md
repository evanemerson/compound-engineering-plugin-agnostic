# cepa

Compound engineering plugin for Claude Code. Provides parallel review agents, solution documentation, and interactive triage.

## What's Included

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

### Commands (3)
| Command | Purpose |
|---|---|
| `/cepa:review` | Run all active agents in parallel, collect findings |
| `/cepa:compound` | Document a solved problem with 5 sub-agents |
| `/cepa:triage` | Interactively approve/skip findings from review |

### Skills (2)
| Skill | Purpose |
|---|---|
| `compound-docs` | Solution document format, categories, plan-solution linking |
| `file-todos` | Structured YAML frontmatter format for review findings in `todos/` |

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

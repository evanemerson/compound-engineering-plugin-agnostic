---
name: file-todos
description: Structured YAML frontmatter format for review findings in todos/. Used by /cepa:review and /cepa:triage commands.
---

# File-Based Todo Tracking

## Overview

Define the structured format for review findings stored in `todos/`. Each review run produces one file. Findings use YAML frontmatter for machine-parseable metadata and markdown body for human-readable detail.

## File Format

### Filename Convention

```
todos/review-YYYY-MM-DD-HHMMSS.md
```

### Document Structure

```markdown
---
date: 2026-02-17T14:30:00
scope: feature/billing-phase-7
branch: dev
agents:
  - learnings-researcher
  - security-sentinel
  - performance-oracle
  - python-reviewer
summary:
  total: 12
  p1: 2
  p2: 5
  p3: 5
  pending: 12
  ready: 0
  skipped: 0
---

# Review Findings — 2026-02-17 14:30

## Findings

### 1
- status: pending
- severity: P1
- agent: security-sentinel
- category: Compliance
- confidence: 90
- action_class: corroborated
- file: backend/apps/communications/views/thread.py
- lines: 42-48
- title: PHI exposed in log statement

**Problem:**
Patient name is included in a structlog info call...

**Fix:**
Remove patient name from log parameters...

### 2
- status: pending
- severity: P2
- agent: performance-oracle
- category: Database
- file: backend/apps/billing/views.py
- lines: 155-170
- title: N+1 query in payment list view

**Problem:**
...

**Fix:**
...
```

## Finding Fields

Each finding under `## Findings` uses this structure:

| Field | Required | Values | Description |
|---|---|---|---|
| `status` | yes | `pending`, `ready`, `skipped` | Triage state |
| `severity` | yes | `P1`, `P2`, `P3` | Priority level |
| `agent` | yes | agent name | Which agent found it |
| `category` | yes | free text | Agent-specific category (OWASP, Database, Migration, etc.) |
| `confidence` | yes | `0`-`100` | How certain the finding is real and the fix is right. 100 = verified against the code; 75 = strong evidence; 50 = plausible but unverified |
| `action_class` | yes | `mechanical`, `corroborated`, `judgment` | Auto-apply eligibility — see the `autonomy` skill §4. `mechanical` = unambiguous fix; `corroborated` = multiple agents converged on it; `judgment` = needs a human decision |
| `file` | yes | relative path | File where the issue is |
| `lines` | no | `N` or `N-M` | Line number or range |
| `title` | yes | short text | One-line summary |

When agents merge duplicate findings (same location, same reason), the merged
finding's `action_class` becomes `corroborated` and its `confidence` is the
maximum of the merged findings' scores.

The `**Problem:**` and `**Fix:**` sections follow as markdown body. Include code snippets where relevant.

## Status Lifecycle

```
pending  →  ready     (approved during triage — will be fixed)
pending  →  skipped   (rejected during triage — removed from file)
pending  →  applied   (auto-applied by an autonomous run — fix committed)
pending  →  deferred  (filed as residual work by an autonomous run —
                       also recorded in memory/tasks.md and the PR body)
ready    →  completed (fixed and verified)
```

`skipped` removal applies to interactive triage only. Autonomous runs never
delete findings: unresolved items become `deferred` so the record survives.

## Frontmatter Summary

The `summary` block in frontmatter is updated by `/cepa:triage` as decisions are made:

```yaml
summary:
  total: 12
  p1: 2
  p2: 5
  p3: 5
  pending: 3    # Updated as triage progresses
  ready: 7
  skipped: 2
```

## Querying Findings

To find all pending P1 findings across all review files:
1. Read all `todos/review-*.md` files
2. Parse YAML frontmatter for quick summary counts
3. For individual findings, parse the `### N` sections and check `status` and `severity` fields

## Rules

- One file per review run — never append findings to an existing file
- Finding numbers are sequential within a file, starting at 1
- Skipped findings are removed entirely from the file during triage (not just marked)
- The frontmatter `summary` is the source of truth for counts
- Keep finding titles under 80 characters
- Code snippets in Problem/Fix sections use fenced code blocks with language tags

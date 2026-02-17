---
name: compound-docs
description: Solution documentation format, categories, and bidirectional plan-solution linking rules. Used by the /cepa:compound command.
---

# Compound Documentation Skill

## Overview

Define the format, categories, and linking rules for solution documents created by the `/cepa:compound` command. Solution documents capture solved problems so that future work benefits from past experience.

## Document Format

Every solution document follows this structure:

### YAML Frontmatter

```yaml
---
title: Descriptive title of the problem and solution
category: one-of-the-categories-below
date: YYYY-MM-DD
tags: [tag1, tag2, tag3]
related: [docs/solutions/category/other-solution.md]
plan: docs/plans/YYYY-MM-DD-feature-name.md  # optional, if this work originated from a plan
---
```

### Body Sections

```markdown
# Title

## Problem
What went wrong. Symptoms the developer observed. Error messages, unexpected behavior, or failing tests. Include enough context that someone encountering the same symptoms can find this document.

## Investigation
What was tried during debugging. Steps taken, hypotheses tested, dead ends encountered. This helps future developers avoid repeating the same investigation.

## Root Cause
Why the problem happened. The underlying technical reason, not just the symptoms. Reference specific code, configurations, or architectural decisions that caused it.

## Solution
The fix. Include:
- Specific files and line numbers changed
- Code snippets (before and after)
- Why this fix addresses the root cause
- Any trade-offs or side effects

## Prevention
How to prevent this from happening again:
- Linter rules to add
- Tests to write
- CLAUDE.md rules to add
- Patterns to avoid
- CI checks to implement

## Related
Links to related solution documents, external references, or relevant documentation.
```

## Category Taxonomy

Categorize each solution into exactly one of these categories:

| Category | When to Use |
|---|---|
| `build-errors` | Build failures, dependency conflicts, Docker issues, compilation errors |
| `database-issues` | Migration problems, query errors, schema drift, data corruption |
| `runtime-errors` | Exceptions, crashes, unhandled errors during execution |
| `performance-issues` | Slow queries, memory leaks, rendering bottlenecks, timeout issues |
| `security-issues` | Vulnerabilities, auth bypasses, data exposure, compliance failures |
| `ui-bugs` | Visual glitches, broken interactions, accessibility issues, CSS problems |
| `integration-issues` | Third-party API problems, webhook failures, service connectivity |
| `logic-errors` | Incorrect business logic, wrong calculations, state management bugs |

## File Naming

Save solutions to: `docs/solutions/<category>/<descriptive-name>.md`

Naming rules:
- Use kebab-case for filenames
- Be descriptive: `context-messages-shadowing-django-framework.md` not `bug-fix.md`
- Include the key concept: `stripe-webhook-idempotency-race-condition.md`
- Don't include dates in filenames (the frontmatter has the date)

## Plan-Solution Linking

### Forward Link (Solution → Plan)
Add the `plan` field to the solution's frontmatter pointing to the plan that initiated this work:
```yaml
plan: docs/plans/2026-02-15-billing-phase-6.md
```

### Backward Link (Plan → Solution)
Append a `## Solutions` section to the originating plan file:
```markdown
## Solutions
- [Context messages shadowing Django framework](../solutions/logic-errors/context-messages-shadowing-django-framework.md) — 2026-02-15
- [Stripe webhook race condition](../solutions/integration-issues/stripe-webhook-idempotency-race-condition.md) — 2026-02-16
```

If the `## Solutions` section already exists, append to it. Don't create duplicates.

### Finding the Plan
To identify the originating plan:
1. Check if the conversation mentions a plan file path
2. Search `docs/plans/` for plans with matching feature names or dates
3. If no plan is found, omit the `plan` field — not all work originates from a plan

## Writing Guidelines

- **Be specific**: Include file paths, line numbers, error messages, code snippets
- **Be searchable**: Use the exact error messages and symptoms as they appear — future developers will search for these
- **Be honest about investigation**: Document dead ends too — they save future debugging time
- **Be actionable in prevention**: Don't just say "be more careful" — give concrete rules, tests, or checks
- **Keep it concise**: Target 200-500 words for the body. Longer is fine for complex issues, but don't pad

## Configurable Behavior

Read `cepa.local.md` for project-specific adjustments:
- Additional categories can be added per-project
- Custom frontmatter fields can be required
- Solution directory path can be customized
- Linking rules can be adjusted

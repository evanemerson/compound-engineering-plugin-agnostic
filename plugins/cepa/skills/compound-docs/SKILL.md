---
name: compound-docs
description: Solution documentation format (including the mandatory Detection section), categories, bidirectional plan-solution linking rules, and the CONCEPTS.md vocabulary-map format. Used by the /cepa:compound and /cepa:compound-refresh commands.
---

# Compound Documentation Skill

## Overview

Define the format, categories, and linking rules for solution documents created by the `/cepa:compound` command and maintained by `/cepa:compound-refresh`, plus the CONCEPTS.md vocabulary-map format both commands feed. Solution documents capture solved problems so that future work benefits from past experience.

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
status: stale                # optional — set only by /cepa:compound-refresh
stale_reason: what was found # required when status: stale
stale_date: YYYY-MM-DD       # required when status: stale
---
```

The three `stale_*` fields are written only by `/cepa:compound-refresh` when
a doc's accuracy is in doubt but the evidence is insufficient to Update,
Replace, or Delete. Consumers must treat a `status: stale` doc as
unreliable: `learnings-researcher` reports it separately as
"Stale (do not act on)" and never extracts its Detection section.

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

## Detection
What a review agent should flag when it sees similar code in a future diff. 2-5 bullets. Each bullet names a concrete, greppable code pattern (a construct, API misuse shape, or anti-pattern — specific enough to match against a diff) plus one clause on why it fails.

## Related
Links to related solution documents, external references, or relevant documentation.
```

### The Detection Section (mandatory)

Every solution document MUST include a `## Detection` section. Prevention and Detection answer different questions:

- **Prevention** is for humans and process: rules, tests, CI checks that stop the problem from being reintroduced.
- **Detection** is for automated reviewers: the code-level signals that indicate the same mistake is being made again, written so an agent reading a diff can match them.

Detection bullets must be concrete enough to act on. Name the exact construct and where it's dangerous:

```markdown
## Detection

Review agents should flag:
- Any `$dispatch(...)` inside `@htmx:after-request` handlers on elements
  INSIDE an `hx-swap="outerHTML"` target — silent detached-node no-op.
- Any `response["HX-Trigger"]` where the requesting element lives inside a
  swap target that other requests also target without `hx-sync` —
  race-prone; require the After-Settle variant.
```

Bad Detection bullets restate Prevention ("be careful with event dispatch") or are too vague to match ("watch for race conditions"). If a bullet couldn't be turned into a grep pattern plus a judgment call, sharpen it or cut it.

`/cepa:review` loads the Detection sections of solution docs that match the files under review and passes them to every review agent as concrete patterns to check the diff against. A Detection section is this format's mechanism for making past mistakes machine-checkable — a solution doc without one only helps humans who happen to read it.

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

## CONCEPTS.md Vocabulary Map

`CONCEPTS.md` at the project's repo root defines the words that mean something specific in that codebase — shared vocabulary that solution docs and instruction files can cite without redefinition. It is a glossary only, not a spec or catch-all.

### How terms enter

- **Accretion** — `/cepa:compound` captures qualifying terms surfaced while documenting a solution. Friction reliably surfaces *peripheral* terms. **Bootstrap exception:** when `/cepa:compound` creates `CONCEPTS.md` (the file doesn't exist yet and a term qualifies), it also seeds the solved problem's area — same scoped-seed rules as below — so the first captured terms don't dangle against undefined siblings.
- **Seeding and reconciliation** — `/cepa:compound-refresh` proactively defines the core domain nouns of the area it refreshes, and scrubs entries that violate the rules below. Seeding catches the *stable-central* terms accretion never reaches: the nouns a system is built around rarely break, so they rarely appear in a learning.

A seed is scoped: define only terms actually investigated against code in the area being worked, sized by the source (the area's declared domain model — schema, core types, primary models) and the qualifying bar, never a target count.

### What earns a slot

A term qualifies when its meaning in this project is precise enough that a new engineer would need it defined to follow conversations, tickets, or code. General programming vocabulary (caches, queues, jobs, sessions) never qualifies, no matter how heavily used.

### Entry format

- Heading per term; cluster headings by domain relationship (entities with their states, processes with their stages) once the file outgrows a flat list.
- Definition is **one sentence** — what the term means in this domain, what distinguishes it from neighbors.
- A term with non-obvious behavioral rules (lifecycle, cancellation semantics, ownership invariants) earns a second paragraph for those rules — never for elaborating the definition.
- Retired synonyms go on an aliases line directly under the definition: `*Avoid:* Booking, appointment`. When the team uses several words for one concept, pick the best and retire the rest.

### The file stands on its own

Each entry must teach its concept to a reader with no access to the codebase, PR history, or team chat. Forbidden in entries:

- Implementation specifics: file paths, class names, function signatures, table names
- Current-config values that will drift: thresholds, counts, enum values — state the behavior, not the number
- Status fields, dates, owners, links to PRs/issues/channels
- Version-specific claims ("currently uses X; migrating to Y")

Cross-references between entries are fine, but an entry that leans on an undefined project-specific sibling means the sibling is itself a candidate to add.

### File skeleton

Start the file with this preamble under a `# Concepts` heading:

> Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Accretes as solutions are documented and refreshed; direct edits are fine. Glossary only, not a spec or catch-all.

End the file with a `## Flagged ambiguities` tail recording settled distinctions as one-line notes (*"'account' had been used for both Customer and User — these are distinct."*) — the audit trail for vocabulary opinions the team has formed.

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

## Brain writeback (optional)

When a repo opts into the cross-repo brain (`brain:` key in
`cepa.local.md` — see the `cepa:brain` skill), the solution doc on disk
stays the source of truth, and `/cepa:compound` ALSO mirrors it into the
brain as typed `memory_payload` atoms (Root Cause / Solution / Prevention /
Detection points → short prose `lessons`/`constraints`/`failures`, fenced
code stripped, evidence-only). The doc format above is unchanged; the brain
is a regenerable compiled index over these docs, never their replacement.
CONCEPTS terms captured in the same run are written as `lessons` atoms.

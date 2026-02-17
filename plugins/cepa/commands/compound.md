---
description: Document a solved problem with 5 parallel sub-agents. Creates solution docs with bidirectional plan linking.
allowed-tools: Bash(git log:*), Bash(git diff:*), Bash(git status:*)
---

# Compound Documentation

Document a solved problem so that future work benefits from this experience. Uses 5 parallel sub-agents to extract, classify, and write the solution document.

**Announce at start:** "I'm using the cepa:compound command to document this solution."

**Required sub-skill:** Use `cepa:compound-docs` skill for document format and categories.

## Step 1: Gather Context

Before spawning agents, collect the raw materials:
1. Review the current conversation for the problem that was solved
2. Run `git log --oneline -20` to see recent commits related to this work
3. Run `git diff main...HEAD` to see the full set of changes
4. If a plan file path is known (from the conversation), note it for plan-solution linking

## Step 2: Spawn 5 Parallel Sub-Agents

Launch these 5 agents simultaneously using Task tool calls:

### Agent 1: Context Analyzer
**Prompt:** "Analyze the conversation context and git history. Extract: (1) What problem was being solved — symptoms, error messages, unexpected behavior. (2) What was tried that didn't work. (3) The timeline of investigation. Return a structured summary."

### Agent 2: Solution Extractor
**Prompt:** "From the conversation and git diff, extract: (1) The root cause of the problem. (2) The exact fix — specific files, lines, and code changes. (3) Why the fix works. (4) Any side effects or trade-offs of the fix. Return structured findings with code snippets."

### Agent 3: Related Docs Finder
**Prompt:** "Search `docs/solutions/` for existing solution documents that relate to this problem. Look for: (1) Similar symptoms. (2) Same files or modules affected. (3) Related patterns or anti-patterns. Return a list of related document paths with brief descriptions of how they relate."

### Agent 4: Prevention Strategist
**Prompt:** "Based on the root cause and fix, determine: (1) How could this have been prevented? (2) Should there be a linter rule, test, or CI check? (3) Should CLAUDE.md be updated with a new rule? (4) Are there other places in the codebase where the same pattern might cause issues? Return concrete prevention recommendations."

### Agent 5: Category Classifier
**Prompt:** "Based on the problem and solution, classify this into one of these categories: build-errors, database-issues, runtime-errors, performance-issues, security-issues, ui-bugs, integration-issues, logic-errors. Also suggest 3-5 tags for the document. Return the category and tags."

## Step 3: Assemble Solution Document

After all agents return, combine their outputs into a single document following the `compound-docs` skill format:

```markdown
---
title: [descriptive title]
category: [from Agent 5]
date: YYYY-MM-DD
tags: [from Agent 5]
related: [from Agent 3 — list of related solution paths]
plan: [path to originating plan, if known]
---

# [Title]

## Problem
[From Agent 1 — what went wrong, symptoms, context]

## Investigation
[From Agent 1 — what was tried, timeline]

## Root Cause
[From Agent 2 — why it happened]

## Solution
[From Agent 2 — the fix, with code snippets]

## Prevention
[From Agent 4 — how to prevent recurrence]

## Related
[From Agent 3 — links to related solutions]
```

## Step 4: Save and Link

1. Save to `docs/solutions/<category>/<descriptive-filename>.md`
2. Create the category directory if it doesn't exist
3. **Plan-Solution Linking** (if a plan file is identified):
   - Add `plan: docs/plans/YYYY-MM-DD-<name>.md` to the solution's frontmatter
   - Read the plan file and append a `## Solutions` section (or add to existing one):
     ```markdown
     ## Solutions
     - [Solution title](../solutions/<category>/<filename>.md) — YYYY-MM-DD
     ```

## Step 5: Report

Present to the user:
- Summary of what was documented
- File path where the solution was saved
- Any plan-solution links created
- Prevention recommendations that might warrant CLAUDE.md updates
- Say: "Solution documented. Consider running `/revise-claude-md` if prevention rules should be added to CLAUDE.md."

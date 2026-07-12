---
description: Document a solved problem with 5 parallel sub-agents. Creates solution docs with bidirectional plan linking.
argument-hint: "[mode:headless]"
allowed-tools: Write, Edit, Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git check-ignore:*), Bash(bash:*)
---

# Compound Documentation

Document a solved problem so that future work benefits from this experience. Uses 5 parallel sub-agents to extract, classify, and write the solution document.

**Announce at start:** "I'm using the cepa:compound command to document this solution."

**Required sub-skill:** Use `cepa:compound-docs` skill for document format and categories.

## Modes

Parse a `mode:headless` token from anywhere in the arguments and strip it.

- **Interactive (default):** run as written below.
- **`mode:headless`** (for callers like `/cepa:lfg` and autonomous
  `/cepa:task`): never prompt. Write the solution doc, plan links, and
  CONCEPTS.md vocabulary updates (Step 4.5 — a silent side effect in every
  mode) exactly as below, but do NOT suggest or perform CLAUDE.md edits —
  return the saved doc path(s), the plan links created, the CONCEPTS.md
  outcome, the commit outcome (Step 4.7 — committed SHA, local-only list,
  or `failed — <reason>`), and the prevention recommendations as structured
  output for the caller's report. Sub-agents return text to this
  orchestrator; only the orchestrator writes files.

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
**Prompt:** "Based on the root cause and fix, determine: (1) How could this have been prevented? (2) Should there be a linter rule, test, or CI check? (3) Should CLAUDE.md be updated with a new rule? (4) Are there other places in the codebase where the same pattern might cause issues? (5) Detection signals: 2-5 concrete, greppable code patterns a review agent should flag when it sees similar code in a future diff — name the exact construct and where it's dangerous, each with one clause on why it fails (per the `cepa:compound-docs` skill's Detection section spec; signals for automated reviewers, distinct from the prevention rules for humans). Return concrete prevention recommendations and the Detection signals separately."

### Agent 5: Category Classifier
**Prompt:** "Based on the problem and solution, classify this into one of these categories: build-errors, database-issues, runtime-errors, performance-issues, security-issues, ui-bugs, integration-issues, logic-errors. Also suggest 3-5 tags for the document. Additionally, list candidate domain vocabulary terms this problem involved — entities, named processes, or status concepts whose meaning is project-specific and precise enough that a new engineer would need them defined (per the `cepa:compound-docs` skill's CONCEPTS.md qualifying bar; general programming vocabulary never qualifies). For each candidate: the term and a one-sentence definition drawn from how the code actually uses it. Return the category, tags, and candidate terms (or 'none qualify')."

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

## Detection
[From Agent 4 — concrete code patterns review agents should flag, per the
`cepa:compound-docs` Detection spec. Mandatory — a doc without Detection
signals only helps humans who happen to read it. If Agent 4 returned no
signals meeting the spec's bar, re-prompt Agent 4 once with the spec's
example; if still none, write the section with an explicit
`<!-- BACKFILL: no concrete signals extracted -->` marker and flag it in
the Step 5 report. Never invent vague bullets to satisfy the mandatory
rule.]

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

## Step 4.5: Vocabulary Capture (CONCEPTS.md)

Reconcile Agent 5's candidate terms against `CONCEPTS.md` at the project
root, following the `cepa:compound-docs` skill's vocabulary-map rules:

1. Drop candidates that fail the qualifying bar or violate the
   stands-on-its-own rules (implementation specifics, config values).
2. **If `CONCEPTS.md` exists:** add missing qualifying terms; refine an
   existing entry only when this solution surfaced new precision. Never
   duplicate a term already covered under another name — add an
   `*Avoid:*` alias instead.
3. **If `CONCEPTS.md` does not exist** and at least one term qualifies:
   create it with the skill's preamble, the qualifying term(s), and the
   core domain nouns of the solved problem's area that meet the bar —
   seeded from that area's declared model (schema, core types, primary
   models) only. Do not reach for repo-wide nouns this run never touched;
   hold borderline terms for a later run.
4. Apply edits silently in both modes — vocabulary capture is a side effect
   of documenting, not a decision the user makes per run. Skip entirely
   (and say so in the report) when no candidates qualify.
5. **Failure is never reported as emptiness.** If the CONCEPTS.md write
   fails, report the outcome as `failed — <reason>` and list the qualifying
   terms so a human can apply them manually — never stop, never prompt. If
   Agent 5's output contains no parseable candidate-terms block, report
   "vocabulary capture skipped — classifier returned no candidates block".
   Neither case may be reported as "no qualifying terms" — that phrase
   claims a scan happened and came up empty.

## Step 4.6: Brain Writeback (optional — participating repos only)

When `cepa.local.md` has an `## Integrations` `brain:` key, mirror this
solution into the cross-repo brain per the **`cepa:brain` skill** (the
canonical contract). No key → skip entirely; the doc on disk is unchanged
and authoritative either way.

1. **Decompose, never post the raw doc.** The Agent Memory API takes typed
   atom arrays and rejects (422) content with ≥2 fenced code blocks or
   >15k chars. Turn this solution into `memory_payload` atoms — the Root
   Cause / Solution / Prevention / Detection points as short prose
   `lessons`/`constraints`/`failures`, **fenced code stripped**, each atom
   well under 15k. Add the qualifying CONCEPTS terms as `lessons` atoms.
2. **PHI scrub** if `brain_phi_scrub: true` — run the skill's redaction pass
   over every atom before egress; count redactions.
3. **Write via the vendored client** (never inline the key on a command
   line): `bash "${CLAUDE_PLUGIN_ROOT}/scripts/brain-client.sh" writeback ...`
   which reads the URL + `MCP_ACCESS_KEY` from the repo's gitignored
   `.env.local`, posts `/writeback` with a stable `idempotency_key`
   (`<repo>:<doc-path>:<atom-index>`), then `PATCH /memories/:id/review`
   `evidence_only` on each returned id. A 422/oversize atom is a recorded
   skip (`suppressed_writebacks`), never silent.
4. **Supersede prior versions:** if this doc's source path already has an
   active memory (edited doc), the client issues `supersede` on the old one
   so recall never serves two contradictory versions.
5. Record the outcome in the `brain` Run Metadata block; for interactive
   runs with no findings file, append a one-line `memory/tasks.md` record
   for any strip/suppression/scrub. A brain failure degrades (grep-only
   world continues) and loses nothing — the file is source-of-truth.

Compliance: writeback happens ONLY for a repo that declares the `brain:`
key (opt-in, fail-closed). A repo without it is never written, regardless
of content.

## Step 4.7: Commit the Artifacts (headless mode)

In headless mode, the artifacts must not be left uncommitted — a caller
pipeline (`/cepa:lfg`) runs this command after its push, and an uncommitted
artifact gets autostashed by the next run's git audit, so the compounding
output would structurally never ship.

1. Identify what this command wrote: the solution doc, the plan file (if a
   `## Solutions` link was added), and CONCEPTS.md (if Step 4.5 touched it).
2. Drop anything gitignored (`git check-ignore <path>` — some repos ignore
   `docs/` entirely); those are reported as local-only, never force-added.
3. If anything tracked remains: stage ONLY those files, commit
   `docs(compound): <solution title>`, and push when the current branch has
   an upstream. A failed commit or push is reported as
   `commit: failed — <reason>` with the file list — never silently dropped.

Interactive mode skips this step — the user decides when to commit.

## Step 5: Report

Present to the user:
- Summary of what was documented
- File path where the solution was saved
- Any plan-solution links created
- CONCEPTS.md outcome: created (N entries), updated (terms added/refined), no qualifying terms, vocabulary capture skipped (no candidates block), or failed — reason + terms for manual apply
- Commit outcome (headless): committed SHA + files, local-only (gitignored) list, or failed — reason
- Prevention recommendations that might warrant CLAUDE.md updates
- Say: "Solution documented. Consider running `/claude-md-management:revise-claude-md` if prevention rules should be added to CLAUDE.md."

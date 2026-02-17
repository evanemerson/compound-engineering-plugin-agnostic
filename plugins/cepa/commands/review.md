---
description: Run parallel review agents on current changes, collect findings with P1/P2/P3 severity, write results to todos/
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git show:*), Bash(gh pr diff:*), Bash(gh pr view:*)
---

# Compound Review

Orchestrate parallel review agents on the current code changes. Collect findings, score severity, and write results to `todos/`.

**Announce at start:** "I'm using the cepa:review command to run parallel review agents."

## Step 1: Determine Review Scope

Identify what to review:
1. If a PR number is provided as argument, use `gh pr diff <number>` to get the diff
2. If on a feature branch, use `git diff main...HEAD` (or the project's main branch)
3. If there are uncommitted changes, use `git diff` + `git diff --staged`
4. Run `git log --oneline main...HEAD` to understand the full commit history

Save the diff output — you'll pass it to each agent.

## Step 2: Read Project Configuration

1. Read `cepa.local.md` from the project root
2. Check the `## Review Agents (Active)` section to determine which agents to spawn
3. Read the project's `CLAUDE.md` for any additional review rules

## Step 3: Spawn Review Agents

Launch agents in parallel. For each active agent listed in `cepa.local.md`, dispatch a Task with:
- `subagent_type`: The agent name from this plugin (e.g., `security-sentinel`, `performance-oracle`)
- `prompt`: Include the full diff and instruct the agent to perform its review

**Research agents (run first, feed context to review agents):**
- `learnings-researcher` — Search `docs/solutions/` and `CLAUDE.md` for relevant past learnings

Run `learnings-researcher` first with the diff summary. Include its output as additional context when dispatching review agents below.

**Review agents (from cepa plugin):**
- `security-sentinel` — Security + compliance audit
- `performance-oracle` — Performance + query optimization
- `python-reviewer` — Python code quality + framework patterns
- `data-integrity-guardian` — Migration safety + data consistency
- `architecture-reviewer` — Module boundaries + patterns
- `schema-drift-detector` — Model/migration/serializer alignment
- `frontend-reviewer` — UI bugs + race conditions
- `deployment-verifier` — Deploy readiness + backwards compatibility

**Official agents (if pr-review-toolkit plugin is installed):**
Also dispatch these using their plugin agent names:
- `silent-failure-hunter` — Silent error swallowing
- `pr-test-analyzer` — Test coverage gaps
- `code-simplifier` — Code simplification opportunities

Launch ALL active agents in parallel (use multiple Task tool calls in a single message).

## Step 4: Collect and Deduplicate Findings

After all agents return:
1. Collect all findings from all agents
2. Deduplicate: If multiple agents flagged the same location for similar reasons, merge into one finding with combined reasoning
3. Sort by severity: P1 first, then P2, then P3

## Step 5: Write Findings to todos/

Create a findings file at `todos/review-YYYY-MM-DD-HHMMSS.md` with this format:

```markdown
# Review Findings — YYYY-MM-DD HH:MM

**Scope:** [description of what was reviewed — branch name, PR number, etc.]
**Agents:** [list of agents that ran]

## P1 — Critical

### Finding 1
- **Agent:** security-sentinel
- **Status:** pending
- **Location:** `path/to/file.py:42-48`
- **Problem:** [description]
- **Fix:** [concrete suggestion]

## P2 — High

### Finding 2
...

## P3 — Medium

### Finding 3
...

---

**Summary:** X findings (Y P1, Z P2, W P3)
**Next step:** Run `/cepa:triage` to review findings interactively.
```

## Step 6: Report

Present a summary to the user:
- Total findings by severity
- Top P1 findings (if any) with brief descriptions
- Say: "Findings saved to `todos/review-YYYY-MM-DD-HHMMSS.md`. Run `/cepa:triage` to review each finding interactively."

## When to Stop

- If no changes are found to review, report that and stop
- If `cepa.local.md` doesn't exist, inform the user they need to create one
- If agents fail to return useful results, report partial results and note which agents had issues

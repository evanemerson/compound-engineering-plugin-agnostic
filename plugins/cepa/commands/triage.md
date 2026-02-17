---
description: Interactive review of findings from /cepa:review. Present each finding for approve, skip, or customize decisions.
allowed-tools: Bash(git diff:*), Bash(git show:*)
---

# Compound Triage

Interactively review findings from the most recent review. Present each finding one at a time for the user to approve, skip, or customize.

**Announce at start:** "I'm using the cepa:triage command to review findings interactively."

## Step 1: Load Findings

1. Search `todos/` for the most recent `review-*.md` file (by filename date, or use the most recently modified)
2. Parse all findings with `status: pending`
3. Count findings by severity and report: "Found X pending findings (Y P1, Z P2, W P3). Starting with P1 findings."

If no pending findings exist, report that and stop.

## Step 2: Present Findings (P1 First)

For each finding, starting with P1 (critical), then P2, then P3:

### Present the Finding

Display clearly:
```
## Finding N of M — [Severity]

**Agent:** [which agent found it]
**Location:** `path/to/file.py:42-48`

**Problem:**
[Full description of the issue]

**Proposed Fix:**
[The agent's suggested fix]
```

If the finding references specific code, show the relevant code snippet using Read tool.

### Ask for Decision

Use AskUserQuestion with these options:
- **Approve** — Mark as `status: ready` (will be fixed)
- **Skip** — Remove from findings (not a real issue or not worth fixing)
- **Customize** — Edit the finding before deciding (change severity, modify fix, add context)

### Handle Decision

- **Approve:** Update the finding's status to `ready` in the todos file
- **Skip:** Remove the finding from the todos file entirely
- **Customize:** Let the user modify the finding via conversation, then ask approve/skip again

## Step 3: Summary

After all findings are reviewed, present a summary:

```
## Triage Complete

- Approved: X findings (Y P1, Z P2, W P3)
- Skipped: X findings

### Approved Findings:
1. [P1] Brief description — `file.py:42`
2. [P2] Brief description — `file.py:88`
...
```

Update the todos file to reflect final state — only approved findings remain with `status: ready`.

## Step 4: Next Steps

Based on what was approved:
- If P1 findings were approved: "There are critical findings to address. These should be fixed before merging."
- If only P2/P3: "No critical issues. Consider addressing these in this branch or a follow-up."
- Say: "To fix approved findings, work through them in priority order. The findings file is at `todos/<filename>.md`."

## Rules

- Always start with P1 findings — don't let the user skip ahead to P3 while P1s are pending
- Present ONE finding at a time — don't batch them
- Show the actual code context for each finding, not just the agent's description
- If the user says "approve all remaining", do it — but confirm first with the count
- If the user says "skip all P3", do it in batch
- Keep a running count: "Finding 3 of 12 (2 approved, 0 skipped)"

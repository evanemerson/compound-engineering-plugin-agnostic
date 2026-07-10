---
description: Triage findings from /cepa:review. Default batch mode auto-applies safe verified fixes and presents the rest as one decision table; pass "interactive" for the classic one-at-a-time flow.
allowed-tools: Bash(git diff:*), Bash(git show:*)
---

# Compound Triage

Triage findings from the most recent review. **Batch mode is the default:**
auto-apply the findings that are safe to apply, then present everything else
as a single decision table. The classic one-finding-at-a-time flow is
available with the `interactive` argument.

**Announce at start:** "I'm using the cepa:triage command — batch mode" (or
"— interactive mode").

## Step 1: Load Findings (both modes)

1. Search `todos/` for the most recent `review-*.md` file (by filename date, or use the most recently modified)
2. Parse all findings with `status: pending`
3. Count findings by severity and report: "Found X pending findings (Y P1, Z P2, W P3)."

If no pending findings exist, report that and stop.

## Batch Mode (default)

### Step 2a: Auto-Apply Eligible Findings

Apply the auto-apply rubric from the **`cepa:autonomy` skill §4**:
`mechanical` or `corroborated` findings with `confidence ≥ 75` are eligible;
`judgment` findings never are.

1. **Checkpoint first:** commit the current tree (`checkpoint: pre-triage`)
   or stash, so the auto-apply diff is isolated.
2. Apply each eligible finding's fix. Mark it `status: applied` in the
   findings file.
3. **Autofix self-review** (autonomy §4): diff only the changes introduced
   since the checkpoint, review that diff for duplicated helpers, broadened
   contracts, and advisory-only findings; fix what the self-review surfaces.
4. Rerun the affected tests (and again after any self-review edits). A fix
   that breaks tests gets reverted and demoted to the decision table with a
   note.
5. Commit: `fix(review): apply triaged findings`.

### Step 3a: Present the Decision Table

Present ALL remaining findings at once — one table, not a sequence:

```
## Triage — X auto-applied, Y need decisions

| # | Sev | Class | Confidence | Location | Title |
|---|-----|-------|------------|----------|-------|
| 3 | P1  | judgment | 80 | billing/services.py:112 | Refund path bypasses SubscriptionService |
| 7 | P2  | judgment | 60 | portal/views.py:45 | Magic-link reuse window |
...

Reply with: "fix 3, 7", "fix all", "defer all", or "skip 7" (combinable).
```

Show code context on request, not preemptively. P1s in this table lead and
are called out — they should be resolved before merging.

### Step 4a: Execute Decisions and Summarize

- "fix N" → mark `ready`, then implement the fixes in severity order,
  test, and commit.
- "defer N" / "defer all" → mark `deferred` AND append to `memory/tasks.md`
  (autonomy §5 — deferrals must be durable).
- "skip N" → remove from the file (interactive skips only; a skip is an
  explicit human judgment that the finding is wrong).

Finish with the summary: applied / fixed / deferred / skipped counts and the
findings file path.

## Interactive Mode (`interactive` argument)

The classic flow — present each finding one at a time, P1 first:

### Present the Finding

```
## Finding N of M — [Severity]

**Agent:** [which agent found it]
**Class:** [action_class] (confidence NN)
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

After all findings, present the same summary as batch mode and update the
todos file so only approved findings remain `ready`.

## Rules

- Batch mode is the default; only use interactive when asked
- Never auto-apply a `judgment` finding — no matter the confidence
- Checkpoint before auto-applying, self-review the auto-apply diff, and
  rerun tests after (autonomy §4) — an unreviewed autofix is not a fix
- Deferred findings always land in `memory/tasks.md`, not just the todos file
- P1 findings lead every table and every interactive sequence
- In interactive mode: one finding at a time, show code context, keep a
  running count; "approve all remaining" works after confirming the count;
  "skip all P3" works as a batch

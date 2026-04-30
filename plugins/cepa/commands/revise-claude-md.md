---
description: Surface preventive rules for CLAUDE.md from this session — including any recent /cepa:review findings — and apply them with approval
allowed-tools: Read, Edit, Glob, Bash(find:*), Bash(ls:*)
---

# Revise CLAUDE.md

Review this session for learnings about working with Claude Code in this codebase, and propose targeted CLAUDE.md updates. Designed to run standalone, or as the final step of `/cepa:review`.

**Announce at start:** "I'm using the cepa:revise-claude-md command to surface preventive rules."

## Step 1: Reflect

What context was missing that would have helped Claude work more effectively?
- Bash commands that were used or discovered
- Code style patterns followed
- Testing approaches that worked
- Environment / configuration quirks
- Warnings or gotchas encountered

**If a recent review findings file exists** (`todos/review-*.md`), read the most recent one. Each P1/P2 finding is a candidate for a preventive rule — would a one-line CLAUDE.md note have caught this?

```bash
ls -t todos/review-*.md 2>/dev/null | head -1
```

## Step 2: Find CLAUDE.md Files

```bash
find . -name "CLAUDE.md" -o -name ".claude.local.md" 2>/dev/null | head -20
```

Decide where each addition belongs:
- `CLAUDE.md` — Team-shared (checked into git)
- `.claude.local.md` — Personal / local only (gitignored)

## Step 3: Draft Additions

**Keep it concise** — one line per concept. CLAUDE.md is part of the prompt, so brevity matters.

Format: `<command or pattern>` — `<brief description>`

Avoid:
- Verbose explanations
- Obvious information
- One-off fixes unlikely to recur

## Step 4: Show Proposed Changes

For each addition:

```
### Update: ./CLAUDE.md

**Why:** [one-line reason]
**Source:** [finding ID, conversation moment, or "session learning"]

\`\`\`diff
+ [the addition — keep it brief]
\`\`\`
```

The `Source:` field ties each rule back to what motivated it, so the diff is reviewable rather than a wall of suggestions.

## Step 5: Apply with Approval

Ask if the user wants to apply the changes. Only edit files they approve. Never auto-apply.

## When to Stop

- If nothing surfaced that's worth a CLAUDE.md note, say so and stop. A clean review producing zero suggestions is a valid outcome.
- If no `CLAUDE.md` exists and the user hasn't asked for one to be created, propose creating it but don't create it unprompted.

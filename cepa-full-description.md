## Compound Engineering Loop — Full Description

**The loop:** Plan → Work → Review → Compound (cyclical — each task's learnings improve the next)

### Plugin: `cepa` v1.1.0

**Location:** `~/.claude/plugins/cache/cepa/cepa/1.0.0/`

**Structure:**

```
cepa/1.0.0/
├── .claude-plugin/plugin.json          # manifest
├── commands/
│   ├── task.md                         # THE ORCHESTRATOR (this doc)
│   ├── review.md                       # parallel review agents
│   ├── triage.md                       # interactive finding review
│   └── compound.md                     # solution documentation (5 agents)
├── agents/
│   ├── research/
│   │   └── learnings-researcher.md     # searches docs/solutions/ + CLAUDE.md
│   └── review/                         # 8 review agents
│       ├── security-sentinel.md
│       ├── performance-oracle.md
│       ├── python-reviewer.md
│       ├── data-integrity-guardian.md
│       ├── architecture-reviewer.md
│       ├── schema-drift-detector.md
│       ├── frontend-reviewer.md
│       └── deployment-verifier.md
├── skills/
│   ├── file-todos/SKILL.md             # YAML format for review findings
│   └── compound-docs/SKILL.md          # solution doc format + categories
└── README.md

```

* * *

## The 5 Phases

### Phase 1: Git Safety Audit + Context Gathering

**Purpose:** Never start work in a confused git state.

**What it does:**

1. Runs `git status`, `git branch`, `git stash list`, `git diff --staged/unstaged`, checks for unpushed branches
2. Presents a status report with any issues found
3. If issues exist → numbered choices (stash, commit, abandon, stay on branch)
4. If a GitHub issue number is provided → `gh issue view` to pull requirements, comments, linked PRs
5. Creates branch from latest main: `git checkout main && git pull && git checkout -b <prefix>/<name>`

**Forces:** Nothing external. Pure git + gh CLI.

### Phase 2: Research + Design (PLAN)

**Purpose:** Surface institutional knowledge, then design the approach.

**Step 2.1 — Surface Past Learnings**

- **Delegates to:** `cepa:research:learnings-researcher` agent
- **File:** [agents/research/learnings-researcher.md](vscode-webview://0hhe3o123gn0afj1ovvheln1imnrrnpjni92t2amuu7u4l24mejg/~/.claude/plugins/cache/cepa/cepa/1.0.0/agents/research/learnings-researcher.md)
- **What it does:** Searches `docs/solutions/`, `CLAUDE.md`, and `memory/tasks.md` for relevant past problems, patterns, and fixes
- Presents findings before design begins so past mistakes aren't repeated

**Step 2.2 — Design**

- **Delegates to:** `superpowers:brainstorming` skill
- **File:** [skills/brainstorming/SKILL.md](vscode-webview://0hhe3o123gn0afj1ovvheln1imnrrnpjni92t2amuu7u4l24mejg/~/.claude/plugins/cache/superpowers-marketplace/superpowers/4.3.1/skills/brainstorming/SKILL.md)
- **What it does:** Explores project context (enriched with learnings + issue context), asks clarifying questions one at a time, proposes 2-3 approaches with trade-offs, saves design doc to `docs/plans/YYYY-MM-DD-<topic>-design.md`

### Phase 3: Plan + Build (WORK)

**Purpose:** Create implementation plan, then execute it.

**Step 3.1 — Implementation Plan**

- **Delegates to:** `superpowers:writing-plans` skill
- **File:** [skills/writing-plans/SKILL.md](vscode-webview://0hhe3o123gn0afj1ovvheln1imnrrnpjni92t2amuu7u4l24mejg/~/.claude/plugins/cache/superpowers-marketplace/superpowers/4.3.1/skills/writing-plans/SKILL.md)
- **What it does:** Creates detailed TDD implementation plan, breaks into 2-5 minute tasks, saves to `docs/plans/YYYY-MM-DD-<feature>.md`
- **Mandatory:** Plan is committed before implementation starts

**Step 3.2 — Build**

- **Delegates to (user's choice):**
    - `superpowers:subagent-driven-development` (default — same session)
        - **File:** [skills/subagent-driven-development/SKILL.md](vscode-webview://0hhe3o123gn0afj1ovvheln1imnrrnpjni92t2amuu7u4l24mejg/~/.claude/plugins/cache/superpowers-marketplace/superpowers/4.3.1/skills/subagent-driven-development/SKILL.md)
    - `superpowers:executing-plans` (alternative — parallel session)
        - **File:** [skills/executing-plans/SKILL.md](vscode-webview://0hhe3o123gn0afj1ovvheln1imnrrnpjni92t2amuu7u4l24mejg/~/.claude/plugins/cache/superpowers-marketplace/superpowers/4.3.1/skills/executing-plans/SKILL.md)

- **What they do:** Task-by-task implementation with TDD, spec compliance review, code quality review, commits per task

### Phase 4: Ship + Review (REVIEW)

**Purpose:** Verify, push, create PR, run automated review, auto-fix critical issues.

**Step 4.1** — Run full test suite + linter **Step 4.2** — `git push -u origin <branch>` + `gh pr create` **Step 4.3** — Auto-Review:

- **If `cepa.local.md` exists:** Delegates to `/cepa:review` command
    - **File:** [commands/review.md](vscode-webview://0hhe3o123gn0afj1ovvheln1imnrrnpjni92t2amuu7u4l24mejg/~/.claude/plugins/cache/cepa/cepa/1.0.0/commands/review.md)
    - Spawns `learnings-researcher` first, then launches up to **11 review agents in parallel:**
        - 8 cepa agents (security-sentinel, performance-oracle, python-reviewer, data-integrity-guardian, architecture-reviewer, schema-drift-detector, frontend-reviewer, deployment-verifier)
        - 3 pr-review-toolkit agents (silent-failure-hunter, pr-test-analyzer, code-simplifier)
    - Deduplicates findings, writes to `todos/review-YYYY-MM-DD-HHMMSS.md` with P1/P2/P3 severity
- **If no `cepa.local.md`:** Falls back to `/pr-review-toolkit:review-pr`

**Step 4.4** — Auto-Fix by severity:

- **P1 (Critical):** Fixed immediately, no questions asked. Commit + push.
- **P2 (Important):** Presented as numbered choices for user to approve/skip
- **P3 (Suggestions):** Listed for awareness. User picks what to address.
- If cepa:review was used → delegates to `/cepa:triage` command
    - **File:** [commands/triage.md](vscode-webview://0hhe3o123gn0afj1ovvheln1imnrrnpjni92t2amuu7u4l24mejg/~/.claude/plugins/cache/cepa/cepa/1.0.0/commands/triage.md)
    - Interactive: one finding at a time, approve/skip/customize

### Phase 5: Compound (COMPOUND)

**Purpose:** Feed learnings back into the system. **Always runs. Never skipped.**

**Step 5.1 — Capture Learnings** (scaled by task size):

- **Small tasks:** Quick inline capture — what went wrong, surprises, prevention rules
- **Medium/large tasks:** Delegates to `/cepa:compound` command
    - **File:** [commands/compound.md](vscode-webview://0hhe3o123gn0afj1ovvheln1imnrrnpjni92t2amuu7u4l24mejg/~/.claude/plugins/cache/cepa/cepa/1.0.0/commands/compound.md)
    - Spawns **5 parallel agents:** Context Analyzer, Solution Extractor, Related Docs Finder, Prevention Strategist, Category Classifier
    - Assembles solution doc, saves to `docs/solutions/<category>/<filename>.md`
    - Creates bidirectional links between plan and solution files

**Step 5.2 — Auto-Propose System Updates:**

- Drafts CLAUDE.md rule additions and presents for approval (numbered: apply / modify / skip)
- Proposes `cepa.local.md` review agent rule additions
- Notes test guards for future planning phases

**Step 5.3 — Save Undone Items:**

- Skipped P2/P3 findings + deferred plan items → `memory/tasks.md`

**Step 5.4 — Final Status Report:**

- PR number, branch, findings fixed/deferred, learnings captured, system updates applied
- Next steps: 1) Merge PR, 2) Start next task, 3) Address deferred items

* * *

## Dependencies

| Plugin | Version | What cepa:task uses from it |
| --- | --- | --- |
| **cepa** | 1.1.0 | `task`, `review`, `triage`, `compound` commands + `learnings-researcher` agent + 8 review agents + 2 skills |
| **superpowers** (superpowers-marketplace) | 4.3.1 | `brainstorming`, `writing-plans`, `subagent-driven-development`, `executing-plans` skills |
| **pr-review-toolkit** | (built-in) | `review-pr` skill + `silent-failure-hunter`, `pr-test-analyzer`, `code-simplifier` agents |

## Global Rules That Govern the Loop (from `~/.claude/CLAUDE.md`)

- **Model:** Always Opus — never Sonnet
- **No Co-Authored-By** in commit messages
- **Branch workflow:** descriptive prefixes, plan first, commit plan before code, PR + auto-review
- **Numbered choices** for all decisions
- **Docker commands** executed without confirmation

## Resume Behavior

If invoked on an existing feature branch (not main):

1. Skips branch creation
2. Checks for existing plan in `docs/plans/`
3. If plan exists → asks which phase to resume at
4. If no plan → starts from Phase 2 (design)
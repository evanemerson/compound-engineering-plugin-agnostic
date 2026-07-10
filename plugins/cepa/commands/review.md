---
description: Run parallel review agents on current changes, collect findings with P1/P2/P3 severity, write results to todos/
argument-hint: "[PR number] [mode:headless]"
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git show:*), Bash(gh pr diff:*), Bash(gh pr view:*)
---

# Compound Review

Orchestrate parallel review agents on the current code changes. Collect findings, score severity, and write results to `todos/`.

**Announce at start:** "I'm using the cepa:review command to run parallel review agents."

## Modes

Parse a `mode:headless` token from anywhere in the arguments and strip it.

- **Interactive (default):** run as written below, ending with the Step 6
  report and the `/cepa:triage` suggestion.
- **`mode:headless`** (for callers like `/cepa:lfg`, scheduled runs, and
  autonomous `/cepa:task`): never prompt the user for anything. Skip the
  conversational parts of Step 6 and instead end by returning a structured
  summary: the findings file path, counts by severity, the counts of
  auto-apply-eligible findings (`mechanical`/`corroborated` with
  confidence ≥ 75 — see the `cepa:autonomy` skill §4), and the
  `deploy_verdict` (verdict + conditions verbatim — a caller must never
  ship past a NO-GO or unmet condition it was never told about). The caller
  decides what to apply. If `cepa.local.md` is missing in headless mode, run the
  cepa review agents with stack details inferred from the repo, note the
  missing config in the findings file, and continue — never block.

**Fail-safe:** if the harness exposes no blocking-question tool, behave as
headless even without the token.

## Step 1: Determine Review Scope

Identify what to review:
1. If a PR number is provided as argument, use `gh pr diff <number>` to get the diff
2. If on a feature branch, use `git diff main...HEAD` (or the project's main branch)
3. If there are uncommitted changes, use `git diff` + `git diff --staged`
4. Run `git log --oneline main...HEAD` to understand the full commit history

Save the diff output — you'll pass it to each agent.

## Step 2: Read Project Configuration

1. Read `cepa.local.md` from the project root
2. Check the `## Review Agents (Active)` section to determine which agents to
   spawn. Lines prefixed with `!` are NOT roster entries — they are
   exclusions for conditional-tier agents (see Step 3); never dispatch a `!`
   line as an agent name. A `!` on a non-conditional agent name has no
   effect; note it in the `conditional_dispatch` record.
3. Check the `## Integrations` section (if present) for optional stage
   providers — see "Integration Dispatch" in Step 3
4. Read the project's `CLAUDE.md` for any additional review rules

## Step 3: Spawn Review Agents

Launch agents in parallel. For each active agent listed in `cepa.local.md`, dispatch a Task with:
- `subagent_type`: The agent name from this plugin (e.g., `security-sentinel`, `performance-oracle`)
- `prompt`: Include the full diff and instruct the agent to perform its review

**Research agents (run first, feed context to review agents):**
- `learnings-researcher` — Search `docs/solutions/` and `CLAUDE.md` for relevant past learnings

Run `learnings-researcher` first with the diff summary. Include its output as additional context when dispatching review agents below.

**Review agents (from cepa plugin — roster tier, controlled by `cepa.local.md`):**
- `security-sentinel` — Security + compliance audit
- `performance-oracle` — Performance + query optimization
- `python-reviewer` — Python code quality + framework patterns
- `data-integrity-guardian` — Migration safety + data consistency
- `architecture-reviewer` — Module boundaries + patterns
- `schema-drift-detector` — Model/migration/serializer alignment
- `frontend-reviewer` — UI bugs + race conditions
- `deployment-verifier` — Go/No-Go deploy verdict + rollback plan

**Roster skip rules:** a roster agent whose entire domain is absent from the
diff may be skipped — `frontend-reviewer` when the diff touches no templates,
JS/CSS, or frontend components; `schema-drift-detector` when it touches no
models, migrations, serializers, forms, or admin; `deployment-verifier` when
it touches no config, dependencies, Docker/compose, env, or migration files
AND changes no task signatures, beat/cron schedules, API contracts, model
fields, or external-service client code. When in doubt, run the agent. Every
skipped agent is recorded in the `agents_skipped` frontmatter field (see the
`file-todos` skill's Run Metadata section) with the rule that skipped it — a
silent skip is indistinguishable from a clean pass. When deployment-verifier
is skipped, set `deploy_verdict: not-evaluated` with the skip rule as basis.

**Conditional tier (dispatched by diff signals — no roster listing needed):**
These three run automatically when their signal fires, in any project. A
project opts out of one by adding `- !agent-name` to its
`## Review Agents (Active)` list.
- `adversarial-reviewer` — dispatch when the diff is large (roughly 300+
  changed lines) OR touches risky paths: payments/billing, auth/session,
  PHI/PII-flagged fields (per `## Compliance`), or data migrations. Failure-
  scenario construction on the code most likely to hurt.
- `reliability-reviewer` — dispatch when the diff touches task-queue code,
  webhooks, scheduled jobs, transaction blocks with side effects, external
  API calls, locks, or cache invalidation.
- `previous-comments-reviewer` — dispatch when ANY `todos/review-*.md` file
  exists in the project (once a project has review history, continuity is
  always worth checking — this agent is effectively always-on after the
  first review, by design), OR `memory/tasks.md` has entries touching the
  diff's files, OR a PR number was provided and the PR has human review
  threads (`gh pr view <n> --comments`). Verifies prior findings and human
  review requests weren't lost or re-broken.

**When in doubt, dispatch** — an unnecessary conditional agent costs one
subagent run; a missed one costs the coverage the tier exists for. Record
ALL THREE conditional agents every run in the `conditional_dispatch`
frontmatter field (see the `file-todos` skill's Run Metadata section):
`dispatched: true` with the signal, or `dispatched: false` with the reason
(signal absent, or excluded by config) — a non-dispatch must never be
indistinguishable from a clean pass.

**Companion agents (from `pr-review-toolkit` plugin — install if missing):**
These cover angles the cepa agents intentionally don't, so they're part of the
default rotation when active in `cepa.local.md`. Dispatch via the Task tool
using the bare name; the runtime resolves which plugin owns each.
- `silent-failure-hunter` — Silent error swallowing, inadequate error handling
- `pr-test-analyzer` — Test coverage gaps, missing behavioral tests
- `comment-analyzer` — Comment accuracy, comment rot, WHAT-vs-WHY hygiene
- `type-design-analyzer` — Type/model invariants, encapsulation quality (use when new types/models are added)
- `code-simplifier` — Simplification opportunities (run last — after the others have surfaced concrete issues)

NOTE: `pr-review-toolkit:code-reviewer` is intentionally NOT included — it
overlaps with `python-reviewer` + `architecture-reviewer` and produces
duplicate findings. If a project doesn't use the cepa python/architecture
agents, swap in `code-reviewer` from `cepa.local.md` instead.

Launch ALL active agents in parallel (use multiple Task tool calls in a single message).

**Integration Dispatch (optional):** when `cepa.local.md` has an
`## Integrations` section AND the named skill is installed (skip silently
otherwise):
- `qa:` — if the diff touches templates, JS/CSS, or frontend components,
  invoke the configured skill after the review agents return and fold its
  results in as findings.
- `second_opinion:` — if the diff touches payment, auth, or PHI-flagged
  paths (per the `## Compliance` section), invoke the configured skill on
  those files; its findings merge into the set below. This is additional
  review only — it never loosens the compliance carve-out in Step 4.

## Step 4: Collect and Deduplicate Findings

After all agents return:
1. Collect all findings from all agents
2. Deduplicate: If multiple agents flagged the same location for similar reasons, merge into one finding with combined reasoning
3. Score each finding with `confidence` (0-100) and `action_class`
   (`mechanical` / `corroborated` / `judgment`) per the `file-todos` skill
   field definitions. Merged duplicates become `corroborated` with the max
   confidence of their sources. **The compliance carve-out is absolute:**
   anything touching compliance-sensitive surfaces (PHI/PII fields, auth,
   payments) is always `judgment` — confidence and fix completeness never
   override this.
4. Sort by severity: P1 first, then P2, then P3

## Step 5: Write Findings to todos/

Create a findings file at `todos/review-YYYY-MM-DD-HHMMSS.md` in the
**`cepa:file-todos` skill format — that skill is the single canonical spec**
(YAML frontmatter with the `summary` block including `applied`/`deferred`
counters, the Run Metadata fields — `agents_skipped`,
`conditional_dispatch`, `deploy_verdict` — then `### N` findings with
`status`, `severity`, `agent`, `category`, `confidence`, `action_class`,
`file`, `lines`, `title`, and `**Problem:**`/`**Fix:**` bodies). Include the
`## Deploy Verdict` body section when the verdict is NO-GO or GO WITH
CONDITIONS. Do not invent a variant format: `/cepa:triage` and `/cepa:lfg`
machine-parse these fields, and a divergent file silently produces "0
eligible findings".

End the file body with:

```markdown
---

**Summary:** X findings (Y P1, Z P2, W P3)
**Next step:** Run `/cepa:triage` (batch auto-apply by default; pass `interactive` for one-at-a-time).
```

## Step 6: Report

Present a summary to the user:
- Total findings by severity
- Top P1 findings (if any) with brief descriptions
- Say: "Findings saved to `todos/review-YYYY-MM-DD-HHMMSS.md`. Run `/cepa:triage` to triage them (batch auto-apply by default; `interactive` for one-at-a-time)."

## When to Stop

- If no changes are found to review, report that and stop
- If `cepa.local.md` doesn't exist, inform the user they need to create one
  (interactive mode only — headless mode infers the stack and continues, per
  the Modes section)
- If agents fail to return useful results, report partial results and note which agents had issues

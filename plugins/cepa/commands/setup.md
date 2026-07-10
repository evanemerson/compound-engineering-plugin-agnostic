---
description: "Health-check and bootstrap a project's cepa setup: validate cepa.local.md, create missing scaffold dirs, check CI and plugin-version drift, and install a stack-matched CI template. Default is a read-only report; pass 'fix' to apply."
argument-hint: "[fix] [mode:headless]"
allowed-tools: Bash(bash:*), Bash(git status:*), Bash(git check-ignore:*), Bash(ls:*), Bash(mkdir:*)
---

# cepa:setup — Project Health Check & Bootstrap

Audit one project's cepa scaffold against the canonical checklist and
(optionally) repair it. This is the consistency tool: run it in every repo
and they all end up with the same working setup.

**Modes:** default is **check** — read-only report, no writes. The `fix`
argument applies repairs. `mode:headless` never prompts (per the
`cepa:autonomy` skill §1 fail-safe): in check mode it returns the report;
with `fix` it applies all non-destructive repairs and reports what it did.

**Announce at start:** "Running cepa:setup (check|fix) on <project>."

## Step 1: Run the Health Script

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-health.sh"
```

The script is read-only and prints `OK` / `MISS` / `INFO` facts: config
sections, scaffold dirs, git tracking of plans/todos, CI presence, installed
plugin version. If the script is unavailable, perform the same checks
manually (it's short — read it for the list).

## Step 2: Interpret + Extend

Beyond the script's facts, check:

1. **Roster validity** — every non-`!` agent line in
   `## Review Agents (Active)` must be a real agent: the 8 cepa roster
   agents, or a pr-review-toolkit companion (silent-failure-hunter,
   pr-test-analyzer, comment-analyzer, type-design-analyzer,
   code-simplifier). Conditional-tier names (adversarial-reviewer,
   reliability-reviewer, previous-comments-reviewer) should appear only as
   `!` exclusions — listing one as a roster entry is a misconfiguration
   (they dispatch by signal). Flag unknown names — typos silently reduce
   review coverage.
2. **Stack ↔ roster fit** — a `frontend: none` project listing
   frontend-reviewer, or a Django project missing schema-drift-detector,
   is worth flagging (advice, not an error).
3. **Compliance sanity** — if `hipaa: true` or PII fields are declared,
   security-sentinel and data-integrity-guardian must be in the roster.
4. **Plugin version drift** — compare the installed cepa version (script
   INFO line) against the marketplace's latest. Stale installs are how
   projects silently run old contracts; recommend
   `claude plugin update cepa@cepa`.
5. **CI reality** — a workflow that only deploys or notifies is NOT a test
   gate (the script flags this). Classify: none / deploy-only / real gate.

## Step 3: Report

```markdown
## cepa:setup — <project> health report

**Config:** cepa.local.md OK | issues: [...]
**Scaffold:** [missing dirs/files]
**Roster:** N agents valid | flagged: [...]
**CI:** real gate | deploy-only | none — [recommendation]
**Plugin:** installed vX.Y.Z (latest vX.Y.Z) [drift warning]

**Repairs available (run `/cepa:setup fix`):** [numbered list]
```

In check mode, stop here.

## Step 4: Fix (only with the `fix` argument)

Apply, in order — all idempotent, none destructive:

1. **Scaffold:** create missing `docs/plans/`, `docs/solutions/` (with the 8
   category subdirs from the `compound-docs` skill: build-errors,
   database-issues, runtime-errors, performance-issues, security-issues,
   ui-bugs, integration-issues, logic-errors — each with a `.gitkeep`),
   `todos/`, `memory/`, and `memory/tasks.md` (header line only).
2. **Config:** if `cepa.local.md` is missing, generate one — infer the
   `## Stack` from the repo (framework files, lockfiles, compose files),
   pick the roster by stack (drop python/schema agents for non-backend
   repos), default `autonomy: gated` (the user opts into `full`
   deliberately), and include a commented `## Integrations` block. If it
   exists but lacks `## Autonomy`/`## Integrations`, append commented
   examples — never change existing values.
3. **CI template:** when the CI check reported none/deploy-only, install the
   stack-matched template from `${CLAUDE_PLUGIN_ROOT}/templates/ci/`:
   - Django/Python backend → `django.yml`
   - Astro/static site → `astro.yml`
   Copy to `.github/workflows/ci.yml` (never overwrite an existing file of
   that name), then **adapt the TODO-marked lines** to the project: Python/
   Node version, settings module, service versions, requirements path,
   working directory, env vars required by the test settings. Read the
   project's test config (pytest.ini, package.json, Makefile) to fill these
   — an unadapted template that fails on first run teaches the user to
   ignore CI.
4. **Commit** the repairs (`chore(cepa): scaffold + CI from /cepa:setup`)
   only when the working tree was otherwise clean; otherwise leave staged
   nothing and list the created files in the report. Never push.

Re-run the health script after fixing and include the before/after in the
final report.

## Rules

- Check mode writes NOTHING — it is safe to run anywhere, anytime.
- Fix mode never overwrites existing files or changes existing config
  values; it only creates what's missing.
- CI templates must be adapted before committing — filling the TODOs is part
  of the fix, not the user's homework.
- Version drift is a warning, not something setup fixes (updating the plugin
  is a user-scope action; name the exact command instead).

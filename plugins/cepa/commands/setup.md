---
description: "Health-check and bootstrap a project's cepa setup: validate cepa.local.md, create missing scaffold dirs, check CI and plugin-version drift, and install a stack-matched CI template. Default is a read-only report; pass 'fix' to apply."
argument-hint: "[fix] [mode:headless]"
allowed-tools: Bash(bash:*), Bash(git status:*), Bash(git check-ignore:*), Bash(git ls-files:*), Bash(git add:*), Bash(git commit:*), Bash(git rev-parse:*), Bash(ls:*), Bash(find:*), Bash(mkdir:*), Bash(cp:*), Write, Edit
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
   code-simplifier, or `code-reviewer` — the documented swap-in when a
   project excludes python-reviewer/architecture-reviewer; see review.md's
   companion note). Conditional-tier names (adversarial-reviewer,
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
5. **CI reality** — the script only reports FACTS (which workflow files
   mention a test/build command, whether any triggers on `pull_request`);
   classification is YOUR job: **read each matched workflow file**. A match
   inside a deploy job, a comment, or an echo is not a gate; a build that
   runs only on push-to-main is not a PR gate. Classify: none / deploy-only
   / real gate — and say which file earned the classification.
6. **Grounding provider** — when the script's grounding facts show
   `grounding:` configured (see the `cepa:grounding` skill), interpret:
   configured-but-unavailable (binary or graph missing) means every review
   silently runs grep-only — flag it, advice not error;
   configured-but-not-ignored is the dirty-tree hazard — flag prominently
   (autonomous loops skip refresh and degrade until it's fixed);
   `grounding:` in a repo WITH `## Compliance` gets the skill's warning
   verbatim (maintaining graphify-out/ arms the global graphify skill's
   LLM doc pass — human policy needed). Fix mode NEVER installs graphify
   or edits ignore files — the report names the exact human commands
   instead (`uv tool install graphifyy` — package name deliberately
   `graphifyy`, binary `graphify`; spike-validated at v0.9.12 — then an
   initial graph build, then the ignore entries). For unattended/headless
   use, also name the operator settings-allowlist entries the researcher
   pre-step needs (`Bash(timeout -k 5 60 graphify query:*)`,
   `Bash(timeout -k 5 60 graphify affected:*)`) — a subagent's Bash calls
   are not covered by any command's `allowed-tools`, and without these
   the pre-step reports `failed — permission denial` on every headless
   run (cepa:grounding skill, headless permissions note).

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
   deliberately), and include a commented `## Integrations` block (its
   example lines include `# grounding: graphify` — see the
   `cepa:grounding` skill). The
   generated file MUST open with a provenance marker the health check
   flags until a human removes it:
   `<!-- generated by /cepa:setup fix on <date> — stack and roster were
   inferred; verify, and declare ## Compliance if any regime applies -->`
   (compliance flags are uninferrable — never guess them). If the file
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
4. **Commit** the repairs (`chore(cepa): scaffold + CI from /cepa:setup`),
   staging ONLY the exact paths this fix run created — everything fix mode
   makes is a new path, so a scoped `git add <created paths>` can never
   sweep in the user's unrelated work, and it's safe regardless of tree
   state. Never `git add -A`, never push. Scaffolding left uncommitted
   would report healthy on this machine and be missing on every other
   checkout (the health check flags exists-but-untracked dirs for exactly
   this reason).

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

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
   review coverage. **A name with trailing prose is an unknown name**
   (`- python-reviewer — project is TypeScript`): a justification written
   onto a roster line does not exclude the agent, it corrupts its name.
   The fix for an unwanted roster-tier agent is to DELETE the line (or
   comment it) — `!` only excludes conditional-tier agents.
1b. **Weekly roster validity** — runs on EVERY project, not only those with
   a `## Review Agents (Weekly)` section, because the absent-section case is
   the failure that matters. Three states:
   - **Present with entries** (the `cadence:weekly` debt tier, see review.md)
     — validate names as in check 1. An agent listed in BOTH sections is
     probable misconfiguration: flag it (advice, not error), since the per-PR
     tier already covers it every run.
   - **Present but empty** — a scheduled `cadence:weekly` run will fail-closed
     and review nothing. Flag prominently: it reports as a clean pass to
     anyone not reading the exit reason.
   - **Absent** — scan for a near-miss heading (case-insensitive match on
     "Review Agents" + "Weekly", any nesting level): `## Review Agents
     (weekly)`, `## Weekly Review Agents`, `### Review Agents (Weekly)`. A
     near-miss reads as absent to review.md's parser, so a scheduled run
     fail-closes forever while the config looks configured — flag it as a
     probable typo. With no near-miss and no weekly schedule, report
     "weekly tier: not configured" explicitly rather than staying silent;
     not-configured and misconfigured must be distinguishable in this report,
     which is the only on-demand check covering the scheduled path.
2. **Stack ↔ roster fit** — a `frontend: none` project listing
   frontend-reviewer, or a Django project missing schema-drift-detector,
   is worth flagging (advice, not an error).
3. **Compliance sanity** — if `hipaa: true` or PII fields are declared,
   security-sentinel and data-integrity-guardian must be in
   `## Review Agents (Active)` **specifically** — not merely present
   somewhere in the file. Presence only under `## Review Agents (Weekly)`
   fails this check: it demotes a compliance-critical agent to a once-a-week
   debt pass, so most PRs would merge without it, and `cepa:autonomy` §4's
   compliance carve-out assumes both ran against the diff. Check 1b flags an
   agent in BOTH sections; this check flags one present ONLY in Weekly.
3b. **Residual sink shape** — the script reports `dir: memory/tasks.d/` and
   a shard count. A repo with a populated `memory/tasks.md` but no
   `memory/tasks.d/` predates the sharded sink (`cepa:autonomy` §5) — note
   it (advice, not error; fix mode creates the directory). Legacy entries
   need no migration: readers consult both locations. **Flag prominently
   when the installed plugin version (check 4) is < 1.13.0 AND shards
   exist:** that client's sweep reads only the legacy file, so every
   sharded residual is invisible to it and its "all sinks swept" report is
   silently incomplete — recommend `claude plugin update cepa@cepa` as the
   fix, not a config change.
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
   **A real gate can still be a dying gate.** When the script reports
   `action pins differ from the cepa templates`, the project installed a
   template before a later bump — its copy never tracks template updates, and
   an action major whose JS runtime GitHub has retired is a step with no
   interpreter. Report that as its own condition beside the classification
   ("real gate, but N step(s) drifted from the shipped template"), name the
   pins, and give the user the edit — fix mode never overwrites an existing
   `ci.yml`, so nothing else will do it for them. `NOT CHECKED` is not a pass:
   report it as unverified.
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
7. **Brain provider** — when `cepa.local.md` has an `## Integrations`
   `brain:` key (see the `cepa:brain` skill), interpret: a gitignored
   `.env.local` must define `BRAIN_URL`, `MCP_ACCESS_KEY`, and
   `BRAIN_WORKSPACE_ID`, and `.env.local` must be git-ignored — flag a
   missing/tracked `.env.local` prominently (a committed key is a leak).
   A `brain:` key in a repo WITH a `## Compliance` section is fine (the PHI
   scrub is forced on) but note it so the operator confirms the
   certification. For unattended use, name the operator settings-allowlist
   entry the recall pre-step needs (`Bash(bash:*)`) — subagent Bash calls
   aren't covered by `allowed-tools`, so without it the pre-step reports
   `failed — permission denial` every headless run. Fix mode NEVER writes
   keys or stands up the OB1 instance — that's the human U1 setup step.

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
   `docs/handoff/` (with a `.gitkeep` — session handoffs from
   `/cepa:handoff`),
   `todos/`, `memory/`, `memory/tasks.d/` (with a `.gitkeep` — the sharded
   residual sink from `cepa:autonomy` §5), and `memory/tasks.md` (header
   line only; kept for back-compat reading — writers append to `tasks.d/`
   shards, never to this file). When creating `memory/tasks.d/` in a repo
   whose `memory/tasks.md` already has entries, also append §5's one-time
   migration marker to the legacy file so pre-1.13 readers surface the
   drift instead of silently under-reading.
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
   **Surface the action-pinning choice in the final report** — it is not a
   TODO line, so the adapt pass above will not raise it, and this step commits.
   The templates ship mutable major tags deliberately (a template is adapted,
   not consumed), which means the installing repo inherits that default
   silently unless you say so. State it once: the tags are mutable, hardening
   to full commit SHAs is the adopter's call, and the template header explains
   the runtime constraint that governs which majors are eligible.
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

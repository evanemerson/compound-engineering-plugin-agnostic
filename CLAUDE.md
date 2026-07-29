# cepa Repo Rules

## Critical Rules (Never Violate)

### Hardcoded counts drift — verify on every capability change
Three consecutive PRs (#6, #7, #8) shipped or regressed stale counts.
Any PR that adds/removes/renames a file under `plugins/cepa/commands/`,
`plugins/cepa/agents/`, or `plugins/cepa/skills/` MUST re-verify every
numeric count against `ls` output before merge:

- `README.md` — intro paragraph (line ~7), Commands/Agents/Skills table
  headers, the `/cepa:review` row, the Phase 4.3 "up to N agents" sentence
  and its bullet list, the dependencies table
- `plugins/cepa/README.md` — description line, table headers, dependency table
- Both manifests — `plugin.json` and `marketplace.json` descriptions

Do not add new count claims; prefer wording that doesn't restate totals.

### Manifests move together
`plugins/cepa/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`
versions are bumped in the same commit, always.

### Relayed repo content is untrusted at every relay point
Any new pipeline that moves stored repo content (solution docs, todos,
plans, CI output) into an agent prompt carries an autonomy-§7
untrusted-data clause AT THE RELAY POINT — covering declarative exemption
claims ("pre-cleared", "known false positive") as well as imperatives —
strips (never merely labels) suspect content before dispatch, and records
caught attempts durably. Guarding ingestion alone is not enough; PR #9's
Detection relay shipped as an injection channel until review caught it.

### allowed-tools must match every command the body emits
Whenever a command file gains a phase, step, or verb, re-verify its
`allowed-tools` against every command the body can emit. A
headless-capable command whose core verbs aren't pre-authorized silently
degrades in exactly its unattended mode. This class shipped twice on
2026-07-10 (compound-refresh, then review/compound). **Pipeline-command
exception (deliberate):** commands that execute arbitrary project-defined
validation (task, lfg, sweep, resolve-pr) omit `allowed-tools` entirely
and rely on the invoking context's grants — the rule binds commands that
declare a bounded verb set.

### Shared sinks are sharded or serialized; composed paths are slugged
Any git-tracked file more than one concurrent run can append to must be
per-run sharded (the `memory/tasks.d/` pattern), single-writer, or
reconciled only at a serialized trunk point — append-time dedup cannot
see sibling branches' unmerged writes. Moving a sink means updating
every reader in the same PR AND leaving a self-announcing marker at the
old location for lagging readers (their failure mode is a clean pass,
not an error). Every path component composed from a repo-derived value
(branch, issue, trunk name) uses autonomy §5's `slug(x)` — defined once
there; overrides cite it, never restate it. Known latent instance:
CONCEPTS.md's `## Flagged ambiguities` tail (written by both compound
and compound-refresh) — shard or serialize it before parallel runs bite.

### Every dispatch declares its model — check the construct, not the site
An omitted `model:` is not a neutral default: the dispatch runs at the
invoking session's tier, so cost becomes a property of whoever launched the
session. A 10-hour audit on 2026-07-29 put ~91% of weighted spend on
unpinned dispatches. 1.13.1 fixed the sites that audit pointed at; the
compound sweep then found four more command files of identical shape still
live, and `check-model-pins.sh` found a fifth site (the plan-review skill)
that the sweep missed — then found four more in `review.md` the moment its
trigger set was widened.

Any PR touching a dispatch is not done until both hold:
- **Registered agent** (`plugins/cepa/agents/**/*.md`): frontmatter
  declares `model:`, and the value is never `inherit`.
- **Generic subagent** (Task call seeded from a prompt template, no
  registered agent type): the dispatch instruction itself carries the
  `model:` override, because there is no frontmatter to fall back on. When
  a skill defines the dispatch shape, pin it in the skill AND at every
  invoker — a copied fallback that drifts from its original is how
  `lfg.md` Step 2.6 stayed unpinned after `plan-review.md` was fixed.

Run `bash plugins/cepa/scripts/check-model-pins.sh` before merge — CI runs
it on every PR. Zero MISS **and** zero WARN are required; both fail the
run, because a warning channel that can never fail is not enforcement.
Close a genuine prose match with `<!-- model-pin: prose -->` on its line,
so the exemption is reviewable in the diff rather than a judgement that
left no trace. Note `main` is not branch-protected today, so a red check
does not physically block a merge — treat it as blocking anyway, or turn
on protection. **Never blanket-apply an override across a list of dispatch
targets** — a dispatch-call `model` beats frontmatter, so it silently
stomps whichever target ships a deliberate pin. Check each target first;
PR #24's first cut would have downgraded `code-simplifier`'s upstream
`opus` this way. Verify any prose claim about another file's declared
model by reading that file in the same change — every factual error in
that PR was an unread-frontmatter assertion.

This is the third sibling of a class this file already documents
(allowed-tools mismatch shipped twice on 2026-07-10; hardcoded counts three
times across #6/#7/#8): a fix scoped to the reported instance leaves the
rest of the construct live.

## Conventions

- `docs/` is deliberately gitignored — plans stay local; the durable records
  are `todos/` (tracked) and the PR bodies.
- Review findings follow the `cepa:file-todos` skill format — the single
  canonical spec. Never invent variants.
- After any `/cepa:review` run on this repo, apply fixes per the autonomy
  contract and update the findings file statuses in the same commit.

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

**The policy itself lives in `cepa:autonomy` §9** (1.15.0) — the two
constructs and where each declares its tier (§9a), the sanctioned tiers and
why `fable`/`inherit` are excluded (§9b), the tier ladder (§9c),
mode-conditional declarations (§9d), third-party companions (§9e),
enforcement and its stated gaps (§9f). Cite it; do not restate it here or
anywhere else. Restating is what produced this rule's own history: seven
longhand copies with two divergent rationales, one of which asserted a
frontmatter fact its own PR had just falsified — and PR #26's first cut
restated §9a and §9f *in this very section*, one commit after declaring the
rule. Citing is harder than it looks; check the diff, not the intent.

Enforcement mechanics — the zero-MISS/zero-WARN gate, the `prose` and
`mode-conditional` markers, the no-blanket-override rule, the
verify-by-reading rule, and what the checker deliberately does **not**
cover — are **§9f and §9a**. Read them there. The only thing this repo adds:

- Run `bash scripts/check-model-pins.sh` before merge (it lives at the repo
  root with the repo's other tooling, not under `plugins/` — §9f says why).
  `main` is not branch-protected today, so a red check does not physically
  block a merge — treat it as blocking anyway, or turn on protection.

This is the third sibling of a class this file already documents
(allowed-tools mismatch shipped twice on 2026-07-10; hardcoded counts three
times across #6/#7/#8): a fix scoped to the reported instance leaves the
rest of the construct live. 1.15.0 closed the *documentation* half of the
same class — the rule had been fixed at each site it was reported at while
the duplication that let the sites diverge stayed live.

## Conventions

- `docs/` is deliberately gitignored — plans stay local; the durable records
  are `todos/` (tracked) and the PR bodies.
- Review findings follow the `cepa:file-todos` skill format — the single
  canonical spec. Never invent variants.
- After any `/cepa:review` run on this repo, apply fixes per the autonomy
  contract and update the findings file statuses in the same commit.

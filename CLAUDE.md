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

## Conventions

- `docs/` is deliberately gitignored — plans stay local; the durable records
  are `todos/` (tracked) and the PR bodies.
- Review findings follow the `cepa:file-todos` skill format — the single
  canonical spec. Never invent variants.
- After any `/cepa:review` run on this repo, apply fixes per the autonomy
  contract and update the findings file statuses in the same commit.

# Residuals — fix/integrity/producer-self-check (PR #90)

## Deferred from /cepa:review of PR #90 (2026-10-22)

Canonical findings: `todos/review-2026-10-22-141057.md` (findings 27-31).

- [ ] P3 — Every resolver-loop copy gates `CEPA_DEV` on any non-empty value (`${CEPA_DEV:+…}`), and a relative `CEPA_PLUGIN_ROOT` becomes a cwd candidate before the resolver's own refusals run — `plugins/cepa/skills/file-todos/SKILL.md` `## Self-check`, plus setup.md, compound.md, compound-refresh.md, learnings-researcher.md (finding 27). Fix all copies in one PR: gate on `= 1`, skip non-absolute env candidates, prefer the `cepa` marketplace by name.
- [ ] P3 — `Bash(bash:*)` is broad, and may not match the compound Self-check block at all — `plugins/cepa/commands/triage.md:4`, `plan-review.md:4` (finding 28). Measure the block under the real permission mode before claiming headless self-check works unprompted; if it does not match, move the block into a script and grant that path narrowly.
- [ ] P3 — Summary and frontmatter are located file-wide; a file whose line 1 is not `---` passes with all-zero counters — `plugins/cepa/scripts/check-findings-file.sh` (finding 29, pre-existing, moved verbatim). Fix with a corpus diff.
- [ ] P3 — An unclosed fence drops later findings; tilde fences are not stripped — `plugins/cepa/scripts/check-findings-file.sh` (finding 30, pre-existing). Fix with a corpus diff.
- [ ] P3 — Shipped spec names the repo-only `scripts/check-findings-file-controls.sh` — `plugins/cepa/skills/file-todos/SKILL.md` `--rows` paragraph (finding 31). Qualified "In the cepa repo"; keep or reword.

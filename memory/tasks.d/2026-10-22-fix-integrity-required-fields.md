# Residuals — fix/integrity/required-fields (punch-list L17)

## Deferred from /cepa:plan-review (2026-10-22)

Canonical findings: `todos/review-2026-10-22-164539.md` (finding 5).

- [ ] P3 — `/cepa:resolve-pr` writes one finding per PR comment; a PR-level comment names no file, and the spec requires `file`. Once the required-field leg ships, such a run reports a failed self-check. Spec decision: a sanctioned no-file value, or relax `file` for `pr-feedback:` scopes — `plugins/cepa/commands/resolve-pr.md:90`, `plugins/cepa/skills/file-todos/SKILL.md` `## Finding Fields` (finding 5). Unmeasured here: `grep -l '^scope: pr-feedback' todos/*.md` → none.

# Residuals — fix/integrity/required-fields (punch-list L17)

## Deferred from /cepa:plan-review (2026-10-22)

Canonical findings: `todos/review-2026-10-22-164539.md` (finding 5).

- [ ] P3 — `/cepa:resolve-pr` writes one finding per PR comment; a PR-level comment names no file, and the spec requires `file`. Once the required-field leg ships, such a run reports a failed self-check. Spec decision: a sanctioned no-file value, or relax `file` for `pr-feedback:` scopes — `plugins/cepa/commands/resolve-pr.md:90`, `plugins/cepa/skills/file-todos/SKILL.md` `## Finding Fields` (finding 5). Unmeasured here: `grep -l '^scope: pr-feedback' todos/*.md` → none.

## Deferred from /cepa:review of PR #92 (2026-10-22)

Canonical findings: `todos/review-2026-10-22-172115.md` (findings 3, 5, 18, 21).

- [x] P2 — (closed 2026-10-22 on this branch: the self-check's own set covers findings the run created or whose non-status fields it edited; a status-only change gets a WARN, so triage or sweep moving an old incomplete finding passes, and the repo checker stays strict. Control own-statusonly. The dpc-pro run, relayed, found no file before 2026-07-10: the 41 failing files date 07-15 to 10-21.) Findings files written before 2026-07-10 (a8f69e1 made `confidence`/`action_class` required) fail every later self-check: a writer may never invent a value for an earlier run's finding, so triage or sweep touching such a file reports a failed self-check each run — `plugins/cepa/skills/file-todos/SKILL.md` `## Self-check` (finding 3). Spec decision: a sanctioned legacy value (`action_class: judgment`), a file-level exemption like `counter_convention:`, or report earlier-run gaps as pre-existing. Measure on dpc-pro first (the hand-off run).
- [ ] P2 — A title containing ` · file: x` stands in for a missing `file:` row: the positional spelling cannot tell a field from look-alike title text — `plugins/cepa/scripts/check-findings-file.sh` fields leg (finding 5). Inherent to the admitted positional spelling; narrowing it is a spelling decision.
- [ ] P3 — STATES has no machine link to the spec; extend `wire-required` to read the `status` row's values — `scripts/check-findings-file-controls.sh` (finding 18).
- [ ] P3 — The fields leg inherits residual finding 30 of `2026-10-22-fix-integrity-producer-self-check.md` (unclosed fence drops later findings; a three-tilde fence is not stripped): both legs read `_cff_body` — `plugins/cepa/scripts/check-findings-file.sh` (finding 21). Fix with that residual and a corpus diff.

## Deferred from /cepa:review of the #92 follow-up (2026-10-22)

Canonical findings: `todos/review-2026-10-22-191935.md` (findings 1, 18, 19). Finding 1 is the P2 above, now closed.

- [ ] P3 — The own set is self-attested: `own=none`, or a list that leaves out a finding the run edited, turns its gaps into WARN at exit 0; BADOWN catches a wrong id, not an omitted one. Option: a `git diff`-based cross-check in the Self-check block — `plugins/cepa/skills/file-todos/SKILL.md` `## Self-check` (finding 18).
- [x] P3 — (closed 2026-10-22: accepted by coord@main as a NAMED exception to the unique-kill rule for this one pass-through path only — not a general rule; the rule's wording is unchanged.) The per-file own plumbing (`_cff_main` passing `$own` to each file) has no kill of its own: its only kill, `own-multi`, is shared with the WARN-split mutant. Measured by the worker's mutant matrix (A5-firstonly vs M1-split) — `scripts/check-findings-file-controls.sh` (finding 19).

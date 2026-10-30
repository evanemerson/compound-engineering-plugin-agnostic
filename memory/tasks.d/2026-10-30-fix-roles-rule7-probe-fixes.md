# Residuals — fix/roles/rule7-probe-fixes (punch-list L27)

## Deferred from /cepa:review of PR #99 (2026-10-30)

Canonical findings: `todos/review-2026-10-30-181500.md` (findings 2, 3, 4).
Finding 1 (the higher-level-heading control) is applied on this branch.

- [ ] P3 — No control moves review's citation into `## Modes`; needs a two-anchor mutant form, since the suite models one substitution. `cite-moved-review` is a sound proxy today — `scripts/check-orca-turn-endings-controls.sh` (finding 2).
- [ ] P3 — SITES is duplicated as CITE_SITES in the controls; derive it from the checker, or leave it, since a one-sided edit turns the clean-copy run red — `scripts/check-orca-turn-endings-controls.sh` (finding 3).
- [ ] P3 — resolve-pr's Step 9 serves both modes; the citation is not marked interactive-only. No fix required: rule 7 already says a headless sub-step does not end a turn — `plugins/cepa/commands/resolve-pr.md` Step 9 (finding 4).

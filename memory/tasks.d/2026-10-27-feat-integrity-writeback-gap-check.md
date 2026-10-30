# Residuals — feat/integrity/writeback-gap-check (punch-list L18)

## Deferred from /cepa:review of PR #93 (2026-10-27)

Canonical findings: `todos/review-2026-10-27-190245.md` (findings 15, 16, 17, 18, 19, 21, 22).

- [ ] P3 — No retry on a transient `gh api` error: a 5xx turns the check red (fails closed, loud) — `scripts/check-writeback-gap.sh` fetch_body, check_commit (finding 15). Operator call: retry latency vs a rare red flake.
- [ ] P3 — No `concurrency:` group; every `edited` event runs the full job — `.github/workflows/writeback-gap.yml` (finding 16). Cancel only pull_request runs; the expression is untested.
- [ ] P3 — `fetch-depth: 0` now serves both the controls' real cases and the push range; do not narrow it without moving both — `.github/workflows/writeback-gap.yml` (finding 17).
- [ ] P3 — L18 and the 2026-09-25 entry say option (b) "fails"; the built check WARNs on deferred findings and MISSes only on probe failures (reason in the script header) — `memory/tasks.d/2026-10-02-punch-list.md` L18 (finding 18). coord@main records it when closing L18.
- [ ] P3 — The mutation sweep registry does not cover `scripts/check-writeback-gap-controls.sh` (no sibling suite is covered either) — `scripts/mutants/registry.sh` (finding 19).
- [ ] P3 — The grep-error paths (`cites` exit 2, the scan-error MISS) have no control; needs a stub findings checker whose FIELD_PRE makes grep error — `scripts/check-writeback-gap.sh` (finding 21).
- [ ] P3 — Signal quality: 22 of 89 merged PRs flag, most for deferrals in their own review file (probe: `bash scripts/check-writeback-gap.sh --replay`, 2026-10-27). Keep file-level WARNs, or mark a citation of a file the same PR added — `scripts/check-writeback-gap.sh` check_body (finding 22).

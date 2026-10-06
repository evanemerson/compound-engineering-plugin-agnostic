# Residuals — fix/integrity/positional-status-field (PR #85)

## Deferred from /cepa:review of PR #85 (2026-10-06)

Canonical findings: `todos/review-2026-10-06-120000.md`.

- [ ] P2 — No mechanical guard keeps the file-todos spec's grep prefix equal to `FIELD_PRE` — `scripts/check-residual-integrity.sh:228` (finding 6). Add a leg that extracts the spec's prefix and diffs it, plus its mutation control.
- [ ] P3 — Separator whitespace, key charset and widened separator sets are unpinned by any control — `scripts/check-residual-integrity.sh:228` (finding 14).
- [ ] P3 — No suite executes the fixture's stated counts — `plugins/cepa/skills/file-todos/fixtures/status-spellings.md` (finding 15).
- [ ] P3 — `$(grep -c … || true)` turns a grep regex error into an empty count at the tally sites — `scripts/check-residual-integrity.sh` (finding 16, pre-existing).

## Owed proof (not runnable from this repo)

- [ ] P2 — Positive-shape proof on dpc-pro's `todos/`: old vs new per-file row diff. The prompt is in PR #85's body. This repo has no positional rows, so its corpus diff can only prove zero over-match.

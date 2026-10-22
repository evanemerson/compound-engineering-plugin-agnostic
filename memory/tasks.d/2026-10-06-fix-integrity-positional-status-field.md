# Residuals — fix/integrity/positional-status-field (PR #85)

## Deferred from /cepa:review of PR #85 (2026-10-06)

Canonical findings: `todos/review-2026-10-06-120000.md`.

- [x] P2 — No mechanical guard keeps the file-todos spec's grep prefix equal to `FIELD_PRE` — `scripts/check-residual-integrity.sh:228` (finding 6). Add a leg that extracts the spec's prefix and diffs it, plus its mutation control. — **DONE 2026-10-22** (PR #90): closed by deletion — the spec cites the shipped script instead of restating it; `wire-onecopy` fails on a second copy.
- [ ] P3 — Separator whitespace, key charset and widened separator sets are unpinned by any control — `scripts/check-residual-integrity.sh:228` (finding 14).
- [x] P3 — No suite executes the fixture's stated counts — `plugins/cepa/skills/file-todos/fixtures/status-spellings.md` (finding 15). — **DONE 2026-10-22** (PR #90): `rows-live`/`rows-not` in check-findings-file-controls.sh.
- [x] P3 — `$(grep -c … || true)` turns a grep regex error into an empty count at the tally sites — `scripts/check-residual-integrity.sh` (finding 16, pre-existing). — **DONE 2026-10-22** (PR #90): `_cff_numeric` at every tally site, pinned by `cli-tallyerr` and `tally-*`.

## Owed proof (not runnable from this repo)

- [x] P2 — Positive-shape proof on dpc-pro's `todos/`: old vs new per-file row diff. The prompt is in PR #85's body. This repo has no positional rows, so its corpus diff can only prove zero over-match.
  **Done 2026-10-06** by two read-only dpc-pro hand-off probes (206 files): 0 files lost rows, 4 gained. Results are recorded under punch-list L8 in `memory/tasks.d/2026-10-02-punch-list.md`; the remaining dpc-pro gaps are L13.

# Residuals — test/formulation/detection-gate-controls (punch-list L52)

## Measured on this branch (2026-11-27)

- Probe: `bash scripts/check-orca-detection-controls.sh` (every control
  passed, 0 failed). The per-leg check used a scratch driver, not committed:
  it `exec`s the controls' python heredoc with `mutate()` patched to dump each
  mutant's full MISS list, then groups the lines by leg. Result: every leg the
  check's header lists has at least one mutant that is red in that leg only.
  The new FIXTURES and TITLE mutants are in EXACT, so the controls re-assert
  on every run that each is red only on its killer.
- `setsid-grandchild-holds-stdout` is not redundant against the
  `pipe-read-to-brace` mutant. That mutant reads the probe through a pipe and
  stops at the JSON's closing `}` line, so `bg-child-holds-stdout` stays
  green on it. A plainer pipe (`| cat`, `$(…)`) is also killed by
  `bg-child-holds-stdout`. So the case is unique only against this
  hand-built shape.

## Open (from /cepa:review of PR #152, `todos/` file of that run)

- [ ] P3 — The per-leg sweep is a scratch script, so "every leg kills a case no
  other leg kills" is measured by hand each time. A `--legs` mode on the
  controls would make it a re-run — `scripts/check-orca-detection-controls.sh`.
- [ ] P3 — Only the L52 mutants are in EXACT. Measure the others with the
  `--legs` mode above, then add each one that is red on its killer only —
  `scripts/check-orca-detection-controls.sh` `EXACT`.
- [ ] P3 — `hostile-json-in-cwd` (§12a) runs only the PATH route. Both routes
  share one parse line today. If that line is ever split, add an
  `ORCA_CLI_COMMAND` twin — `scripts/check-orca-detection.sh`.
- Finding 21 (the §12a and rule 6 blocks print one reason for timeout, kill
  and crash) is a plugin change and out of this test-only scope. It stays
  tracked in `2026-10-30-feat-roles-orca-adapter.md` and
  `2026-10-30-feat-roles-orca-session-titles.md` (finding 15), not here.

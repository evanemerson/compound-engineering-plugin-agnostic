# Residuals — test/formulation/detection-gate-controls (punch-list L52)

## Measured on this branch (2026-11-27)

- Per-leg sweep: every mutant of `scripts/check-orca-detection-controls.sh` was
  run and its full MISS set read (a scratch driver that `exec`s the controls'
  heredoc and dumps `misses` per mutant; not committed). Result: 97/97 controls
  passed, and every leg (BLOCK, BOUNDS, FIXTURES, RETRY, TITLE-BLOCK,
  TITLE-BOUNDS, TITLE, CITES, TITLE-SURFACES) has at least one mutant that is
  red in that leg only. The five new FIXTURES/TITLE mutants are each red on
  exactly one case: their killer.
- `setsid-grandchild-holds-stdout` does catch something no other case does:
  `pipe-read-to-brace` reads the probe through a pipe and stops at the JSON's
  closing `}` line, so `bg-child-holds-stdout` stays green; only a probe that
  hangs before it answers, with a grandchild outside the timeout's process
  group, keeps that pipe open.

## Open

- [ ] P3 — The per-leg sweep is a scratch script, so "every leg kills a case no
  other leg kills" is measured by hand each time. A `--legs` mode on the
  controls (dump each mutant's MISS set, group by leg) would make it a re-run,
  not a re-build — `scripts/check-orca-detection-controls.sh`.
- Finding 21 (the §12a and rule 6 blocks print one reason for timeout, kill
  and crash) is a plugin change and out of this test-only scope. It stays
  tracked in `2026-10-30-feat-roles-orca-adapter.md` and
  `2026-10-30-feat-roles-orca-session-titles.md` (finding 15), not here.

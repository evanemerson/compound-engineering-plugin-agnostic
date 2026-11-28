# Residuals — docs/matrix/shard-flip-and-block-select-rules (punch-list L51, L56)

Rules recorded in repo CLAUDE.md ("A leg that runs a fenced block selects it
by a line no mutant edits", "Flip the shard line in the commit that closes its
item"). Solution docs (local, `docs/` is gitignored), in the matrix lane:
`docs/solutions/logic-errors/a-shard-line-is-flipped-in-the-commit-that-closes-its-item.md`,
`docs/solutions/logic-errors/a-leg-that-runs-a-fenced-block-selects-it-by-a-line-no-mutant-edits.md`.

## L51 — evidence (origin/main f4443ef, 2026-11-27)

Probe: `python3 -I scripts/probe-shard-lag.py` → 8 candidates. Read one by
one: 3 lag, 5 not.

- lag — `2026-10-27-feat-integrity-writeback-gap-check.md` line 10: L18 is
  completed and its closure records the WARN behaviour the line asks for.
- lag — `2026-11-01-fix-roles-run-rebind-on-restart.md` line 15: "close L45
  after merge"; L45 is completed.
- lag — `2026-11-02-feat-integrity-lane-stack-skill.md` line 5: lock wait and
  bound, "owner L66's gate header"; L66 is completed and the
  `stack-gate.sh` header now states `lock_wait_seconds` and the refusal.
- not lag — `2026-10-30-feat-roles-orca-turn-endings.md` line 8 (the
  no-handle fallback is still open), `2026-11-01-fix-gain-quoted-values-compound-11b.md`
  line 5 and `2026-11-01-fix-integrity-findings-file-collision.md` line 5 (L41 /
  L54 named as context), and the two findings-leg hits
  (`review-2026-07-12-115234` #5, `review-2026-11-01-190014-…` #7: each applied
  in part, the rest deliberately filed in the shard).

The 2026-11-01 triage's 7 had no stated probe, so the two counts are not
comparable line for line.

## Residuals

- [ ] P3 — Flip the 3 lagging lines above (coord@main closed those three items; this branch did not edit another run's shard) — `memory/tasks.d/` (L51 evidence).
- [ ] P3 — L56 instance 4, live: the BLOCK leg's heredoc regex `<<'([A-Z_]+)' \|\| true` is edited by mutant `block-unquoted-delimiter`, so both its killers go red through "no block to run", not by sending the hostile message. Probe: apply the mutant's old→new to `plugins/cepa/skills/autonomy/SKILL.md` and run the leg's two regexes — clean `1 True`, mutant `1 False`. Fix: accept both quote forms in the regex (as RULE2BLOCK does) so the block still runs — `scripts/check-orca-nudge.sh` BLOCK leg (~line 1700).
- [ ] P3 — L56 mechanical check, not built: in `scripts/check-orca-nudge-controls.sh`, for each SKILL_MUTANTS / SKILLH_MUTANTS entry, apply it to `SKILL.md` and assert each leg's selectors (the `skill_block` needle, and the gating regex) still select exactly one block; a control plants a mutant that edits a needle and must go red. Not added here because open PR #149 edits both `check-orca-nudge.sh` and its controls; do it after #149 merges, together with instance 4 (it would flag that instance first).
- [ ] P3 — Consider promoting the shard-flip rule from repo CLAUDE.md to `cepa:autonomy` §5 (residual durability), so every repo's closures carry it. Plugin content, so a version bump; operator's call.

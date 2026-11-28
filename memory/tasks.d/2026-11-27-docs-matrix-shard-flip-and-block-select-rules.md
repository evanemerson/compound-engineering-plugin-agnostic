# Residuals — docs/matrix/shard-flip-and-block-select-rules (punch-list L51, L56)

Rules recorded in repo CLAUDE.md ("A leg that runs a fenced block selects it
by a line no mutant edits", "Flip the shard line in the commit that closes its
item"). Solution docs (local, `docs/` is gitignored), in the matrix lane:
`docs/solutions/logic-errors/a-shard-line-is-flipped-in-the-commit-that-closes-its-item.md`,
`docs/solutions/logic-errors/a-leg-that-runs-a-fenced-block-selects-it-by-a-line-no-mutant-edits.md`.

## L51 — evidence (origin/main f4443ef, 2026-11-27)

Probe: `python3 -I scripts/probe-shard-lag.py`, run on `git archive f4443ef
memory todos` → 9 candidates, 0 skip notes. Read one by one: 4 lag, 5 not.
All 4 lag lines are flipped on this branch, with a closing note on each:

- lag — `2026-10-22-feat-roles-anchor-count-checker.md` line 8: "Close L7
  when #91 merges"; L7 is completed (2026-10-22).
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

Closing L51's own sources on this branch: `todos/review-2026-10-30-192000.md`
finding 16 → `applied`; its tracking line
`2026-10-30-fix-roles-rule7-probe-fixes.md` line 26 → `[x]` (the probe found
that line once finding 16 flipped).

The probe's first cut read only `- status:` (35 of 133 findings files use a
bare `status:`) and a 4-space `status:` line straight after a one-line
punch-list title (13 of 103 items missed: 8 by a 3-space indent, 5 by a
wrapped title). Review of #150 measured both; the fixed probe gained one row
(the L7 line) and lost none on the same tree.

The 2026-11-01 triage's 7 had no stated probe, so the two counts are not
comparable line for line.

## L56 — instances

1-3. PR #116 (tab25@roles, L46), from
   `2026-11-01-fix-roles-rename-rebind-hardening.md` line 14: HEALTHBLOCK
   found rule 8's block by its `orca-health.sh" "${` call line, and
   RULE2BLOCK's regex needed the quote and `|| true`, so three mutants of
   exactly those texts went red because the block was not found. Probe: run a
   mutant and read its MISS lines; `output []` on every case of a leg means
   the selector, not the block, failed. Fixed in #116 by selecting on
   `cepa_health_args=$(cat` and tolerating both edits in the regex.
4. Live on f4443ef — the BLOCK leg, below.

## Residuals

- [ ] P3 — L56 instance 4, live: the BLOCK leg's heredoc regex `<<'([A-Z_]+)' \|\| true` is edited by mutant `block-unquoted-delimiter`, so both its killers go red through "no block to run", not by sending the hostile message. Probe: apply the mutant's old→new to `plugins/cepa/skills/autonomy/SKILL.md` and run the leg's two regexes — clean `1 True`, mutant `1 False`. Fix: accept both quote forms in the regex (as RULE2BLOCK does) so the block still runs — `scripts/check-orca-nudge.sh` BLOCK leg (~line 1700).
- [ ] P3 — L56 mechanical check, not built: in `scripts/check-orca-nudge-controls.sh`, for each SKILL_MUTANTS / SKILLH_MUTANTS entry, apply it to `SKILL.md` and assert each leg's selectors (the `skill_block` needle, and the gating regex) still select exactly one block; a control plants a mutant that edits a needle and must go red. Not added here because open PR #149 edits both `check-orca-nudge.sh` and its controls; do it after #149 merges, together with instance 4 (it would flag that instance first). When it lands, move the rule text into that checker's header and leave CLAUDE.md a pointer (review of #150, finding 12).
- [ ] P3 — Consider promoting the shard-flip rule from repo CLAUDE.md to `cepa:autonomy` §5 (residual durability), so every repo's closures carry it. Plugin content, so a version bump; operator's call (review of #150, finding 4).
- [ ] P3 — `scripts/probe-shard-lag.py` still skips without a note: a `Canonical findings:` line in any other spelling (canon stays unset), and a line naming two findings files. Fix: print a `?` note for each (review of #150, finding 11).

# Residuals — chore/integrity/p3-backlog-triage (P3 backlog triage, PR #115)

## Deferred from /cepa:review of PR #115 (2026-11-01)

Canonical findings: `todos/review-2026-11-01-203000.md` (findings 4, 5, 6).

- [ ] P3 — "#99 finding 2" in the cite-moved-review-modes comment names no findings file — `scripts/check-orca-turn-endings-controls.sh` (finding 4).
- [ ] P3 — review-2026-07-12 findings 5-12 closed on the file's own `resolution:` line; spot-check 5 and 8 against the brain provider, or accept — `todos/review-2026-07-12-115234.md` (finding 5).
- [ ] P3 — The PR #99 section header names only finding 1 as applied — `memory/tasks.d/2026-10-30-fix-roles-rule7-probe-fixes.md` line 6 (finding 6).

## Triage result — items that need the operator (2026-11-01)

The triage scope was the open non-P1 lines in `memory/tasks.d/2026-10-3*.md`
and `2026-11-*.md`, and the `todos/` files with `status: pending|ready`.
Probe: `git grep -cE '^\s*- \[ \] P3' 0dcd88c -- 'memory/tasks.d/2026-10-3*.md' 'memory/tasks.d/2026-11-*.md'`
gives 62, and 47 outside the two L46 shards.
Only one open finding outside L46 met the autonomy §4 rubric (mechanical or
corroborated, confidence 75 or more): review-2026-10-30-181500 finding 2,
applied on this branch. Each item below is a decision, numbered here as D1, D2 and so on.

- [ ] P3 — D1. Turn-endings checker: count POINTER outside fences only (review-2026-10-30-161650 #21, mechanical 60), and add `--enter` to rule 7's guard (review-2026-10-30-192000 #9, judgment 60). Patch tested: 214/214 checks, 148/148 controls; both new controls go red on the old checker. Recommend: fix — `scripts/check-orca-turn-endings*.sh`.
- [ ] P3 — D2. Close with no change: 181500 #3 (SITES duplicated), 181500 #4 ("no fix required"), 10-30-192000 #10 ("leave unless it drifts"), 232854 #11 ("Accept"), 125030 #13 (1.2 s bound, no flake seen), and send-heredoc shard line 9 (1.43.0 sessions; every session restarted after the reboot, per L47). Recommend: skip all six.
- [ ] P3 — D3. `orca-health.sh` REASONS: drop the pre-1.43.0 and pre-1.44.0 groups (review-2026-10-31-233000 #10). That is due now, because the plugin is at 1.45.0. Recommend: do it with L47, which edits the same refusal reasons — `plugins/cepa/scripts/orca-health.sh`.
- [ ] P3 — D4. `orca-health.sh` hardening batch: review-2026-10-31-214500 #21, #23, #24, #29, #31, #32 and review-2026-10-31-230000 #7. Recommend: keep deferred; one worker after L47.
- [ ] P3 — D5. `sweep.md`: model-filled values sit in single quotes (review-2026-10-31-230000 #5, judgment 80). The repo convention says such a value goes through a quoted heredoc. Recommend: fix in its own worker (injection class) — `plugins/cepa/commands/sweep.md`.
- [ ] P3 — D6. `check-findings-file.sh`: harden `sed -n …p | head -1` to `sed -n '…{p;q}'` (review-2026-10-31-213000 #4), and accept #3 (no counter_convention mutant). Recommend: fix #4 with a patch bump, accept #3.
- [ ] P3 — D7. Detection-gate controls: 3 FIXTURES cases with no mutant (152000 #11), a killer substring for TITLE-SURFACES (session-names shard, finding 12), and a hostile `json.py` fixture (094500 #24 with 125030 #15). Recommend: one test-only worker after L46, because #15 also covers the rule 6 block.
- [ ] P3 — D8. Record a "flip the shard line in the same commit as the finding" rule (review-2026-10-30-192000 #16). This triage measured the drift: 7 shard lines lagged findings or punch-list items that were already closed. Recommend: fix with `/cepa:compound`.
- [ ] P3 — D9. A pointer leads nowhere. `2026-10-31-fix-integrity-session-names.md` cites `todos/review-2026-10-31-213000.md` for PR #107 findings 12 and 13. That file is the review of PR #108 (sigpipe), and no `scope: pr:#107` file exists in `todos/` (probe: `grep -lE '^scope: pr:#?107' todos/*.md` returns nothing). Recommend: correct the pointer to say the shard is the only record.
- [ ] P3 — D10. Keep deferred, no action now: 094500 #22 (model pins miss `worker-start`), 111256 #4 (no orca.yaml validator), 184500 #23 (raw `orchestration send` grant in review.md), 125359 #15 (over-long citation lines), 125359 #17 (phrase scope), 191547 #2 (nudge timeout per command). Recommend: keep.

## After L46 — left open, fix lands in an L46 file

These fixes land in §12a/§12b, `orca-send.sh`, `orca-nudge.sh`,
`orca-rebind.sh` or `check-orca-nudge*.sh`, or in the two L46 shards:
review-2026-10-30-094500 #21 #25; 152000 #3 (P2) #7; 125030 #12 #15;
161650 #6 (P2) #11 #13 #19; 181219 #5 #13 #14 #15 #16; 191547 #11 #12;
10-30-192000 #6 #7 #15; 10-31-120000 #8-#14; 125359 #14 #16 #18;
184500 #18; 10-31-192000 #11-#16 #19 #20; 214500 #22 #26 #27 #28 #30;
230000 #4 (= L46 item 1) #6; 233000 #7 #8 #9; 232854 #11 (if not closed by D2);
review-2026-11-01-083310 (all).

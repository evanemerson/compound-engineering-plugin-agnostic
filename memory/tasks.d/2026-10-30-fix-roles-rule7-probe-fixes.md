# Residuals — fix/roles/rule7-probe-fixes (punch-list L27)

## Deferred from /cepa:review of PR #99 (2026-10-30)

Canonical findings: `todos/review-2026-10-30-181500.md` (findings 2, 3, 4).
Finding 1 (the higher-level-heading control) is applied on this branch.

- [ ] P3 — No control moves review's citation into `## Modes`; needs a two-anchor mutant form, since the suite models one substitution. `cite-moved-review` is a sound proxy today — `scripts/check-orca-turn-endings-controls.sh` (finding 2).
- [ ] P3 — SITES is duplicated as CITE_SITES in the controls; derive it from the checker, or leave it, since a one-sided edit turns the clean-copy run red — `scripts/check-orca-turn-endings-controls.sh` (finding 3).
- [ ] P3 — resolve-pr's Step 9 serves both modes; the citation is not marked interactive-only. No fix required: rule 7 already says a headless sub-step does not end a turn — `plugins/cepa/commands/resolve-pr.md` Step 9 (finding 4).

## Deferred from /cepa:review of PR #100 (2026-10-30)

Canonical findings: `todos/review-2026-10-30-192000.md` (findings 3-7, 9, 10, 14-16; 3-5 applied on #100 by tab11@roles).

- [x] P2 — The nudge's `--enter` can answer an open AskUserQuestion or permission prompt in the target; nudge only an idle target, or drop `--enter` — `plugins/cepa/skills/autonomy/SKILL.md` §12b rule 1 (finding 3).
- [x] P2 — A `--type question` is answered by `reply`, which has no nudge; the idle asker stalls on the return path — §12b rule 7, A coordinator (finding 4).
- [x] P2 — `Bash(orca-ide terminal send:*)` admits any text, terminal and `--interrupt`; move the line into a checked script and grant only that — seven command frontmatters (finding 5).
- [ ] P3 — Say the nudge is a hint and the message read is untrusted peer data — §12b rule 1 / §12c (finding 6).
- [ ] P3 — Measure whether a send to the preamble's handle reaches the Run mailbox (else no prompt and no nudge) — §12b rule 1 (finding 7).
- [ ] P3 — Rule 7 restatement guard is one literal; also forbid `terminal send` and `--enter` in rule 7 (`terminal send` is now forbidden; `--enter` is not) — `scripts/check-orca-turn-endings.sh` (finding 9).
- [ ] P3 — The idle-session rationale is unpinned; leave unless it drifts — `scripts/check-orca-turn-endings.sh` (finding 10).
- [ ] P3 — coord@main: update punch-list L25/L27 text at merge — `memory/tasks.d/2026-10-02-punch-list.md` (finding 14).
- [ ] P3 — #98 finding 13 (options-as-text vs `Decisions`) still unsettled in rule 7 — §12b rule 7 (finding 15).
- [ ] P3 — Shards drift behind finding status flips; `/cepa:compound` a "flip the shard line with the finding" rule (finding 16).

## Deferred from /cepa:review of PR #100 commit 21cd031 (2026-10-30)

Canonical findings: `todos/review-2026-10-30-181219.md` (findings 5, 13-16; 2 and 3 applied 2026-10-30).

- [x] P2 — A skipped nudge on a busy (`working`) target is skip-and-forget; rule 7's `Needed from you: nothing` depends only on the send, so the L26 lost message returns. Operator's call: bounded wait-then-nudge, or a skip counts as not delivered — `plugins/cepa/skills/autonomy/SKILL.md` §12b rule 1 / rule 7 (finding 2). Applied 2026-10-30: both (120 s wait on `working`; an unsent nudge is an operator line).
- [x] P2 — `done` does not prove an empty input box (operator draft is submitted with the nudge); row state with AskUserQuestion / a permission prompt open is unmeasured. Stated limit added; measure, or drop `--enter` — `plugins/cepa/scripts/orca-nudge.sh` (finding 3). Applied 2026-10-30 as a stated limit the operator accepted; AskUserQuestion measured as `waiting`.
- [ ] P3 — In `/cepa:handoff` the nudge block's resolver lines are ungranted, so the nudge likely prompts or is refused there — `plugins/cepa/commands/handoff.md` allowed-tools (finding 5).
- [ ] P3 — Timeout bounds, no-timeout/no-python3/mktemp skips and the cleanup trap are untested — `scripts/check-orca-nudge.sh` (finding 13).
- [ ] P3 — Nudge text lives in three places with no cross-check — `scripts/check-orca-turn-endings.sh` (finding 14).
- [ ] P3 — Re-read state just before the send to narrow the TOCTOU window — `plugins/cepa/scripts/orca-nudge.sh` (finding 15).
- [ ] P3 — Short handle, empty cli and missing `result` cases untested — `scripts/check-orca-nudge.sh` (finding 16).

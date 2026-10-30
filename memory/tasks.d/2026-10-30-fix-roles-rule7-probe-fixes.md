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

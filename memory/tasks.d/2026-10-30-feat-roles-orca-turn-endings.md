# Residuals — feat/roles/orca-turn-endings (punch-list L24)

## Deferred from /cepa:review of PR #98 (2026-10-30)

Canonical findings: `todos/review-2026-10-30-161650.md` (findings 2, 6, 11, 13, 14, 19, 21).

- [x] P2 — (applied #99) `/cepa:review` and `/cepa:resolve-pr` never run §12a, so rule 7 does not reach them; add the citation (and review.md's orca-ide grants) and add both to SITES — `plugins/cepa/commands/review.md` Step 6, `resolve-pr.md` Step 9 (finding 2).
- [ ] P2 — A question sent with `orchestration send` to an idle coordinator stalls with no card in NEEDS YOU; choose a wake path or end as The operator; test it in the plan §10 probe — `plugins/cepa/skills/autonomy/SKILL.md` §12b rule 7 (finding 6). Note 2026-10-30: the nudge landed in #100 (rule 1, "Send, then nudge"); the idle-recipient re-probe is pending (L27 tail); the no-handle fallback is still open.
- [ ] P3 — The orca-ide prefix grants cannot admit §12a's compound probe; every run of the five citing commands now runs §12a and may prompt; keep, drop, or add an admissible probe helper — five command frontmatters (finding 11).
- [ ] P3 — Operator kind forbids options as text; §10d's `Decisions` lists them; say which holds — §12b rule 7 vs §10d (finding 13).
- [x] P3 — Global `~/.claude/CLAUDE.md` still requires `## Next steps`; tracked by L24, coord@main edits it after the probe (finding 14). Closed 2026-11-01 by triage: the global file now says `## Next steps` is outside Orca only.
- [x] CLOSED in PR #112 (L41, 1.44.0; rule 1 now reads the message from a file, and rule 6 does not have the hazard) — P3 — Verify whether rule 1's `CEPA_BODY` heredoc has rule 6's terminator break-out; if so apply the same guard — §12b rule 1 (finding 19).
- [x] P3 — POINTER is counted inside fences; apply CITES' `unfenced()` to §6 — `scripts/check-orca-turn-endings.sh` (finding 21). Closed 2026-11-01 (L49): fixed, control `pointer-fenced`.

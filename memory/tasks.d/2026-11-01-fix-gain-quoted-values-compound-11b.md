# Residuals — fix/gain/quoted-values-compound-11b (L59, PR #124)

## 2026-11-01 — /cepa:review of #124 (todos/review-2026-11-01-204244-fix-gain-quoted-values-compound-11b.md)

- [ ] P3 — `plugins/cepa/commands/compound.md` (three `CEPA_RUN` heredocs), `plugins/cepa/skills/autonomy/SKILL.md` §11b (two), `plugins/cepa/commands/sweep.md` (`CEPA_BRANCH`) — a value line that is exactly the fixed delimiter ends the heredoc early and the lines after it run (finding 4, reproduced). Prose states the one-line rule. Fix: a per-run delimiter the session invents (`<<'CEPA_RUN_<hex>'`), as L41 did for `CEPA_BODY`. Interface change, so it needs the operator's call.

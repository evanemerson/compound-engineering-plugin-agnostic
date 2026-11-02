# Residuals — fix/gain/sweep-heredoc-values (L50, PR #121)

## Deferred from /cepa:review of PR #121 (2026-11-01)

Canonical findings: `todos/review-2026-11-01-200405-fix-gain-sweep-heredoc-values.md`.

- [ ] P3 — The merged-branch block's SKIP lines print refused values (`$b`, `$want`, `$bad`, `$taken`) raw to the terminal; print through `printf '%q'` or strip control characters — `plugins/cepa/commands/sweep.md` SKIP echo lines (finding 7).

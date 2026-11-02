# Residuals — fix/integrity/findings-file-collision (punch-list L54)

## Found while doing L54

- [ ] P3 — `todos/sweep-YYYY-MM-DD-HHMMSS.md` (`plugins/cepa/commands/sweep.md`, headless report) has the same second-stamped, hand-composed name as the L54 findings files. L54 was scoped to `todos/review-*.md`; `findings-path.sh` takes `--kind review|review-weekly` only. Fix: add `--kind sweep` and point sweep.md at the block, after checking every reader of `sweep-*`. Probe: `git grep -n 'sweep-YYYY' -- plugins`.
- [ ] P3 — `todos/plan-review-2026-09-13-053000.md` uses a `plan-review-` prefix, so every `review-*.md` reader (check-residual-integrity.sh's walk, previous-comments-reviewer, check-health) skips it: its findings are never counted. No current writer emits that prefix (`git grep -n 'plan-review-YYYY' -- plugins` → 0). Fix: rename it to the `review-` shape, or record why it stays.
- [ ] P3 — 29 of 101 findings-file stamps end in `000` (`ls todos/review-*.md | grep -cE -- '-[0-9]{3}000\.md$'`, 2026-11-01): writers typed the stamp. The new block takes it from `date`, but the `date:` frontmatter field is still model-written, so it can disagree with the name.

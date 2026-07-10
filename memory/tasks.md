# Deferred Tasks

## 2026-07-10 — feat/compounding-hygiene (1.6.0)

Deferred review findings from the /cepa:lfg run (see todos/review-2026-07-10-160000.md and -170000.md for full detail):

1. **[P2, judgment, conf 70]** `plugins/cepa/commands/compound-refresh.md` (Phase 5) — headless commit phase can move the user's HEAD (`git checkout -b` on main carries dirty files, never returns) and a scheduled run on a foreign feature branch injects refresh commits into that branch's open PR. Proposed: record starting ref and restore it after commit/PR (or temp worktree); downgrade to Recommended-with-patch on a foreign feature branch. (r1 finding 12)
2. **[P3, judgment, conf 55]** `plugins/cepa/commands/compound.md` — in /cepa:lfg, compound artifacts (solution doc, CONCEPTS.md) are written after push/CI and never committed; next lfg run autostashes them. Proposed: headless commit instruction in compound.md, or lfg Step 7 commits/pushes compound artifacts before the report. Partly pre-existing. (r1 finding 13)
3. **[P3, mechanical, conf 60]** `plugins/cepa/commands/compound-refresh.md` (Scope Selection) — interactive broad-scope: unspecified whether clusters after the confirmed starting cluster are processed; add "Not processed this run: K docs" report line. (r1 finding 14)
4. **[P3, judgment, conf 60]** `plugins/cepa/commands/compound-refresh.md` (stale-marking) — stale-marking a doc leaves CLAUDE.md rules previously derived from it active (researcher's Active Rules side door). Proposed: on stale-mark, run the Delete-style citation grep and flag instruction-file citations in the report. (r2 finding 7)

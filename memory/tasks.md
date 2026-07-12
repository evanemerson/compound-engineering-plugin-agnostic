# Deferred Tasks

## 2026-07-10 — feat/compounding-hygiene (1.6.0)

Deferred review findings from the /cepa:lfg run (see todos/review-2026-07-10-160000.md and -170000.md for full detail):

1. ~~[P2, judgment, conf 70] compound-refresh headless commit phase HEAD-move / foreign-branch injection (r1 finding 12)~~ — **DONE 2026-07-11** (fix/refresh-commit-placement, 1.6.1): record-and-restore starting ref, own-branch vs foreign-branch ownership rules, detached-HEAD → Recommended.
2. ~~[P3] lfg compound artifacts never committed (r1 finding 13)~~ — **DONE 2026-07-11** (feat/plan-review-and-units): compound.md Step 4.7 headless commit (gitignore-aware) + lfg Step 7 verify-committed-and-pushed. Necessity confirmed by portfolio scan: all 7 repos track docs/solutions; artist360 104 docs, contexthub 29, dpc-pro 6.
3. ~~[P3] compound-refresh interactive cluster drop-out (r1 finding 14)~~ — **DONE 2026-07-11** (same branch): cluster-by-cluster continuation + "Not processed this run" report line. Necessity: artist360's 104 docs hit the 9+ path immediately.
4. ~~[P3] stale-derived CLAUDE.md rules side door (r2 finding 7)~~ — **DONE 2026-07-11** (same branch): derived-rule check on every stale-mark/Replace/Delete flags instruction-file citations in the report; never edits instruction files. Necessity: artist360 CLAUDE.md carries 20+ rules citing specific solution docs.
5. ~~Rule proposal: relay-point §7 guard~~ — **ADOPTED 2026-07-11** into repo CLAUDE.md Critical Rules.
6. ~~Rule proposal: allowed-tools re-verify~~ — **ADOPTED 2026-07-11** into repo CLAUDE.md Critical Rules.

## OB1 brain integration — outstanding (feat/brain-provider, cepa 1.10.0)

7. **[OUTSTANDING, compliance backstop] Hard-delete remediation script** — the
   `service_role` purge of `agent_memories` + orphaned `thoughts` for retracting a
   participating repo (real PHI slipped, or policy change). NOT a cepa client command
   (needs the server-only `service_role` key) → belongs in OB1-server tooling, build
   alongside U1. Until then the recall provenance filter (`brain-participants.tsv`) is
   the sole Stage-1 retraction backstop. (Plan decision 9; gauntlet prev-comments #5.)
8. **[OUTSTANDING, U1] `brain-participants.tsv` manifest** — active/retracted registry
   the recall filter reads; create with the OB1 instance setup.
9. **[OUTSTANDING, pre-U5] Live-API validation** — before backfill, confirm on the
   running instance: `schema_version` literals, `limits.max_items` shape, `mark_stale`
   drops from recall, content-hash idempotency dedups unchanged / inserts edited.

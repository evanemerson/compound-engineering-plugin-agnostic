# Residual — fix/brain-writeback-contract (PR #47)

## 2026-08-22

- P3 brain-ops backfill prompts pass the wrong `idkey` 3rd argument —
  `/home/evan/webapps/brain-ops/backfill-*.prompt.md:55` calls
  `idkey <repo> <docpath> <docpath>`, hashing the source doc instead of the
  payload file (same defect as PR #47 finding 4, fixed in cepa's compound.md).
  Deferred: `brain-ops` is a separate repository and this session did not start
  in it — global rule forbids committing there. Impact is bounded (backfills are
  one-time and complete), but a re-run would reuse stale content keys. — 2026-08-22
- Note (not a defect): `memory/tasks.md` item 9 records "Live-API validation —
  DONE 2026-07-12, ALL PASS". Two contract breaks have landed against that same
  API since (d9544e3 recall envelope, dc49bde writeback envelope + recall
  provenance), so that line is stale in effect. It is a dated historical log
  entry, not a parsed `status:` field, so nothing miscounts it. — 2026-08-22

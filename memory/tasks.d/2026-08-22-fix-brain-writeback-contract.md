# Residual — fix/brain-writeback-contract (PR #47)

## 2026-08-22

- ~~P3 brain-ops backfill prompts pass the wrong `idkey` 3rd argument~~ —
  **CLOSED 2026-08-23.** `/home/evan/webapps/brain-ops/backfill-*.prompt.md`
  called `idkey <repo> <docpath> <docpath>`, hashing the source doc instead of
  the payload file (same defect as PR #47 finding 4, fixed in cepa's
  compound.md). Deferred from PR #47 because `brain-ops` is a separate
  repository this session did not start in. Fixed by the operator in that repo:
  all four prompts (artist360, helm, dpc-pro, contexthub) now pass
  `/tmp/wb.json` as arg 3 and carry a note that the third argument is the
  PAYLOAD FILE. Verified by reading the files 2026-08-23. — 2026-08-22
- Note (not a defect): `memory/tasks.md` item 9 records "Live-API validation —
  DONE 2026-07-12, ALL PASS". Two contract breaks have landed against that same
  API since (d9544e3 recall envelope, dc49bde writeback envelope + recall
  provenance), so that line is stale in effect. It is a dated historical log
  entry, not a parsed `status:` field, so nothing miscounts it. — 2026-08-22

# Residuals — fix/roles/orca-full-reads (PR #131, punch-list L72)

## Deferred review findings (2026-11-02)

Source: `todos/review-2026-11-02-214114-fix-roles-orca-full-reads.md`.

1. [P2] `orchestration check` message rows not measured with and without `--full`; rules 5/8 and the nudge text pass none (finding 4) — `plugins/cepa/skills/autonomy/SKILL.md:2213`
2. [P3] Send re-read guard rejects the whole window on one row without `to_handle` (finding 5) — `plugins/cepa/scripts/orca-send.sh:853`
3. [P3] Health inbox guard requires possibly-nullable `thread_id`/`created_at` keys (finding 6) — `plugins/cepa/scripts/orca-health.sh:691`
4. [P3] Inbox re-read with `ok: false` reads "not stored", not "unconfirmed" (finding 7) — `plugins/cepa/scripts/orca-send.sh:851`
5. [P3] An Orca that rejects `--full` fails every send as "no message stored" (finding 8) — `plugins/cepa/scripts/orca-send.sh:215`
6. [P3] Short-shape transform omits measured short-only fields; no single-key `thread_id` case (finding 9) — `scripts/fixtures/orca-short-shape.py:47`

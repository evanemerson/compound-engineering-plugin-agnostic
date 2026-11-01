# Residuals — fix/integrity/sigpipe-grep (PR #108, L39)

## 2026-10-31 — /cepa:review of #108 (todos/review-2026-10-31-213000.md)

- [ ] P3 — `plugins/cepa/scripts/check-findings-file.sh:296-298` — counter_convention here-string has no mutant (finding 3). Add a control with a frontmatter larger than one pipe write, or accept.
- [ ] P3 — `plugins/cepa/scripts/check-findings-file.sh:318,404,410,470,491,513` and `scripts/run-mutation-sweep.sh:533,534,536` — `sed -n …p | head -1` value captures (finding 4). Not reachable today (one matched line); harden with `sed -n '…{p;q}'` if a field can repeat.
- [x] P3 — `memory/tasks.d/2026-10-02-punch-list.md:1250` — L39 still `pending` (finding 5). owner: coord@main, after #108 merges. Closed 2026-11-01 by triage: L39 CLOSED (PR #108).

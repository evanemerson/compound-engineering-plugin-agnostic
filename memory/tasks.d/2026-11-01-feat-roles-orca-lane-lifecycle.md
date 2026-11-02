# Residuals — PR #118 review (L55 Orca lane lifecycle)

Canonical findings: `todos/review-2026-11-01-181000.md`. Branch `feat/roles/orca-lane-lifecycle`. Owner: cepa coord@main (decisions are the operator's).

## 2026-11-01

- [ ] P2 — #1 The reflog guard refuses a reused lane after a squash merge — `plugins/cepa/scripts/orca-lane.sh` (rm step 3).
- [ ] P2 — #4 create cannot resume after a partial failure — `plugins/cepa/scripts/orca-lane.sh` (create).
- [ ] P3 — #16 The main checkout's orca.yaml is not verified before the hook runs — `plugins/cepa/scripts/orca-lane.sh` (rm).
- [ ] P3 — #17 The script grant widens handoff and rm has no confirm field — `plugins/cepa/commands/handoff.md` (frontmatter).
- [ ] P3 — #28 The park test uses the local origin/<base> — `plugins/cepa/scripts/orca-lane.sh` (create park).
- [ ] P3 — #30 name exits 0 when it skipped lanes — `plugins/cepa/scripts/orca-lane.sh` (name).

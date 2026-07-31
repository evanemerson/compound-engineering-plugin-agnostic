# Residuals — fix/pin-remaining-dispatch-sites (PR #25)

## 2026-07-29 — /cepa:review pr-25 (todos/review-2026-07-29-091538.md)

- [x] P3 — **CLOSED in PR fix/cite-trunk-ladder-once (1.16.0)** — moved to scripts/check-model-pins.sh at the repo root; all three live readers updated in the same commit. Originally: plugins/cepa/scripts/check-model-pins.sh:1-30 — a repo-self-check
  ships inside the distributed plugin next to consumer-facing tools; move to
  the root `scripts/` and update the CLAUDE.md rule + workflow path
  (finding #11, judgment: placement — cheaper to do together with the
  `/cepa:setup` item below)
- [x] P3 — **PARTIALLY CLOSED in PR fix/cite-trunk-ladder-once (1.16.0)** — SHA pin landed (11d5960a… # v4.4.0, verified upstream) with a bump rule in the file; the renovate/dependabot half was DECLINED and refiled as an open residual in memory/tasks.d/2026-07-30-fix-cite-trunk-ladder-once.md. Originally: .github/workflows/model-pins.yml:33 — `actions/checkout@v4` is a
  mutable tag in the repo's first workflow, which every future one will copy;
  pin to a full commit SHA verified upstream + add a bump rule
  (finding #12, judgment: confidence 55, SHA must be verified not recalled)
- [x] P3 — plugins/cepa/skills/plan-review/SKILL.md:69-78 — **operator
  decision**: the `opus` persona pin is a floor as well as a ceiling, so a
  `--model sonnet` scheduled sweep now runs 2-6 personas at opus per
  replication where they previously ran at sonnet. Accept as-is, or make the
  pin conditional on invocation mode (opus interactive, session tier
  headless) (finding #13, judgment: spend policy)
  — DECIDED + DONE 2026-07-29 in PR #26 (1.15.0): mode-conditional, `opus`
  interactive / `sonnet` under `mode:headless`. Not "session tier headless"
  as this line proposed — a fixed `sonnet` literal, because a session-
  relative ceiling is not statically checkable; §9d records that rejection
  and names a `model_policy` config key as the honest path (still a
  non-goal). Enforced by `check-model-pins.sh` leg 3.
- [ ] Deferred from PR #24, **partially closed**: finding #5 (centralize the
  dispatch-model policy in `cepa:autonomy` and cite it) — DONE 2026-07-29 in
  PR #26 (1.15.0) as §9; the normalization PR #25's finding #6 did is what
  made it cheap, as predicted. Finding #4 (`dispatch_models` Run Metadata
  field) is **still open** — see
  `memory/tasks.d/2026-07-29-fix-close-model-inherit-leaks.md`.
- Not repeated here (already recorded in the PR #24 shard, §5 dedup):
  finding #10, the `/cepa:setup` consumer half of PR #24's finding #7.

# Residuals — fix/pin-remaining-dispatch-sites (PR #25)

## 2026-07-29 — /cepa:review pr-25 (todos/review-2026-07-29-091538.md)

- [ ] P3 — plugins/cepa/scripts/check-model-pins.sh:1-30 — a repo-self-check
  ships inside the distributed plugin next to consumer-facing tools; move to
  the root `scripts/` and update the CLAUDE.md rule + workflow path
  (finding #11, judgment: placement — cheaper to do together with the
  `/cepa:setup` item below)
- [ ] P3 — .github/workflows/model-pins.yml:33 — `actions/checkout@v4` is a
  mutable tag in the repo's first workflow, which every future one will copy;
  pin to a full commit SHA verified upstream + add a bump rule
  (finding #12, judgment: confidence 55, SHA must be verified not recalled)
- [ ] P3 — plugins/cepa/skills/plan-review/SKILL.md:69-78 — **operator
  decision**: the `opus` persona pin is a floor as well as a ceiling, so a
  `--model sonnet` scheduled sweep now runs 2-6 personas at opus per
  replication where they previously ran at sonnet. Accept as-is, or make the
  pin conditional on invocation mode (opus interactive, session tier
  headless) (finding #13, judgment: spend policy)
- [ ] Deferred from PR #24 and still open: finding #4 (`dispatch_models` Run
  Metadata field) and finding #5 (centralize the dispatch-model policy in
  `cepa:autonomy` and cite it) — see
  `memory/tasks.d/2026-07-29-fix-close-model-inherit-leaks.md`. PR #25's
  review finding #6 normalized the five new pin sites to two identical
  clauses specifically so #5 stays cheap.
- Not repeated here (already recorded in the PR #24 shard, §5 dedup):
  finding #10, the `/cepa:setup` consumer half of PR #24's finding #7.

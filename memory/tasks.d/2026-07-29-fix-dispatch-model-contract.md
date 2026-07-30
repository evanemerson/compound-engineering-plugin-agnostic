# Residuals — fix/dispatch-model-contract (PR #26)

## 2026-07-29 — /cepa:review pr-26 (todos/review-2026-07-29-215819.md)

- [ ] P3 — plugins/cepa/scripts/check-model-pins.sh leg 3 — cannot verify a
  declared pair matches the tier §9c's ladder mandates:
  `interactive=haiku headless=haiku` passes (both sanctioned, not inverted)
  while silently downgrading a panel §9c puts at opus. Closing it needs a
  path→expected-tier table in the script — the hardcoded-coupling class that
  drifted three times (#6/#7/#8), plausibly worse than the gap. Documented in
  the script header AND §9f's "what the checker does NOT cover" table so a
  green run is not misread (finding #15, judgment: deliberate, revisit if a
  downgrade ever ships)
- [ ] P3 — plugins/cepa/skills/autonomy/SKILL.md — layering: §9a/§9b/§9c/§9e
  are cost governance with no gating semantics; only §9d ties tier to autonomy
  state. Natural split into a `cepa:dispatch-tiers` skill if cohesion becomes
  a problem (finding #16, judgment: trade-off chosen, not defaulted)
- [ ] P3 — **compound candidate**: no docs/solutions/ doc covers the
  restatement-drift meta-pattern — *a cross-cutting policy stated in prose at
  N call sites will diverge; state it once in the skill that owns it and
  require every site to cite, never restate*. Flagged on two consecutive PRs
  (080933 #5, 091538 #6) before centralizing, and PR #26's own consolidating
  commit restated §9a/§9f anyway (finding #1) — strong evidence for the doc.
  Run `/cepa:compound` after this merges so Detection can catch the shape
  (finding #17)
- [ ] P3 — plugins/cepa/scripts/check-model-pins.sh — deferred finding #11
  (relocate this repo-self-check to root `scripts/`) was not bundled although
  PR #26 opened the file again; third touch now on record, strengthening the
  case for doing #10 + #11 next (finding #18)
- Rejected on reasoning, not carried: finding #19 (require §9d's branch
  phrasing adjacent to each literal in prose) — co-located prose is what
  created finding #4's formatting false positive, whose cheapest remedy was
  deleting the marker. Marker authoritative, prose documentary.
- Not repeated here (still open in the PR #24 shard): finding #4
  (`dispatch_models` Run Metadata field) and finding #10 (`/cepa:setup`
  consumer-side model check) — see
  `memory/tasks.d/2026-07-29-fix-close-model-inherit-leaks.md`. Finding #12
  (`actions/checkout@v4` SHA pin) stays in the PR #25 shard.

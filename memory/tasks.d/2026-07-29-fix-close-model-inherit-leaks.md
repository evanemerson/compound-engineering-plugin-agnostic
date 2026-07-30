# Residuals — fix/close-model-inherit-leaks (PR #24)

## 2026-07-29 — /cepa:review pr-24 (todos/review-2026-07-29-080933.md)

- [ ] P2 — plugins/cepa/skills/file-todos/SKILL.md — add `dispatch_models`
  Run Metadata field so a dropped model override is observable (finding #4,
  judgment: spec-surface change)
- [ ] P2 — plugins/cepa/skills/autonomy/SKILL.md — state the dispatch-model
  policy once as a cited contract; review.md/task.md/lfg.md/adversarial-
  reviewer note cite it instead of restating (finding #5, judgment)
- [x] P3 — plugins/cepa/commands/compound.md:44-56 — pin the 5-agent
  fan-out to sonnet or document its exclusion; same for plan-review persona
  dispatch (operator policy: personas run at session model — currently
  written down nowhere) (finding #6, judgment)
  — DONE 2026-07-29 in PR #25 (1.14.0). Scope was larger than this line
  said: four command files, plus `skills/plan-review/SKILL.md` found by the
  new checker, plus four sites in `review.md` found once its trigger set was
  widened. Personas are pinned `opus`, NOT left at session model — the
  operator policy this line cites was superseded by the ceiling rule.
- [x] P3 — plugins/cepa/commands/setup.md — health check flagging any
  agents/**.md missing a `model:` frontmatter key (finding #7, judgment)
  — PARTIALLY DONE 2026-07-29 in PR #25: implemented as
  `plugins/cepa/scripts/check-model-pins.sh` + a CI workflow, which covers
  THIS repo. `/cepa:setup` itself still has no model check, so a downstream
  consumer project gets nothing — carried forward below.
- [ ] P3 — plugins/cepa/commands/setup.md — the consumer half of finding
  #7: `/cepa:setup`'s health check still never looks at `model:`
  frontmatter, so an installed-plugin project has no equivalent guard
  (PR #25 review, finding #10)
- [x] Compound candidate: no docs/solutions/ doc exists for the
  model-inherit-leak-at-dispatch-sites defect class — run /cepa:compound
  after PR #24 merges so Detection can catch future unpinned dispatches
  — DONE 2026-07-29: docs/solutions/logic-errors/unpinned-subagent-
  dispatches-inherit-the-session-model.md (5 Detection signals; gitignored
  locally, mirrored to the brain as 17 atoms). Its Prevention section
  supersedes finding #6's scope: the sweep found 3 unpinned sites, not 2
  (compound.md fan-out, plan-review.md personas, AND lfg.md Step 2.6's
  duplicated persona fallback).

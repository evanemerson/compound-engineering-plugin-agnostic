# Residuals — fix/ci-template-runtime (PR #45)

## 2026-08-09 — /cepa:review pr:45

Findings file: `todos/review-2026-08-09-*.md` (the pr:45 run). Five agents plus
the learnings researcher. Every substantive finding was against this branch's
own new work — the second review in a row where that was true.

Applied in-branch: the rule/pin contradiction, the recipe's three lying-success
paths, the third in-file copy, `model-pins.yml`'s stale exclusivity claim, the
misfiled residuals, a wrong severity tally, and the installed-copy drift check.

### Open

- [ ] P2 — **fix mode still cannot repair an installed workflow, only report
  it.** PR #45 added the detection half: `check-health.sh` compares the
  project's `uses:` pins against the templates the plugin currently ships and
  reports drift, and `setup.md` now requires that be surfaced as its own
  condition beside the CI classification. The repair half is unresolved because
  `setup.md`'s install step says *"never overwrite an existing file of that
  name"* — a deliberate safety rule, and the user's `ci.yml` is by then their
  file, adapted. So the drifted pins are named and the user edits by hand.
  Options, none free: a narrow in-place `uses:`-only rewrite for workflows that
  still carry the template's provenance marker; or a printed diff the user can
  apply; or leave it reported-only and accept that. Deliberately deferred — a
  command that edits a user's existing workflow is a real scope change and
  `setup.md`'s never-overwrite rule exists for good reasons.

- [ ] P2 — **the drift check sees copies falling behind the template; nothing
  sees the TEMPLATE falling behind the runtime.** These are different
  populations and only the first is now covered. The next Node retirement finds
  the shipped templates the same way this one did — a human noticing. Moved
  here from the `chore/adopt-dependabot` shard, where it was misfiled against
  §5's per-branch rule. Cheapest honest option remains a WARN step over
  `plugins/cepa/templates/` comparing each `uses:` major against the action's
  live `runs.using`; this is one of the few places a home-grown check is not
  competing with Dependabot, which structurally cannot reach a template
  directory. Deferred because the escalation design is a genuine decision — a
  check that reddens every PR because an upstream action deprecated something
  is the routed-around-signal failure this repo already documents. **Do not
  build it as a table of runtimes and removal dates**: that design was already
  rejected once here, and the drift check added in this PR deliberately avoids
  it by comparing against shipped content instead.

- [ ] P3 — **retrofit the placeholder remedy onto `model-pins.yml`'s own two
  examples.** `.github/workflows/model-pins.yml` still carries real version
  numbers inside copy-pasteable `gh api` recipes (the shape the
  illustrative-version-rot P3 in `2026-08-06-checkout-node24-bump.md`
  describes). PR #45 field-validated the placeholder form at two new sites and
  did the runtime audit a retrofit would need, so this is now cheap. Left out
  of #45 to keep a deadline PR from growing a third scope.

### Resolved in-branch, recorded for the pattern

- **The header taught a rule and violated it twelve lines down.** It said
  majors are chosen "by RUNTIME, not recency" while the pins were `v7/v7/v7` —
  the newest major of each, i.e. recency. Verified minimum-satisfying was
  `checkout@v5` / `setup-node@v5` / `setup-python@v6` (and note a uniform `v5`
  would have left `setup-python` on node20 — the obvious counter-proposal was
  also wrong). Resolved by stating the criterion actually used: newest major on
  a current runtime, so the next forced bump is farthest out. The rule now
  reproduces the pins, which is the only property that makes it load-bearing.

- **The lookup recipe returned a confident, exit-0 wrong answer.** Reproduced
  live: `github/codeql-action/init@v3` is node20, but folding `init` into the
  repo name reads the repo root and returns `using: composite` with exit 0.
  Empty output on failure and `using: composite` were both being read as
  passes. All three failure modes are now named in the header. This was a
  lying-success path shipped as an instruction into other people's repos — the
  repo's dominant defect class, in the artifact meant to prevent it.

- **Two claims falsified by cheap checks, again.** #44's review had two; this
  one had the rule/pin contradiction and the severity tally. The tally is the
  sharper lesson: the PR body asserted "counters rebalanced (10/10/10)" and the
  check run was real — it validated `p1+p2+p3 == total` and the status sum, but
  not the severity *distribution*, which was 2/7/1 against a declared 2/6/2. A
  verification that passes while checking the wrong invariant reads exactly
  like one that checked the right one.

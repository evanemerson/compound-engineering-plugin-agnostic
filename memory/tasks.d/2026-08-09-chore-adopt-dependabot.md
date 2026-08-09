# Residuals — chore/adopt-dependabot (PR #44)

## 2026-08-09 — /cepa:review pr:44

Findings file: `todos/review-2026-08-09-*.md`. Five agents (security-sentinel,
architecture-reviewer, silent-failure-hunter, adversarial-reviewer,
previous-comments-reviewer) plus the learnings researcher. Applied in-branch:
the cite-once P1, two duplication P2s, two stale `todos/` statuses with their
counters, a wrong prediction corrected, and `applies-to: security-updates`.
Below is what could not land in a config-adoption PR.

### Open

- [ ] P1 — **the CI templates this repo SHIPS pin a runtime that dies on
  2026-09-16, and no detector here can see them.** Found by the adversarial
  reviewer, outside the diff, and verified directly:
  `plugins/cepa/templates/ci/django.yml:77,105` and
  `plugins/cepa/templates/ci/astro.yml:21` carry `actions/checkout@v4` — the
  last `node20` line, per `model-pins.yml`'s own eligibility rule — plus
  `setup-python@v5` and `setup-node@v4` as mutable tags.
  `plugins/cepa/commands/setup.md:178` installs one into a user's project on
  `/cepa:setup fix`. **38 days from filing.** After removal these are, in
  `model-pins.yml`'s own words, "a job with no interpreter" — and the breakage
  surfaces in the user's repo, not this one.

  **Blind by construction, all four detectors:** `runtime-deprecation`
  enumerates `repos/$GITHUB_REPOSITORY/actions/workflows` and reads annotations
  from runs *this repo executes* — templates never execute here, so they can
  never enter `hits`. Dependabot's `github-actions` ecosystem with `directory: /`
  scans `.github/workflows/` only, and **has no path form that reaches a
  directory of workflow templates** — this is not fixable by adding an
  `updates:` entry. The escape-hatch grep scans `.github/` only.
  `check-model-pins.sh` checks model pins, not action pins.

  This is one of the few places a home-grown check is NOT competing with a
  configuration file — the usual argument against building one does not apply.
  Two decisions: **(a) bump the tags before 2026-09-16, as its own PR, reading
  each candidate's `runs.using` rather than trusting recency** (they are
  deliberately tags, not SHAs, which is defensible for a template a user
  adapts — so this is a tag bump, not a conversion to pinning); **(b) decide who
  owns template action currency and write it down**, since no automation can.
  Scope note already added to `2026-08-06-derive-changelog-on-release.md`.

- [ ] P2 — **nothing re-reads the two repo settings the adoption depends on.**
  Raised independently by silent-failure-hunter and adversarial-reviewer.
  `vulnerability-alerts` and `automated-security-fixes` were enabled out of tree
  and verified once, in a session, then discarded — the repo's own
  `verification-evidence-must-be-a-committed-executable-artifact` S1 signal
  (*verification built, run, and discarded*). The failure is silent by
  construction: version updates are configured in-tree, so **weekly `chore:` bot
  PRs keep arriving on schedule after the settings are off** — the observable
  signal does not change while CVE coverage is gone. Three no-intent triggers
  besides a deliberate click: a fork (alerts default OFF), a transfer into an
  org whose default is off, a settings restore.

  Fix: a fourth job in `model-pins.yml` beside `sweep-freshness` and
  `runtime-deprecation` — the credential-in-its-own-job pattern is established
  twice in that file, so it is additive. Read
  `.security_and_analysis.dependabot_security_updates.status` (needs
  `administration: read`) and warn, never fail, exiting 0 after an explicit
  warning per the sibling jobs' contract. **Verify that scope actually populates
  the field under `GITHUB_TOKEN` before relying on it** — it is admin-gated and
  was confirmed only under a PAT. If it does not, fall back to
  `GET /repos/{owner}/{repo}/automated-security-fixes` and treat 403 as
  `UNVERIFIED` with a warning, never a pass. `.github/dependabot.yml`'s header
  now names this gap and points here.

- [ ] P2 — **`.github/dependabot.yml` has no validation, and a broken config is
  indistinguishable from a quiet one.** A malformed key, a wrong
  `package-ecosystem`, or a `directory` matching nothing surfaces only on the
  repo's Insights → Dependabot page. Nothing in CI parses it. The repo's
  dominant self-documented defect class, applied to the file that just became
  load-bearing. The established local convention is policy-file-plus-observer
  (`check-model-pins.sh` + its controls suite). Minimally a YAML-parse plus
  required-key check gated on changes to the file. Note the honest counter-
  argument before building: this is a fifth home-grown detector, and the
  adoption's own reasoning was that those lose to configuration.

- [ ] P3 — **grouping trades isolated review for atomic bumps, and the trade is
  invisible until a second action exists.** `patterns: ["*"]` is a no-op today —
  `actions/checkout` is the only distinct dependency, and Dependabot's
  github-actions updater already opens one PR per dependency spanning every file
  that references it, so the three sites move together with or without the
  block. The moment a second action is added, an unrelated or compromised bump
  can ride along with a benign one under a single approval. Re-examine then;
  narrow the pattern or state the trade at the site.

- [ ] P3 — **compound candidate: "a deferral whose blocking premise can never
  resolve is a decline that was never written down."** The
  renovate/dependabot question appears as an independent finding or deferral at
  least six times across ten weeks —
  `todos/review-2026-07-29-091538.md:401` → `review-2026-07-30-234123.md` →
  `memory/tasks.d/2026-07-30-fix-cite-trunk-ladder-once.md` →
  `2026-08-06-checkout-node24-bump.md` → `review-2026-08-06-151255.md:665` →
  `review-2026-08-07-030542.md:260` → closed here. Each deferral was locally
  reasonable; none noticed the premise was permanent. No solution doc covers it.
  Run `/cepa:compound` with a Detection section keyed on deferral reasons that
  name an unchanging repo property. Pairs with the existing
  `cross-cutting-policy-must-be-cited-once` doc.

### Recorded, not filed as findings

- The **escalation-clock P2** from the same review lives in
  `memory/tasks.d/2026-08-06-feat-runner-runtime-detector.md`, with the job it
  concerns, rather than here.
- **Three reviewers refuted this branch's own token prediction** by static read.
  Corrected in that same shard. The instructive part is that labelling a claim
  "a prediction, not an observation" is what made shipping it feel safe — an
  honest label is not a substitute for cheap verification.
- **`groups` without `applies-to` covers version updates only** — confirmed
  against GitHub's options reference during the run, not recalled. The
  single-group cut would have left the CVE half ungrouped.

# Residuals — node20 runtime sweep, INSTALLED COPIES (portfolio-wide)

## 2026-08-28 — cross-repo sweep, filed from `main`

Not a review shard. This is the population that
`memory/tasks.d/2026-08-09-chore-adopt-dependabot.md` explicitly declared out of
scope when it closed its P1:

> "this closes the TEMPLATE population. Copies already installed in users'
> repos are a distinct problem."

This shard IS that distinct problem, measured. It was first swept on 2026-08-09
in a session that ended on an unanswered menu, so it lived only in a transcript
for 19 days. Re-derived from scratch on 2026-08-28 rather than filed from the
stale numbers — two upstream targets had already moved in that window
(`setup-uv` v9→v10, `setup-buildx` v4.2→v4.3) and one new repo had appeared
(`illo-characters`), so filing the old table would have shipped wrong pins.

**Deadline: 2026-09-16 — 19 days from this filing.** After removal these are,
in `model-pins.yml`'s own words, "a job with no interpreter."

### Method (so this is reproducible, not recalled)

Every `uses:` across `~/webapps/*/.github/workflows/*.y{a,}ml`, each distinct
pin resolved to its own `runs.using` upstream — never inferred from the version
number, per the template header's rule:

```
gh api "repos/<OWNER>/<REPO>/contents/action.yml?ref=<TAG>" \
  --jq .content | tr -d '\n' | base64 --decode | grep -A2 '^runs:'
```

Both `action.yml` and `action.yaml` spellings tried; empty output treated as
LOOKUP-FAILED, never as a pass. Composites recursed into (see below).

Cutline, verified live 2026-08-28: **`checkout`/`setup-node` v5+ and
`setup-python` v6+ are node24; v4 and below are node20/16/12.**

### Scope: 30 repos scanned, 15 have workflows, 10 are exposed

Clean (all node24): `artist360`, `compound-engineering`, `contexthub`,
`dpc-insider-www`, `helm`, `kcprimetime`. Fifteen repos have no workflows.

- [ ] **P1 — `medusajs` (7 pins, worst — node12)**
  ```
  actions/checkout@v2.3.5                 node12 -> actions/checkout@v7
  actions/checkout@v3                     node16 -> actions/checkout@v7
  actions/setup-node@v3                   node16 -> actions/setup-node@v7
  peter-evans/create-pull-request@v5      node16 -> peter-evans/create-pull-request@v8
  pnpm/action-setup@v2                    node16 -> pnpm/action-setup@v6
  styfle/cancel-workflow-action@0.11.0    node16 -> styfle/cancel-workflow-action@0.13.1
  styfle/cancel-workflow-action@0.9.1     node12 -> styfle/cancel-workflow-action@0.13.1
  ```
  Nothing here is even node20 — this CI may already be degraded. Two majors
  behind on `create-pull-request` (v5→v8) and `pnpm/action-setup` (v2→v6) means
  breaking changes are likely; this one is a real port, not a tag bump.

- [ ] **P1 — `paperclip` (8 pins)**
  ```
  actions/checkout@v4                     node20 -> actions/checkout@v7
  actions/setup-node@v4                   node20 -> actions/setup-node@v7
  actions/upload-artifact@v4              node20 -> actions/upload-artifact@v7
  docker/build-push-action@v6             node20 -> docker/build-push-action@v7
  docker/login-action@v3                  node20 -> docker/login-action@v4
  docker/metadata-action@v5               node20 -> docker/metadata-action@v6
  docker/setup-buildx-action@v3           node20 -> docker/setup-buildx-action@v4
  pnpm/action-setup@v4                    node20 -> pnpm/action-setup@v6
  ```
  The whole docker publish chain. If this pipeline pushes images, its failure
  is a shipping failure, not just a red check.

- [ ] **P1 — `OB1` (6 pins)**
  ```
  actions/checkout@v4                     node20 -> actions/checkout@v7
  actions/github-script@v7                node20 -> actions/github-script@v9
  actions/setup-node@v4                   node20 -> actions/setup-node@v7
  actions/upload-artifact@v4              node20 -> actions/upload-artifact@v7
  peter-evans/create-pull-request@v6      node20 -> peter-evans/create-pull-request@v8
  release-drafter/release-drafter@v6      node20 -> release-drafter/release-drafter@v7
  ```

- [ ] **P2 — `artist360-www` (3)** — `checkout@v4`→v7, `setup-node@v4`→v7,
  `cloudflare/wrangler-action@v3`→v4. Wrangler v3→v4 is a major; check its
  changelog before assuming a tag swap.
- [ ] **P2 — `bakerydemo` (2)** — `checkout@v4`→v7, `setup-python@v4`→v7
  (node16). Note it already runs `checkout@v6`/`setup-node@v6` elsewhere in the
  same repo, so the v4s are stragglers in one file.
- [ ] **P2 — `dpc-pro-docs` (2)** — `checkout@v4`→v7, `setup-node@v4`→v7.
- [ ] **P2 — `youtube` (2)** — `checkout@v4`→v7, `astral-sh/setup-uv@v5`→v10.
  Five majors on setup-uv; read its changelog.
- [ ] **P3 — `dpc-pro` (1)** — `setup-node@v4`→v7. Its `checkout@v5` and
  `setup-python@v6` are already node24.
- [ ] **P3 — `compound-engineering-plugin` (1)** —
  `googleapis/release-please-action@v4.4.0`→v5. This is the cepa mirror; worth
  doing for consistency with the rule this repo enforces elsewhere.
- [ ] **P3 — `illo-characters` (1)** — `checkout@v4`→v7. Repo did not exist at
  the 2026-08-09 sweep; found only because the sweep was re-run.

### Cross-repo boundary

Per CLAUDE.md, **none of these fixes may be made from this repo's sessions.**
Each is a branch + PR in its own repo's session. This shard is the durable
carrier; `docs/handoff/2026-08-28-node20-installed-copies.md` holds the
paste-ready prompt blocks.

### Feeds an already-open finding

`memory/tasks.d/2026-08-09-fix-ci-template-runtime.md` has an open P2: *"the
drift check sees copies falling behind the template; nothing sees the TEMPLATE
falling behind the runtime."* This sweep adds a third, unrecorded population and
a measurement of how badly the existing check answers the deadline question:

**cepa's `check-health.sh` pin check is neither sound nor complete for
"does this break in September."** Measured against this sweep:

- **False alarms (4):** `contexthub`, `helm`, `kcprimetime`, `dpc-insider-www`
  are all flagged as drifted and are all entirely node24.
- **Misses (3+):** it only compares the three actions its own templates use, so
  `paperclip`'s five docker actions, `OB1`'s `release-drafter`/`github-script`/
  `upload-artifact`, and `youtube`'s `setup-uv` are invisible. Worst case is
  `compound-engineering-plugin`, where the flagged pin (`checkout@v6`) is fine
  and the real exposure (`release-please@v4.4.0`) is unseen.

It measures **template conformance**, which is a different question from
**runtime risk**. Not a defect in what it was built to do — a limit on what it
can be used to conclude. The open P2's proposed WARN step over
`plugins/cepa/templates/` would inherit the same blind spot unless it resolves
`runs.using` rather than comparing shipped content.

### Stated limits

- **Composites resolved, not assumed.** The 2026-08-09 sweep left two flagged
  UNVERIFIED, per the template's own "composite is NOT a pass" warning. Both
  now recursed: `anthropics/claude-code-action@v1` → inner
  `oven-sh/setup-bun@0c5077e` (node24, clean); `appleboy/ssh-action@v1` → no
  nested actions, only `shell: bash` run steps (clean). Neither adds exposure.
- **A 40-hex SHA pin is not resolved to a runtime here.** `compound-engineering`
  itself carries `actions/checkout@3d3c42e…`; it was resolved by SHA in this
  pass (node24), but the general case needs a network lookup per SHA and is not
  covered by the tag cutline above.
- **Only `~/webapps/*` at depth 1 was scanned.** Nested checkouts, worktrees,
  and repos outside `~/webapps` are unmeasured.
- **Upstream targets drift.** Two moved in the 19 days between sweeps. Re-verify
  `runs.using` at fix time; do not paste these tags blind.

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

### Scope: 30 repos scanned, 15 have workflows, 10 exposed — but only 4 ARE OURS

**Ownership was not checked in the first two passes of this shard, and it is the
single most important cut.** Ten repos carry dying pins; six of them are other
people's code that merely sits in `~/webapps`. We cannot merge a PR in those,
and their maintainers own their own CI. Checked by `git remote get-url origin`
plus `git log --author=Evan | wc -l`, and by `gh api repos/... --jq .fork` for
the one ambiguous case.

Clean and ours (all node24): `artist360` (fixed 2026-08-09, PR #286),
`compound-engineering`, `contexthub`, `dpc-insider-www`, `helm`, `kcprimetime`.
Fifteen repos have no workflows at all.

#### OURS — the actual work list (4 repos, 8 pins)

- [ ] **P2 — `artist360-www` (3)** — `evanemerson/artist-360-www`, 26 commits ours.
  `checkout@v4`→v7, `setup-node@v4`→v7, `cloudflare/wrangler-action@v3`→v4.
  **The only one of the four needing care:** wrangler-action v3→v4 tracks
  Wrangler itself, and this workflow deploys the site — confirm the project's
  wrangler version is compatible rather than assuming a tag swap.
- [ ] **P3 — `dpc-pro-docs` (2)** — `evanemerson/dpc-pro-docs`, 82 commits ours.
  `checkout@v4`→v7, `setup-node@v4`→v7. Pure tag swap.
- [ ] **P3 — `youtube` (2)** — `evanemerson/youtube-transcript-scraper`, 52
  commits ours. `checkout@v4`→v7, `astral-sh/setup-uv@v5`→v10. Five majors on
  setup-uv (cache behaviour and `enable-cache` defaults moved) — read that
  changelog; the checkout half is a straight swap.
- [ ] **P3 — `dpc-pro` (1)** — `evanemerson/dpc-pro`, 1327 commits ours.
  `setup-node@v4`→v7. Its `checkout@v5` and `setup-python@v6` are already
  node24, and its `appleboy/ssh-action@v1` composite is clean. One line.

#### NOT OURS — recorded, not owed (6 repos, 25 pins)

Do not open PRs in these. They will break on 2026-09-16 if their maintainers do
nothing; the only action on our side is to pull their updates before September
if their CI breaking would block us. Listed because a future sweep will find
them again and should not re-litigate ownership.

| Repo dir | Actually owned by | Pins | Note |
|---|---|---|---|
| `medusajs` | `medusajs/medusa-starter-default` | 7 | upstream starter template; nothing even node20 — all node12/16 |
| `paperclip` | `paperclipai/paperclip` | 8 | **a fork under our account** — `gh api` confirms `fork=true`; top authors Dotta/Forgotten/Devin Foley, zero ours |
| `OB1` | `NateBJones-Projects/OB1` | 6 | Nate's project; we use it, we do not own its CI |
| `bakerydemo` | `wagtail/bakerydemo` | 2 | Wagtail's demo app |
| `compound-engineering-plugin` | `EveryInc/compound-engineering-plugin` | 1 | **the upstream cepa was derived from — NOT our mirror.** Our plugin is this repo, `compound-engineering` |
| `illo-characters` | `tmchow/illo-characters` | 1 | the illo skill's asset repo |

**Two misattributions this section corrects, both from trusting a path or a
remote prefix instead of checking:** `compound-engineering-plugin` was called
"the cepa mirror" and given a do-it-for-consistency rationale — it is a third
party's repo. `paperclip` was counted as ours because its remote reads
`evanemerson`; it is a fork of `paperclipai/paperclip` with none of our commits.
Both were P1/P3 items on a work list they never belonged on. The first two
passes of this shard ranked `medusajs` as P1 — the single highest-priority item
was in a repo we cannot merge to.

### Cross-repo boundary

Per CLAUDE.md, **none of these fixes may be made from this repo's sessions.**
Each is a branch + PR in its own repo's session. This shard is the durable
carrier; `docs/handoff/2026-08-28-node20-installed-copies.md` holds the
paste-ready prompt blocks — for the four owned repos only.

Note the boundary rule and the ownership cut are different constraints that
happen to point the same way here. The boundary rule says *do not run commands
in another checkout*; it applies to `dpc-pro` as much as to `medusajs`.
Ownership says *there is no PR to open at all*; it applies only to the six.

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
- **Ownership is inferred from remote + commit authorship, not from a manifest.**
  `git remote get-url origin` plus an author count, with `gh api .fork` for the
  ambiguous case. A repo we own but have never committed to under the name
  "Evan" would be misfiled as third-party by this method. The six were each
  checked by hand; a future sweep should re-check rather than inherit this
  table.
- **Upstream targets drift.** Two moved in the 19 days between sweeps. Re-verify
  `runs.using` at fix time; do not paste these tags blind.

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

#### Second check, added 2026-08-28 after it failed: DOES THE TAG EXIST?

The runtime lookup above resolves the runtime **of a tag**, and in doing so
silently assumes the tag exists. That assumption is what broke on `youtube`:
this shard prescribed `astral-sh/setup-uv@v10`, which 404s. The runtime check
had "passed" because it was run against `@v10.0.1` — a real release — while the
line written into the work list carried a floating major that was never
published.

Prescribing a tag therefore takes **two** checks, not one:

```
# 1. does the tag resolve at all?
gh api "repos/<OWNER>/<REPO>/git/ref/tags/<TAG>" --jq .ref     # 404 => do not prescribe

# 2. what runtime does it name? (the check already documented above)
gh api "repos/<OWNER>/<REPO>/contents/action.yml?ref=<TAG>" \
  --jq .content | tr -d '\n' | base64 --decode | grep -A2 '^runs:'
```

**Do not substitute `releases/latest` for check 1.** That endpoint reports a
*release*, which is not the same object as a resolvable ref — it is exactly
what produced the bad `v10` here, and what made an earlier pass of this shard
report "targets moved v9→v10" as though both were usable tags.

Actions are moving AWAY from floating majors as a supply-chain measure —
setup-uv cites the tj-actions compromise explicitly — so this will recur. An
action that publishes no floating major needs a deliberate full-version bump
and cannot be left to ride a major tag. Verified 2026-08-28 for the three
prescriptions still outstanding: `actions/checkout@v7`, `actions/setup-node@v7`
and `cloudflare/wrangler-action@v4` all resolve as refs. `youtube` was the only
affected item.

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

**Status 2026-09-01: CLOSED — 4 of 4 repos, 8 of 8 pins, 15 days before the
deadline.**

| repo | pins | landed as | date |
|---|---|---|---|
| `youtube` | 2 | PR #29 / `6ced39a` | 2026-08-28 |
| `artist360-www` | 3 | PR #8 / `fab115f` | 2026-08-29 |
| `dpc-pro-docs` | 2 | PR #5 / `d659c879` | 2026-08-29 |
| `dpc-pro` | 1 | direct commit `aac9bcce` | 2026-08-29 |

Verified 2026-09-01 by reading the live workflow files through `gh api` — not
by trusting this shard's own checkboxes. `dpc-pro-docs/ci.yml` carries
`checkout@v7` + `setup-node@v7`; `dpc-pro/supply-chain-audit.yml:189` carries
`setup-node@v7`, with every other pin in that repo already `checkout@v5` /
`setup-python@v6` (node24) plus the clean `appleboy/ssh-action@v1` composite.

### The shard went stale for three days and produced a hand-off for finished work

On 2026-09-01 this session read the status line above (then dated 2026-08-29,
reading "2 of 4"), re-verified that `actions/checkout@v7` and
`actions/setup-node@v7` still resolve as node24 refs, and wrote paste-ready
prompts for two repos that had **already shipped their fixes on 2026-08-29**.
The operator caught it: "I think those are both done."

**The wrong invariant was checked.** Verifying the prescription (does the target
tag exist? what runtime does it name?) is necessary and this shard rightly
demands it — but it says nothing about whether the *target repo still needs the
change*. Both checks passed cleanly while the work list they served was three
days out of date. This is another instance of
`checking-the-wrong-invariant-reads-exactly-like-checking-the-right-one`, and
the fourth recorded in this repo.

`dpc-pro` also shows why a PR list is not a completion check: `aac9bcce` was a
**direct commit to the branch**, so `gh pr list` showed nothing and the first
pass here concluded the pin was outstanding. The workflow file is the authority
on what a workflow pins; a PR search is a proxy that misses every non-PR path.

**For the next sweep: read the current state of the target before prescribing
anything.** One `gh api .../contents/.github/workflows/<f>` per repo — no
working tree touched, no boundary-rule tension — costs one call and is the only
check that answers "is this still owed."

- [x] ~~**P2 — `artist360-www` (3)** — `evanemerson/artist-360-www`, 26 commits
  ours.~~ **DONE 2026-08-29 — PR #8, merged as `fab115f`.**
  `checkout@v4`→v7, `setup-node@v4`→v7, `cloudflare/wrangler-action@v3`→v4.

  **The predicted hazard was real and had a dependency consequence this shard
  did not name.** wrangler-action v3→v4 tracks Wrangler itself, so the bump
  required `@cloudflare/workers-types`→v5 for wrangler 4 (commit `e8ac058`) —
  i.e. an action pin bump reached into the project's own package
  dependencies, not just its CI. The shard said "confirm the project's wrangler
  version is compatible"; the actual work was upgrading a typings package to
  match. Worth generalizing: for any action that wraps a CLI (wrangler,
  terraform, gcloud, aws), a major bump is a **toolchain** upgrade with
  in-project dependency fallout, not a CI-only change — budget for it
  accordingly.

  That session also recorded why wrangler-action's `command` input is not
  shell-injectable (commit `3701dd0`), which is a durable answer to a question
  the bump naturally raises.
- [x] ~~**P3 — `dpc-pro-docs` (2)** — `evanemerson/dpc-pro-docs`, 82 commits
  ours. `checkout@v4`→v7, `setup-node@v4`→v7. Pure tag swap.~~
  **DONE 2026-08-29 — PR #5, merged as `d659c879`.** Swap was pure as predicted.
- [x] ~~**P3 — `youtube` (2)** — `evanemerson/youtube-transcript-scraper`, 52
  commits ours.~~ **DONE 2026-08-28 — PR #29, merged as `6ced39a`.** CI green
  on both matrix legs.
  ```
  actions/checkout@v4     -> @v7        node24
  astral-sh/setup-uv@v5   -> @v10.0.1   node24   <- NOT @v10; see below
  ```
  **This shard prescribed `setup-uv@v5`→`v10` and that tag does not exist.**
  setup-uv stopped publishing floating major and minor tags at v8.0.0 as a
  deliberate supply-chain measure, citing the tj-actions compromise. Verified
  against the API: `@v8`, `@v9`, `@v10` all 404 while `@v5` still resolves —
  the floating majors were withdrawn, not merely absent for v10. Only full
  versions (`v10.0.1`) or commit SHAs resolve. Applying the old line verbatim
  produced a workflow whose action cannot be resolved at all — a harder failure
  than the node20 one this shard exists to fix. **setup-uv needs deliberate
  full-version bumps; there is no floating major to ride.**

  Changelog review v5→v10, since this shard flagged it as the part needing
  care: both inputs this workflow uses survive unchanged (`python-version`
  still sets `UV_PYTHON`; `enable-cache` still boolean). Removed inputs
  `pyproject-file`/`uv-file` (v6) and `server-url` (v7) were unused. v6 stopped
  auto-activating a venv for `python-version` — harmless here because every
  step goes through `uv sync`/`uv run`. v10 changed the `enable-cache` DEFAULT
  to `auto` (disables caching on `pull_request_target`/`workflow_run`/
  `release`), so the explicit `enable-cache: true` was kept, with a comment.
- [x] ~~**P3 — `dpc-pro` (1)** — `evanemerson/dpc-pro`, 1327 commits ours.
  `setup-node@v4`→v7. Its `checkout@v5` and `setup-python@v6` are already
  node24, and its `appleboy/ssh-action@v1` composite is clean. One line.~~
  **DONE 2026-08-29 — direct commit `aac9bcce`, no PR.** In
  `supply-chain-audit.yml:189`. Because it never became a PR, a `gh pr list`
  check on 2026-09-01 reported it outstanding; the workflow file is the
  authority, not the PR list.

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
carrier, and the paste-ready prompt blocks are inlined below rather than kept
in a separate handoff.

An earlier revision pointed at
`docs/handoff/2026-08-28-node20-installed-copies.md`. **`docs/` is gitignored in
this repo**, so that file existed only on the machine that wrote it — the
pointer resolved to nothing from any other checkout or for anyone else reading
the shard. Same defect class as a stale count: a reference that reads as
authoritative and cannot be followed. The blocks now live in the tracked file
that is meant to carry them.

Note the boundary rule and the ownership cut are different constraints that
happen to point the same way here. The boundary rule says *do not run commands
in another checkout*; it applies to `dpc-pro` as much as to `medusajs`.
Ownership says *there is no PR to open at all*; it applies only to the six.

#### Paste-ready prompt blocks — the two outstanding repos

Every tag below was re-verified as a resolvable ref on 2026-08-28. Re-verify at
fix time anyway: run BOTH checks in the Method section, since tags can be
withdrawn as well as superseded.

(The `artist360-www` block is retired — that repo shipped as PR #8 / `fab115f`.)

**`dpc-pro-docs`** — 2 pins, pure swap:

```
CI action pins in this repo target the node20 runtime GitHub removes on
2026-09-16. After that date an action needing node20 has no interpreter and the
step dies. Before changing any pin, verify BOTH that the target tag resolves
(gh api "repos/<OWNER>/<REPO>/git/ref/tags/<TAG>") and what runtime it names.
Then branch, fix, and open a PR.

  actions/checkout@v4     node20 -> actions/checkout@v7
  actions/setup-node@v4   node20 -> actions/setup-node@v7

Both are straight tag swaps with no input changes. Confirm the workflow still
parses and CI runs green.

Note actions/setup-node sets the Node version used to build THIS PROJECT; the
bump changes only which Node runs the action itself. Do not change the
project's node-version input.

Context: portfolio sweep at
memory/tasks.d/2026-08-28-node20-runtime-sweep-installed-copies.md in the
compound-engineering repo. Check this repo's own base-branch convention rather
than assuming main or dev.
```

**`dpc-pro`** — 1 pin:

```
One CI action pin in this repo targets the node20 runtime GitHub removes on
2026-09-16. After that date an action needing node20 has no interpreter and the
step dies. Before changing it, verify BOTH that the target tag resolves
(gh api "repos/actions/setup-node/git/ref/tags/v7") and what runtime it names.
Then branch, fix, and open a PR.

  actions/setup-node@v4   node20 -> actions/setup-node@v7

Leave everything else alone: actions/checkout@v5 and actions/setup-python@v6
are already node24, and appleboy/ssh-action@v1 is a composite with no nested
actions (only `shell: bash` run steps), so it is clean.

Note actions/setup-node sets the Node version used to build THIS PROJECT; the
bump changes only which Node runs the action itself. Do not change the
project's node-version input.

Context: portfolio sweep at
memory/tasks.d/2026-08-28-node20-runtime-sweep-installed-copies.md in the
compound-engineering repo. dpc-pro branches off dev — confirm before creating
the branch.
```

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

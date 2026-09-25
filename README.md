# CEPA — Compound Engineering Plugin Agnostic

CEPA is a [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin
that runs your whole engineering loop and keeps what it learns. Audit the git
state, research past work, plan, build with tests first, review with parallel
agents, then write down what the work taught you. One command does all of it.
It fits any stack, because every agent reads its conventions from one file in
your project instead of having Rails or Django baked in.

The part that compounds is the last step. Each finished task leaves a solution
doc behind: what broke, why, the fix, and the code pattern that would catch it
again. The next task searches those docs before design starts, and review agents
load the detection patterns from the ones that match your diff. Fix something
once and the system starts watching for it. Put `/cepa:sweep` on a schedule and
even deferred work drains back through the pipeline on its own.

Claims like that are cheap, so this repo checks itself. Every subagent dispatch
must declare its model tier, and a script fails the build if one doesn't. A
second script proves that checker still catches what its record says it catches.
A mutation sweep then sabotages the checker on purpose to confirm the proof
would notice. Details are in [Verification](#verification).

```
Plan → Work → Review → Compound
  ↑                        |
  └────── learnings ───────┘
```

---

## Start here

Three commands cover most of the work. The other eight are in
[the full table](#commands-11).

**`/cepa:task <what you want>`** runs the loop end to end, stopping at decision
points. Start here if you are new.

**`/cepa:review`** runs the review agents against your current changes and
writes the findings to `todos/`. Useful on its own, no loop required.

**`/cepa:lfg <issue #>`** is the same loop with nobody watching: build, review
and fix until clean, open the PR, watch CI to green, compound, then one report
at the end. Marked beta because it commits and pushes without asking.

---

## Install

You need Claude Code and the GitHub CLI (`gh`) for PR and issue handling.

Fastest path, which installs cepa and its companions together:

```bash
bash <(curl -s https://raw.githubusercontent.com/evanemerson/compound-engineering-plugin-agnostic/main/scripts/setup.sh)
```

Or step through it yourself:

```bash
# cepa
claude /plugin marketplace add evanemerson/compound-engineering-plugin-agnostic
claude /plugin install cepa

# superpowers — required. Supplies the brainstorm, plan, and execute skills
# cepa delegates to in Phases 2 and 3.
claude /plugin marketplace add obra/superpowers-marketplace
claude /plugin install superpowers

# pr-review-toolkit — required. Five more review agents. Already in the
# built-in claude-plugins-official marketplace, so no registration needed.
claude /plugin install pr-review-toolkit
```

Recommended, not required:

```bash
claude /plugin install commit-commands      # /commit, /commit-push-pr
claude /plugin install claude-md-management # /revise-claude-md
claude /plugin install code-review          # GitHub PR review
```

Update with `claude /plugin update cepa`.

---

## Quick start

Write `cepa.local.md` in your project root. This is the file that makes cepa
stack-agnostic, and every agent reads it.

```markdown
# cepa Project Configuration

## Stack
- framework: Django 5.x
- frontend: HTMX, vanilla JS, Tailwind CSS
- database: PostgreSQL 18
- testing: pytest-django
- linting: ruff

## Review Agents (Active)
- security-sentinel
- performance-oracle
- python-reviewer
- data-integrity-guardian
- architecture-reviewer
- schema-drift-detector
- frontend-reviewer
- deployment-verifier
```

Create the directories cepa writes to:

```bash
mkdir -p docs/brainstorms docs/plans docs/solutions todos
```

Then run it:

```
/cepa:task add user authentication to the portal
```

Or let `/cepa:setup` do the scaffolding. It health-checks what you have, and
`/cepa:setup fix` creates what's missing and installs a CI template matched to
your stack.

[CONFIGURATION.md](CONFIGURATION.md) has the full reference, including examples
for Next.js, FastAPI, and Rails.

---

## How the loop works

Five phases. [LOOP.md](LOOP.md) documents each step in detail, including the
exact commands and hand-offs.

**Phase 1 — Git safety audit.** cepa won't start work in a confused git state.
It inspects your tree, stashes, and unpushed branches, reports anything
unresolved as numbered choices, then branches from the latest trunk. Pass an
issue number and it pulls those requirements first.

**Phase 2 — Research and design.** `learnings-researcher` searches
`docs/solutions/`, `CLAUDE.md`, your residual shards, and past plans, then puts
what it found in front of you before design starts. Design itself goes to
`superpowers:brainstorming`, which asks questions one at a time and proposes a
few approaches with trade-offs.

**Phase 3 — Plan and build.** The plan gets written as Implementation Units with
stable ids and per-unit test scenarios, then committed. A persona panel reviews
it before any code exists, because a design flaw caught here costs a paragraph
instead of a refactor. Build runs task by task with tests written first.

**Phase 4 — Ship and review.** Tests and linter run, the PR opens, and up to 16
review agents go out in parallel. Findings are deduplicated into `todos/` with
P1/P2/P3 severity and confidence scores. P1s get fixed on the spot. P2s and P3s
either become numbered choices or flow through the auto-apply rubric, depending
on your autonomy setting.

**Phase 5 — Compound.** Always runs. The work becomes a solution doc with a
Detection section written for the review agents that will read it next time.
Prevention strategies become proposed CLAUDE.md rules. Anything skipped goes
into a residual shard rather than getting lost.

---

## Verification

Most of this plugin is prose that tells a model what to do, which is exactly the
kind of thing that rots quietly. The scripts in `scripts/` push back, and every
one of them is read-only.

**`check-model-pins.sh`** is the one that matters most. An omitted `model:` key
on a dispatch isn't a neutral default: the subagent inherits whatever tier
launched the session, so cost becomes a property of the caller. An audit in July
2026 traced roughly 91% of weighted spend to unpinned dispatches. This script
walks every dispatch site in the plugin and fails on any that could fall
through. Run it before you merge.

**`check-model-pins-controls.sh`** proves the checker still works. It feeds
known-bad input and confirms each MISS still fires, so the pin check can't rot
into a green light that means nothing.

**`run-mutation-sweep.sh`** sabotages the checker deliberately and confirms the
controls notice. Takes about 43 minutes locally, and it refuses a tree that
changed mid-run, so don't edit tracked files while it works.

**`check-residual-integrity.sh`** catches a narrower failure. A findings file can
say "resolved" in its prose while the frontmatter field a consumer parses still
says open. This checks that the parsed field agrees with the body, in both
findings files and residual shards.

There is also `check-sweep-branch-classes.sh`, which fixtures branch shapes no
real repo in the portfolio produces (a non-trunk base, multiple merged PRs on one
head), and `check-brain-client-args.sh` for the brain client's argument guards.

CI pins its actions and Dependabot keeps them current.
[CHANGELOG.md](CHANGELOG.md) is generated from GitHub Releases rather than
hand-written.

---

## Commands (11)

| Command | What It Does |
|---|---|
| `/cepa:task` | Full loop orchestrator, all 5 phases end to end, gated or autonomous via the `autonomy:` config |
| `/cepa:lfg` | **BETA** — the loop hands-off: build, review and fix until clean, PR, watch CI to green, compound, one report |
| `/cepa:review` | Review agents in parallel (8 roster + 3 conditional + 5 pr-review-toolkit), P1/P2/P3 severity with confidence scores. Loads Detection sections from matching solution docs. Supports `mode:headless` and `cadence:weekly` |
| `/cepa:triage` | Triage findings. Batch mode auto-applies safe verified fixes and tables the rest. Pass `interactive` to go one at a time |
| `/cepa:plan-review` | Persona-panel review of a plan before build, with conditional activation and confidence anchors. Supports `mode:headless` |
| `/cepa:compound` | Document a solved problem with 5 parallel sub-agents. Seeds the CONCEPTS.md vocabulary map. Supports `mode:headless` |
| `/cepa:compound-refresh` | Refresh `docs/solutions/` against the current code: update drifted learnings, consolidate overlap, prune dead docs, reconcile CONCEPTS.md. Supports `mode:headless` |
| `/cepa:sweep` | Scheduled residual sweep. Drains deferred findings, residual shards, and hygiene through full lfg runs, then closes each item in every sink. Reports merged local branches no worktree holds. Supports `mode:headless` |
| `/cepa:resolve-pr` | Resolve human PR feedback: fetch once, judge centrally, fix per the autonomy rubric, reply and resolve after push. Supports `mode:headless` |
| `/cepa:handoff` | End a session without losing state. Judges whether switching is timely (`GO`/`WAIT`/`GO WITH CARE`), inventories work in flight, makes residuals durable, resolves the next session's branch, and emits a self-contained prompt. Supports `mode:headless` |
| `/cepa:setup` | Health-check a project's cepa scaffold, or `fix` it: create missing dirs and config, install a stack-matched CI template |

## Agents (12)

`learnings-researcher` handles research, searching `docs/solutions/`,
`CLAUDE.md`, `memory/tasks.d/` (plus the legacy `memory/tasks.md`), and past
plans for anything relevant to the task at hand.

The eight roster review agents run on every review:

| Agent | What It Does |
|---|---|
| `security-sentinel` | OWASP top 10, compliance (HIPAA/SOC2/PCI), auth patterns, data exposure, input validation, secrets |
| `performance-oracle` | N+1 queries, missing indexes, caching, task queue, frontend perf |
| `python-reviewer` | Pythonic patterns, framework conventions, logging compliance, testing |
| `data-integrity-guardian` | Migration safety, transactions, referential integrity, encryption |
| `architecture-reviewer` | Module boundaries, service layers, URL conventions, task queue placement |
| `schema-drift-detector` | Model, migration, serializer, and admin alignment. Missing migrations, index consistency |
| `frontend-reviewer` | Race conditions, event listener lifecycle, polling conflicts, CSS consistency, template correctness |
| `deployment-verifier` | Container config, env vars, static assets, backwards compatibility. Ends in a Go/No-Go verdict with a rollback plan |

Three more are dispatched only when the diff calls for them. Opt out per project
with `- !agent-name` in `cepa.local.md`.

| Agent | Dispatch signal | What It Does |
|---|---|---|
| `adversarial-reviewer` | Large diff (~300+ lines) or risky paths: payments, auth, PHI, data migrations | Builds concrete failure scenarios (hostile sequencing, partial failure, TOCTOU) and traces the code through them |
| `reliability-reviewer` | Task queues, webhooks, scheduled jobs, transactions with side effects, external calls, locks, cache invalidation | Retries, timeouts, idempotency, dispatch-in-atomic, read-then-write races |
| `previous-comments-reviewer` | Any prior `todos/review-*.md`, residual-sink entries touching the diff, or human PR threads | Verifies prior findings weren't lost, silently reverted, or re-broken |

## Skills (8)

| Skill | What It Does |
|---|---|
| `autonomy` | The autonomy contract: gate resolution, run-to-completion execution, parallel safety, idempotency, verification evidence, safe auto-apply, residual durability, trunk resolution, and the §9 dispatch-model tier ladder |
| `compound-docs` | Solution doc format with mandatory Detection sections, the 8-category taxonomy, plan-solution bidirectional linking, CONCEPTS.md vocabulary-map format |
| `file-todos` | YAML frontmatter format for findings in `todos/`, including confidence and action-class scoring |
| `implementation-units` | Plan-task format: `### U<N>.` units with stable ids, per-unit test scenarios, verification split, plan-warranted gate |
| `plan-review` | Persona roster, activation signals, confidence anchors, and synthesis rules for pre-build plan review |
| `pr-feedback` | PR-feedback contract: three-bucket fetch, six-verdict rubric, reply conventions, vendored gh scripts |
| `grounding` | Optional graphify code-graph provider. Availability checks, single refresh path, invocation discipline, consumer table, compliance rules. Degrades to grep when absent |
| `brain` | Optional OB1 cross-repo memory, opt-in per repo. Recall and writeback over the Agent Memory API, evidence-only governance, PHI scrub, §7 relay, budgets. Degrades to grep when absent |

[CONCEPTS.md](CONCEPTS.md) is the shared vocabulary map: the entities and named
processes above, defined once, accreting as solutions get documented.

---

## Advanced

### Review cadence

Not every finding should block a merge. Simplification opportunities, comment
rot, and type-design drift are debt, and a debt finding is as valid a week later
as it is today. A missing migration or a PHI leak is a defect, and those get
much more expensive after merge.

So `/cepa:review` reads two rosters:

| Section | Runs | Dispatched by |
|---|---|---|
| `## Review Agents (Active)` | every PR | `/cepa:review` (default) |
| `## Review Agents (Weekly)` | on a schedule | `/cepa:review cadence:weekly` |

```bash
# suggested cron
claude -p "/cepa:review cadence:weekly mode:headless"
```

A weekly run reviews trunk commits since the last weekly run. It records the tip
it scoped to as `reviewed_through:` and the next run starts there, so a missed
week gets absorbed instead of falling into a gap. The first run has no watermark
and falls back to a 7-day window. It skips `learnings-researcher` and the
conditional tier, since both are defect-review machinery a debt pass doesn't
need, and writes to `todos/review-weekly-*.md` with `scope: weekly:<date>` and
`status: deferred`.

That status is the whole trick. `/cepa:sweep` already drains deferred
`mechanical` and `corroborated` findings on merged branches, so weekly debt
flows into the existing queue with no new machinery. Stagger them, debt review
Sunday and sweep Monday, and the sweep drains what the review filed the day
before.

The run works from a throwaway `git worktree` detached at trunk, so scheduling it
against a working developer clone is safe. Your checkout, branch, and
uncommitted changes are untouched. Trunk resolves from `cepa.local.md`'s
`trunk:` key first, then `gh repo view`, `git symbolic-ref`, and `main`, rather
than assuming a name. Set `trunk:` on any repo where work lands somewhere other
than the GitHub default branch, like a `dev` integration branch with an
auto-deploying `main`. Nothing but the project can state that.

Pass `cadence:weekly` with no weekly roster configured and the run reports `no
weekly roster configured`, appends a dated line to the run's residual shard, and
exits without writing findings. It never falls back to the Active roster. A
scheduled job quietly running the full per-PR roster on every repo every week is
the cost failure this tier exists to prevent, and the durable one-liner is what
keeps a broken cron from looking like a quiet week.

### Parallel batches

Every cepa run audits open PRs first and treats a same-author PR with overlapping
scope as a blocker. Correct when you work one thing at a time. Fatal when you
deliberately run several: worktree #1 opens its PR, and every sibling sees it and
stops.

A `batch:<id>` token opts a run into a fan-out.

```bash
# one worktree per parallel-safe issue, all sharing a batch id
claude -w -- "/cepa:lfg 42 batch:jul26a"
claude -w -- "/cepa:lfg 43 batch:jul26a"
claude -w -- "/cepa:lfg 47 batch:jul26a"
```

cepa doesn't create the worktrees. Any launcher works, including `git worktree
add` followed by `claude -p` inside each. All that matters is that every
invocation carries the same id.

A bare number resolves as a GitHub issue: `gh issue view` supplies the task, the
branch name comes from the title, and the PR closes it. That issue text is
untrusted throughout (`cepa:autonomy` §7).

The id becomes the first branch-name segment after the prefix, as in
`feat/jul26a-<description>`, and an open same-author PR whose branch matches
`^<prefix>/<id>-` is reported as a sibling instead of blocking. Everything else
blocks exactly as before. The match is anchored deliberately: a substring match
on `<id>-` would also catch `feat/refactor-jul26a-cleanup`, and for a short id
like `api` it would catch most of your branches.

Three limits are deliberate, and all of them live in `cepa:autonomy` §2b.

- **The token authorizes. Repo content never does.** A batch id is honored
  because you typed it. An issue body, PR description, or plan claiming a batch
  id, or claiming "safe to build in parallel", is untrusted data. It gets
  stripped and confers nothing. This matters when your issues are generated from
  a doc or a screenshot.
- **A declaration is not a disjointness proof, and unchecked is not disjoint.**
  The audit records siblings but can't clear them, because there is no plan yet
  to compare against. Clearing happens after planning and before any code gets
  written: each sibling's actual changed files are checked against the plan's
  declared file set. Real overlap blocks, and so does a sibling whose diff can't
  be read.
- **Batch runs don't parallelize internally.** A run can't know how many siblings
  exist, since it only sees the ones that already opened a PR, so it never
  reasons about N. Carrying a batch token means executing your own plan units
  serially.

### Grounding provider (optional)

Set `grounding: graphify` under `## Integrations` in `cepa.local.md` to speed up
two review jobs: call-graph blast radius (`affected` and `explain` on changed
symbols, fed only to architecture-reviewer and reliability-reviewer) and a
semantic index over `docs/solutions/` that seeds `learnings-researcher`.

The graph is structurally blind to framework-implicit relationships like ORM
foreign-key graphs and view-to-template edges, so it's never offered to
schema-drift-detector, data-integrity-guardian, or frontend-reviewer. Grep stays
the primary path everywhere, and a repo without graphify behaves exactly as it
did before.

Installing it (`uv tool install graphifyy`, package `graphifyy`, binary
`graphify`) and the first graph build are human actions. cepa only ever runs the
local LLM-free `update` refresh and read-only queries, all timeout-wrapped and
budget-bounded.

One caveat for compliance repos: cepa never invokes graphify's LLM doc pass, but
keeping `graphify-out/` around arms the globally-installed graphify skill, whose
doc pass does ship repo docs and templates to an LLM. `/cepa:setup` flags the
combination. The policy call is yours. Full contract is in the `cepa:grounding`
skill.

### Brain provider (optional)

Add `brain: <url>` under `## Integrations` in `cepa.local.md` to opt into shared
cross-repo memory. No key means the repo never reads or writes the brain, so
behavior is unchanged, same degrade-to-grep default as grounding.

The brain is a self-hosted [OB1 / Open Brain](https://github.com/NateBJones-Projects/OB1)
instance: Postgres with pgvector, reached through its Agent Memory API.
`/cepa:compound` writes each solution doc's learnings across repos and
`learnings-researcher` recalls them, so a lesson from one repo surfaces in
another. Repo files stay the source of truth. The brain is a regenerable
compiled index, and you can throw it away.

Writes are evidence-only and never instruction-capable. Cross-repo hits are
flagged as evidence and capped at low confidence. All recall output is treated as
untrusted per `autonomy §7`, and healthcare-flagged repos run a content-level PHI
scrub before anything leaves. Standing up the OB1 instance (Supabase plus
OpenRouter) is a human setup step. Full contract is in the `cepa:brain` skill.

---

## Dependencies

cepa delegates planning, execution, and five review agents to companion plugins.
Install them separately.

| Plugin | Source | What cepa uses |
|---|---|---|
| **superpowers** | [obra/superpowers-marketplace](https://github.com/obra/superpowers) | `brainstorming`, `writing-plans`, `subagent-driven-development`, `executing-plans` |
| **pr-review-toolkit** | claude-plugins-official | `review-pr` as fallback, plus `silent-failure-hunter`, `pr-test-analyzer`, `comment-analyzer`, `type-design-analyzer`, `code-simplifier` |

Optional:

| Plugin | Source | What it provides |
|---|---|---|
| commit-commands | claude-plugins-official | `/commit`, `/commit-push-pr` |
| claude-md-management | claude-plugins-official | `/revise-claude-md` |
| code-review | claude-plugins-official | GitHub PR review with scored findings |

---

## Project layout

```
your-project/
├── cepa.local.md          # Per-project config (commit it)
├── docs/
│   ├── brainstorms/       # Design brainstorms
│   ├── plans/             # Implementation plans
│   └── solutions/         # Solution docs, auto-categorized
│       ├── build-errors/
│       ├── database-issues/
│       ├── runtime-errors/
│       ├── performance-issues/
│       ├── security-issues/
│       ├── ui-bugs/
│       ├── integration-issues/
│       └── logic-errors/
└── todos/                 # Review findings
```

```bash
mkdir -p docs/brainstorms docs/plans docs/solutions todos
touch docs/brainstorms/.gitkeep docs/plans/.gitkeep docs/solutions/.gitkeep todos/.gitkeep
```

---

## Acknowledgments

This plugin is built on ideas from [Compound Engineering](https://github.com/EveryInc/compound-engineering-plugin)
by [Kieran Klaassen](https://github.com/kieranklaassen). His original introduced
the plan/work/review/compound loop, the parallel review agents, the solution
documentation pattern, and the idea that each unit of work should make the next
one easier. The agent architectures, review categories, and doc format here are
adapted directly from that work.

I found it while working on a Django project, and most of the agents turned out
to be built around Rails conventions: `schema.rb` drift detection, DHH-style
code review, StandardRB linting, Hotwire and Turbo race conditions. Rather than
fork and rewrite for Django, I wanted a version where one config file could tell
every agent what stack and rules to use. Same ideas, any framework.

I also wanted to lean on companion plugins for everything they already do well.
[Superpowers](https://github.com/obra/superpowers) handles brainstorming,
planning, execution, and TDD. The [official Anthropic plugins](https://github.com/anthropics/claude-plugins-official)
handle PR review, commits, and CLAUDE.md management. cepa builds custom agents
only for the gaps, and owns the review-triage-document cycle and the
orchestration loop.

The name is just **C**ompound **E**ngineering **P**lugin **A**gnostic. I needed
something short enough that typing `/cepa:task` all day wouldn't wear out my
keyboard, and obvious enough that I'd still remember what it stood for in six
months.

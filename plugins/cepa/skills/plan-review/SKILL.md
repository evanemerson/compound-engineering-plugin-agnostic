---
name: plan-review
description: Persona roster, activation signals, confidence anchors, and synthesis rules for reviewing plan documents before build. Used by the /cepa:plan-review command; findings land in the cepa:file-todos format.
---

# Plan Review

Rules for reviewing a plan document with a small persona panel before any
code is written. The `/cepa:plan-review` command orchestrates; this skill
is the spec it follows. Findings always land in the `cepa:file-todos`
format — this skill defines how persona output maps into it, never a
variant format.

**Why the thresholds differ from code review:** document review has
opposite economics. There is no linter backstop — the review IS the
backstop — and a missed plan defect derails downstream implementation,
while a surfaced-and-skipped finding costs one triage decision. Filter
low and let triage handle volume.

## Document Types and Origin

Classify by **content shape**, path only as tie-breaker:

- **plan** — Implementation Units (`### U<N>.` ids per the
  `cepa:implementation-units` skill), per-unit Files/Test scenarios/
  Verification, repo-relative paths.
- **design doc** — what/why prose, approaches and trade-offs, no per-unit
  file lists (e.g. superpowers:brainstorming output).

Ambiguous defaults to **design doc** — it activates fewer plan-grade
checks, so misclassification errs quiet.

**Origin:** a plan whose design doc exists in `docs/plans/` and was
approved (or whose GitHub issue pins the scope) has *validated origin*.
Validated origin **suppresses premise-level techniques** — the panel does
not re-litigate whether the feature should exist; that decision was made
upstream. A plan with no origin gets full premise scrutiny. The
orchestrator classifies once and passes `document_type` and `origin` to
every persona; personas trust the slot and never re-classify.

## Persona Roster and Activation

Always-on:

| Persona | Reviews |
|---|---|
| `coherence` | Internal consistency: contradictions between units, undefined references, sequencing impossibilities, terms used before definition |
| `feasibility` | Will it work in THIS repo: paths that don't exist, APIs used wrong, shadow paths (happy/nil/empty/error), unimplementable steps |

Conditional — dispatch on signal, record the one-line justification:

| Persona | Dispatch when |
|---|---|
| `scope-guardian` | Priority tiers present, more than a handful of units, stretch goals, or goal-scope misalignment smell |
| `security-lens` | Plan touches auth, endpoints, PII/PHI, payments, or third-party integrations |
| `product-lens` | The doc makes challengeable premise claims AND origin is not validated |
| `adversarial` | High-value challenge surface only: high-stakes domain (auth/payments/migrations/compliance), a new abstraction or framework, no validated origin, scope extending beyond origin, or an explicit alternatives section |

**Adversarial do-not-activate guard:** do NOT activate adversarial on a
routine, well-structured plan that derives from a validated origin, stays
within scope, and introduces no high-stakes domain or new abstraction. A
plan having more units or more rationale is not adversarial signal — that
is the plan doing its job.

When in doubt on the others, dispatch — one persona costs one subagent
run. Every non-dispatch is recorded with its reason (a non-dispatch must
never be indistinguishable from a clean pass).

Personas are **reference prompts, not registered agents**: the
orchestrator dispatches generic subagents seeded with
`references/subagent-template.md` plus the persona file. A failed persona
degrades to a noted coverage gap, never a blocked run.

## Confidence Anchors

Persona confidence is a discrete anchor with behavioral meaning — not a
sliding scale:

| Anchor | Meaning | Routing |
|---|---|---|
| 0 | False positive or pre-existing issue | Don't emit |
| 25 | Might be real, could not verify | Don't emit |
| 50 | Verified real but advisory — "nothing breaks, but…" | P3 advisory finding |
| 75 | Will hit in practice; names a concrete downstream consequence | Actionable |
| 100 | Evidence directly confirms; will happen | Actionable |

The anchor-75 bar: the finding must name a concrete downstream consequence
someone will hit — a wrong build order, an unimplementable unit, a
contract mismatch, missing evidence that blocks a decision.
Strength-of-argument concerns ("motivation is thin") do not meet the bar.

## Synthesis Order

Strictly ordered, after all personas return:

1. **Validate** each persona's output against the template contract; drop
   malformed findings (never narrate parser diagnostics). Record a
   per-persona `validation_drops` count in the findings file's Run
   Metadata — an uncounted drop is a silently lost finding. A persona
   whose ENTIRE output fails validation is a failed persona
   (`agents_failed`), never a clean pass.
2. **Anchor gate:** 0/25 dropped (count them), 50 → P3 advisory,
   75/100 → actionable.
3. **Dedup** by fingerprint `normalize(section) + normalize(title)`
   (lowercase, strip punctuation, collapse whitespace). Merge keeping
   highest severity and highest anchor, union the evidence, note agreeing
   personas. Opposing-action matches are NOT merged — see step 5.
4. **Cross-persona promotion:** 2+ independent personas on one merged
   finding promote its anchor one step (50→75, 75→100). Independent
   corroboration is strong signal — this is the plan-side twin of the
   file-todos "merged duplicates become corroborated" rule.
5. **Contradictions** (personas recommending opposing actions) merge into
   ONE judgment-class finding framed as a tradeoff, not a verdict —
   contradictions are by definition human decisions.

## Mapping to file-todos

| Persona output | file-todos field |
|---|---|
| severity P0 or P1 | `severity: P1` |
| severity P2 | `severity: P2` |
| severity P3, or anchor 50 | `severity: P3` |
| anchor | `confidence` (verbatim: 100/75/50) |
| persona name | `agent:` |
| persona's review domain (Coherence, Feasibility, Scope, Security, Product, Adversarial) | `category:` |
| autofix `safe_auto` | `action_class: mechanical` |
| autofix `gated_auto` | `action_class: judgment` — deliberate collapse: cepa has no middle auto-tier, and a gated fix that two personas corroborate gets promoted by the row below, which is the only auto path it should have |
| cross-persona-agreed finding | `action_class: corroborated` |
| everything else (incl. all contradictions) | `action_class: judgment` |
| section + evidence quotes | folded into the `**Problem:**` body |
| suggested fix | the `**Fix:**` body |

`file:` is the plan path; `lines:` the plan's line range; frontmatter
`scope:` is `plan:docs/plans/<file>`. The compliance carve-out is
absolute and transfers unchanged: a finding on plan content that designs
PHI/PII handling, auth, or payments is always `judgment`.

Severity and class are independent: a P1 can be `mechanical` when there is
one clear correct fix. The test is never "how important?" — it is "is
there one clear fix, or does this need judgment?"

## What Happens to Findings

Per the `cepa:autonomy` contract, uniformly with code review:
`mechanical`/`corroborated` at confidence ≥ 75 may auto-apply **to the
plan file**, committed separately as `docs: revise plan per plan review`
(visible, revertable — this is deliberately cepa's §4 gate, not upstream's
apply-only-at-100, for one rubric across the whole pipeline). `judgment`
findings go durable: the plan's `## Deferred / Open Questions` section
under `### From YYYY-MM-DD review`, plus the findings file
(`status: deferred`) and `memory/tasks.md`. The PR-body sink is n/a
pre-PR — state that in the report rather than leaving it ambiguous. U-ID
edits obey the stability rule (`cepa:implementation-units`): revisions
never renumber units.

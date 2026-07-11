---
name: implementation-units
description: The canonical format for plan tasks — Implementation Units with stable U-IDs, per-unit test scenarios, and a verification split. Consumed by /cepa:task, /cepa:lfg, and /cepa:plan-review the way file-todos is consumed for findings.
---

# Implementation Units

The single canonical format for the task list inside an implementation
plan. Commands reference this skill instead of restating the rules — a
plan that follows it can be executed, reviewed, and cross-referenced
mechanically; a plan that doesn't gets restructured to it before build.

**Boundary with superpowers:** `superpowers:writing-plans` (when installed)
remains the planning-process authority — how to think about tasks, TDD
framing, bottom-up ordering. This skill is a **format contract layered on
its output**: whatever process produced the plan, the saved artifact
renders its tasks as Implementation Units. They are not competing planning
systems.

## What a Unit Is

Each unit is **one meaningful change that an implementer could typically
land as an atomic commit** — focused on one component, behavior, or
integration seam; usually touching a small cluster of related files;
ordered by dependency; concrete enough for execution without pre-writing
the code.

Avoid:
- 2-5 minute micro-steps (choreography, not planning)
- Units spanning multiple unrelated concerns (mush)
- Units so vague the implementer still has to invent the plan

Unit count scales with plan depth: light work usually 2-4 units, standard
3-6, deep 4-8 (group into phases when that improves clarity). The bound is
the work, never a target number.

## Format

Each unit is a **level-3 heading with a stable ID prefix**: `### U1. Name`.
Never bullets, never `- [ ]` checkboxes — per-unit fields are flush-left
bold-leader lines, which terminate CommonMark list continuation and detach
fields from a list-item title; headings render everywhere and give each
unit a durable anchor (`rg -n '^### U[0-9]+\.'` finds every unit).

Per-unit fields:

- **Goal:** what the unit accomplishes.
- **Dependencies:** cited by U-ID (e.g. "U1, U3"). Omit when none.
- **Files:** repo-relative paths to create/modify — never absolute. Every
  feature-bearing unit includes its **test file path** here.
- **Approach:** key decisions, data flow, boundaries — direction, not code.
- **Patterns to follow:** existing code to mirror. Omit when none apply.
- **Test scenarios:** see the contract below.
- **Verification:** how an implementer knows the unit is complete,
  expressed as **outcomes**, not shell command scripts.

Optional fields, used sparingly: **Requirements** (upstream requirement or
issue IDs the unit advances), **Execution note** (one natural-language
direction, e.g. "add characterization coverage before modifying this
legacy parser" — never expanded into RED/GREEN/REFACTOR substeps),
**Technical design** (pseudo-code or diagram, directional not
specification).

At ~10+ units, open the section with a Unit Index table (U-ID · one-line
title · files touched · depends-on) — navigation only; unit bodies stay
authoritative. Omit below that.

## Test-Scenario Contract

Enumerate scenarios per unit, right-sized to complexity and risk — a
config change may need one, a payment flow a dozen. Include every category
that applies:

1. **Happy path** — works as expected
2. **Edge cases** — boundaries, empty, nil, concurrency
3. **Error/failure paths** — invalid input, downstream failure, timeout,
   permission denial
4. **Integration** — cross-layer behaviors mocks can't prove (required for
   callbacks, middleware, multi-layer units)

The quality signal is **specificity**: each scenario names the input, the
action, and the expected outcome, so the implementer doesn't invent
coverage. For units with no behavioral change (pure config, scaffolding,
styling), write `Test expectation: none -- [reason]` instead of leaving
the field blank. **Feature-bearing units with blank or missing test
scenarios are incomplete** — the annotation is invalid for them, and plan
review flags it.

## U-ID Stability Rule

Once assigned, a U-ID is **never renumbered**. Reordering units leaves
their IDs in place (U1, U3, U5 in their new order is correct; renumbering
to U1, U2, U3 is not). Splitting a unit keeps the original U-ID on the
original concept and assigns the next unused number to the new unit.
Deletion leaves a gap; gaps are fine.

Why: executors, review findings in `todos/`, and solution docs all cite
U-IDs across plan edits ("resolves U3 of <plan>"). Renumbering silently
breaks every cross-reference. Plan revision — including plan-review edits
— is the most likely accidental-renumber vector; the rule binds there too.

## Verification Split

Two levels, deliberately separate:

- **Per-unit Verification** — observable outcomes ("the health check
  reports the new skill", "requests to /x return 403 for non-members").
- **Plan-level `## Verification Contract` section** — the repo-specific
  commands and quality gates, stated once ("`docker compose exec web
  pytest`", "`ruff check .`", measurable thresholds for
  optimization-shaped goals). Avoid generic "run tests" language when the
  repo has concrete commands.

Executors read the Verification Contract once, then check per-unit
outcomes — no shell choreography inside units.

## No Progress in the Plan

Plans carry no status field and no per-unit progress state. A plan is a
decision artifact, not a tracked work item — whether a unit shipped is
derived from git, from `todos/`, and from PR bodies, never stored in the
doc. Executors never mutate the plan mid-run (plan-review revisions,
committed separately, are the one sanctioned edit).

## Plan-Warranted Gate

Bias toward producing a plan — a thin plan for small work is mild
ceremony, but skipping a plan that was warranted costs the implementer
real time. Skip the plan document only when ALL of these hold:

1. The work is atomic — fits in one commit, no unit boundaries.
2. No design choices constrain implementation — nothing worth recording.
3. No scope boundaries worth pinning.
4. No upstream artifact (issue, design doc) needs traceability through
   this plan.

Stress-test the "looks atomic" trap: "add caching" hides TTL, invalidation
and key decisions → plan. "Fix typo" → skip.

## Pre-Write Checklist

Before a plan is committed (and before autonomous execution begins),
verify: units concrete, dependency-ordered, implementation-ready; every
applicable test category present per unit; scenarios name inputs, actions,
outcomes without becoming test code; U-IDs unique and stability-clean;
feature-bearing units have real scenarios and test file paths; deferred
items are explicit — never fake certainty to make the plan look complete.

The readiness bar: **a plan is ready when an implementer can start
confidently without needing the plan to write the code for them.**

## Autonomous Runs

When a plan is produced or revised without a user present, inferred scope
decisions land in the plan's `## Assumptions` section — labeled, reviewable
bets, never silently promoted to user-confirmed decisions. Unresolved
judgment questions land in `## Deferred / Open Questions`. (Both per the
`cepa:autonomy` contract: make residuals durable instead of asking.)

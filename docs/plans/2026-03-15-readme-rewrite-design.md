# README Rewrite Design

**Date:** 2026-03-15
**Branch:** chore/readme-rewrite

## Goal

Rewrite README.md to be useful for newcomers learning about compound engineering for the first time, while including the full mechanical reference for power users. Single source of truth.

## Audience

Primary: newcomers who've never heard of compound engineering. Lead with what/why, put mechanics later.

## Decisions

1. **Newcomer-first** structure — hook with why, then what's in the box, then get running, then full reference
2. **Manual install + setup script** — README shows step-by-step, mentions `scripts/setup.sh` as optional shortcut
3. **Full mechanical detail inline** — no collapsed sections or separate docs for the 5 phases
4. **Short config example + link** — one Django example in README, full reference in `docs/CONFIGURATION.md`
5. **COMPARISON.md stays** — gets updated to reflect current state (learnings-researcher, file-todos, task command)

## README Structure

1. What is this (2-3 paragraphs)
2. The Loop (diagram + one paragraph)
3. What's Included (commands, agents, skills tables)
4. Install (step-by-step + setup script mention)
5. Quick Start (first task walkthrough)
6. The 5 Phases (full mechanical breakdown from cepa-full-description.md, corrected)
7. Dependencies (plugin table)
8. Per-Project Configuration (short example + link to docs/CONFIGURATION.md)
9. Project Directory Structure
10. Acknowledgments

## Corrections to Make

- Phase 2 is research + brainstorming only; writing-plans is Phase 3
- Phase 4: /cepa:review spawns up to 11 agents (8 cepa + 3 pr-review-toolkit)
- learnings-researcher searches docs/solutions/, CLAUDE.md, memory/tasks.md, plans, and optionally git history
- marketplace.json version needs 1.0.0 → 1.1.0
- COMPARISON.md needs update for learnings-researcher, file-todos, task command

## Deliverables

- [ ] README.md — full rewrite
- [ ] scripts/setup.sh — automated install
- [ ] docs/CONFIGURATION.md — full cepa.local.md reference
- [ ] marketplace.json — version bump
- [ ] COMPARISON.md — update for current state (local-only, gitignored)

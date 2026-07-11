---
description: Refresh docs/solutions against the current codebase — update drifted learnings, consolidate overlap, prune dead docs, reconcile CONCEPTS.md
argument-hint: "[scope hint — directory, filename, module, or keyword] [mode:headless]"
allowed-tools: Write, Edit, Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(git branch:*), Bash(git add:*), Bash(git commit:*), Bash(git checkout:*), Bash(git push:*), Bash(git rm:*), Bash(gh pr create:*)
---

# Compound Refresh

Maintain the quality of `docs/solutions/` over time. `/cepa:compound` captures
a newly solved problem; this command keeps those learnings trustworthy as the
codebase evolves — individually accurate, and collectively well-designed as a
document set. It also reconciles `CONCEPTS.md` (the vocabulary map defined in
the `cepa:compound-docs` skill) as part of every run.

**Announce at start:** "I'm using the cepa:compound-refresh command to refresh
docs/solutions."

**Required sub-skill:** `cepa:compound-docs` is the canonical spec for the
solution-doc format (including the mandatory Detection section) and the
CONCEPTS.md vocabulary-map rules. Read it before classifying anything.

## Modes

Parse a `mode:headless` token from anywhere in the arguments and strip it;
the remainder is the scope hint.

- **Interactive (default):** investigate first, then ask for decisions only
  on genuinely ambiguous cases — one question at a time, multiple choice,
  recommendation first. Unambiguous actions apply directly without asking.
- **`mode:headless`** (for scheduled runs and autonomous callers): never
  prompt. Apply all unambiguous actions (Keep, Update, Consolidate,
  auto-Delete, Replace with sufficient evidence). Mark genuinely ambiguous
  cases stale instead of acting: add `status: stale`,
  `stale_reason: <what was found>`, `stale_date: YYYY-MM-DD` to the doc's
  frontmatter. If a write fails, record the action as **Recommended** in the
  report and continue — never stop or ask. **Multi-step actions are atomic
  (see Phase 3):** a failed write inside a Consolidate or Replace makes the
  ENTIRE action Recommended — "continue" means continue to the next doc,
  never onward to that action's delete step. When a scope hint was provided
  but matched nothing, report the miss and exit without widening to all
  docs; process everything only when NO hint was given.

**Fail-safe:** if the harness exposes no blocking-question tool, behave as
headless even without the token.

## Scope Selection

Candidates are all `.md` files under `docs/solutions/`, excluding `README.md`
files. If a legacy `_archived/` directory exists, exclude its contents but
flag it in the report for cleanup — the archive policy is delete, not stash.

If a scope hint was given, narrow with the first strategy that produces
matches: (1) subdirectory name under `docs/solutions/`, (2) frontmatter
`tags`/`category` match, (3) filename match (partial ok), (4) content keyword
search. No candidates at all → report "No candidate docs found in
docs/solutions/. Run /cepa:compound after solving problems to start building
your knowledge base." and stop.

With 9+ candidates, triage before deep investigation: read all frontmatter,
cluster by module/category, spot-check whether each cluster's primary
referenced files still exist, and work the clusters in impact order (a dense
cluster with missing references first). Interactive mode confirms the
starting cluster; headless processes all clusters in that order.

## Maintenance Model

Classify every candidate into exactly one outcome:

| Outcome | Meaning | Action |
|---|---|---|
| **Keep** | Still accurate and useful | No file edit — report it as reviewed and trustworthy |
| **Update** | Core solution correct, references drifted | Evidence-backed in-place edits |
| **Consolidate** | Docs overlap heavily, both correct | Merge unique content into the canonical doc, delete the subsumed doc |
| **Replace** | Now misleading, better successor is known | Write a trustworthy successor, delete the old doc |
| **Delete** | No longer useful, applicable, or distinct | Delete the file — git history is the archive |

### Core rules

1. **Evidence informs judgment.** Signals are inputs, not a scorecard.
2. **Prefer no-write Keep.** Never edit a doc just to leave a review
   breadcrumb, fix a typo, or polish wording.
3. **Match docs to reality, not the reverse.** When code and doc disagree,
   the doc changes. This command does doc maintenance, not code review —
   never ask whether a code change was "intentional."
4. **Update vs Replace boundary:** paths moved, classes renamed, links broke
   → Update. If you find yourself rewriting the Solution section or changing
   what the doc recommends, stop — that is Replace. A doc whose
   recommendation now *contradicts* current code is actively misleading:
   strong Replace signal, not minor drift.
5. **Replace needs a real successor** — codebase investigation that can
   document the current approach honestly, or strong successor evidence in
   newer docs/PRs. Insufficient evidence → mark stale and recommend
   `/cepa:compound` on the next encounter with that area.
6. **Age alone is not staleness.** A 2-year-old doc matching current code is
   a Keep; use age only as a prompt to inspect harder.
7. **Delete, don't archive.** No `_archived/` directory, no tombstone
   metadata. `git log --diff-filter=D -- docs/solutions/` recovers anything.
8. **Before Delete, two checks:**
   - *Problem domain still active?* Missing files only prove the
     implementation is gone. If the app still deals with what the doc
     addresses (the concept persists under a new implementation), that is
     Replace, not Delete.
   - *Inbound links.* Grep the repo's markdown for the filename slug.
     **Decorative** citations (principle restated inline, "see also") allow
     Delete — clean them up in the same commit. **Substantive** citations
     (the citing doc relies on content not stated inline) signal Replace.
     Mixed or unclear → stale-mark in headless mode.
   - Auto-delete only when all three hold: implementation gone (or plainly
     redundant), problem domain gone, citations absent or decorative.
9. **Evaluate the set, not just each doc.** Two docs saying the same thing
   will eventually say different things — redundancy is drift risk.

## Phase 1: Investigate

For each candidate, read it and cross-reference its claims against the
current codebase. Dimensions that go stale independently:

- **References** — do cited paths, classes, and modules still exist?
- **Solution** — does the fix still match how the code works today?
- **Code snippets** — do they reflect the current implementation?
- **Related links** — do cross-referenced docs still exist and agree?
- **Detection section** — the `cepa:compound-docs` skill makes `## Detection`
  mandatory. A doc missing one — where "missing" includes an empty section
  or one containing only a `<!-- BACKFILL ... -->` marker — or whose
  Detection signals reference constructs that no longer exist, is drift. **A missing Detection section
  alone justifies classifying the doc as Update** — backfilling the
  mandatory section is substantive maintenance, not a review breadcrumb;
  core rule 2 ("prefer no-write Keep") does not apply to it. Backfill or
  fix the Detection section when the investigation evidence supports
  concrete signals; otherwise flag the gap in the report rather than
  inventing vague bullets.
- **Overlap** — note when another in-scope doc covers the same problem,
  files, or fix; record which dimensions overlap and which doc looks
  broader or more current (feeds Phase 2).
- **Vocabulary** — note domain terms the doc uses that are missing from
  `CONCEPTS.md`, or whose entry no longer matches how the code uses the
  term. Collect centrally for Phase 4; do not edit `CONCEPTS.md` yet.

Match depth to specificity: a doc citing exact paths and snippets needs more
verification than one stating a general principle.

**Subagent strategy:** use read-only investigation subagents for context
isolation when candidates are numerous — parallel only when docs are truly
independent (overlapping docs are investigated together). Each returns: path,
evidence per dimension, recommended outcome, confidence, open questions.
Replacement docs are drafted by subagents one at a time, sequentially,
following the `cepa:compound-docs` format — each returns its draft to the
orchestrator rather than writing it (see Phase 3's Replace flow). The
orchestrator performs ALL file writes, deletions, consolidation merges, and
metadata edits centrally — subagents never write.

## Phase 2: Document-Set Analysis

Compare in-scope docs against each other, not just against reality:

- **Overlap:** same problem, same solution shape, same files, same root
  cause? High overlap across 3+ dimensions → Consolidate candidate.
- **Supersession:** a newer doc covers the same ground more broadly; an old
  incident doc that a newer doc generalizes. The older doc's unique content
  merges into the canonical doc; the rest deletes.
- **Canonical doc:** per topic cluster, the doc a maintainer should find
  first — usually the most recent, broadest, most accurate. Every other doc
  in the cluster is distinct (keep), subsumed (consolidate), or redundant
  (delete).
- **Retrieval-value test:** separate docs earn their keep only when someone
  would search for the sub-problems independently, or merging would create
  an unwieldy doc. Otherwise consolidate — drift risk beats slight length.
- **Conflicts:** docs that contradict each other are more urgent than
  individual staleness — resolve via Consolidate or targeted Update/Replace,
  never leave both standing.

## Phase 3: Execute

Apply each classification (interactive mode confirms only the ambiguous
ones first — Delete with non-obvious evidence, Replace successors, unclear
canonical choice):

- **Keep** — no edit; goes in the report's reviewed-without-edits list.
- **Update** — apply the evidence-backed edits, including Detection
  backfill per Phase 1.
- **Consolidate** — merge the subsumed doc's unique content into the
  canonical doc (as a section or addendum), update the canonical doc's
  `related` frontmatter, repoint any inbound links to the canonical doc,
  and delete the subsumed doc last.
- **Replace** — a replacement subagent drafts the successor from the
  investigation evidence and RETURNS its full content — subagents never
  write files. The orchestrator validates the returned draft against the
  `cepa:compound-docs` spec (frontmatter and sections, including
  `## Detection`) BEFORE anything touches disk, then writes it (same path,
  or a better-named one with inbound links repointed) and deletes the old
  doc if the path changed. The old doc is never overwritten or deleted
  until the successor has passed validation. If the draft fails validation
  or the subagent fails, leave the old doc untouched — stale-mark it per
  the headless rules and record the Replace as Recommended with the
  validation failure noted.
- **Delete** — final inbound-link check, remove the file, clean decorative
  citations in the same commit. Removal is always
  `git rm docs/solutions/<relative-path>` — the exact relative path, no
  flags, no `..` segments, never raw `rm`. `git rm` only removes tracked
  files, stages the deletion atomically for Phase 5, and keeps recovery a
  `git checkout` away.

**Multi-step actions are atomic.** Deletion is always the LAST step of its
action and is gated on verification: before deleting a subsumed or replaced
doc, confirm the merged/successor content exists on disk with the expected
sections. If any earlier write in the action failed, perform no further
steps of that action — leave every involved doc in place and record the
entire action as Recommended. "Continue" always means continue to the next
doc, never to a delete whose prerequisites failed.

## Phase 4: Vocabulary Reconciliation (CONCEPTS.md)

Aggregate the vocabulary signals collected in Phase 1 and reconcile against
`CONCEPTS.md` per the `cepa:compound-docs` rules:

1. Add qualifying terms that surfaced; when one term surfaced from several
   docs with different shades, union the shades into one entry.
2. Re-derive the in-scope area's core domain nouns from its declared model
   and backfill central ones that are missing — bounded to the area in
   scope, never a repo-wide sweep.
3. Scrub existing entries that violate the skill's stands-on-its-own rules
   (file paths, class names, config values, status metadata, duplicates
   under different names). Refresh is an audit — the full scrub is in scope.
   When the scrub resolves a duplicate-under-different-names or settles
   terms the corpus used interchangeably, append a one-line resolution note
   under the file's `## Flagged ambiguities` tail — that section is the
   audit trail for vocabulary opinions, and this pass is its writer.
4. If `CONCEPTS.md` does not exist and at least one term qualifies,
   bootstrap it with the skill's preamble and a conservative seed of the
   in-scope area's core nouns.
5. Apply silently in both modes; when nothing qualifies, record "scanned,
   no qualifying terms" in the report — a visible no-result beats a silent
   skip.

## Phase 5: Report and Commit

**The full report is the deliverable — print it in full, never a one-liner:**

```text
Compound Refresh Summary
========================
Scanned: N docs

Kept: X | Updated: Y | Consolidated: C | Replaced: Z | Deleted: W | Marked stale: S
Detection sections backfilled: D (gaps flagged, not backfilled: G)
CONCEPTS.md: <scanned, no qualifying terms | created with N entries | updated — added A, refined R, scrubbed V>
```

Then per file: path, classification, evidence found, action taken. For
Consolidate: which doc was canonical, what merged, what was deleted. In
headless mode, split actions into **Applied** (writes succeeded) and
**Recommended** (writes failed — with enough context for a human to apply
manually).

**Commit:** skip when nothing changed. Stage ONLY the files this refresh
touched. Interactive mode: offer commit options fitting the current branch
state. Headless defaults: on main → create `docs/refresh-<scope>`, commit,
attempt a PR (report the branch name if PR creation fails); on a feature
branch → separate commit on that branch; git failure → include the
recommended commands in the report and continue. Commit message summarizes
the refresh (e.g., "docs: refresh 3 stale learnings, consolidate 2, delete 1").

## When to Stop

- No `docs/solutions/` directory or no candidate docs → report and stop.
- Scope hint matched nothing → report the miss and stop (headless: never
  widen silently).
- Everything else is handled by classifying, stale-marking, or recording
  Recommended actions — this command never blocks mid-run.

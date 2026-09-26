---
description: Refresh docs/solutions against the current codebase — update drifted learnings, consolidate overlap, prune dead docs, reconcile CONCEPTS.md
argument-hint: "[scope hint — directory, filename, module, or keyword] [mode:headless]"
allowed-tools: Write, Edit, Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(git branch:*), Bash(git add:*), Bash(git commit:*), Bash(git checkout:*), Bash(git push:*), Bash(git rm:*), Bash(gh pr create:*), Bash(bash:*)
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
  never onward to that action's delete step. **All writes are additionally
  subject to Phase 3's execution gate** (report-only mode on a branch the
  run doesn't own; dirty paths read-only) — the gate outranks "apply all
  unambiguous actions." When a scope hint was provided
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
cluster with missing references first). Headless processes all clusters in
that order. Interactive mode confirms the starting cluster, then proceeds
cluster by cluster — after finishing one, ask whether to continue to the
next or stop. Either way, docs left uninvestigated are never silent: the
report's "Not processed this run" line (Phase 5) names them, and "Scanned"
counts only docs actually investigated.

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

**Dispatch each with an explicit `model: sonnet` override** — every
investigation and replacement subagent, at the routine tier per
autonomy §9c; §9a is why the override lives here rather than in frontmatter.

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

**Execution gate — decided BEFORE any write.** Record three things: the
starting ref (current branch name, or the exact SHA when detached), the set
of paths with uncommitted changes, and whether this run OWNS the current
branch. Own means the user invoked the refresh while working on this
branch, or a pipeline caller (e.g. `/cepa:lfg` or `/cepa:sweep`) invoked it as part of this
branch's flow; a scheduled or standalone headless run does not own a
feature branch it merely finds itself on. Ambiguous ownership or detached
HEAD counts as not owned. Two rules consume this record:

- **Not-owned branch → report-only mode.** Phases 3 and 4 make NO writes
  and stage nothing — no Edit, no `git rm`, no CONCEPTS.md changes. Every
  action is produced as Recommended from the investigation evidence alone.
  The invariant is "never mutate work that isn't this run's own," not
  merely "never commit into it" — a mutated tree or staged deletion left
  behind lands in the branch owner's next commit even if this run commits
  nothing. (On main, and on an owned branch, writes proceed normally.)
- **Dirty paths are read-only — all of them.** Any file with uncommitted
  changes is user work in progress: never edit, stage, or commit it. This
  covers candidate docs and CONCEPTS.md, and equally the CITING files that
  Delete/Consolidate/Replace would touch for citation cleanup or link
  repointing — a side door is still a door. Re-check dirtiness immediately
  before each write (scheduled runs are long; a file can become dirty
  mid-run). An action whose write set includes any dirty path is withheld
  WHOLE and reported as Recommended ("dirty path <p> — not touched"):
  partial execution would either blend user work into refresh output (a
  blend that cannot be unpicked afterwards) or leave half-applied state,
  e.g. a deleted doc with its citations dangling. Deferring the whole
  action costs one refresh cycle; both alternatives cost user work or tree
  consistency.

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

**Brain sync (participating repos only).** When `cepa.local.md` has a
`brain:` key and this run OWNS the branch, mirror each executed action into
the cross-repo brain per the **`cepa:brain` skill**, via
`bash "$CEPA_ROOT/scripts/brain-client.sh"` (reads the key from
`.env.local`, never inline): a Delete or stale-mark → `mark_stale` the prior
memories; a Replace/Update → `mark_stale` the prior memories, then write the
successor's `memory_payload` strings (new content hash → new rows — the
payload is an object of typed string arrays, NOT a list of typed atom
objects; the skill's call contract has the envelope).

**PHI scrub — run `brain-client.sh scrub` over the built payload FILE before
egress, and SUPPRESS the writeback if it cannot run.** When the scrub is
forced, the conditions that force it, and what it does and does not redact
are the `cepa:brain` skill's Compliance section — read it there. Four points
that bind *this* command specifically:

- Refresh rewrites drifted docs, so its payloads carry freshly re-quoted code
  and log lines. That is where numeric PHI actually appears, which makes this
  the higher-risk of the two writeback paths, not the lower.
- **The scrub is a numeric-only backstop and does NOT discharge the
  operator's no-real-PHI certification.** It does not redact names, emails,
  phone numbers, written-month dates (`March 14, 1982`), MRNs under 7 digits,
  or digit runs over 12. For a PII repo like `helm` — whose declared
  `pii_fields` are emails and phone numbers — it redacts almost nothing it
  declares, while Run Metadata still reports that the scrub ran. Never read a
  completed scrub as "this payload is now safe".
- **It scrubs the whole FILE, and `sed` cannot tell content from envelope.**
  Ordinary engineering prose is collateral: `Celery task 4567890 ... see PR
  #1234567` becomes two `[REDACTED-PHI-ID]`s, and a memory written that way is
  permanently degraded. Worse, a numeric `BRAIN_WORKSPACE_ID` is itself
  rewritten to `[REDACTED-PHI-ID]`, which 400s the call and then disables the
  brain for the rest of the run. Both measured 2026-09-26. Keep envelope
  values non-numeric, and expect the tradeoff: whole-file scrubbing cannot
  forget a string, at the cost of mangling innocent digits.
- The word "scrub" appears elsewhere in this file meaning CONCEPTS.md
  vocabulary pruning. That is an unrelated sense. A `grep` for it will look
  reassuring whether or not this step is present, so verify by reading the
  writeback phase.

**Suppression is PER-DOC, not per-run.** A scrub or `mv` failure on one doc
suppresses that doc's writeback and continues to the next — the same rule
this command already states for actions ("Continue" always means continue to
the next doc). Run one payload per block so the gate's `exit 1` ends that
doc's writeback only; a block looping over every doc would abort the phase on
the first failure and leave the remaining docs neither written nor counted,
reporting one suppression where there were six.

Count redactions into `scrubbed:` in the Run Metadata block, and count a
suppressed atom into `suppressed_writebacks:` — a suppression is recorded,
never silent. Both counts are **self-reported by the executing agent**:
`scrub` prints no redaction count, so nothing machine-verifies these fields.
Read them as a claim about the run, not as a measurement — and do not cite
`scrubbed: N` as evidence that scrubbing occurred. Making the count real
means teaching `brain-client.sh scrub` to emit one; that is filed, not done.

**`mark_stale` needs `memory_id`s you already hold — "the memories for that
source path" is not a query you can issue.** Per the `cepa:brain` skill's
response-shape rule, recall never projects `source_refs` and returns
`source.uri: null`, so no recall can select the rows belonging to one doc.
Re-measured 2026-09-26 against the deployed service. Use ids recorded in the
doc's Run Metadata or this run's own writeback response; with none, SKIP the
stale-marking, still write the successor strings, and record
`mark_stale: skipped — no path-identifiable prior rows`. Do not substitute a
`scope.project_id` recall — that returns every memory this repo ever wrote,
and stale-marking those retires unrelated rows. No `brain:` key or
report-only mode → no brain calls (not configured — not a failure). A brain
call that FAILS when configured → degrade (`status: degraded — <verb>
failed`) and continue; files stay source-of-truth, so a miss loses nothing,
but it is never silent. Record counts/status in the `brain` Run Metadata
block.

`$CEPA_ROOT` comes from the resolver — source it once before the first brain
call. **Do not spell `"${CLAUDE_PLUGIN_ROOT}/scripts/…"`**: that variable is
NOT exported into the shell these blocks run in, so it expands to
`/scripts/brain-client.sh` and exits 127 with "No such file or directory",
which is how brain sync here was dead rather than degraded.

Resolve it in the SAME block as the brain call — each fenced block is its own
shell, so a `$CEPA_ROOT` set in an earlier block is gone here:

```bash
for R in "${CEPA_PLUGIN_ROOT:-}/scripts/resolve-plugin-root.sh" \
         "${CLAUDE_PLUGIN_ROOT:-}/scripts/resolve-plugin-root.sh" \
         "$HOME"/.claude/plugins/marketplaces/*/plugins/cepa/scripts/resolve-plugin-root.sh \
         "${CEPA_DEV:+$(git rev-parse --show-toplevel 2>/dev/null)/plugins/cepa/scripts/resolve-plugin-root.sh}"; do
  [ -f "$R" ] && . "$R" && break     # sets $CEPA_ROOT
done
# GATE every brain call on this, in code — not on remembering the paragraph
# below. An empty $CEPA_ROOT makes the call `bash "/scripts/brain-client.sh"`,
# which exits 127 and reads as an outage; that is the misdiagnosis this whole
# resolver exists to prevent, so it must not be reachable.
[ -n "${CEPA_ROOT:-}" ] || {
  echo "brain sync: plugin root unresolved — record 'degraded — plugin root" >&2
  echo "  unresolved', NEVER 'unreachable'. Set CEPA_PLUGIN_ROOT." >&2
  exit 1
}
bash "$CEPA_ROOT/scripts/brain-client.sh" health >/dev/null || {
  echo "brain sync: client resolved but health failed — degrade per the skill" >&2
  exit 1
}
```

Every later `brain-client.sh` verb in this phase (`scrub`, `mark_stale`, the
successor writeback) runs in a block that repeats that loop and that gate. A
verb call emitted without them is the defect, not a shortcut.

Gate the writeback on the scrub in code, in the same block — not on
remembering the paragraph above:

```bash
set -euo pipefail
# PASTE THIS AFTER the resolver loop + health gate above, in ONE block. It is
# not a standalone snippet: each fenced block is its own shell, so a
# $CEPA_ROOT resolved earlier is already gone. Run alone, `set -u` aborts on
# the unbound $CEPA_ROOT — fail-closed, but it reports as a resolver failure
# rather than the assembly slip it is.
# $PAYLOAD is the envelope built for THIS doc. Create it fresh per document —
# never reuse one path across Phase 3's loop, or a stale sidecar can be posted
# under the wrong doc's identity, rc=0 end to end and invisible.
PAYLOAD="$(mktemp "${TMPDIR:-/tmp}/cepa-writeback-XXXXXX.json")"
# ... build the envelope into "$PAYLOAD" with the Write tool ...

bash "$CEPA_ROOT/scripts/brain-client.sh" scrub "$PAYLOAD" "$PAYLOAD.scrubbed" || {
  echo "brain sync: scrub failed — SUPPRESS this doc's writeback, do not" >&2
  echo "  send unscrubbed. Record it in suppressed_writebacks: and go on" >&2
  echo "  to the next doc." >&2
  exit 1
}
# Post the SIDECAR. Do not mv it over $PAYLOAD first: a failed mv leaves
# $PAYLOAD holding the PRE-SCRUB original — intact and non-empty, so
# _assert_envelope passes it and the unscrubbed content egresses with every
# exit code reading 0. Writing back the sidecar directly deletes that entire
# failure class instead of guarding it.
bash "$CEPA_ROOT/scripts/brain-client.sh" writeback "$PAYLOAD.scrubbed"
```

**Scrub to a sidecar and post the sidecar.** Two failure modes make this the
shape to use, both measured 2026-09-26:

- Passing one path as both arguments empties it and exits **0** — the shell
  truncates the redirect target before `sed` reads the input, so no `||` gate
  and no `set -e` can catch it. `brain-client.sh` now refuses that outright
  (it compares resolved paths, so `f` and `./f` are caught too), which is the
  durable fix; the shape here means callers never reach the refusal.
- Moving the sidecar over the payload first adds a step that can fail and
  leave the pre-scrub original in place — intact and non-empty, so
  `_assert_envelope` passes it and the unscrubbed content egresses with every
  exit code reading 0. Reproduced: with an ungated `mv`, `writeback` was
  handed a payload still containing `123-45-6789`. Posting the sidecar
  directly removes the step and the failure class with it.

**A failure to RESOLVE is not a brain failure.** If `$CEPA_ROOT` is empty,
record `status: degraded — plugin root unresolved` and say the client path
could not be resolved. Never write `unreachable`, `unavailable`, or `outage`
for a 127: that is a path bug. The failure mode is documented in artist360's
`docs/solutions/integration-issues/false-unavailable-from-missing-cli-path-and-untracked-credential.md`
— 42 review files there carried a false "unreachable" claim while the service
was live. Verify with `brain-client.sh health` before ever claiming an outage.

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
Not processed this run: K docs (clusters ...)   <- whenever candidates found > docs investigated
CONCEPTS.md: <scanned, no qualifying terms | created with N entries | updated — added A, refined R, scrubbed V>
```

**Derived-rule check on every stale-mark, Replace, and Delete:** these
outcomes all mean the doc's guidance changed standing — so run the same
markdown citation grep the Delete flow uses, but over instruction files
(CLAUDE.md, AGENTS.md, cepa.local.md). Any rule citing or plainly derived
from the affected doc gets a flagged line in the report ("instruction-file
rule may derive from <doc> — review it"), because the rule keeps steering
agents after its provenance went stale. Never edit instruction files
autonomously — the flag is the deliverable. (Projects that promote
solution-doc prevention rules into CLAUDE.md accumulate exactly this
exposure; one scanned project carries 20+ such rules.)

Then per file: path, classification, evidence found, action taken. For
Consolidate: which doc was canonical, what merged, what was deleted. In
headless mode, split actions into **Applied** (writes succeeded) and
**Recommended**, naming the sub-case per item: *write failed* (apply
manually), *withheld by the execution gate* (report-only mode or dirty
path — nothing on disk was changed; review, then apply), or *draft failed
validation* (Replace successor rejected — do not apply as-is; fix the
draft or re-run). The sub-cases need different human responses; never
conflate them.

**Commit:** skip when nothing changed. Stage ONLY the files this refresh
touched. Commit message summarizes the refresh (e.g., "docs: refresh 3
stale learnings, consolidate 2, delete 1").

These rules consume the record made by Phase 3's execution gate (starting
ref, dirty paths, ownership) and honor the same invariant: **the run never
leaves HEAD somewhere the user didn't put it, and never mutates or commits
into work that isn't its own.**

Headless rules:

- **On main (or the repo's default branch):** create `docs/refresh-<scope>`
  from the starting ref, commit the staged refresh files, push and attempt
  a PR (report the branch name if PR creation fails) — then check the
  starting ref back out, always. Unrelated dirty files are protected twice:
  selective staging keeps them out of the commit, and the checkout-back
  returns them with HEAD. Never stash them — a stash is user work at risk.
- **On a feature branch that is this run's own work** — the user invoked
  the refresh while working on that branch, or a pipeline caller (e.g.
  `/cepa:lfg` or `/cepa:sweep`) invoked it as part of that branch's flow:
  separate commit on the current branch; HEAD never moves.
- **On a feature branch the run does not own** (per the Phase 3 execution
  gate): the run was in report-only mode — nothing was written or staged,
  so there is nothing to commit. Every action appears in the report as
  Recommended with the exact edits/commands a human needs to apply it.
- **Detached HEAD:** not-owned → report-only mode; never commit.
- **Git failure at any step:** include the recommended commands in the
  report and continue; if the failure happened after a branch was created,
  still restore the starting ref before finishing.

Interactive mode: offer commit options fitting the current branch state, as
before. Options that create a branch default to returning to the starting
ref; an option may explicitly offer to stay on the new branch, and choosing
it satisfies the invariant — a destination the user picked IS where the
user put HEAD.

## When to Stop

- No `docs/solutions/` directory or no candidate docs → report and stop.
- Scope hint matched nothing → report the miss and stop (headless: never
  widen silently).
- Everything else is handled by classifying, stale-marking, or recording
  Recommended actions — this command never blocks mid-run.

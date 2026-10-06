# Fixture — every known `status:` / `severity:` spelling

Not a findings file. This is the oracle for the two verification greps in
`../SKILL.md` ("Verify against the body, never against the block's own
arithmetic"). Every spelling below occurs, or has occurred, in a real
`todos/review-*.md` file.

Run both patterns from `SKILL.md` against this file. **Expected: one status
row and one severity row per pair in `## Live spellings`** — its heading states
the pair count, and that heading is the only place the number lives. Then run
them against `## Must NOT match` and expect **0 rows** from the prose block.

A pattern that scores anything else is wrong, no matter how
reasonable it looks. Add a line here before widening a pattern, never after.

## Live spellings — all 17 pairs must match

- status: plain-dash-marker
- severity: P1
status: bare-no-marker
severity: P2
  status: indented-no-marker
  severity: P3
  - status: indented-with-marker
  - severity: P1
- **status:** bold
- **severity:** P2
- **Status:** CAPITALISED
- **Severity:** P3
- `status: backticked`
- `severity: P1`
* status: star-marker
* severity: P2
+ status: plus-marker
+ severity: P3
- *status:* single-asterisk-italic
- *severity:* P1
- __status:__ underscore-bold
- __severity:__ P2
- status : space-before-colon
- severity : P3
- status: hyphenated-value
- severity: P1
- status: `value-only-backtick`
- severity: `P2`
- **confidence:** 100 · **class:** judgment · **status:** positional-middot
- **confidence:** 100 · **class:** judgment · **severity:** P3
category: X | agent: Y | status: positional-pipe
category: X | agent: Y | severity: P1
- **Agent:** security-sentinel · **Status:** done
- **Agent:** security-sentinel · **Severity:** P2

## Notes on two of those lines

`hyphenated-value`: a `[a-z]+` value class would truncate it to `hyphenated`,
which is why the shipped class is `[a-z_-]+`. The row total is unaffected either
way — see SKILL.md.

`value-only-backtick`: this is the only line that exercises the trailing
`` `? ``. The whole-field form (line 29) does **not** — its leading backtick is
consumed by the pre-field emphasis group, so that line matches identically with
or without the trailing option. Only a backtick touching the value directly,
after the colon, reaches it. A fixture claiming to cover "every spelling" must
exercise each regex **element**, not merely hold a line that looks related; this
pair was added after an audit found the element unexercised.

## Must NOT match — prose, frontmatter tails, and non-tallyable shapes

These lines exist to catch an over-match. A widened pattern that starts scoring
them is inflating tallies, which reads as a plausible count and is therefore
harder to notice than a zero.

status re-validated under lock) rather than refused.
statuses with no status filter, and the statement's reconcile identity
  Status corrected 2026-07-29 during /cepa:triage of
STATUS block, which records the mutation run.
The status of this is unclear.
* the status field is parsed by triage

These are real lines from this repo's `todos/` that mention the field mid-line.
The `**Fix:**`/`**Problem:**` and `- title:` lines OPEN as a field, so only the
positional branch's separator requirement keeps them out. The two wrapped
continuation lines guard the first two branches instead (indent, and a leading
backtick with no list marker).

**Fix:** interactive keeps `status: pending` (sinks still written);
**Problem:** `status: deferred` on all four and `applied: 24 / deferred: 4` in
**Fix:** finding #12 → `status: completed` with a `resolved:` line citing this
- title: Two findings still status:deferred on the exact question this PR settled
- title: U5 verifies counters and checkboxes but never that its own `Closes:` claim actually landed as `status:`/`applied_in:`
  — so every consumer that parses `status:` (the canonical field) still saw 4 open
`status: deferred` and both shard checkboxes were unticked, against CLAUDE.md's

These carry a real separator, but INSIDE inline code or with no `key:` opening.
The first quotes the batch shape: counted, it switched body verification off
for its whole file.

**Fix:** treat `cat: x · severity: P2/P3 (batch)` as a partial file.
**Problem:** the checker misses `- **confidence:** 100 · **status:** pending` rows.
- title: see `x: 1 | status: applied` here
Some prose here · status: pending

## Known limit, not a defect

An indented `status:` inside a finding and an indented `status:` inside a
frontmatter block (`brain:`, `grounding:`) are byte-identical, so no anchor
distinguishes them. A Run Metadata block therefore contributes rows. That is
why comparing the row total against the `### N` headings is mandatory rather
than advisory — the comparison, not the pattern, is what catches it.

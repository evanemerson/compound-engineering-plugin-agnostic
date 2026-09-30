# Fixture — every known `status:` / `severity:` spelling

Not a findings file. This is the oracle for the two verification greps in
`../SKILL.md` ("Verify against the body, never against the block's own
arithmetic"). Every spelling below occurs, or has occurred, in a real
`todos/review-*.md` file.

Run both patterns from `SKILL.md` against this file. **Expected: 13 status rows
and 13 severity rows** — one per line in `## Live spellings`. Then run them
against `## Must NOT match` and expect **0 rows** from the prose block.

A pattern that scores anything other than 13 / 13 / 0 is wrong, no matter how
reasonable it looks. Add a line here before widening a pattern, never after.

## Live spellings — all 13 must match

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

Note the last pair: `[a-z]+` as a value class would truncate
`hyphenated-value` to `hyphenated`, which is why the shipped class is
`[a-z_-]+`. The row total is unaffected either way — see SKILL.md.

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

A **mid-line** field is out of reach of any line-anchored pattern and is
deliberately not matched — it is one of the four non-tallyable shapes:

- **Agent:** security-sentinel · **Status:** done

## Known limit, not a defect

An indented `status:` inside a finding and an indented `status:` inside a
frontmatter block (`brain:`, `grounding:`) are byte-identical, so no anchor
distinguishes them. A Run Metadata block therefore contributes rows. That is
why comparing the row total against the `### N` headings is mandatory rather
than advisory — the comparison, not the pattern, is what catches it.

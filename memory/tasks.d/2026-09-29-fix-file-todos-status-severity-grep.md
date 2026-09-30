# Residuals — fix/file-todos-status-severity-grep (PR #75)

## 2026-09-29 — /cepa:review findings deferred to human judgment

Source: `todos/review-2026-09-29-203720.md` (4 findings; #3 applied in the
review commit, the three below are `judgment` and left for a decision).

1. **P2 — five more spellings return a silent zero in the file-todos verify
   grep** — `plugins/cepa/skills/file-todos/SKILL.md:231` (the "every
   combination" claim). Indented `- status:`, `*`/`+` list markers,
   single-asterisk italic, `__underscore-bold__`, and `status :` (space before
   colon) all return zero against the shipped pattern; none is named as out of
   scope. Verified zero occurrences across the real 193-file corpus, so this is
   a latent contract/regex disagreement, not an active miscount. Related
   asymmetry observed live: indented `status:` WITHOUT a dash over-matches
   (reaches frontmatter), while indented `- status:` WITH a dash under-matches.
   Fix is either to narrow the prose claim or widen the anchor to
   `^[[:space:]]*[-*+]?[[:space:]]*` and re-run the corpus sweep.

2. **P2 — `[a-z]+` truncates at the first non-letter, collapsing two statuses
   into one `uniq -c` bucket** — `plugins/cepa/skills/file-todos/SKILL.md:243`.
   `not-attempted` and `not-configured` both print as `status: not`. Both values
   are real in the live corpus, but no single file holds two same-prefix values
   today, and the row TOTAL stays correct — so the section's prescribed oracle
   (row total vs `### N`) is unaffected. Add a clause to the `-o`/`uniq -c` note,
   optionally widen to `[a-z_-]+`.

3. **P3 — the closing verification instruction names no reachable corpus** —
   `plugins/cepa/skills/file-todos/SKILL.md:277`. It says to sweep "a corpus
   containing every spelling", but that corpus is another repo's `todos/`
   (dpc-pro, 193 files), named nowhere in the file; the concrete numbers live
   only in the commit message. Suggested fix: commit a fixture at
   `plugins/cepa/skills/file-todos/fixtures/status-spellings.md` and point the
   paragraph at it, making the check runnable from inside this repo.

All three are `action_class: judgment` — filed rather than auto-applied per
`cepa:autonomy` §4. Findings #1 and #2 are the same defect class this PR just
fixed, recurring at a different spelling set; that recurrence is itself the
argument for the #3 fixture.

## 2026-09-29 — RESOLVED: all three applied in the same session

Applied on `fix/file-todos-status-severity-grep` (PR #75) after the user chose
to close the class rather than ship the P2s as residuals. Status in
`todos/review-2026-09-29-203720.md` moved `pending → applied` for all four
findings; `summary.applied: 4`, `pending: 0`.

**Item 1 was filed with a wrong measurement and a wrong fix — both corrected.**
The "zero occurrences in the corpus" claim was measured with the wrong probe
(it tested indented `- status:` WITH a marker, which is absent; the live form is
indented `status:` with NO marker, present in **50 of 193 files**). So the
indentation gap was ACTIVE, not latent. Worse, the filed fix — require a list
marker on indented lines, to exclude frontmatter — passed a 13-case fixture and
then lost rows on **51 of 193 corpus files, 17 dropping to zero** (one went
26 → 0). Root cause: an indented `status: applied` in a finding and an indented
`status: fresh` in a `brain:` frontmatter block are byte-identical, so no anchor
separates them. The over-match is inherent; the `### N` comparison is the only
thing that catches it, which the spec now says explicitly.

Shipped pattern (both fields, `-i`):
`^[[:space:]]*[-*+]?[[:space:]]*(\*\*|__|\*|_|`)?status[[:space:]]*:(\*\*|__|\*|_|`)?[[:space:]]*`?[a-z_-]+`

Item 2: value class widened to `[a-z_-]+`; the `uniq -c` note promoted to its own
paragraph covering both bucketing failures and stating that neither moves the row
total.

Item 3: fixture committed at
`plugins/cepa/skills/file-todos/fixtures/status-spellings.md` (13/13/0 expected,
verified), plus a new "compare old against new, not just new against the fixture"
paragraph carrying the 51-file regression as its evidence.

Verification, against patterns extracted from the shipped file rather than
retyped: fixture 13/13 positive and 0/0 negative; corpus **0 losses, 0 gains,
same 6 explained zeros**; YAML-style file back to 26 rows; the three
originally-broken bold files still 9/9/8.

**Nothing is owed from this shard.** Left in place as the record of a filed fix
that was wrong and how it was caught.

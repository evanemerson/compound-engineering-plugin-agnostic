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

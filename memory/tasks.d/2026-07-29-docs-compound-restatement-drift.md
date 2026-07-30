# Residuals — docs/compound-restatement-drift

## 2026-07-29 — /cepa:compound on the restatement-drift meta-pattern

Closes PR #26 finding #17 (`todos/review-2026-07-29-215819.md`). Solution doc:
`docs/solutions/logic-errors/cross-cutting-policy-must-be-cited-once-not-restated-at-every-site.md`
(gitignored — `docs/` is local-only in this repo; CONCEPTS.md is the tracked
half). Brain writeback: 11 atoms, all promoted `evidence_only`.

### Live instances found while writing the doc — verified, unfixed

Both were found by the compound sub-agents and then re-verified directly
against the files, not relayed. Neither is in scope for a compound run's own
diff, so both are recorded here rather than fixed silently.

- [ ] P2 — `plugins/cepa/commands/review.md:172-179` restates the whole §8
  four-rung trunk ladder **and** its normalization rule, then closes the same
  paragraph with *"§8 is the single definition — do not restate the ladder
  here."* The prohibition and its violation are one paragraph. Three more
  sites append an abbreviated rung list to a §8 citation — `commands/task.md:115`,
  `commands/lfg.md:86`, `commands/compound.md:36` — the decorative-citation
  shape. Nothing about §8 requires local colocation (unlike §7's relay-point
  clause), so a rung added, reordered, or renamed goes stale at four sites
  silently. Fix: reduce all four to citations; consider generalizing leg 4 to
  every `§N<letter>` anchor repo-wide rather than only `§9`.

- [ ] P3 — `.github/workflows/model-pins.yml:8-10` states *"Leg 2 … is
  heuristic and only warns, so a false positive never blocks a merge."* The
  checker exits 1 when warnings are non-zero
  (`plugins/cepa/scripts/check-model-pins.sh:338-341`) and §9f requires both
  counts at zero. This copy was false **in the commit that introduced it**
  (`50120ad` shipped the comment and that verdict block together) — not later
  rot. Fix: delete the sentence and point at §9f; a comment describing what an
  adjacent checker does is a restatement in a different language from its
  subject, so it is never re-read when the behavior changes.

### Checked and clean (recorded so a future run does not re-derive it)

- §5 residual-sink and `slug(x)` rules: ~40 `§5` citations, 5 `slug(x)` uses,
  all pointers to the one definition. No restatement.
- `cepa:file-todos` format: cited as "the single canonical spec" everywhere.
- autonomy §7 untrusted-data clause: written out longhand in 6 non-owner
  files with differing wording — **correct by design**, not drift. CLAUDE.md
  requires the clause *at the relay point*; a citation cannot guard the read.
  The live risk there is *coverage* drift (does each instantiation still carry
  every clause §7 now requires, incl. declarative exemption claims?), which is
  a completeness audit, not a consolidation. Converting these to citations
  would break the guard — the doc's Detection section carries a signal against
  exactly that mistake.
- The "indistinguishable from a clean pass" idiom (~10 files): a design idiom
  applied locally to a different mechanism each time, not one fact copied.

### Deliberate non-actions

- **No new `CLAUDE.md` rule.** The file already states this lesson twice — as
  the named family of three siblings, and in the dispatch-model rule's own
  history paragraph. A fourth generalizing rule would be a new longhand copy
  of a lesson the file already carries: the defect committed into the document
  warning against it, for the second time. Agent 4 recommended this
  decisively; the doc records the reasoning.
- **CONCEPTS.md prior brain rows not `mark_stale`d.** This run's edit was
  purely additive (2 new terms + 1 flagged ambiguity); no existing row is
  contradicted, so the §4.6 retire-on-edit step does not apply.
- **PHI scrub not run** — `cepa.local.md` has no `## Compliance` section and
  no `brain_phi_scrub: true`, so the scrub is not forced (`cepa:brain`).

### Still open from earlier shards (not repeated here)

#4 (`dispatch_models` Run Metadata) and #10 (`/cepa:setup` consumer-side model
check) in the PR #24 shard; #11 (relocate `check-model-pins.sh`) and #12
(`actions/checkout@v4` SHA pin + dependabot) in the PR #25 shard; #15 (leg 3
ladder-tier gap), #16 (`cepa:dispatch-tiers` split) and #18 (bundle #10+#11)
in the PR #26 shard.

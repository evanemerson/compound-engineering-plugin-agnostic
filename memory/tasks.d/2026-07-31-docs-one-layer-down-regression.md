# Residuals — docs/one-layer-down-regression

## 2026-07-31 — `/cepa:compound` on the one-layer-down regression pattern

Solution doc: `docs/solutions/logic-errors/each-fix-reintroduced-the-defect-class-one-layer-down.md`
(gitignored — `docs/` is local by convention, so this shard and CONCEPTS.md are
the tracked record). Plan backlink appended to
`docs/plans/2026-07-31-checker-symlink-traversal-symmetry.md`. Brain writeback:
18 atoms, all promoted to `evidence_only`.

CONCEPTS.md gained **Silent pass** and **Stated limit** under *Verification
authoring*, **One-layer-down regression** under a new *Fix authoring* section,
and one flagged ambiguity (consistency between sibling call sites is not
self-evidently good — when the site being changed is the correct outlier,
matching its neighbours adopts their omission).

### Deferred

- [ ] **`brain-client.sh` resolves `.env.local` relative to the CWD, not to the
  repo root, and nothing says so.** Hit live this run: a `cd` to a scratchpad
  before invoking the client made it fail with `BRAIN_URL not set (check
  .env.local)`. The `cepa:brain` skill says the credentials live in "a
  gitignored `.env.local` in the repo root", which reads as a location fact
  about the file, not as a constraint on the caller's working directory.
  `BRAIN_ENV_FILE` overrides it but is documented only inside the script.
  Either the skill states the constraint at the call contract, or the client
  resolves upward to the repo root. **Deliberately NOT added to CLAUDE.md** —
  the skill is the owning artifact and lives in this repo as plugin source;
  a CLAUDE.md copy would be a second home for the fact, which is the drift
  this repo keeps paying for.

- [ ] **`/cepa:compound` Step 1 prescribes `git diff <trunk>...HEAD`, which is
  empty when the work being documented has already merged.** This run
  documented a pattern spanning three landed PRs, so the range had to be
  derived by hand (`edf4bdc..5dab52c`). The command has no branch for the
  retrospective case, and an empty diff degrades quietly — the sub-agents just
  see less evidence, which is the silent-pass shape the doc this run produced
  is about. Low urgency; only bites when compounding after the fact.

- [ ] **Two buildable controls named in the solution doc's Prevention section
  were not built.** (1) a per-*leg* unreadable-subtree fixture rather than
  per-root — precisely what would have caught the layer-2 regression before
  merge; (2) a structural check that every `find` in the checker is either
  inside `traverse()` or a `traverse` call, making "a new leg bypasses the
  helper" mechanical instead of a review judgment call. Both are new control
  cases, so they land with the mutant-set cadence question already carried in
  `memory/tasks.d/2026-07-31-fix-checker-symlink-traversal-symmetry.md` rather
  than independently.

### Decided this run (recorded so it is not re-litigated)

**No fourth CLAUDE.md rule for this defect class.** The model-pin section
already names it generically ("a fix scoped to the reported instance leaves the
rest of the construct live"). A new heading would reproduce the restatement
drift that section itself documents — the failure PR #26 committed one commit
after declaring the rule against it. A one-line addition to that section's
existing enumeration was drafted and **declined by the operator**; the durable
record is the solution doc and the CONCEPTS entry instead.

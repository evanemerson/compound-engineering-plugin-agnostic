# Residuals — docs/compound-restatement-drift

## 2026-07-30 — /cepa:review + /cepa:triage on PR #27

Findings file: `todos/review-2026-07-30-075218.md` (8 findings, 0 P1, 4 P2,
4 P3). Applied in triage: #1 (close PR #26 finding #17 in both sinks), #5
(model-pins workflow comment → §9f citation), #6 (date/locate the "checked
and clean" §7 claim), #8 (add the `completed` counter to the `file-todos`
summary spec). The four below were deferred by human decision — all
`judgment` class under `cepa:autonomy` §4.

### Deferred

- [ ] P2 — `plugins/cepa/commands/compound.md` — a compound run has no
  instruction routing a live defect its sub-agents verify *outside* the run's
  diff scope to a canonical sink. Grepping for `residual`, `todos/`,
  `tasks.d`, `out of scope` returns one hit (line 186, the brain-writeback
  step). `sweep.md:98-107` reads `memory/tasks.d/*.md` but states unmatched
  items "are never build-eligible" — an item with no `todos/` entry can never
  be built. PR #27's own two discoveries hit this and were rescued only
  because the review run filed them as findings #4 and #5. **Deferred
  because** the fix adds a step to a command contract (a behavior change
  warranting a version bump), which would turn a `docs(compound):` PR into a
  `fix:` PR. Fix: add the step citing §5 rather than restating it (review
  finding #2, confidence 85).

- [ ] P2 — `CONCEPTS.md:155` — third append to the `## Flagged ambiguities`
  tail that CLAUDE.md names as a known unsharded multi-writer sink, written
  by both `/cepa:compound` and `/cepa:compound-refresh`. The note entered at
  `e24814c` (PR #23); `efeaaca` and `d84d889` have appended since without
  addressing it. Serial runs don't collide, so nothing is broken today — the
  point is that the recurrence count was invisible until now. **Deferred
  because** the fix requires choosing a mechanism (per-run shard mirroring
  `memory/tasks.d/`, vs. a single serialized writer), which is a design call.
  Strike the CLAUDE.md known-latent-instance note once done (review finding
  #3, confidence 78).

- [ ] P2 — `plugins/cepa/commands/review.md:172-179` restates the whole §8
  four-rung trunk ladder **and** its normalization rule, then closes the same
  paragraph with *"§8 is the single definition — do not restate the ladder
  here."* Three further sites append an abbreviated rung list to a §8
  citation — `commands/task.md:115`, `commands/lfg.md:86`,
  `commands/compound.md:36` — the decorative-citation shape. Nothing about §8
  requires colocation (unlike §7's relay-point clause), so a rung added,
  reordered, or renamed goes stale at four sites silently. Re-verified
  2026-07-30 at all four cited lines. **Deferred because** the fix touches
  four command files and pairs with generalizing `check-model-pins.sh` leg 4
  from `§9` to every `§N<letter>` anchor — its own PR (review finding #4,
  confidence 90). **Bundle with the item below: one checker change closes
  both.**

- [ ] P3 — `CONCEPTS.md:141-144` — the instantiation carve-out states its
  conclusion ("whether the copy has to be there for the mechanism to work")
  without the mechanism behind it: an agent's handling of adjacent untrusted
  content depends on what is physically in context at the read, so a bare
  `see §7` pointer does not guarantee the guard was loaded first. A future
  agent could reclassify the six §7 instantiations as citable restatements
  and convert each relay point into an unguarded channel. Not exploitable
  today; `compound-docs/SKILL.md:173` forbids CONCEPTS.md from carrying paths
  or anchors, so prose alone cannot close it. Fix: build the
  `<!-- policy-owner: <anchor> -->` marker the solution doc's Prevention
  section proposes, as a leg-4 generalization — **the same checker change as
  the item above** (review finding #7, confidence 45).

### Applied this run (recorded so a future run does not re-derive it)

- PR #26 finding #17 is now `status: completed` with a `resolved:` line in
  `todos/review-2026-07-29-215819.md`, and its checkbox in
  `memory/tasks.d/2026-07-29-fix-dispatch-model-contract.md` is struck. The
  compound work had been done since 2026-07-29; only the machine-parsed
  record was stale.
- `.github/workflows/model-pins.yml:8-10` no longer describes what
  `check-model-pins.sh` does — it cites §9f. The old comment was false in the
  commit that introduced it (`50120ad` shipped the comment and the verdict
  block together), which is the strongest evidence on record for the
  "comment describing an adjacent checker" Detection signal.

### Dismissed after verification (do not re-file)

- The shard's `#12` cross-reference ("`actions/checkout@v4` SHA pin +
  dependabot") was flagged as adding detail absent from the source. It is
  not: `todos/review-2026-07-29-091538.md:402` reads "add a renovate/dependabot
  rule to bump it." The PR #25 shard is the abbreviated copy, not this one.
- All seven carry-forward references in the 2026-07-29 shard (#4, #10, #11,
  #12, #15, #16, #18) verified present, correctly attributed, and still open.

### Still open from earlier shards (not repeated here)

#4 (`dispatch_models` Run Metadata) and #10 (`/cepa:setup` consumer-side model
check) in the PR #24 shard; #11 (relocate `check-model-pins.sh`) and #12
(`actions/checkout@v4` SHA pin + bump rule) in the PR #25 shard; #15 (leg 3
ladder-tier gap), #16 (`cepa:dispatch-tiers` split) and #18 (bundle #10+#11)
in the PR #26 shard.

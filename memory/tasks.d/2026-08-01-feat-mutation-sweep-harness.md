# Residuals — feat/mutation-sweep-harness

## 2026-08-01 — the mutation sweep harness (U1–U4)

Plan: `docs/plans/2026-07-31-mutation-sweep-harness.md` (local; `docs/` is
gitignored). Plan review: `todos/review-2026-08-01-000851.md`, 28 findings,
6 personas.

Shipped: `scripts/mutants/registry.sh` (63 mutants), `scripts/run-mutation-sweep.sh`,
`.github/workflows/mutation-sweep.yml`, `cepa:autonomy` §9f extension, and the
controls 17/36 fix that adding a second workflow file required.

### Decided this run

- **Deferred finding #2 — how the driver reaches the mutated checker.** Resolved
  to option (a): `cp -a` the tree **including `.git`** to a temp dir and run the
  harness with cwd inside the copy, `CEPA_PIN_CHECKER` left unset. The plan's
  cost objection ("a full tree copy per mutant") did not survive measurement —
  the tree is 1.7 MB and `.git` 9.1 MB, and the copy happens **once per run**,
  not per mutant. Option (b) would have put a one-env-var hole in a guard whose
  stated job is keeping CI from validating an unreviewed checker.
  `git worktree add` was rejected inside option (a): it checks out HEAD, so it
  would test the *committed* checker while the operator is mid-edit on the
  checker — the exact moment the sweep matters.
  Stated consequence: under (a) the mutated checker is also **content** in the
  fixture the harness builds, so a mutant perturbing citation-shaped text would
  redden the baseline for a reason unrelated to the behaviour under test. No
  registered mutant does; the registry header says to author around it.

- **`BASELINE-DIRTY` did not materialise.** The plan expected "~a third" of
  mutants to abort at the baseline gate. Measured: **zero of 63**. That figure
  was a property of the prior round's uncurated set. Enumerating by construct
  and applying the "a mutant must be silent on the clean tree" rule (now in
  §9f) eliminates the state by construction rather than tolerating it. The
  outcome is kept — the rule is what makes it rare, and a future mutant that
  ignores the rule needs somewhere to land.

- **`HARNESS-ERROR` added beyond the plan's five outcomes.** D3 folds every
  missing trailer into `BASELINE-DIRTY`. A fixture failure, a `--only`
  mismatch, or a dead runner is not a fact about the mutant, and labelling it
  as one would put a false finding in the CI issue. The driver aborts the whole
  run instead. D3's actual guarantee — *a missing trailer is never a `CAUGHT`* —
  is preserved. Also added: `CAUGHT-DECLARED`, which is D4's "a declared
  survivor that starts being caught is a FAIL" given a name so it can be
  printed and selftested.

### Open

- [ ] P2 — **21 of 63 mutants are `SURVIVED-UNDECLARED`: real gaps in the
  control suite.** The sweep exits 1 on its first full run, so the weekly job
  is red from day one and its failure-issue channel carries 21 known items
  before it carries a new one. Per the plan these are residuals, not additions
  to this branch (a detection change and the thing it detects must not hide
  each other), and per §9f they must not be relabelled as declared survivors —
  a declared survivor cites a *recorded stated limit*, and open work is not
  one. **The list, by construct:**

  | Mutant | Construct with no control behind it |
  |---|---|
  | `ext-cite-yaml` | leg 4's `.yaml` extension — case 28 uses `.yml` only |
  | `tier-fable` | `fable` admitted to the leg-1 tier set (L3c only reaches `tier_rank`) |
  | `l1-unreadable` | leg 1's per-file readability guard — 33/34 plant under `scripts/` |
  | `l1-bom` | BOM/CRLF normalization before frontmatter parsing |
  | `l1-awk-nofm` | the no-frontmatter-at-all guard |
  | `l1-awk-close` | the frontmatter closing-delimiter exit |
  | `l1-value-comment` | inline-comment stripping in a `model:` value |
  | `l1-value-lowercase` | lowercasing the leg-1 value (case 8 is leg 4) |
  | `l1-tier-exact` | `grep -qx` — the value becomes a substring pattern |
  | `l1-nomodel-count` | the miss COUNT for a missing `model:` key |
  | `l2-grep-binary` | `-a` on leg 2's scanning grep (unreachable while the NUL probe stands) |
  | `l2-grep-rc` | leg 2's grep read-error arm — nothing plants an unreadable file under `plugins/` |
  | `l3-grep-rc` | leg 3's own read-error arm |
  | `l3-marker-boundary` | the left word boundary on `interactive=` |
  | `l4-index-anchored` | the `^` anchor when building the heading index |
  | `l4-index-bom` | BOM/CRLF normalization when building the heading index |
  | `l4-index-lowercase` | lowercasing the INDEX side of the anchor lookup (case 12 is the citation side) |
  | `l4-skillfiles-zero` | the zero-SKILL.md guard |
  | `l4-qual-dash` | leading-dash qualifier blanking (case 5 kills the round-1 delimiter defect instead) |
  | `l4-range-inherit` | inheriting the section number into a bare-letter range endpoint |
  | `v-miss-prefix` | the `MISS ` line prefix — counts and exit code are unchanged |

  Note the shape: **11 of 21 are leg 1 or the shared frontmatter/value
  sanitizers**, which is the mirror image of the first control-suite cut
  putting 22 of 26 cases on leg 4. The construct-based enumeration found what
  incident-based authoring could not.

- [ ] P3 — **`timeout-minutes: 120` is unmeasured on a hosted runner.** Local
  end-to-end: 63 mutants in 42 min (~40s each — the control suite's own 30.1s
  plus a tree copy and restore per mutant). The bound is ~3x the local figure.
  U3's verify item is one `workflow_dispatch` run measured on CI before the
  number is trusted; it cannot run until the workflow is on the default branch.

- [ ] P3 — **nothing machine-checks that a `SURVIVOR` declaration is
  *honest*.** The driver verifies the cited `<file>:<line>` still carries the
  literal words `STATED LIMIT`, which is deferred finding #12's floor, not its
  ceiling: relabelling a real gap as expected is still a one-word diff plus a
  reference to any line that happens to say `STATED LIMIT`. Carried forward.

- [ ] P3 — deferred findings #20, #21, #23 from the plan review remain open and
  were not touched: whether the workflow header rules belong in a shared
  include (#20), whether the registry should be data rather than sourced shell
  (#21), and the exact wording of §9f's gap-table row (#23 — a row was written;
  its wording is not settled). #12 is folded into the item above. #13 —
  the classifier's own coverage — is closed by `--selftest` (12 assertions
  across every branch, run as its own CI step before the sweep).

### Caught by this branch's own work

`.github/workflows/mutation-sweep.yml` broke controls 17 and 36 exactly as the
plan predicted — both neutralized `model-pins.yml` **by name**, so a second
`.yml` left `.github` still scannable and the expected MISS never appeared.
Reproduced: `2/2 passed` → `FAIL 17` / `FAIL 36`. Both now act on every
scannable file under the root via a `scannable_in()` helper, with the plant
asserted in both directions.

The first full sweep also exposed a defect in the sweep's own report: a footer
sentence beginning with the bare token `SURVIVED-UNDECLARED` was picked up by
the CI failure-issue grep (`^<OUTCOME> `) and reported as a 64th mutant.
Reworded, with the constraint recorded at the site.

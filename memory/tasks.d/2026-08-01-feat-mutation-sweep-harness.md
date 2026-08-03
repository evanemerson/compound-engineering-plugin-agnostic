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

### From the 2026-08-01 six-agent review (`todos/review-2026-08-01-123412.md`)

28 findings — 8 P1, 11 P2, 9 P3; 24 applied in `6fff3ca`, 4 deferred below.
**Three of the P1s were self-inflicted instances of the defect class this
harness exists to catch**, which is the durable lesson of this branch: the
`tee sweep.log` collision meant the workflow could never have completed a run;
a control that could not be SET UP was credited as a control that CAUGHT the
mutant; and `read_file`'s `;` made its own failure guard dead code. Two were
reproduced empirically before being fixed. Building a detector for a class does
not exempt the detector from the class.

- [x] **RESOLVED 2026-08-01 — option (b): land the fixes first.** The operator
  chose to close the gaps before merging rather than add a tracked known-gaps
  list, on the ground that (a) buys a third survivor category that would want
  deleting a week later, while two categories both meaning "expected" is the
  ambiguity §9f's no-relabel rule exists to prevent. The tension the plan
  raised ("a detection change and the thing it detects must not hide each
  other") was discharged by DISCIPLINE rather than by sequencing: the exit-3
  change landed first, and `run-mutation-sweep.sh` and `registry.sh` were then
  byte-identical across the control commit, so every flip is attributable to a
  control. The two can only hide each other if both move.
  Consequence, accepted: the 21 fixes landed on `feat/mutation-sweep-harness`
  itself rather than a fresh branch, and the merge plus the timeout
  calibration moved to the end of the work.

- [ ] ~~P1 — **the observer channel ships saturated.**~~ The sweep exits 1 on its
  first full run, so the weekly job is red from day one and its issue carries
  21 known items before it carries a new one. The workflow's own comment
  justifies `failure()` over `always()` because "an issue opened on a green run
  is noise that trains the reader to ignore the channel" — a channel that is
  red every week does the same thing faster. Week N+1's 22nd survivor arrives
  as one row inside a comment that has read "the same 21" for months.
  **Needs an operator decision.** §9f forbids relabelling a real gap as a
  declared survivor (that cites a *recorded stated limit*, and open work is not
  one). A third category — a tracked known-gaps list the driver subtracts, so a
  red run means something NEW — is the adversarial reviewer's proposal; unlike
  the mutant→control mapping the plan killed, its staleness is detectable (a
  listed gap that starts being caught can be reported). The alternative is to
  land the 21 fixes first so day one is green, which the "a detection change
  and the thing it detects must not hide each other" rule argues against.
  (review finding #25, confidence 90.)

- [x] **RESOLVED 2026-08-01 — detector in the PR gate, not a second schedule.**
  A scheduled heartbeat shares the failure mode it would be watching for: the
  same 60-day inactivity rule disables both, so the detector goes quiet
  together with the thing it detects. The check lives in `model-pins.yml`
  (push + pull_request), reads the sweep workflow's own run history through
  `actions: read`, and WARNS — freshness is not a property of the PR under
  review, and failing unrelated PRs is how a signal gets routed around. Stated
  limit: it cannot fire DURING the silence, only at the next push, which is
  the first moment anyone is present to act. A renamed or deleted sweep
  workflow lands in the UNVERIFIED branch, so it warns rather than passing
  quietly.

- [ ] ~~P2 — **the `schedule:` off-switch is documented but not detected.**~~
  GitHub disables scheduled workflows after 60 days of repository inactivity;
  the only mitigation is a comment telling a human to notice an absent run.
  This is the one-layer-up version of what the sweep solves. Right-sized fix is
  a judgment call: a second cheap workflow asserting "mutation-sweep completed
  within ~9 days", or an external dead-man's switch. (finding #26, confidence 90.)

- [x] **RESOLVED 2026-08-01 — `exit 3`, with `--partial-ok`.** Taken despite
  the plan having sanctioned the banner specifically: prose in the middle of a
  report is invisible to `set -e` and to every caller reading `$?`, so a
  subset run was green by construction. Exit 3 rather than folding into 1,
  because a subset that found nothing is not a finding and a caller that
  cannot tell those apart learns to ignore both. The weekly workflow never
  filters, so CI is unaffected.

- [ ] ~~P3 — **a filtered run that passes exits 0.**~~ `--mutants X` prints the
  PARTIAL banner and exits 0; the banner is prose in the middle of a report CI
  consumes. Any future step running a subset is green by construction — and a
  per-PR fast path is explicitly discussed and rejected in both headers, which
  is exactly the pressure that produces one later. Proposed `exit 3` unless
  `--partial-ok`; deferred because the plan sanctioned the banner specifically
  and the exit code affects any caller. (finding #27, confidence 90.)

- [x] **RESOLVED 2026-08-01 — keep the isolation, and it is the mechanism, not
  the debt.** `ext-cite-yaml` sabotages `CITE_EXTS` in the CHECKER. Had
  `scannable_in()` derived its list from there, the sabotage would propagate
  into the control, the control would agree with it, and the mutant would be
  uncatchable BY CONSTRUCTION. The second copy is what makes divergence
  detectable. Closing `ext-cite-yaml` with control 37 is the proof.
  (finding #28, confidence 62 — closed against the sweep, not against the
  argument.)

### Open

- [x] **RESOLVED 2026-08-01 — 18 closed by controls, 3 were never gaps.**
  18 new controls now cover 18 of the 21; each was verified individually by
  re-running the sweep for its own mutant and watching
  `SURVIVED-UNDECLARED -> CAUGHT`. `l1-nomodel-count` is covered twice (L1i and
  L1j), which is why 18 controls close 18 mutants and not 18-for-18 by name.

  **THREE OF THE 21 WERE NOT HOLES IN THE CONTROLS.** They are unreachable by
  any fixture, measured rather than argued, and are now `survivor()` entries
  against `STATED LIMIT` text recorded at their sites:

  | Mutant | Why no control can exist | Limit |
  |---|---|---|
  | `l2-grep-binary` | `-a` is observable only on a file GNU grep calls binary; under the `LC_ALL=C` the checker exports, only a NUL does that, and the NUL probe two lines above refuses the file first. Measured on grep 3.11: `0x80/0xFF/0x01/0x1B` with no NUL matches identically with and without `-a` | `check-model-pins.sh:311` |
  | `l2-grep-rc` | leg 2's readability probe reads the whole file before this arm runs. Control L2j plants exactly that fixture and stays GREEN under the mutant, while leg 3's identical arm dies to L3f — leg 3 has no probe. The guards are redundant in both directions, so neither is individually observable | `check-model-pins.sh:311` |
  | `l4-range-inherit` | the bare-letter arm is unreachable from `CITE_RE`, which numbers both sides of every hyphen. Instrumented and measured at **zero firings** across every citation in this repo | `check-model-pins.sh:614` |

  This is the distinction §9f's no-relabel rule turns on, and it was applied in
  the direction the rule intends: a declared survivor cites a limit, and open
  work is not one — but a construct **no fixture can reach** is a limit, not
  open work, and the existing `t-rc-half`/`t-err-half` pair is the same shape
  ("kept for the failures a fixture cannot stage"). The evidence is a
  measurement at each site, not a judgement.

  `l2-grep-rc` is the one that had to be *discovered*: it was written up as a
  real gap, a control was built for it, and the control passed under the
  mutant. The fixture is kept — L2j is now the only case covering leg 2's
  readability probe, a construct **no mutant sabotages**, which is §9f's
  stated ceiling ("a construct nobody thought to sabotage reports as covered")
  showing up in the registry rather than in the suite.

  **The original list, by construct:**

  | Mutant | Construct that had no control behind it | Now |
  |---|---|---|
  | `ext-cite-yaml` | leg 4's `.yaml` extension — case 28 uses `.yml` only | 37 |
  | `tier-fable` | `fable` admitted to the leg-1 tier set (L3c only reaches `tier_rank`) | L1p |
  | `l1-unreadable` | leg 1's per-file readability guard — 33/34 plant under `scripts/` | L1g |
  | `l1-bom` | BOM/CRLF normalization before frontmatter parsing | L1h |
  | `l1-awk-nofm` | the no-frontmatter-at-all guard | L1i |
  | `l1-awk-close` | the frontmatter closing-delimiter exit | L1j |
  | `l1-value-comment` | inline-comment stripping in a `model:` value | L1k |
  | `l1-value-lowercase` | lowercasing the leg-1 value (case 8 is leg 4) | L1m |
  | `l1-tier-exact` | `grep -qx` — the value becomes a substring pattern | L1n |
  | `l1-nomodel-count` | the miss COUNT for a missing `model:` key | L1i + L1j |
  | `l2-grep-binary` | `-a` on leg 2's scanning grep (unreachable while the NUL probe stands) | **declared** |
  | `l2-grep-rc` | leg 2's grep read-error arm — nothing plants an unreadable file under `plugins/` | **declared** |
  | `l3-grep-rc` | leg 3's own read-error arm | L3f |
  | `l3-marker-boundary` | the left word boundary on `interactive=` | L3g |
  | `l4-index-anchored` | the `^` anchor when building the heading index | 40 |
  | `l4-index-bom` | BOM/CRLF normalization when building the heading index | 41 |
  | `l4-index-lowercase` | lowercasing the INDEX side of the anchor lookup (case 12 is the citation side) | 42 |
  | `l4-skillfiles-zero` | the zero-SKILL.md guard | 38 |
  | `l4-qual-dash` | leading-dash qualifier blanking (case 5 kills the round-1 delimiter defect instead) | 39 |
  | `l4-range-inherit` | inheriting the section number into a bare-letter range endpoint | **declared** |
  | `v-miss-prefix` | the `MISS ` line prefix — counts and exit code are unchanged | V1 |

  Note the shape: **11 of 21 are leg 1 or the shared frontmatter/value
  sanitizers**, which is the mirror image of the first control-suite cut
  putting 22 of 26 cases on leg 4. The construct-based enumeration found what
  incident-based authoring could not.

- [x] **RESOLVED 2026-08-02 — measured on a hosted runner.** One
  `workflow_dispatch` on `main` (run 30741347574, 63 mutants against 75
  controls): **64.0 min — 43% of the 150-min step bound, 36% of the 180-min
  job bound.** Both hold with real margin; neither number is changed.

  **1.50x the local figure** (42.7 min on this machine). The reliability
  reviewer predicted exactly this, and the reasoning was right: per-mutant
  cost is dominated by the tree copy and restore, and that I/O is what a
  hosted runner does more slowly. My own note above — that growing the suite
  57 → 75 left the runtime "essentially unchanged" — was true locally and did
  not transfer. **A local timing is not evidence about these bounds.** That
  sentence now sits in the workflow beside the numbers, together with the
  re-measure trigger, so the next person to grow the registry or the suite
  does not repeat the inference.

- [ ] P3 — **the registry has no mutant for leg 2's readability probe.**
  Discovered by building L2j: the probe is the construct that actually catches
  an unreadable file in leg 2, and nothing sabotages it. Adding one would not
  help — the exit>1 arm backs the probe up, so a probe-only mutant survives
  too, and the pair would become a fourth and fifth declared survivor of the
  `t-rc-half` shape. Recorded rather than fixed: the honest description is
  that leg 2 has THREE redundant guards of which only the NUL check is
  individually observable, and §9f's ceiling paragraph is where that lives.

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
  the classifier's own coverage — is closed by `--selftest` (30 assertions
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

### Full sweep, 2026-08-01, after the control work

Clean tree at `6b28a56` — gate result. **58 CAUGHT / 5 SURVIVED-DECLARED / 0
undeclared survivors, 0 baseline-dirty, 0 anchor-missing, exit 0.** 42m41s for
63 mutants. The weekly job is green on day one, which was the whole point of
taking option (b).

Before: 40 CAUGHT / 2 SURVIVED-DECLARED / 21 SURVIVED-UNDECLARED, exit 1.

### From the 2026-08-01 second review (`todos/review-2026-08-01-201705.md`)

20 findings — 1 P1, 8 P2, 11 P3; 11 applied in `c4fcd42`, 9 deferred below.
**The P1 was in the freshness detector**, the component built to catch a
silent off-switch, and it was a silent-pass path of its own; a second finding
was a control whose post-plant assertion was vacuously true. Both reproduced
before being fixed. Third round on this branch where the detector fell to the
class it detects.

**New lesson, and it belongs to the freeze:** freezing `run-mutation-sweep.sh`
and `registry.sh` across the control commit is what makes each
`SURVIVED-UNDECLARED -> CAUGHT` flip attributable to a control — and it is
also what left 16 `why` fields describing a world the same PR had ended, two
of them naming a killer whose own comment in that PR says it cannot do the
job. The discipline that made the evidence trustworthy made the record wrong.
The missing step is a reconcile pass after the unfreeze, not a weaker freeze.

- [x] ~~P2 — **the nested per-mutant timeout cannot reach a hung checker.**~~ GNU
  `timeout` without `--foreground` puts its child in a new process group, so
  the sweep's outer `timeout -k 30 900` never signals the controls suite's own
  nested `timeout 120 bash "$CHECKER"`. Verified empirically: the grandchild
  survives as an orphan, the child's TERM trap never fires, and because the
  orphan holds the pipe the outer `$( )` reads, one mutant's worst case is
  ~1050s not 930s. Never a false CAUGHT (no trailer -> `HARNESS-ERROR` ->
  exit 2), and **latent** — no registered mutant targets the construct case 32
  guards. Needs a design call: `-k` on the inner timeout, `--foreground`,
  process-group-aware killing, or accept and record. (finding #12, conf 85.)
  **RESOLVED 2026-08-02** (fix/sweep-hung-checker-bound, 1.18.2) — the central
  claim did not survive re-measurement against the real constructs. A hand-hung
  checker (`sleep 600`) in a driver-style copy, outer bound scaled to `-k 5 20`:
  the `$( )` returned at **23s = the outer bound**, twice. The orphans are real
  (inner timeout + checker survive the group-kill, dying at the inner bound) but
  they cannot hold the OUTER pipe: every checker invocation is captured by
  `run_checker`'s inner `$( )`, whose reader dies in the group-kill, so the
  outer reader gets EOF on time. The blocking topology needs a descendant that
  inherits the suite's plain stdout — which the suite does not have today.
  What was hardened, since the bound held by fd-wiring accident rather than by
  structure: the driver now writes the controls transcript to a file under
  `$WORK` and waits on `timeout` alone (a future backgrounded fixture helper
  can no longer re-create the hold), and `run_checker` gained `-k 30` so a
  TERM-immune hang stays a 150s CASE failure instead of escalating to the 900s
  outer abort. Orphan afterlife ≤ inner bound after the driver proceeds:
  accepted and recorded, not fixed. Verified: controls 75/75, selftest 17/17,
  checker 0/0, one-mutant sweep (`t-predicate` CAUGHT by 31/33/35) through the
  file path.

- [ ] P3 — **the STATED LIMIT guard binds to a line, not to content.** With
  the target-file check applied, a survivor must cite its own target — but
  `l2-grep-binary` and `l2-grep-rc` both cite `:311`, whose two claims sit on
  separate lines, so deleting either leaves both declarations green with half
  their rationale gone. Refines the already-open "nothing machine-checks that a
  SURVIVOR declaration is honest". (finding #13, conf 80.)

- [ ] P3 — **`exit 3` and the detector's `UNVERIFIED` have no rule in §9f.**
  §9f's outcome table is per-mutant with no exit-code row; the freshness
  detector, its 16-day bound and its stated limit live only in a YAML comment.
  Both fail safe today. Note the collision: §9 says "for a caller's gate,
  UNVERIFIED counts as MISSING", while this step's UNVERIFIED exits 0 by
  design — same word, different constructs, and that is exactly what wants
  saying once rather than twice. (finding #14, conf 75.)

- [ ] P3 — **leg 2's readability probe is sabotaged by no mutant** (see the
  earlier entry; the second review corroborates it and adds that a probe-only
  mutant would survive too, because the `exit>1` arm backs it up — a fourth
  and fifth declared survivor of the `t-rc-half` shape rather than coverage).
  (finding #20, conf 85.)

- [ ] P3 — four smaller deferrals, all judgment: `gh issue list --limit 100`
  can miss the tracking issue and open a duplicate (#15); the INVALID message
  says the tree changed but not what changed (#16); per-mutant cost is
  I/O-bound so the 42m41s local figure may understate a hosted runner, which
  folds into the calibration item above (#17); and the "bound external text
  before display" and "a branch reachable by N causes must not name one" rules
  are applied at the sites review found, not audited across both workflows
  (#18, #19).

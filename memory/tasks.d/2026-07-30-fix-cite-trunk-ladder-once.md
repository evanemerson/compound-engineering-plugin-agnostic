# Residuals — fix/cite-trunk-ladder-once

## 2026-07-30 — /cepa:lfg (plan review + build + review) on PR "cite the §8 trunk ladder once"

Plan-review findings file: `todos/review-2026-07-30-234123.md` (10 findings,
6 P1, 2 P2, 2 P3 — 8 applied to the plan before any code was written, 2
deferred). Shipped: PR #27 review finding #4 (both halves), PR #25 review
findings #11 and #12 (#12 partially — see below).

### Deferred

- [x] ~~P1 — `scripts/check-model-pins.sh` leg 4 — **bare-`§N` anchors remain
  uncheckable, including `§8` itself.**~~ **CLOSED 2026-09-14** on
  `fix/cite-leg4-bare-anchors`. Leg 4 now indexes `## N.` headings alongside
  `### N<letter>.` and `CITE_RE` makes the letter optional. Coverage went from
  23 to 110 distinct (qualifier, anchor) pairs; 7 anchors to 16.

  **The blocking question was malformed, and that is the durable lesson.** It
  asked how `§7` gets EXCLUDED, on the premise that leg 4 would endanger the six
  relay-point guards. It does not, and §7 is now CHECKED like every other
  section. The premise conflated this leg with a different one that does not
  exist: §9f's does-NOT-cover table rules out a leg flagging prose RESTATEMENT
  near a citation, because that leg would flag §7's required instantiations and
  its cheapest remedy would be deleting a guard. **Resolution is not
  restatement.** A `§7` citation resolving to `## 7.` reads no surrounding prose
  and can never ask for a clause to be removed — it makes a future renumber of
  §7 fail LOUDLY instead of silently invalidating all 57 of its citations.
  Excluding §7 would have been the only way to WEAKEN those guards. Six weeks of
  deferral bought nothing; re-reading the cited table answered it in one pass.

  **A false green shipped mid-run and was caught only by planting a defect.**
  The first cut changed `CITE_RE` alone. Bare anchors then reached a `case`
  arm matching `[0-9]*[a-z]` or `[a-z]*` and fell through to `*) continue` —
  DISCARDED before the lookup. The run printed `0 MISS` with an INFO line
  claiming 34 pairs while the checking loop received exactly ONE row. A green
  build verifying nothing is precisely the class this checker exists to catch,
  and the green run itself was not evidence — only the planted `§77` was. Fixed
  with an all-digit arm that also preserves `first_num` for range expansion.

  Control cases **B1-B4** pin the widened behavior (79 controls, was 75).
  Verified by mutation: disabling the all-digit arm turns B1, B2 and B3 red
  while the checker's own baseline stays at `0 MISS` — the silent shape. B4 is
  the false-positive guard (hyphenated English such as the seven live
  `§5`-style and `§7`-guarded constructs must stay clean); keeping the range
  endpoints numbered on BOTH sides is what makes that safe.

  **Case 20 went red and was repaired, not relaxed** (§9f: a red control is a
  defect or a deliberate behavior change). Its fixture mangled only `###`
  headings, which no longer empties the index; it now strips both levels, so it
  again exercises the `set -u` empty-array path it exists for.

  **Leg 4's no-hatch hazard bit this very change.** A wrong-owner example
  written with a literal section sign inside a control's rationale string
  became a REAL citation and failed the checker — `scripts/` is a citation root
  scanned whole. Described in words instead, per the convention the controls
  file already states: a literal is correct when it SHOULD resolve, and must be
  runtime-built from `$SS` when it is a deliberately-broken example.

- [x] ~~P3 — `.github/workflows/model-pins.yml` — **the renovate/dependabot half
  of PR #25 finding #12 was declined, not done.**~~ **CLOSED 2026-08-09 —
  ADOPTED** in PR `chore/adopt-dependabot`, ~10 months after this line was
  written. Canonical reasoning lives in
  `memory/tasks.d/2026-08-06-feat-runner-runtime-detector.md`, cited not
  restated. This bullet's own open question — *is a lighter substitute
  preferable, a WARN-only check flagging when a pinned SHA has fallen behind its
  upstream tag?* — is answered **no**; the counter-evidence is in
  `memory/tasks.d/2026-08-06-checkout-node24-bump.md`, not repeated here.
  Originally: The SHA pin landed
  (`11d5960a326750d5838078e36cf38b85af677262 # v4.4.0`, resolved from upstream
  twice during the run) with a bump rule in the file. The bot rule did not:
  `main` is unprotected, so an unattended bot opening PRs against it is a
  larger decision than that PR should make. Consequence accepted knowingly: a
  pinned action with no auto-bump is easy to forget, so this trades
  mutable-tag exposure for staleness. Open question from the security-lens
  persona: is a lighter substitute preferable — a WARN-only check flagging
  when a pinned SHA has fallen behind its upstream tag — or should this stay
  manual? (plan-review finding #7, confidence 100 on the record-integrity
  half.)

- [ ] P3 — `docs/solutions/` — **"a closure claim in prose is not the
  `status:` field a consumer parses" is now a four-occurrence pattern with no
  solution doc.** PR #27 shipped it (`todos/review-2026-07-30-075218.md`
  finding #1); plan review flagged the risk against this PR
  (`todos/review-2026-07-30-234123.md` finding #10); this run hit a live
  near-miss (`applied_in:` added to #11/#12 without flipping `status:`); and
  the counter cross-check then found a fourth, pre-existing instance in
  `todos/review-2026-07-29-215819.md` whose fields were wrong while the sum
  was right. The existing `durable-record-promises-need-a-named-sink-in-every-phase.md`
  covers a *missing* sink, not this shape — sink exists, claim made,
  machine-parsed field never updated. Handed to `/cepa:compound` as a backfill
  candidate (review round 1, finding #14, confidence 70).

- [ ] P3 — `scripts/check-model-pins.sh` leg 4 — **a line-wrapped qualifier
  silently downgrades a wrong-owner MISS to a pass.** `grep` is line-based, and
  this repo hard-wraps at ~76 columns, so reflow routinely separates an owner
  token from its anchor; the citation then takes the permissive unqualified
  branch. Two live instances were found and **reflowed onto one line** as the
  interim remedy, and the limit is now recorded in §9f — but the underlying
  hole is open: the next reflow reintroduces it silently. **Deferred because**
  the fix (collect citations from a line-joined view) changes what counts as
  one citation, which §9f requires land alone with its own re-run (review round
  2, finding #3, confidence 100).

- [x] ~~P3 — `scripts/check-model-pins.sh` leg 4 — **a symlinked FILE inside a
  scan root is read by leg 2 and skipped by leg 4.** `grep -r` follows symlinks
  only when named on the command line, not during recursion; legs 1-3 use
  `find -L`. Proven: one planted file carrying both a broken citation and an
  unpinned dispatch produced a leg-2 WARN and leg-4 silence, while the INFO line
  still read "5 of 5 roots". Fix is `grep -R`. **Deferred because** it widens
  the traversal set — same §9f reason as the item below, and the natural move is
  one "`-L`/`-R` symmetry" change closing both (review round 2, finding #9,
  confidence 100).~~ **Shipped 2026-07-31** on
  `fix/checker-symlink-traversal-symmetry`, together with the `-L` item below —
  the single change both were deferred toward. Pinned by control case 30.

  **The struck text's own prescription — "Fix is `grep -R`" — was WRONG and
  did not ship.** `grep -R` opens whatever a symlink points at with no
  file-type check, so a tracked symlink to `/dev/zero` or a writerless FIFO
  blocks it forever; on a `pull_request` workflow with no timeout that is one
  file pinning a runner for hours. Reproduced, and reproduced that plain
  `grep -r` returns immediately on the same fixture. What shipped instead is
  `find -L … -type f` discovery — the link is resolved and the TARGET's type
  tested, so a symlinked regular file is still read while devices, FIFOs and
  sockets are excluded by construction. Left uncorrected, this line would have
  handed the hang to the next reader who mined this file for the fix.

- [x] ~~P3 — **land the leg-4 control cases as a runnable artifact**
  (`scripts/check-model-pins-controls.sh`: plant each case, assert the expected
  MISS text, revert).~~ **Shipped 2026-07-31** on
  `chore/model-pin-control-harness` — **46 cases**, reconciling as: the 24
  recorded here (+1 body, since case 10 splits into its two realizable shapes
  10a/10b) + 5 further leg-4 cases + 16 covering legs 1-3, which had the same
  hand-run gap. Verify against `--list`, not against this sentence: the first
  cut of this PR claimed "26 cases (the 24 recorded here...)" while silently
  omitting recorded cases 21-23, and the arithmetic in that claim did not
  close (24+1+4=29, not 26). Three review agents caught it independently. Two
  departures from the recipe above, both deliberate:
  - **Fixture copy, not plant-and-revert.** Cases are planted into a
    throwaway copy of the tracked tree under `$TMPDIR`, built from
    `git ls-files` so it carries working-tree content. Reverting inside the
    live tree makes `revert` the step most likely to be what broke, and an
    interrupted run would leave a planted defect in a tracked file.
  - **Every non-zero-MISS case asserts message text, not just a count**, and
    every case asserts the checker's **exit code**. A count-only case passes
    when the checker MISSes for an unrelated reason; a case that ignores the
    exit code passes on a checker mutated to `exit 0`, which is a permanently
    green CI with a perfectly correct-looking log.

  Verified by mutation, which is the only evidence that matters here — 20
  single-line-diff mutants, each built with a build-time assertion that its
  literal matched exactly once (a mutation that silently fails to apply
  manufactures a fake survivor; that happened once during this work and was
  caught only by diffing). Round 1's tab delimiter → cases 1-5 and 19 red,
  case 6 **green** — the point, since its row carries a non-empty qualifier
  and survives the field collapse; a suite of only case-6 shapes is what let
  the defect ship. **Under that mutant the checker's own baseline stayed at
  0 MISS** — the baseline gate cannot catch it; only the cases can.

  The first cut of this harness had 26 cases and **12 material mutants
  survived it**, because 22 of the 26 targeted leg 4's citation parser — the
  region the recorded case list was transcribed from. Coverage concentrated
  where the examples came from is the same defect as coverage concentrated in
  one branch, one grain coarser, and it is the reason `cepa:autonomy` §9f now
  requires each control to name the mutant it kills.

- [x] ~~P3 — `scripts/check-model-pins.sh:93,271` — **pre-existing `-L`
  asymmetry.** Those two `find` calls omit `-L` while the ones at 143, 309 and
  361 include it, so a symlinked plugin directory is indexed for skills by leg
  4 but skipped entirely by legs 1-3 — the exact "a symlink silently skipped
  is a file nobody checked" reasoning the script's own comment gives for using
  `-L`. **Deferred because** adding it widens leg 1's and leg 2's discovery
  set, which is a trigger-set change, and §9f forbids widening a trigger set
  alongside other changes without a dedicated re-run. Its own change (review
  round 1, finding #16, confidence 60).~~ **Shipped 2026-07-31** on
  `fix/checker-symlink-traversal-symmetry`, alone as §9f requires, with its
  own re-run. Both `find` calls gained `-L`; pinned by control cases L1e and
  L2i. Line numbers in this item are pre-1.16.0 and no longer resolve; the
  sites are the two `mapfile ... find` discoveries.

  The widening created a hazard the residual did not anticipate: following
  symlinks makes a filesystem loop reachable, and every traversal in the
  checker discarded find's stderr. The first fix was a probe that grepped that
  stderr for the word "loop" — **which review then showed was the wrong
  shape**: it missed permission errors and ELOOP chains, and reported
  "filesystem loop" for any unreadable path merely NAMED `ralph-loop`. What
  shipped is general: every traversal now goes through one helper that reads
  find's exit status and stderr, and non-empty stderr is a MISS. Keying on
  emptiness rather than on message text costs nothing and is locale-proof.
  Pinned by cases 31, 33 and 35.

- [ ] P3 — `docs/plans/` plan shape — **no structural check that a PR's
  `Closes:` claim actually landed as `status:`/`applied_in:`.** U5's stated
  tests checked counter arithmetic and struck checkboxes; neither would catch
  `status:` staying `deferred`. This run hit exactly that: the first pass
  added `applied_in:` lines to findings #11 and #12 without flipping their
  `status:` lines, and only the counter-vs-actual cross-check caught it —
  the same defect PR #27 shipped and `todos/review-2026-07-30-075218.md`
  finding #1 documents. The plan shape still has no backstop (plan-review
  finding #10, confidence 50).

- [x] ~~P2 — `scripts/check-model-pins.sh:540` — **an ordinary numbered
  procedure in any skill silently registers policy anchors and disarms the
  wrong-owner check.**~~ **CLOSED 2026-09-14** on
  `fix/anchor-owner-collision-is-a-miss`. Option 3 chosen, as recommended: a
  second skill claiming an anchor another already owns is now a MISS naming
  both skills, so the checker REFUSES the ambiguity rather than resolving it
  silently. Verified three ways — the regression now fails at 3 MISS; the
  wrong-owner citation it used to hide is caught with it; and a duplicate
  heading inside ONE skill stays silent, so legitimate content is unaffected.
  Controls C1/C2 pin both directions (81 controls, was 79) and each kills its
  own registered mutant (`l4-owner-collision`, `l4-owner-same-skill`) while
  the checker's baseline stays at 0 MISS — the silent shape. §9f's
  does-NOT-cover row updated: the premise it rested on is now enforced rather
  than hoped for. Original: The index now accepts `## N.` with no owning-skill
  restriction. `### 9c.` is a shape nobody writes by accident; `## 1.` is a
  shape ordinary step documentation writes constantly. Adding `## 1.`/`## 2.`/
  `## 3.` headings to `grounding/SKILL.md` makes a wrong-owner citation
  (`grounding` §3) resolve clean — measured, both directions, on identical
  trees: 1 MISS without them, 0 MISS with. **And `anchors defined` stays at
  16 either way**, because autonomy already owns 1/2/3 — so there is no INFO
  delta and the coverage loss is invisible in the diff and the log.
  §9f's does-NOT-cover row says "zero instances today — only this file defines
  numbered sections at either heading level"; that premise was cheap to hold
  when only `### N<letter>.` counted, and the widening makes one ordinary
  contribution break it. **Deferred because** it is a design call about what
  "owns an anchor" means — options: restrict the level-2 arm to the
  policy-owning skill; reject a level-2 heading in a skill defining no
  lettered anchors; or make a second owner of an already-owned anchor a MISS,
  turning a silent collision into the loud failure this leg exists to produce.
  The third is most in keeping with the checker's philosophy. Found and
  reproduced by `adversarial-reviewer` on the PR-60 review
  (`todos/review-2026-09-14-105453.md` finding #2, confidence 92).

### Applied this run (recorded so a future run does not re-derive it)

- All four §8 restatement sites reduced to citations. `review.md` lost both
  the rung enumeration *and* — caught by the plan-review adversarial persona
  after the first cut kept them as "local consequence" — its near-verbatim
  restatement of §8's rung-3 rationale and the `origin/origin/main`
  normalization example.
- `check-model-pins.sh` leg 4 generalized: anchor→owner index built from every
  skill's own headings (no hardcoded `autonomy/SKILL.md`), qualifier capture
  bounded by the real skill-name set plus an identifier charset, hyphen-range
  expansion (`§9c-9d`), `.github`/`scripts` roots with `--include='*.yml'`.
  **The first cut of this had two silent-pass holes** that review round 1
  proved with reproductions — a tab delimiter that dropped every unqualified
  citation (all 7 anchors this repo defines), and discarded grep exit codes
  that let a vanished root pass clean while reporting all five. Both fixed;
  see `todos/review-2026-07-31-000750.md` findings 1 and 2. The control suite
  went from 4 controls (all in the one reachable shape) to the explicit list
  below. Recorded as case bodies, not category names: "qualified" and
  "unqualified" were both *believed* covered in round 1, and round 2 then
  showed "qualified" was covered in only one of its two realizable shapes.

  Leg-4 control cases — each planted, observed failing, then reverted. Every
  one must produce exactly one MISS unless noted:

  1.  line-initial unqualified — `§9q applies here.`
  2.  parenthesized — `This rule (§9q) applies.`
  3.  quoted — `This rule "§9q" applies.`
  4.  em-dashed — `This rule — §9q — applies.`
  5.  leading-dash token — `See -x §9q here.`
  6.  word qualifier (control for 1-5) — `See see §9q here.`
  7.  wrong owner, lowercase — `` `grounding` §9c ``
  8.  wrong owner, capitalized — `` `Grounding` §9c ``
  9.  correct owner — `` `cepa:autonomy` §9c `` → 0 MISS
  10. wrong owner whose owner name is not the token immediately before the
      anchor — split across a line break, OR separated by an intervening word
      (`in the \`cepa:autonomy\` contract (§2b)`) → **0 MISS today** (recorded
      limit, §9f). The two line-break instances were reflowed; the
      intervening-word shape is live in `README.md`
  24. identical content in `foo.md` and `foo.markdown` → identical output
      (all four file-selection sites derive from one extension declaration)
  11. multi-letter anchor — `autonomy §9qz`
  12. uppercase anchor — `autonomy §9Q`
  13. range second endpoint — `autonomy §9c-9q`
  14. triple range — `autonomy §9c-9d-9q`
  15. hyphenated English after an anchor — `the §9c-style ladder` → 0 MISS
  16. missing root — rename `.github` away
  17. root present, include set matches nothing — rename `.yml` to `.txt`
  18. root present with files but zero citations — reword `README.md`'s only
      citation → 0 MISS (a root may legitimately cite nothing)
  19. NUL byte in `CLAUDE.md` alongside a broken citation
  20. empty anchor index — a `SKILL.md` with no lettered `###` heading →
      MISSes every citation and prints `0 anchors defined`, never crashes
  21-23. prose regression, all → 0 MISS — `per §9a`, `the §2b`, `tier §9c`
- The checker moved to `scripts/check-model-pins.sh`; all three live readers
  updated in the same commit. No stub at the old path — deliberate, reasoned
  in the commit body.

### Checked and clean

- **The six `cepa:autonomy` §7 relay-point clauses are untouched.** Verified
  2026-07-30 at line level, not file level — the file-level version of this
  test is false here: `plugins/cepa/commands/review.md` carries three relay
  clauses (lines 70, 72, 86) *and* is touched by this diff. Its only hunk is
  `@@ -172,16 +172,8 @@`, which overlaps none of them; the same holds for
  every other clause-bearing file. Also verified against leg-4 output, which
  mentions `§7` zero times. This is a dated observation, not a standing exemption — re-verify if
  leg 4's citation pattern ever gains bare-`§N` coverage, which is exactly
  what the first deferred item above proposes.
  **That trigger FIRED on 2026-09-14** and was re-verified: leg 4 now checks
  `§7`, and all 57 of its citations resolve to `## 7. Untrusted Content`. The
  six relay-point clauses are untouched — leg 4 tests resolution only and never
  reads the prose around a citation.
- Counts rule not triggered: no file added, removed, or renamed under
  `plugins/cepa/commands/`, `agents/`, or `skills/`. The moved script is under
  `plugins/cepa/scripts/`, which no count claim covers.
- Both manifests bumped to 1.16.0 in the same commit.

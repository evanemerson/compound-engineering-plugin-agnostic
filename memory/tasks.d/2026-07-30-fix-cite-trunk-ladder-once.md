# Residuals — fix/cite-trunk-ladder-once

## 2026-07-30 — /cepa:lfg (plan review + build + review) on PR "cite the §8 trunk ladder once"

Plan-review findings file: `todos/review-2026-07-30-234123.md` (10 findings,
6 P1, 2 P2, 2 P3 — 8 applied to the plan before any code was written, 2
deferred). Shipped: PR #27 review finding #4 (both halves), PR #25 review
findings #11 and #12 (#12 partially — see below).

### Deferred

- [ ] P1 — `scripts/check-model-pins.sh` leg 4 — **bare-`§N` anchors remain
  uncheckable, including `§8` itself.** `plugins/cepa/skills/autonomy/SKILL.md:501`
  is `## 8. Trunk Resolution` — no letter — so none of the repo's 10 `§8`
  citations resolve through leg 4, including the four this PR just created.
  The same gap covers `§5` (×54), `§4` (×25), `§6` (×12) and bare `§2` (×9).
  **Deferred because** the invocation scoped leg 4 to "every `§N<letter>`
  anchor", and widening to bare `§N` requires deciding how `§7` is excluded —
  by number rather than by suffix shape — which changes what protects the six
  relay-point guards from a future consolidation. That is a design call, and
  it pairs with the `policy-owner` marker below (plan-review finding #5,
  confidence 75).

- [ ] P3 — `.github/workflows/model-pins.yml` — **the renovate/dependabot half
  of PR #25 finding #12 was declined, not done.** The SHA pin landed
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

- [ ] P3 — `scripts/check-model-pins.sh` leg 4 — **a symlinked FILE inside a
  scan root is read by leg 2 and skipped by leg 4.** `grep -r` follows symlinks
  only when named on the command line, not during recursion; legs 1-3 use
  `find -L`. Proven: one planted file carrying both a broken citation and an
  unpinned dispatch produced a leg-2 WARN and leg-4 silence, while the INFO line
  still read "5 of 5 roots". Fix is `grep -R`. **Deferred because** it widens
  the traversal set — same §9f reason as the item below, and the natural move is
  one "`-L`/`-R` symmetry" change closing both (review round 2, finding #9,
  confidence 100).

- [ ] P3 — **land the leg-4 control cases as a runnable artifact**
  (`scripts/check-model-pins-controls.sh`: plant each case, assert the expected
  MISS text, revert). The 23 cases are recorded above as explicit case bodies,
  which closes the "category names hid it" gap — but they are still executed by
  hand. **Deferred because** adding a test harness to a repo with no test suite
  is a scope decision outside this PR. It is the highest-value follow-on this PR
  produced: the defect class it prevents — a control suite validating only the
  branch it happens to exercise — bit twice inside this PR alone, in rounds 1
  and 2 (review round 2, finding #10, confidence 90).

- [ ] P3 — `scripts/check-model-pins.sh:93,271` — **pre-existing `-L`
  asymmetry.** Those two `find` calls omit `-L` while the ones at 143, 309 and
  361 include it, so a symlinked plugin directory is indexed for skills by leg
  4 but skipped entirely by legs 1-3 — the exact "a symlink silently skipped
  is a file nobody checked" reasoning the script's own comment gives for using
  `-L`. **Deferred because** adding it widens leg 1's and leg 2's discovery
  set, which is a trigger-set change, and §9f forbids widening a trigger set
  alongside other changes without a dedicated re-run. Its own change (review
  round 1, finding #16, confidence 60).

- [ ] P3 — `docs/plans/` plan shape — **no structural check that a PR's
  `Closes:` claim actually landed as `status:`/`applied_in:`.** U5's stated
  tests checked counter arithmetic and struck checkboxes; neither would catch
  `status:` staying `deferred`. This run hit exactly that: the first pass
  added `applied_in:` lines to findings #11 and #12 without flipping their
  `status:` lines, and only the counter-vs-actual cross-check caught it —
  the same defect PR #27 shipped and `todos/review-2026-07-30-075218.md`
  finding #1 documents. The plan shape still has no backstop (plan-review
  finding #10, confidence 50).

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
  10. wrong owner split across a line break → **0 MISS today** (recorded
      limit, §9f); the two live instances were reflowed instead
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
- Counts rule not triggered: no file added, removed, or renamed under
  `plugins/cepa/commands/`, `agents/`, or `skills/`. The moved script is under
  `plugins/cepa/scripts/`, which no count claim covers.
- Both manifests bumped to 1.16.0 in the same commit.

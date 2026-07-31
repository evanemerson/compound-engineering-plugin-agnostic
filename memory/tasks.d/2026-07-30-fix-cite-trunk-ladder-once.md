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
  expansion (`§9c-9d`), `.github`/`scripts` roots with `--include='*.yml'`,
  and a zero-citation guard. Four negative controls observed failing before
  revert.
- The checker moved to `scripts/check-model-pins.sh`; all three live readers
  updated in the same commit. No stub at the old path — deliberate, reasoned
  in the commit body.

### Checked and clean

- **The six `cepa:autonomy` §7 relay-point clauses are untouched.** Verified
  2026-07-30 against the run's own diff (`git diff` touches none of the ten
  files carrying them) and against leg-4 output, which mentions `§7` zero
  times. This is a dated observation, not a standing exemption — re-verify if
  leg 4's citation pattern ever gains bare-`§N` coverage, which is exactly
  what the first deferred item above proposes.
- Counts rule not triggered: no file added, removed, or renamed under
  `plugins/cepa/commands/`, `agents/`, or `skills/`. The moved script is under
  `plugins/cepa/scripts/`, which no count claim covers.
- Both manifests bumped to 1.16.0 in the same commit.

#!/usr/bin/env bash
# Controls for scripts/check-residual-integrity.sh — proves the checker still
# responds the way its record says it does. Read-only with respect to this
# repository: every case is planted into a throwaway fixture, never into the
# working tree.
#
# WHY THIS EXISTS, and it is not hypothetical for this checker. Its FIRST run
# reported 21 MISS over a tree with 2 real defects: the tally grepped `status:`
# file-wide, so the frontmatter provider blocks (`status: available`,
# `status: unavailable`, `status: fresh`) each counted as an extra finding.
# Every message read "body carries N+1, total says N" — plausible, uniform, and
# wrong. That is this checker's own subject matter one level down: a tally that
# fires on the wrong rows reads exactly like one that fires on the right rows.
# Case `fm` exists solely to keep that defect dead.
#
# WHY A SYNTHETIC FIXTURE, unlike the model-pin controls which copy the tree.
# That suite's baseline gate demands 0 MISS / 0 WARN, and this checker's
# baseline over the live tree is NOT clean (2 MISS of real counter drift, 2 WARN
# of legitimate no-checkbox prose). Copying the tree would make the baseline
# dirty by construction, and the standard fix — waive the known findings —
# builds a suite that passes because it was told to ignore what it found. So the
# fixture is a minimal hand-built tree that is genuinely clean, and every case
# is a delta from it.
#
# THE COST, recorded rather than left implicit: a synthetic fixture exercises
# the shapes it was built with, not the shapes the repo actually contains. The
# model-pin suite gets real-tree coverage for free; this one does not, and a
# residual file shape nobody thought to plant here is unexercised. The `real`
# case below is the partial mitigation — it runs the checker over the ACTUAL
# tree and asserts the findings are exactly the known set, so a change in what
# the live tree produces fails this suite instead of passing silently.
#
# HOW A CASE EARNS ITS PLACE: `cepa:autonomy` §9f. The `why` field of every
# `reg` names the mutant that case kills, and is printed on failure.
#
# Usage:
#   bash scripts/check-residual-integrity-controls.sh              # run all
#   bash scripts/check-residual-integrity-controls.sh --list       # ids/titles
#   bash scripts/check-residual-integrity-controls.sh --only sum,fm
#   bash scripts/check-residual-integrity-controls.sh --keep       # keep fixtures
set -u
# The fixture builder is a pipeline whose failure mode is a silently truncated
# tree, and a tree missing files is CLEANER, not dirtier — so a truncation
# passes the baseline gate. `pipefail` is load-bearing, not hygiene.
set -o pipefail

KEEP=0
ONLY=''
LIST_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1 ;;
    --list) LIST_ONLY=1 ;;
    # A bare trailing `--only` must not shift past the end, leave ONLY empty,
    # and silently run all cases — an argument error that WIDENS the run.
    --only) shift; [ $# -gt 0 ] || { printf -- '--only needs a value\n' >&2; exit 2; }; ONLY="$1" ;;
    --only=*) ONLY="${1#--only=}" ;;
    -h|--help) sed -n '1,40p' "$0"; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  printf 'FATAL: not inside a git work tree\n' >&2
  exit 2
}

# `CEPA_RESIDUAL_CHECKER` exists for MUTATION TESTING: point the suite at a
# deliberately broken copy and confirm the controls go red. A control suite that
# passes on a broken checker proves nothing. Resolved to an ABSOLUTE path
# immediately — a relative override resolves against two different directories
# depending on the call site, and the header would print the unresolved string,
# so an override could read as an ordinary run.
CHECKER=$(readlink -f "${CEPA_RESIDUAL_CHECKER:-$REPO_ROOT/scripts/check-residual-integrity.sh}" 2>/dev/null) || CHECKER=''
[ -n "$CHECKER" ] && [ -r "$CHECKER" ] || {
  printf 'FATAL: no readable checker at %s\n' "${CEPA_RESIDUAL_CHECKER:-$REPO_ROOT/scripts/check-residual-integrity.sh}" >&2
  exit 2
}
# CI must never set the override. Enforced, not merely asserted in a comment.
if [ -n "${CEPA_RESIDUAL_CHECKER:-}" ] && [ -n "${CI:-}" ]; then
  printf 'FATAL: CEPA_RESIDUAL_CHECKER is set in CI — the suite would validate a checker nobody reviewed\n' >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Case registry
# ---------------------------------------------------------------------------
# reg <id> <title> <expect_misses> <expect_warns> <expect_re> <forbid_re> <why>
#
# <why> names the mutant the case kills. It is PRINTED on failure — an editor
# who makes a control go red needs the reason at the failure site.
IDS=(); TITLES=(); EXP_MISS=(); EXP_WARN=(); EXP_RE=(); FORBID_RE=(); WHY=()
reg() {
  IDS+=("$1"); TITLES+=("$2"); EXP_MISS+=("$3"); EXP_WARN+=("$4")
  EXP_RE+=("$5"); FORBID_RE+=("$6"); WHY+=("$7")
}

# --- leg 1a: the sums -------------------------------------------------------
# NOTE ON COUNTS: one plant can trip several sub-invariants, and the expected
# number is the OBSERVED number, verified by reading the output — not a guess at
# which single leg "should" fire. A case whose count was hand-waved passes for
# the wrong reason and stops pinning anything.
# Dropping `applied` unbalances the state sum (1a) and puts `applied` at odds
# with the body (1b). Both fire, and both are correct.
reg sum   'state counters do not sum to total'      2 0 'state counters sum to' '' \
  'kills: removal of the 1a state-sum check'
# Moving all three severity counters unbalances the severity sum (1a) AND puts
# each of the three at odds with the body (1b): 1 + 3 = 4.
reg sev   'p1+p2+p3 do not sum to total'            4 0 'p1\+p2\+p3 sum to' '' \
  'kills: removal of the 1a severity-sum check'

# --- leg 1b: agreement with the body ----------------------------------------
# The DOCUMENTED failure: a balanced total over a wrong distribution. This
# shipped twice, was reported as "counters verified", and was caught only by a
# later review. Both cases below keep `total` correct on purpose — a suite that
# only ever unbalances the total cannot tell 1a from 1b, and 1a alone is the
# check the spec calls insufficient. Two MISS each: moving a count off one state
# makes BOTH states disagree with the body.
reg agree 'a state counter disagrees with the body' 2 0 'but the body carries' '' \
  'kills: removal of the 1b per-state agreement loop; total still balances'
reg dist  'balanced total, wrong severity split'    2 0 'a balanced total hides a wrong distribution' '' \
  'kills: removal of the 1b severity check — the exact defect that shipped twice'

# --- leg 1c: the gap EQUALITY ----------------------------------------------
# `gap <= skipped` is satisfied by `gap = 0, skipped = 0`, which is precisely
# the encoding the spec rejects. `gapne` is what makes the equality load-bearing.
#
# `gapeq` PINS A RECORDED LIMIT, not correct behavior — read the checker's
# "STATED LIMIT — leg 1c cannot detect the rejected encoding ON A SINGLE FILE"
# before "fixing" it. A file whose total was shrunk AND whose counters were
# shrunk consistently is byte-identical to a file that only ever had that many
# findings; the removal left no trace in any parsed field. It expects ZERO
# misses because that is what the checker can see, and it exists so that a
# future revision claiming to close this limit has to change this case
# deliberately rather than discover the gap in production.
reg gapeq 'the rejected encoding is INVISIBLE on one file (recorded limit)' 0 0 '' '^MISS ' \
  'pins the stated 1c limit: a consistently-shrunk total leaves no trace to find'
# The inconsistent middle IS catchable, and this is what 1c actually enforces:
# a body that lost a finding while total held. Three MISS — the sums go too.
reg gapne 'a removal the counters do not account for'  3 0 'must EQUAL the removals' '' \
  'kills: removal of the 1c gap check entirely'
# A file with only RETAINED skips (the /cepa:resolve-pr verdict edge) has NO
# gap. The two kinds of skip behave differently and the checker must not assume
# one: a naive `gap == skipped` that ignores retention fires here.
reg retain 'retained skips are in the body, so no gap' 0 0 '' '^MISS ' \
  'kills: a 1c that counts retained skips as removals — false-positives every resolve-pr file'

# --- the non-tallyable shapes ----------------------------------------------
# Miscounting these is not hypothetical: a scan called twelve files bad when six
# were, by treating batch suffixes as drift; a later pass then shrank a CORRECT
# file's total from 30 to 26 on an invisible heading range. Both cases expect
# ZERO misses — they are false-positive guards, and they are what kill the
# "count it anyway" mutants no positive case can reach.
reg batch 'a severity batch suffix is not drift'    0 0 'not tallyable per line' '^MISS ' \
  'kills: treating `severity: P2/P3 (batch)` as a disagreement'
reg range 'a heading range is not drift'            0 0 'not tallyable per line' '^MISS ' \
  'kills: treating `### 21-25` as missing findings — shrank a correct total 30->26'
# The exemption must be a FIELD. A grandfather clause that lives only in prose
# beside the file is unreadable to every consumer, which is the defect the spec
# exists to prevent.
reg convn 'counter_convention: exempts the file'    0 0 'carries counter_convention' '^MISS ' \
  'kills: skipping on a FILENAME instead of the field, or dropping the exemption'

# --- the pattern-did-not-fire guards ---------------------------------------
# A zero tally on a file that HAS findings is a broken pattern, not a clean
# file. Without this, every mutant that narrows the tally regex reports success.
reg zero  'headings present, zero status rows matched' 1 0 'the tally pattern did not fire' '' \
  'kills: a narrowed status: tally — a zero count would otherwise read as clean'
# Both field formats are live in this repo. A pattern anchored to one returns
# zero rows on the other, SILENTLY.
reg bare  'bare `status:` with no leading dash tallies' 0 0 '' '^MISS ' \
  'kills: anchoring the tally to `- status:` and missing every bare-format file'
# THE FIRST-RUN DEFECT. Frontmatter carries status: fields that are not finding
# statuses. This case is why the tally is body-scoped.
reg fm    'frontmatter status: fields are not findings' 0 0 '' '^MISS ' \
  'kills: the first-run file-wide grep that read `status: available` as a finding (21 false MISS)'

# --- legs 2-4: prose vs checkbox -------------------------------------------
reg leg2  'struck-through text under an open box'   0 1 'struck through' '' \
  'kills: removal of leg 2'
reg leg3  'open box carrying closure vocabulary'    0 1 'closure vocabulary' '' \
  'kills: removal of leg 3'
reg leg4  'a P-bullet with no checkbox'             0 1 'no checkbox' '' \
  'kills: removal of leg 4'
# Legs 2-4 are WARN in this cut. If one is promoted to MISS the promotion must
# be deliberate, so this case pins the CURRENT contract: a prose finding alone
# must leave the exit code at 0. Promoting a leg without updating this case
# fails the suite, which is the point.
reg warnrc 'prose legs do not fail the run'         0 3 'WARN-ONLY' '' \
  'kills: silently promoting a prose leg to MISS — legs 2-4 are WARN by design'

# --- the traversal guard ---------------------------------------------------
# A `find` that could not complete is never a pass. The sibling checker turned a
# real MISS into `0 MISS, 0 WARN` this exact way.
reg trav  'an unreadable scan root is not a pass'   1 0 'traversal that could not complete' '' \
  'kills: dropping the traverse() stderr/exit predicate — a truncated walk reads as clean'

# --- the empty-tree guard --------------------------------------------------
# Measured before the guard existed: an empty tree passed `0 MISS, 0 WARN` and
# exited 0. That is the most reassuring possible output from a run that checked
# nothing, and the likeliest real cause is a wrong working directory.
reg empty 'a run that found no input is not a pass' 1 0 'a scan over nothing is not a pass' '' \
  'kills: removal of the empty-tree guard — a misdirected run reports success'

# --- the live tree ---------------------------------------------------------
# The synthetic fixture cannot see shapes nobody planted. This case runs the
# checker over the REAL tree and pins the findings to the known set, so a change
# in what the live tree produces fails here instead of passing silently. It is
# NOT a clean-run assertion: the tree has 2 real MISS and 2 legitimate WARN
# today, and pretending otherwise is what a waiver would do.
reg real  'live tree matches the recorded finding set' 2 2 'a balanced total hides a wrong distribution' '' \
  'kills: a checker that silently stops finding the known live drift'

if [ "$LIST_ONLY" -eq 1 ]; then
  i=0
  while [ $i -lt ${#IDS[@]} ]; do
    printf '%-8s %s\n' "${IDS[$i]}" "${TITLES[$i]}"
    i=$((i + 1))
  done
  exit 0
fi

# ---------------------------------------------------------------------------
# Fixture
# ---------------------------------------------------------------------------
TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/cepa-residual-controls.XXXXXX") || exit 2
cleanup() { [ "$KEEP" -eq 1 ] || rm -rf "$TMPROOT"; }
trap cleanup EXIT

# A minimal CLEAN tree: one findings file that satisfies every sub-invariant,
# and one shard with no prose defect. Every case is a delta from this.
build_pristine() {  # build_pristine <dir>
  local d="$1"
  mkdir -p "$d/todos" "$d/memory/tasks.d" || return 1
  cat > "$d/todos/review-2026-01-01-000000.md" <<'EOF'
---
date: 2026-01-01T00:00:00
scope: fixture
grounding:
  status: available
brain:
  status: fresh
summary:
  total: 3
  p1: 1
  p2: 1
  p3: 1
  pending: 0
  ready: 0
  skipped: 0
  applied: 3
  deferred: 0
  completed: 0
---

# Fixture findings

### 1
- severity: P1
- status: applied

Body text.

### 2
- severity: P2
- status: applied

Body text.

### 3
- severity: P3
- status: applied

Body text.
EOF
  cat > "$d/memory/tasks.d/2026-01-01-fixture.md" <<'EOF'
# Residuals — fixture

- [ ] P2 — an ordinary open item with no closure claim.
- [x] ~~P3 — an ordinary closed item.~~ DONE 2026-01-01.
EOF
  return 0
}

PRISTINE="$TMPROOT/pristine"
build_pristine "$PRISTINE" || { printf 'FATAL: could not build the pristine fixture\n' >&2; exit 2; }

FIX_TODOS='todos/review-2026-01-01-000000.md'
FIX_SHARD='memory/tasks.d/2026-01-01-fixture.md'

# A plant that silently no-ops is how a zero-MISS case re-asserts the baseline
# and prints PASS forever. Every sed below is followed by an assertion that the
# tree actually changed.
plant() {  # plant <id> <dir>
  local id="$1" d="$2" f="$2/$FIX_TODOS" s="$2/$FIX_SHARD"
  case "$id" in
    sum)   sed -i 's/^  applied: 3$/  applied: 2/' "$f" ;;
    sev)   sed -i 's/^  p2: 1$/  p2: 2/; s/^  p3: 1$/  p3: 0/; s/^  p1: 1$/  p1: 2/' "$f" ;;
    # total stays 3 and the sums stay balanced — only the DISTRIBUTION moves,
    # so 1a passes and only 1b can catch it.
    agree) sed -i 's/^  applied: 3$/  applied: 2/; s/^  deferred: 0$/  deferred: 1/' "$f" ;;
    dist)  sed -i 's/^  p2: 1$/  p2: 2/; s/^  p3: 1$/  p3: 0/' "$f"
           sed -i 's/^  p1: 1$/  p1: 1/' "$f" ;;
    gapeq) # The REJECTED encoding, applied CONSISTENTLY: body loses a finding,
           # total shrinks to match, every counter follows, skipped stays 0.
           # The result is byte-identical to a file that only ever had two
           # findings — which is why no single-file check can see it.
           sed -i '/^### 3$/,/^Body text.$/d' "$f"
           sed -i 's/^  total: 3$/  total: 2/; s/^  p3: 1$/  p3: 0/; s/^  applied: 3$/  applied: 2/' "$f" ;;
    gapne) # Body loses a finding, total holds, but skipped does not account.
           sed -i '/^### 3$/,/^Body text.$/d' "$f"
           sed -i 's/^  applied: 3$/  applied: 2/; s/^  p3: 1$/  p3: 0/' "$f" ;;
    retain) # A RETAINED skip: still in the body, so there is no gap.
           sed -i 's/^### 3$/### 3/' "$f"
           sed -i '0,/^- status: applied$/!{0,/^- status: applied$/!s/^- status: applied$/- status: skipped/;}' "$f"
           sed -i 's/^  applied: 3$/  applied: 2/; s/^  skipped: 0$/  skipped: 1/' "$f" ;;
    batch) sed -i 's/^- severity: P2$/- severity: P2\/P3 (batch)/' "$f" ;;
    range) sed -i 's/^### 3$/### 3-4/' "$f" ;;
    convn) # The exempt file carries counters that would MISS loudly without the
           # exemption. A second, ordinary file is left in place so the
           # "verified nothing" guard still has something to verify — otherwise
           # this case cannot distinguish "the exemption worked" from "the whole
           # leg went quiet", which is the shape that guard exists to catch.
           cp "$f" "$d/todos/review-2026-01-02-000000.md"
           sed -i 's/^date: /counter_convention: legacy-total-shrink\ndate: /' "$f"
           sed -i 's/^  total: 3$/  total: 99/' "$f" ;;
    zero)  # Headings remain; every status row is renamed so the tally cannot
           # fire. A zero count must not read as a clean file.
           sed -i 's/^- status: applied$/- state: applied/' "$f" ;;
    bare)  sed -i 's/^- status: applied$/status: applied/; s/^- severity: /severity: /' "$f" ;;
    fm)    # MORE frontmatter provider fields. A file-wide tally counts each as
           # a finding; a body-scoped one ignores them.
           sed -i 's/^  status: fresh$/  status: fresh\nextra:\n  status: unavailable\nmore:\n  status: available/' "$f" ;;
    leg2)  printf -- '- [ ] ~~P3 — struck through but the box is open.~~\n' >> "$s" ;;
    leg3)  printf -- '- [ ] P3 — this was RESOLVED last week.\n' >> "$s" ;;
    leg4)  printf -- '- **P1 — a finding bullet with no checkbox.**\n' >> "$s" ;;
    warnrc) printf -- '- [ ] ~~P3 — struck.~~\n- [ ] P3 — this is DONE.\n- **P2 — no box.**\n' >> "$s" ;;
    trav)  chmod 000 "$d/todos" ;;
    empty) rm -f "$d/$FIX_TODOS" "$d/$FIX_SHARD" ;;
    real)  : ;;  # no plant — this case runs against the real tree
    *) printf 'FATAL: no plant for case %s\n' "$id" >&2; return 1 ;;
  esac
  return 0
}

# Post-plant assertion: the tree MUST differ from pristine (except `real`,
# which deliberately does not plant). A sed that matched nothing exits 0.
assert_planted() {  # assert_planted <id> <dir>
  [ "$1" = real ] && return 0
  if [ "$1" = trav ]; then
    [ -r "$2/todos" ] && { printf 'plant did not take effect (dir still readable)\n'; return 1; }
    return 0
  fi
  if diff -rq "$PRISTINE" "$2" >/dev/null 2>&1; then
    printf 'plant was a no-op — the fixture is identical to pristine\n'
    return 1
  fi
  return 0
}

CHK_OUT=''; CHK_MISS=''; CHK_WARN=''; CHK_RC=0
run_checker() {  # run_checker <dir>
  local d="$1" verdict
  CHK_OUT=$(cd "$d" && bash "$CHECKER" 2>&1); CHK_RC=$?
  verdict=$(printf '%s\n' "$CHK_OUT" | grep -E '^-- [0-9]+ MISS, [0-9]+ WARN --' | tail -1)
  [ -n "$verdict" ] || { CHK_MISS=''; CHK_WARN=''; return 1; }
  CHK_MISS=$(printf '%s' "$verdict" | sed -E 's/^-- ([0-9]+) MISS.*/\1/')
  CHK_WARN=$(printf '%s' "$verdict" | sed -E 's/.*, ([0-9]+) WARN --$/\1/')
  return 0
}

count_ok() {  # count_ok <actual> <expected>
  case "$2" in
    '+') [ "$1" -gt 0 ] ;;
    *)   [ "$1" -eq "$2" ] ;;
  esac
}

# The exit code is the ENTIRE mechanism by which CI fails. Asserting only counts
# and messages leaves it untested: in the sibling suite, mutating the final
# `exit 1` to `exit 0` passed 26/26. Here legs 2-4 are WARN and must NOT change
# the exit code, so the expectation keys on misses alone.
expected_rc() {  # expected_rc <expect_misses>
  if [ "$1" = 0 ]; then printf 0; else printf 1; fi
}

# ---------------------------------------------------------------------------
# Baseline gate
# ---------------------------------------------------------------------------
printf '== control suite for %s ==\n' "$CHECKER"
if ! run_checker "$PRISTINE" || [ "$CHK_MISS" != 0 ] || [ "$CHK_WARN" != 0 ] || [ "$CHK_RC" -ne 0 ]; then
  printf 'BASELINE-ABORT dirty\n'
  printf 'FATAL: baseline is not clean — every case expectation is a delta from it,\n'
  printf '       so a dirty baseline makes the whole suite meaningless.\n'
  printf '       got: %s MISS, %s WARN, exit %s\n\n' "${CHK_MISS:-?}" "${CHK_WARN:-?}" "$CHK_RC"
  printf '%s\n' "$CHK_OUT"
  exit 1
fi
# A clean run over NOTHING is not a clean run. The checker's INFO lines are its
# own coverage accounting, and a zero in either means it scanned nothing and
# said so politely.
baseline_bad=''
printf '%s\n' "$CHK_OUT" | grep -qE 'summary blocks checked: [1-9]' || baseline_bad="${baseline_bad}summary-blocks "
printf '%s\n' "$CHK_OUT" | grep -qE 'shard prose scanned: [1-9]'    || baseline_bad="${baseline_bad}shard-prose "
if [ -n "$baseline_bad" ]; then
  printf 'BASELINE-ABORT zero-coverage\n'
  printf 'FATAL: baseline reports zero coverage in: %s\n' "$baseline_bad"
  printf '       A clean run over nothing is not a clean run.\n\n'
  printf '%s\n' "$CHK_OUT"
  exit 1
fi
printf 'baseline: 0 MISS, 0 WARN, exit 0; coverage counters non-zero\n\n'

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
passed=0; failed=0; ran=0
FAILED_IDS=''

selected() {
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; esac
  return 1
}

fail_case() {  # fail_case <index> <reason>
  local i="$1"
  printf 'FAIL  %-8s %s\n' "${IDS[$i]}" "${TITLES[$i]}"
  printf '        %s\n' "$2"
  printf '        why this case exists: %s\n' "${WHY[$i]}"
  printf '        --- checker output ---\n'
  printf '%s\n' "$CHK_OUT" | sed 's/^/        | /'
  failed=$((failed + 1))
  FAILED_IDS="${FAILED_IDS}${IDS[$i]} "
}

i=0
while [ $i -lt ${#IDS[@]} ]; do
  id="${IDS[$i]}"
  selected "$id" || { i=$((i + 1)); continue; }
  ran=$((ran + 1))

  if [ "$id" = real ]; then
    workdir="$REPO_ROOT"
  else
    workdir="$TMPROOT/case-$id"
    if ! build_pristine "$workdir"; then
      fail_case "$i" 'could not build the fixture'; i=$((i + 1)); continue
    fi
    if ! plant "$id" "$workdir"; then
      fail_case "$i" 'plant failed'; i=$((i + 1)); continue
    fi
    if ! msg=$(assert_planted "$id" "$workdir"); then
      CHK_OUT=''; fail_case "$i" "$msg"; i=$((i + 1)); continue
    fi
  fi

  run_checker "$workdir" || { fail_case "$i" 'checker printed no verdict line'; \
    [ "$id" = trav ] && chmod 755 "$workdir/todos" 2>/dev/null; i=$((i + 1)); continue; }
  [ "$id" = trav ] && chmod 755 "$workdir/todos" 2>/dev/null

  if ! count_ok "$CHK_MISS" "${EXP_MISS[$i]}"; then
    fail_case "$i" "expected ${EXP_MISS[$i]} MISS, got ${CHK_MISS}"; i=$((i + 1)); continue
  fi
  if ! count_ok "$CHK_WARN" "${EXP_WARN[$i]}"; then
    fail_case "$i" "expected ${EXP_WARN[$i]} WARN, got ${CHK_WARN}"; i=$((i + 1)); continue
  fi
  exp_rc=$(expected_rc "${EXP_MISS[$i]}")
  if [ "$CHK_RC" -ne "$exp_rc" ]; then
    fail_case "$i" "expected exit ${exp_rc}, got ${CHK_RC} — the exit code is how CI fails"
    i=$((i + 1)); continue
  fi
  if [ -n "${EXP_RE[$i]}" ] && ! printf '%s\n' "$CHK_OUT" | grep -qE "${EXP_RE[$i]}"; then
    fail_case "$i" "output did not match /${EXP_RE[$i]}/"; i=$((i + 1)); continue
  fi
  if [ -n "${FORBID_RE[$i]}" ] && printf '%s\n' "$CHK_OUT" | grep -qE "${FORBID_RE[$i]}"; then
    fail_case "$i" "output matched forbidden /${FORBID_RE[$i]}/"; i=$((i + 1)); continue
  fi

  printf 'PASS  %-8s %s\n' "$id" "${TITLES[$i]}"
  passed=$((passed + 1))
  i=$((i + 1))
done

printf '\n-- %s run, %s passed, %s failed --\n' "$ran" "$passed" "$failed"
if [ "$failed" -gt 0 ]; then
  printf 'FAILED: %s\n' "$FAILED_IDS"
  exit 1
fi
exit 0

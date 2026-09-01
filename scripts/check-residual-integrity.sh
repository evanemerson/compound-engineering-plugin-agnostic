#!/usr/bin/env bash
# cepa residual-integrity check — read-only. Verifies that a findings file's
# PARSED frontmatter agrees with its own body, and that a residual shard's
# checkbox agrees with its own prose. Run from the repo root. Never modifies
# anything.
#
# The class: `a-closure-claim-in-prose-is-not-the-field-a-consumer-parses`
# (docs/solutions/logic-errors/, gitignored — the tracked halves are
# memory/tasks.d/2026-08-06-chore-reconcile-residual-sink.md and CONCEPTS.md).
# Eight occurrences before it had a name, every one found by a human reading
# prose and noticing it disagreed with a field. That does not scale, and in the
# two measured cases it did not happen for seven days and three PRs.
# /cepa:sweep and /cepa:triage read the FIELD. Prose that says "closed" over a
# field that says open is a unit of attention spent re-deriving nothing is wrong.
#
#   Leg 1: the `summary:` block of a findings file agrees with its body —
#   three sub-invariants, because checking only the first is the DOCUMENTED
#   failure (it shipped twice, was reported as "counters verified", and was
#   caught only by a later review):
#     1a sum      — state counters sum to total; p1+p2+p3 sums to total
#     1b agree    — each counter equals its body count (+ human-triage removals)
#     1c gap      — total − (findings in body) EQUALS the removals skipped holds
#   Leg 2: a struck-through residual item (~~...~~) whose checkbox is open.
#   Leg 3: an open checkbox whose text carries closure vocabulary (DONE,
#   CLOSED, RESOLVED, ...).
#   Leg 4: a `- **P[123]` finding bullet carrying no checkbox at all — an item
#   no consumer can see the state of.
#
# WHY 1c IS AN EQUALITY AND NOT A BOUND. `gap <= skipped` is satisfied by
# `gap = 0, skipped = 0`, which is precisely the encoding the spec rejects: a
# file can shrink `total` to absorb any number of removals and pass clean. A
# check that cannot fail on the state it exists to catch is not a check. The
# spec mandates ONE encoding — total is fixed at write time and NEVER shrunk;
# a human-triage removal increments `skipped` and leaves `total` alone.
#
# WHY THE PROSE LEGS ARE WARN AND LEG 1 IS MISS. Legs 2-4 read prose written by
# people, where the fix for a false positive is to mangle correct writing —
# worse than no check. Leg 4 has 2 legitimate hits in this repo today (the
# evidence block the 2026-08-06 reconciliation deliberately created), so it
# would MISS on a correct tree on day one. Leg 1 is a pure arithmetic invariant
# the spec already states, over a machine-written block, so it is MISS-able
# immediately. Promote legs 2-4 INDIVIDUALLY after a clean burn-in, never as a
# batch — they have independent false-positive profiles and a batch promotion
# is how the first one's clean run vouches for the other two.
#
# NOT BUILT, and recorded so its absence cannot read as a pass: the fifth
# designed leg — a supersession blockquote whose scope covers following open
# boxes. It needs a small state machine rather than the one-liner these four
# are, and it had zero hits at design time and zero today, so it buys nothing
# yet. Its absence means a shard can carry "SUPERSEDED" as a block header over
# items this script still reports as open.
#
# STATED LIMIT — leg 1 verifies p1/p2/p3 only on files with NO removals. Once a
# file has had one, `skipped` is a single scalar with no severity breakdown, so
# the removed finding's severity is unrecoverable and the severity counters
# cannot be re-derived from the body. The spec records this hole rather than
# papering over it; closing it needs a per-severity removal field no consumer
# has asked for. Such files are reported INFO, not silently passed.
#
# FOR WHOEVER WIRES THE NEXT CONSUMER — this script's output is written for a
# human or a CI log. Its MISS/WARN messages interpolate repo-tracked file paths
# and line numbers (never file prose, deliberately), so nothing here is an
# autonomy §7 relay point TODAY: verified at the time of writing that no
# workflow, command, skill, or agent reads this script's stdout. The moment one
# does — a sweep summarizer, a CI-annotation-to-agent bridge — that consumer
# becomes a relay point and owes a §7 untrusted-data clause AT THE RELAY SITE,
# per CLAUDE.md. Recorded here because PR #9's Detection relay shipped as an
# injection channel precisely by being wired up without anyone re-asking the
# question at the new site.
#
# STATED LIMIT — leg 1c cannot detect the rejected encoding ON A SINGLE FILE,
# and this is the most important limit here because 1c is the leg written to
# catch it. A file whose `total` was shrunk to absorb a removal is BYTE-
# IDENTICAL to a file that only ever had that many findings: the removal left no
# trace in any field, which is the spec's own argument for mandating the other
# encoding. What 1c actually catches is the INCONSISTENT middle — a body that
# lost a finding while `total` held, or a `skipped` that does not account for
# the gap. A writer who shrinks `total` AND every counter consistently produces
# a clean file, and only its git history shows the removal.
#
# Closing it needs a diff against the file's own prior revision, which is a
# different tool with a different failure mode (a file legitimately rewritten
# between reviews is indistinguishable from one edited to hide a removal). Not
# built. Recorded here so 1c's PASS cannot be read as "no removal was hidden".
#
# STATED LIMIT — this checks internal agreement, never truth. A file whose
# body and counters agree can still describe work that never happened, and a
# cross-repo shard item can be perfectly consistent and three days stale (see
# memory/tasks.d/2026-09-01-main.md). Agreement is the invariant that IS
# machine-checkable; freshness is not, and pretending otherwise here would be
# the same wrong-invariant substitution that shard records.
set -u

ok()   { printf 'OK   %s\n' "$1"; }
miss() { printf 'MISS %s\n' "$1"; }
warn() { printf 'WARN %s\n' "$1"; }
info() { printf 'INFO %s\n' "$1"; }

# Diagnostics in a stable language. The traversal rule below keys on stderr
# being NON-EMPTY, not on its wording, so detection does not depend on this.
export LC_ALL=C

# --- traversal ---------------------------------------------------------------
# Lifted deliberately from check-model-pins.sh, and NOT reimplemented: `find`
# in a process substitution throws away both the exit status and stderr, so a
# partial walk returns a TRUNCATED but non-empty list and every caller reports
# full coverage over it. That regression turned a real MISS into
# `0 MISS, 0 WARN — 5 of 5 roots` in the sibling checker. Copying the shape of
# the legs while skipping this helper is exactly how it happened.
#
# A traversal that could not complete is never a pass. Non-empty stderr is the
# predicate — strictly stronger than matching diagnostic text, and it covers
# permission errors, symlink cycles, and anything find learns to complain about.
#
# INHERITED STATED LIMIT — this helper's two-part predicate (non-zero exit OR
# non-empty stderr) has neither half individually pinned by any control, HERE OR
# IN THE SIBLING, and cannot be: every failure a fixture can stage sets both, so
# a control that removes either half still passes. Documented at
# check-model-pins.sh:87-95 with the full measurement; cited rather than
# restated, and named here because a reader of only this file would otherwise
# have no way to know the gap exists. `each-fix-reintroduced-the-defect-class-
# one-layer-down` is explicit that copying a shape obliges enumerating what it
# does NOT do — this is that enumeration.
#
# NOT copied from the sibling, deliberately: its `dedup_resolved()` helper
# exists because it discovers directories with `find` (plugins/*/agents), where
# a symlink double-counts and inflates a coverage INFO line. This script's scan
# roots are two fixed strings, so there is nothing to dedup. Recorded so the
# omission reads as a decision rather than an oversight.
TRAVERSE_FILES=()
TRAVERSE_ERR=''
traverse() {  # traverse <find args...> -> TRAVERSE_FILES[]; 1 and TRAVERSE_ERR on failure
  local _out _err _rc _f
  TRAVERSE_FILES=()
  TRAVERSE_ERR=''
  _out=$(mktemp) || { TRAVERSE_ERR='could not create a temp file'; return 1; }
  _err=$(mktemp) || { rm -f "$_out"; TRAVERSE_ERR='could not create a temp file'; return 1; }
  find "$@" -print0 >"$_out" 2>"$_err"
  _rc=$?
  if [ "$_rc" -ne 0 ] || [ -s "$_err" ]; then
    TRAVERSE_ERR="find exit ${_rc}: $(head -1 "$_err")"
    rm -f "$_out" "$_err"
    return 1
  fi
  while IFS= read -r -d '' _f; do TRAVERSE_FILES+=("$_f"); done < "$_out"
  rm -f "$_out" "$_err"
  return 0
}

misses=0
warns=0

# Scope: the TRACKED half only. docs/ is gitignored by convention in this repo,
# so a plan or solution doc is unreadable from a fresh clone and cannot be an
# input to a check anyone else can reproduce.
TODOS_DIR=${RESIDUAL_TODOS_DIR:-todos}
SHARDS_DIR=${RESIDUAL_SHARDS_DIR:-memory/tasks.d}

# The states the spec's lifecycle defines. Declared ONCE and consumed by every
# site: the sibling checker shipped a widening that landed at three sites out
# of four, which made a file readable by one leg and invisible to the others.
#
# THIS LIST MUST TRACK `plugins/cepa/skills/file-todos/SKILL.md`'s `status`
# field enum (its frontmatter field table, ~line 94, and the Status Lifecycle
# block below it). Unlike the autonomy skill, file-todos has no `### N<letter>.`
# anchors, so check-model-pins.sh leg 4 has nothing to resolve here and NO
# machine link forces this array to follow a spec edit. A seventh lifecycle
# state added there would silently go uncounted here — the counter for it would
# read 0 against a body that has one. The internal-duplication defence above
# does not cover that; this note is the only thing that does, so grep for this
# comment when editing the enum.
STATES='pending ready skipped applied deferred completed'

# ---------------------------------------------------------------------------
# Non-tallyable shapes. All three are REPORTED, never counted as disagreement.
# Miscounting these is not hypothetical: a scan of this repo called twelve
# files bad when six were, by treating batch suffixes as drift; a later pass
# then shrank a CORRECT file's total from 30 to 26 and declared four findings
# unrecoverable, because a heading-range block was invisible to a per-line
# tally. They were never lost.
#
#   - severity suffix naming a range or batch: `severity: P2/P3 (batch)`
#   - heading range: `### 21-25`, one severity/status pair covering several
#   - persona-merged entries (pre-2026-07-18 plan reviews)
#
# A file whose counters follow a superseded convention carries
# `counter_convention:` in frontmatter. This skips on THAT FIELD, never on a
# filename — a grandfather clause that lives only in prose beside the file is
# unreadable to every consumer, which is the defect the spec exists to prevent.
BATCH_RE='^-?[[:space:]]*severity:[[:space:]]*P[123](/P[123])*[[:space:]]*\(batch\)'
RANGE_RE='^###[[:space:]]+[0-9]+[[:space:]]*-[[:space:]]*[0-9]+'

# --- leg 1: summary block agrees with the body -------------------------------
leg1_files=0
leg1_skipped=0
leg1_partial=0
leg1_unreadable=0
leg1_nototal=0

if ! traverse -L "$TODOS_DIR" -type f -name 'review-*.md'; then
  miss "residual: could not walk ${TODOS_DIR} (${TRAVERSE_ERR}) — a traversal that could not complete is not a pass"
  misses=$((misses + 1))
  TRAVERSE_FILES=()
fi
leg1_list=("${TRAVERSE_FILES[@]+"${TRAVERSE_FILES[@]}"}")

for f in "${leg1_list[@]+"${leg1_list[@]}"}"; do
  # A file named review-*.md with no `summary:` block is NOT "not a findings
  # file" — it is a findings file whose summary is missing or misspelled, and
  # skipping it silently is the defect this whole script exists to prevent.
  #
  # The aggregate "checked nothing" guard below cannot cover this: it fires
  # only when EVERY file falls through, so one well-formed sibling — which
  # every real run has — disarms it permanently. Measured: a two-file fixture
  # with one clean file and one whose `total:` was typo'd to `grand_total:`
  # (declaring p1:5/completed:5 over a body of one applied P1) reported
  # `0 MISS, 0 WARN`, exit 0. An ordinary typo, not an adversarial input.
  # grep's exit 2 (unreadable, deleted mid-scan, permission change) must NOT
  # be folded into exit 1 (no match) — `||` cannot tell them apart, and a file
  # that vanished between the walk and the read would otherwise be reported as
  # a file that merely lacks a summary block. traverse() proves the WALK
  # completed; it says nothing about whether each file was still readable when
  # its turn came. A concurrent /cepa:triage or a branch switch mid-scan is the
  # ordinary way to produce this.
  grep -qE '^summary:' "$f"
  case $? in
    0) : ;;
    1) miss "residual: ${f} has no 'summary:' block — a findings file with no parsed summary is unverifiable, not clean"
       misses=$((misses + 1)); leg1_unreadable=$((leg1_unreadable + 1)); continue ;;
    *) miss "residual: ${f} could not be read (grep exit 2) — a file that disappeared or became unreadable mid-scan is not a clean file"
       misses=$((misses + 1)); leg1_unreadable=$((leg1_unreadable + 1)); continue ;;
  esac

  # SCOPED TO FRONTMATTER, never file-wide. The spec says this field lives in
  # frontmatter; a file-wide grep lets any writer grant their own file a total
  # exemption by mentioning the field in prose or inside a documentation code
  # fence — and this repo's findings files routinely discuss their own format.
  # Measured on a drifted file: `counter_convention:` inside a ```yaml fence
  # took the whole file out of legs 1a/1b/1c and reported `0 MISS, 0 WARN`.
  # A self-service exemption granted by writing prose is exactly the
  # "unreadable to every consumer" defect the field exists to prevent.
  if printf '%s\n' "$(awk 'NR==1 && /^---[[:space:]]*$/ {infm=1; next} infm && /^---[[:space:]]*$/ {exit} infm' "$f")" |
     grep -qE '^counter_convention:'; then
    leg1_skipped=$((leg1_skipped + 1))
    info "residual: ${f} carries counter_convention: — counters follow a superseded convention and are not verifiable from the body"
    continue
  fi

  # The summary block: from `summary:` to the next line that is neither blank
  # nor indented. Scoped rather than grepped file-wide, so a `total:` in a
  # findings body cannot be read as a counter.
  block=$(awk '
    /^summary:/            { insum = 1; next }
    insum && /^[[:space:]]*$/ { next }
    insum && /^[[:space:]]/   { print; next }
    insum                  { exit }
  ' "$f")

  declared_total=$(printf '%s\n' "$block" | sed -nE 's/^[[:space:]]*total:[[:space:]]*([0-9]+).*/\1/p' | head -1)
  # Same class as the missing-`summary:` case above: a summary block that
  # parses but carries no `total:` is a misspelled or truncated block, and
  # every downstream sub-invariant is derived from `total`. Falling through
  # here means the file was counted as present and verified as nothing.
  if [ -z "$declared_total" ]; then
    miss "residual: ${f} has a 'summary:' block with no 'total:' field — every counter check derives from total, so nothing in this file was verified"
    misses=$((misses + 1))
    leg1_nototal=$((leg1_nototal + 1))
    continue
  fi

  # --- body tallies.
  #
  # TALLY THE BODY ONLY — everything after the closing `---`. Frontmatter has
  # `status:` fields of its own that are NOT finding statuses: the grounding
  # and brain provider blocks carry `status: available|unavailable|fresh`, and
  # a file-wide grep counts each as an extra finding. The first cut of this
  # script did exactly that and reported 21 MISS over a tree with 2 real
  # defects, every message reading "body carries N+1, total says N" — a
  # uniform off-by-one across twenty unrelated files, which is the signature of
  # a broken pattern, not twenty independent drifts. That is this checker's own
  # subject matter one level down: a tally that fires on the wrong rows reads
  # exactly like a tally that fires on the right ones.
  body=$(awk 'NR==1 && /^---[[:space:]]*$/ {infm=1; next} infm && /^---[[:space:]]*$/ {infm=0; body=1; next} body' "$f")

  # The extractor needs a SECOND `---` to ever enter the body state. Without
  # one, `$body` is empty — and an empty body agrees perfectly with a summary
  # declaring `total: 0` and every counter 0: no headings (so the tally-did-
  # not-fire guard cannot fire, it requires headings > 0), gap 0, removals 0,
  # every state counter 0 == 0. Measured: such a file reported `0 MISS,
  # 0 WARN`, exit 0, and was counted in "summary blocks checked". A truncated
  # save is the ordinary way to produce it.
  #
  # STRIP FENCED REGIONS. A ```yaml block quoting `- severity: P3` /
  # `- status: applied` supplies phantom rows the tally counts as a real
  # finding. Measured: deleting a finding from the body while leaving the
  # counters untouched, then adding a documentation fence containing its field
  # rows, produced `0 MISS, 0 WARN` — a finding vanished with every counter
  # agreeing. That is the "inconsistent middle" leg 1c claims to catch, and it
  # was invisible because the rows were counted from the wrong row set.
  body=$(printf '%s\n' "$body" | awk '/^[[:space:]]*```/ {fence = !fence; next} !fence')

  # Checked structurally rather than by testing `-z "$body"`: a findings file
  # legitimately CAN have an empty body (total: 0, no findings yet), and
  # conflating "no body" with "unparseable frontmatter" would MISS on that
  # correct file. The delimiter count distinguishes them.
  if [ "$(grep -cE '^---[[:space:]]*$' "$f")" -lt 2 ]; then
    miss "residual: ${f} frontmatter has no closing '---' — the body could not be extracted, so an empty body was compared against the counters instead of the real one"
    misses=$((misses + 1))
    leg1_nototal=$((leg1_nototal + 1))
    continue
  fi

  # THE LEADING `-` IS OPTIONAL AND THE PATTERN MUST TOLERATE BOTH. Two field
  # formats are live in this repo — `- severity: P1` and bare `severity: P1` —
  # and a pattern anchored to one returns ZERO ROWS on the other, SILENTLY. A
  # zero count is not a clean file; it is a pattern that did not fire.
  headings=$(printf '%s\n' "$body" | grep -cE '^###[[:space:]]+[0-9]' || true)
  body_status_rows=$(printf '%s\n' "$body" | grep -cE '^-?[[:space:]]*status:[[:space:]]*[a-z]+' || true)

  has_batch=$(printf '%s\n' "$body" | grep -cE "$BATCH_RE" || true)
  has_range=$(printf '%s\n' "$body" | grep -cE "$RANGE_RE" || true)

  if [ "$has_batch" -gt 0 ] || [ "$has_range" -gt 0 ]; then
    leg1_partial=$((leg1_partial + 1))
    info "residual: ${f} contains ${has_batch} batch-suffix and ${has_range} heading-range shape(s) — not tallyable per line; sum checked, body agreement not"
  fi

  leg1_files=$((leg1_files + 1))

  # 1a — the sums. Pure arithmetic over the declared block; always checkable,
  # even on a file whose body carries a non-tallyable shape.
  state_sum=0
  for s in $STATES; do
    v=$(printf '%s\n' "$block" | sed -nE "s/^[[:space:]]*${s}:[[:space:]]*([0-9]+).*/\1/p" | head -1)
    state_sum=$((state_sum + ${v:-0}))
  done
  sev_sum=0
  sev_missing=0
  for s in p1 p2 p3; do
    v=$(printf '%s\n' "$block" | sed -nE "s/^[[:space:]]*${s}:[[:space:]]*([0-9]+).*/\1/p" | head -1)
    [ -n "$v" ] || sev_missing=1
    sev_sum=$((sev_sum + ${v:-0}))
  done

  if [ "$state_sum" -ne "$declared_total" ]; then
    miss "residual: ${f} state counters sum to ${state_sum}, total: says ${declared_total}"
    misses=$((misses + 1))
  fi
  if [ "$sev_missing" -eq 0 ] && [ "$sev_sum" -ne "$declared_total" ]; then
    miss "residual: ${f} p1+p2+p3 sum to ${sev_sum}, total: says ${declared_total}"
    misses=$((misses + 1))
  fi

  # A non-tallyable shape defeats per-line body counting, so 1b/1c stop here.
  # Reported above, not silently skipped.
  if [ "$has_batch" -gt 0 ] || [ "$has_range" -gt 0 ]; then
    continue
  fi

  # A zero tally on a file that HAS findings means the pattern did not fire —
  # a leg failure, not a clean file. This is the sibling checker's "a scan that
  # verifies nothing is not a pass" guard, at the per-file level.
  if [ "$headings" -gt 0 ] && [ "$body_status_rows" -eq 0 ]; then
    miss "residual: ${f} has ${headings} finding heading(s) but zero status: rows matched — the tally pattern did not fire; a zero count is not a clean file"
    misses=$((misses + 1))
    continue
  fi

  # EVERY FIELD ROW MUST BELONG TO A HEADING. `headings` was computed and then
  # compared against nothing but zero, so any NON-zero mismatch was invisible:
  # a finding deleted from the body while its field rows survived elsewhere
  # (before the first `### N`, under a `Legend:` line) kept the tally whole and
  # every counter agreeing. Measured at `0 MISS, 0 WARN` before this check.
  # Files with a batch or range shape have already `continue`d above, so a
  # legitimate one-pair-covers-several-findings file never reaches here.
  if [ "$headings" -ne "$body_status_rows" ]; then
    miss "residual: ${f} has ${headings} finding heading(s) but ${body_status_rows} status: row(s) — a field row that belongs to no heading is not a finding any consumer can read"
    misses=$((misses + 1))
    continue
  fi

  # 1c — the gap equality. total − (findings in body) EQUALS the human-triage
  # removals, which is what `skipped` holds MINUS retained skips. The two kinds
  # of skip behave differently and this must not assume one: human-triage skips
  # are REMOVED from the body, /cepa:resolve-pr verdict skips are RETAINED in
  # it. A file with only retained skips has no gap.
  declared_skipped=$(printf '%s\n' "$block" | sed -nE 's/^[[:space:]]*skipped:[[:space:]]*([0-9]+).*/\1/p' | head -1)
  declared_skipped=${declared_skipped:-0}
  body_skipped=$(printf '%s\n' "$body" | grep -cE '^-?[[:space:]]*status:[[:space:]]*skipped[[:space:]]*$' || true)
  gap=$((declared_total - body_status_rows))
  removals=$((declared_skipped - body_skipped))

  if [ "$gap" -lt 0 ]; then
    miss "residual: ${f} body carries ${body_status_rows} findings but total: says ${declared_total} — total was shrunk or a finding was added without it"
    misses=$((misses + 1))
    continue
  fi
  if [ "$gap" -ne "$removals" ]; then
    miss "residual: ${f} gap is ${gap} (total ${declared_total} − ${body_status_rows} in body) but skipped: ${declared_skipped} − ${body_skipped} retained = ${removals} removals — the gap must EQUAL the removals, not merely bound them"
    misses=$((misses + 1))
    continue
  fi

  # 1b — agreement, per state. Each counter equals its body count plus the
  # human-triage removals, which only `skipped` can carry.
  for s in $STATES; do
    declared=$(printf '%s\n' "$block" | sed -nE "s/^[[:space:]]*${s}:[[:space:]]*([0-9]+).*/\1/p" | head -1)
    declared=${declared:-0}
    actual=$(printf '%s\n' "$body" | grep -cE "^-?[[:space:]]*status:[[:space:]]*${s}[[:space:]]*$" || true)
    [ "$s" = skipped ] && actual=$((actual + gap))
    if [ "$declared" -ne "$actual" ]; then
      miss "residual: ${f} declares ${s}: ${declared} but the body carries ${actual} — a counter that disagrees with the body is what /cepa:sweep reads"
      misses=$((misses + 1))
    fi
  done

  # Severity counters are verifiable only where there have been no removals —
  # `skipped` has no severity breakdown, so a removed finding's severity is
  # unrecoverable. Reported, not silently passed.
  if [ "$gap" -gt 0 ]; then
    info "residual: ${f} has ${gap} removal(s) — p1/p2/p3 cannot be re-derived from the body and were not checked"
  elif [ "$sev_missing" -eq 0 ]; then
    for s in p1 p2 p3; do
      declared=$(printf '%s\n' "$block" | sed -nE "s/^[[:space:]]*${s}:[[:space:]]*([0-9]+).*/\1/p" | head -1)
      up=$(printf '%s' "$s" | tr '[:lower:]' '[:upper:]')
      actual=$(printf '%s\n' "$body" | grep -cE "^-?[[:space:]]*severity:[[:space:]]*${up}[[:space:]]*$" || true)
      if [ "${declared:-0}" -ne "$actual" ]; then
        miss "residual: ${f} declares ${s}: ${declared} but the body carries ${actual} ${up} finding(s) — a balanced total hides a wrong distribution"
        misses=$((misses + 1))
      fi
    done
  fi
done

# "A scan that verifies nothing is not a pass" — but an EXEMPT file was not
# skipped by accident, it was skipped by a declared field. Counting exemptions
# as un-verified makes an all-exempt tree fail with nothing wrong in it, and the
# only fix available to the author is to delete a legitimate exemption. The
# guard must fire on files that fell through SILENTLY, not on declared ones.
leg1_unexplained=$(( ${#leg1_list[@]} - leg1_skipped ))
if [ "$leg1_files" -eq 0 ] && [ "$leg1_unexplained" -gt 0 ]; then
  miss "residual: leg 1 checked no summary block across ${leg1_unexplained} non-exempt findings file(s) — a scan that verifies nothing is not a pass"
  misses=$((misses + 1))
fi

# EVERY WALKED FILE MUST BE ACCOUNTED FOR. The guard above fires only when the
# whole run verified nothing, so a single well-formed sibling — which every
# real run has — disarms it permanently while other files fall through
# silently. Each `continue` above now emits its own MISS, and this reconciles
# the totals so a FUTURE `continue` added without one cannot go unnoticed: the
# arithmetic fails even though no individual check does.
#
# This is the accounting the sibling checker learned to keep after a truncated
# walk reported `5 of 5 roots`. Same lesson, per-file rather than per-root.
#
# STATED LIMIT — NO CONTROL CAN REDDEN THIS, and that is not an oversight.
# Every `continue` in the loop above either increments one of the four counters
# or runs after `leg1_files` was incremented, so the arithmetic cannot fail on
# any fixture that can be planted TODAY. Verified by mutation: replacing this
# condition with `false` leaves the suite at 28/28. It is a tripwire for a
# FUTURE edit — the next `continue` added without its own MISS — which is
# precisely the shape that produced the P1 this check closes. Recorded here per
# `an-assertion-must-name-the-edit-that-reddens-it`: the edit that reddens it
# has not been written yet, so no control names it, and pretending otherwise
# would make an unpinnable guard look pinned.
leg1_accounted=$(( leg1_files + leg1_skipped + leg1_unreadable + leg1_nototal ))
if [ "$leg1_accounted" -ne "${#leg1_list[@]}" ]; then
  miss "residual: leg 1 walked ${#leg1_list[@]} findings file(s) but accounted for only ${leg1_accounted} — some file was dropped by a path that emits no finding of its own"
  misses=$((misses + 1))
fi

info "summary blocks checked: ${leg1_files} of ${#leg1_list[@]} findings files (${leg1_skipped} counter_convention:, ${leg1_partial} with a non-tallyable shape)"

# --- legs 2-4: a shard's checkbox agrees with its own prose -------------------
# WARN-only in this cut. See the header for why, and for the promotion rule.
if ! traverse -L "$SHARDS_DIR" -type f -name '*.md'; then
  miss "residual: could not walk ${SHARDS_DIR} (${TRAVERSE_ERR}) — a traversal that could not complete is not a pass"
  misses=$((misses + 1))
  TRAVERSE_FILES=()
fi
shard_list=("${TRAVERSE_FILES[@]+"${TRAVERSE_FILES[@]}"}")

# Both trees carry these shapes: a findings file can hold checkbox items too.
scan_list=("${shard_list[@]+"${shard_list[@]}"}" "${leg1_list[@]+"${leg1_list[@]}"}")

OPEN_BOX='^[[:space:]]*- \[ \]'
CLOSURE_VOCAB='\b(DONE|CLOSED|RESOLVED|FIXED|SHIPPED|COMPLETED|SUPERSEDED)\b'

leg2=0; leg3=0; leg4=0
for f in "${scan_list[@]+"${scan_list[@]}"}"; do
  # Leg 2 — struck-through text under an open box. The strike says closed, the
  # box says open, and the box is what a consumer reads.
  while IFS=: read -r ln _; do
    [ -n "${ln:-}" ] || continue
    leg2=$((leg2 + 1))
    warn "residual: ${f}:${ln} — an open checkbox whose text is struck through (~~...~~); the strike reads as closed, the box reads as open"
    warns=$((warns + 1))
  done < <(grep -nE "${OPEN_BOX}.*~~" "$f" | cut -d: -f1 | sed 's/$/:/')

  # Leg 3 — an open box whose text claims closure in words.
  while IFS=: read -r ln _; do
    [ -n "${ln:-}" ] || continue
    leg3=$((leg3 + 1))
    warn "residual: ${f}:${ln} — an open checkbox carrying closure vocabulary; prose says closed, the parsed box says open"
    warns=$((warns + 1))
  done < <(grep -nE "${OPEN_BOX}.*${CLOSURE_VOCAB}" "$f" | cut -d: -f1 | sed 's/$/:/')

  # Leg 4 — a severity-bearing finding bullet with NO checkbox. No consumer can
  # read the state of an item that has no state field.
  while IFS=: read -r ln _; do
    [ -n "${ln:-}" ] || continue
    leg4=$((leg4 + 1))
    warn "residual: ${f}:${ln} — a '- **P[123]' finding bullet with no checkbox; it has no state any consumer can read"
    warns=$((warns + 1))
  done < <(grep -nE '^[[:space:]]*- \*\*P[123]' "$f" | cut -d: -f1 | sed 's/$/:/')
done

info "shard prose scanned: ${#scan_list[@]} files — leg 2: ${leg2}, leg 3: ${leg3}, leg 4: ${leg4} (all WARN in this cut; promote individually after burn-in)"

# A run that found NO input is not a clean run — it is a run pointed at the
# wrong place, and it exits 0 with a reassuring verdict. Measured: an empty
# tree passed `0 MISS, 0 WARN` before this guard. The sibling suite protects
# its BASELINE from this shape; the checker itself has to protect every other
# caller, including a future CI job whose working directory is wrong.
if [ "${#leg1_list[@]}" -eq 0 ] && [ "${#scan_list[@]}" -eq 0 ]; then
  miss "residual: found no findings files under ${TODOS_DIR} and no shards under ${SHARDS_DIR} — run from the repo root; a scan over nothing is not a pass"
  misses=$((misses + 1))
fi

# --- verdict ---------------------------------------------------------------
echo "-- ${misses} MISS, ${warns} WARN --"
if [ "$misses" -gt 0 ]; then
  echo "FAIL: a parsed counter disagrees with the body it summarizes, or a check could not run."
  exit 1
fi
if [ "$warns" -gt 0 ]; then
  echo "WARN-ONLY: prose and checkbox disagree somewhere. Legs 2-4 do not fail the run in this cut."
fi
exit 0

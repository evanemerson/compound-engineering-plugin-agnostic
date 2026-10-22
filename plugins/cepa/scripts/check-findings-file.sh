#!/usr/bin/env bash
# cepa findings-file check — read-only. Verifies that a findings file's PARSED
# `summary:` block agrees with its own body. Never modifies anything.
#
# THE ONE EXECUTABLE COPY of the `cepa:file-todos` counting rule. Every
# consumer runs THIS file, never a restatement of it:
#
#   - a command that writes or edits a findings file runs it on that file as
#     its self-check — the `cepa:file-todos` skill's `## Self-check` section
#     owns when, how, and what a MISS obliges the writer to do;
#   - the cepa repo's scripts/check-residual-integrity.sh SOURCES it and calls
#     cff_check_file once per walked `todos/review-*.md` (that repo-only
#     checker keeps the walk, the scan-over-nothing guards, and the
#     shard-prose legs 2-4, which are tuned to one repo's conventions);
#   - the spec's `--rows` verification command.
#
# WHY IT SHIPS. It used to live only in the cepa repo's scripts/, which no
# installed plugin carries, so a command running in another repo could not
# call it — and no command recounted what it wrote. Reviews wrote files their
# own checker rejected, and each cleanup was undone by the next review run
# (punch-list L16: six such files on one day in one project).
#
# Usage:
#   check-findings-file.sh FILE...    exit 0 clean, 1 any MISS, 2 usage
#   check-findings-file.sh --rows FILE
#                                     print every status/severity field row
#                                     the pattern matches, then the totals —
#                                     for the spec and its fixture, NEVER on a
#                                     writer's path (it prints file prose)
#   . check-findings-file.sh          define cff_check_file and the patterns
#
# OUTPUT IS DATA. MISS/INFO lines interpolate the path the caller passed and
# numbers derived by counting — never a line of the file's prose. That is what
# keeps the default mode safe to show an agent; `--rows` breaks it by design,
# which is why no writer runs it. A command reading this output is an autonomy
# §7 relay point, and its clause lives at that relay site (the Self-check
# section), not here.
#
# SOURCED CONTRACT. When sourced this file defines functions and read-only
# patterns and nothing else: no `set`, no `exit`, no locale change, no output.
# Results accumulate in the CFF_* globals below; the caller owns its own
# counters and its own exit code. The main path runs only when executed.
#
# The rationale for every check below was written for, and measured on, the
# cepa repo's own `todos/` corpus; it moved here verbatim with the code.

# ---------------------------------------------------------------------------
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
# Non-tallyable shapes. These are REPORTED, never counted as disagreement.
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
# NOT one of them: a heading-less file (rows, no `### N`). That is off-spec
# and fails as a MISS that names the missing denominator — see leg 1.
#
# A file whose counters follow a superseded convention carries
# `counter_convention:` in frontmatter. This skips on THAT FIELD, never on a
# filename — a grandfather clause that lives only in prose beside the file is
# unreadable to every consumer, which is the defect the spec exists to prevent.
# --- field-spelling fragments -------------------------------------------------
# EVERY status:/severity: match below composes these. Do NOT hand-roll another
# anchor at a call site: this script and the file-todos spec both tally the same
# counters, and the last time they carried independent patterns the script kept
# the pre-fix ones and saw ZERO status rows on 18 of 24 real bold-spelling files
# while exiting 0.
#
# The authority for WHICH spellings are live, WHY each fragment is load-bearing,
# and the inherent frontmatter ambiguity is the `cepa:file-todos` skill's
# `## Frontmatter Summary` section (its "verify against the body" paragraph)
# — plus its committed fixture, plugins/cepa/skills/file-todos/fixtures/status-spellings.md. Cited, not
# restated; if the two ever disagree, the spec governs and this is the bug.
#
# Every use needs `-i`: the FIELD NAME is capitalised in real files
# (`- **Status:** FIXED`), so widening the value class alone does not reach it.
#
# THREE BRANCHES. The split between the first two is load-bearing: a leading
# backtick is a real field spelling ONLY behind a list marker:
#
#   - `status: applied`     a field. 8 occurrences across two corpora.
#   `status: applied`       line-initial inline-code PROSE, mid-sentence in a
#                           **Fix:** paragraph. 39 occurrences, never a field.
#
# Allowing a bare leading backtick with no marker over-matches that prose. It is
# not hypothetical: the first cut of this port did exactly that and turned 4
# correct files into MISS, each reading "N headings but N+1 status rows" — a
# uniform off-by-one, which this file's own comment below names as the signature
# of a broken pattern rather than of real drift. The spec's fixture does not
# catch it (its backtick line carries a marker), so only the corpus run does.
#
# The THIRD branch is the POSITIONAL half: a field that follows other fields on
# the same line (`- **confidence:** 100 · **status:** pending`). The first two
# reach only the FIRST field on a line, so these rows were never counted (the
# spec records the measured undercount). The `^` anchor stays: the branch admits
# a line only if it OPENS as a field (`key:`) and the field sits behind a ` · `
# or ` | ` separator OUTSIDE inline code — `[^`]*` with balanced code spans,
# never `.*`. With `.*`, a `**Fix:**` line quoting `` `x · severity: P2/P3
# (batch)` `` set has_batch and switched 1b/1c off for the whole file: 0 MISS on
# a file with wrong counters. Which shapes are live and which prose must stay out
# is the spec's (cited above), not restated here.
FIELD_PRE='^([[:space:]]*[-*+][[:space:]]*(\*\*|__|\*|_|`)?|[[:space:]]*(\*\*|__|\*|_)?|[[:space:]]*([-*+][[:space:]]*)?(\*\*|__|\*|_)?[a-z][a-z0-9_-]*[[:space:]]*:(\*\*|__|\*|_)?[^`]*(`[^`]*`[^`]*)*[[:space:]](·|\|)[[:space:]]*(\*\*|__|\*|_)?)'
FIELD_POST='[[:space:]]*:(\*\*|__|\*|_|`)?[[:space:]]*`?'
# Tail for a VALUE-ANCHORED match: sites that interpolate an expected value and
# pin it with `$` must still allow the bold form's closing `**`/backtick, or
# every emphasised row reads as a zero. The `·`/`|` alternative is the same
# positional half from the other side: a field FOLLOWED by another field
# (`- status: applied | severity: P3`) is counted as a row, so its value must be
# countable too, or the row total and the per-state tally disagree.
VAL_TAIL='(\*\*|__|\*|_|`)?[[:space:]]*($|(·|\|))'

BATCH_RE="${FIELD_PRE}severity${FIELD_POST}P[123](/P[123])*[[:space:]]*\(batch\)"
RANGE_RE='^###[[:space:]]+[0-9]+[[:space:]]*-[[:space:]]*[0-9]+'


# --- leg 1: summary block agrees with the body -------------------------------
# Accumulators. The caller zeroes them (cff_reset) and reads them afterwards.
#   CFF_MISSES     MISS lines emitted
#   CFF_FILES      files whose sums were checked
#   CFF_SKIPPED    files exempted by a frontmatter counter_convention:
#   CFF_PARTIAL    files with a non-tallyable shape (sums checked, body not)
#   CFF_UNREADABLE files with no summary block, unreadable, or a failed tally
#   CFF_NOTOTAL    files whose block or frontmatter could not be parsed
# Every file passed to cff_check_file lands in exactly one of FILES, SKIPPED,
# UNREADABLE, NOTOTAL — cff_accounted is their sum, and a caller compares it
# with the number of files it passed.
cff_reset() {
  CFF_MISSES=0; CFF_FILES=0; CFF_SKIPPED=0; CFF_PARTIAL=0
  CFF_UNREADABLE=0; CFF_NOTOTAL=0
}
cff_reset
cff_accounted() { printf '%s\n' $((CFF_FILES + CFF_SKIPPED + CFF_UNREADABLE + CFF_NOTOTAL)); }

_cff_miss() { printf 'MISS %s\n' "$1"; }
_cff_info() { printf 'INFO %s\n' "$1"; }

# _cff_numeric <file> <value>... — every tally must be a non-negative integer.
_cff_numeric() {
  local _f="$1" _v
  shift
  for _v in "$@"; do
    case "$_v" in
      ''|*[!0-9]*)
        _cff_miss "residual: ${_f} a body tally returned '${_v:-<empty>}', not a count — the pattern errored, so nothing in this file was verified"
        CFF_MISSES=$((CFF_MISSES + 1))
        return 1 ;;
    esac
  done
  return 0
}

# cff_check_file <file> — check one findings file; never exits, always returns 0.
cff_check_file() {
  local f="$1" block declared_total body headings body_status_rows has_batch \
        has_range state_sum sev_sum sev_missing s v declared actual up \
        declared_skipped body_skipped gap removals
  # POSIX classes and the byte-level `·` separator: pinned for this call only,
  # so a caller's locale is untouched (the sourced contract above).
  local -x LC_ALL=C
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
  # a file that merely lacks a summary block. A caller's walk proves the WALK
  # completed; it says nothing about whether each file was still readable when
  # its turn came. A concurrent /cepa:triage or a branch switch mid-scan is the
  # ordinary way to produce this.
  grep -qE '^summary:' "$f"
  case $? in
    0) : ;;
    1) _cff_miss "residual: ${f} has no 'summary:' block — a findings file with no parsed summary is unverifiable, not clean"
       CFF_MISSES=$((CFF_MISSES + 1)); CFF_UNREADABLE=$((CFF_UNREADABLE + 1)); return 0 ;;
    *) _cff_miss "residual: ${f} could not be read (grep exit 2) — a file that disappeared or became unreadable mid-scan is not a clean file"
       CFF_MISSES=$((CFF_MISSES + 1)); CFF_UNREADABLE=$((CFF_UNREADABLE + 1)); return 0 ;;
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
    CFF_SKIPPED=$((CFF_SKIPPED + 1))
    _cff_info "residual: ${f} carries counter_convention: — counters follow a superseded convention and are not verifiable from the body"
    return 0
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
    _cff_miss "residual: ${f} has a 'summary:' block with no 'total:' field — every counter check derives from total, so nothing in this file was verified"
    CFF_MISSES=$((CFF_MISSES + 1))
    CFF_NOTOTAL=$((CFF_NOTOTAL + 1))
    return 0
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
    _cff_miss "residual: ${f} frontmatter has no closing '---' — the body could not be extracted, so an empty body was compared against the counters instead of the real one"
    CFF_MISSES=$((CFF_MISSES + 1))
    CFF_NOTOTAL=$((CFF_NOTOTAL + 1))
    return 0
  fi

  # A pattern anchored to one spelling returns ZERO ROWS on the others,
  # SILENTLY. A zero count is not a clean file; it is a pattern that did not
  # fire. The live spellings and the reason each fragment exists are the
  # `cepa:file-todos` spec's — see FIELD_PRE above.
  headings=$(printf '%s\n' "$body" | grep -cE '^###[[:space:]]+[0-9]' || true)
  body_status_rows=$(printf '%s\n' "$body" | grep -ciE "${FIELD_PRE}status${FIELD_POST}[a-z_-]+" || true)

  has_batch=$(printf '%s\n' "$body" | grep -ciE "$BATCH_RE" || true)
  has_range=$(printf '%s\n' "$body" | grep -cE "$RANGE_RE" || true)

  # A grep that ERRORS prints nothing, and `|| true` hides its exit 2 — so an
  # empty string, not a 0, is what a broken pattern produces here. Arithmetic
  # on it either crashes or, worse, reads as zero rows. Refuse it by name.
  # (Residual from PR #85: "`$(grep -c … || true)` turns a regex error into an
  # empty count".)
  _cff_numeric "$f" "$headings" "$body_status_rows" "$has_batch" "$has_range" ||
    { CFF_UNREADABLE=$((CFF_UNREADABLE + 1)); return 0; }

  if [ "$has_batch" -gt 0 ] || [ "$has_range" -gt 0 ]; then
    CFF_PARTIAL=$((CFF_PARTIAL + 1))
    _cff_info "residual: ${f} contains ${has_batch} batch-suffix and ${has_range} heading-range shape(s) — not tallyable per line; sum checked, body agreement not"
  fi

  CFF_FILES=$((CFF_FILES + 1))

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
    _cff_miss "residual: ${f} state counters sum to ${state_sum}, total: says ${declared_total}"
    CFF_MISSES=$((CFF_MISSES + 1))
  fi
  if [ "$sev_missing" -eq 0 ] && [ "$sev_sum" -ne "$declared_total" ]; then
    _cff_miss "residual: ${f} p1+p2+p3 sum to ${sev_sum}, total: says ${declared_total}"
    CFF_MISSES=$((CFF_MISSES + 1))
  fi

  # A non-tallyable shape defeats per-line body counting, so 1b/1c stop here.
  # Reported above, not silently skipped.
  if [ "$has_batch" -gt 0 ] || [ "$has_range" -gt 0 ]; then
    return 0
  fi

  # A zero tally on a file that HAS findings means the pattern did not fire —
  # a leg failure, not a clean file. This is the sibling checker's "a scan that
  # verifies nothing is not a pass" guard, at the per-file level.
  if [ "$headings" -gt 0 ] && [ "$body_status_rows" -eq 0 ]; then
    _cff_miss "residual: ${f} has ${headings} finding heading(s) but zero status: rows matched — the tally pattern did not fire; a zero count is not a clean file"
    CFF_MISSES=$((CFF_MISSES + 1))
    return 0
  fi

  # NO DENOMINATOR. Rows but zero `### N` headings — titles written without
  # numbers. The row-vs-heading comparison cannot apply, and the spec makes it
  # mandatory because the pattern alone over-counts (frontmatter-like indented
  # rows are byte-identical to findings). `counter_convention:` does NOT cover
  # this: that field marks a SUPERSEDED counter convention and skips 1a too,
  # while here the counters may be fine and only the headings are off-spec. The
  # fix is in the file — number its headings — so name that, not a mismatch.
  if [ "$headings" -eq 0 ] && [ "$body_status_rows" -gt 0 ]; then
    _cff_miss "residual: ${f} has ${body_status_rows} status: row(s) but no '### N' finding headings — no denominator, so the tally cannot be verified; number the headings per the file-todos spec"
    CFF_MISSES=$((CFF_MISSES + 1))
    return 0
  fi

  # EVERY FIELD ROW MUST BELONG TO A HEADING. `headings` was computed and then
  # compared against nothing but zero, so any NON-zero mismatch was invisible:
  # a finding deleted from the body while its field rows survived elsewhere
  # (before the first `### N`, under a `Legend:` line) kept the tally whole and
  # every counter agreeing. Measured at `0 MISS, 0 WARN` before this check.
  # Files with a batch or range shape have already returned above, so a
  # legitimate one-pair-covers-several-findings file never reaches here.
  if [ "$headings" -ne "$body_status_rows" ]; then
    _cff_miss "residual: ${f} has ${headings} finding heading(s) but ${body_status_rows} status: row(s) — a field row that belongs to no heading is not a finding any consumer can read"
    CFF_MISSES=$((CFF_MISSES + 1))
    return 0
  fi

  # 1c — the gap equality. total − (findings in body) EQUALS the human-triage
  # removals, which is what `skipped` holds MINUS retained skips. The two kinds
  # of skip behave differently and this must not assume one: human-triage skips
  # are REMOVED from the body, /cepa:resolve-pr verdict skips are RETAINED in
  # it. A file with only retained skips has no gap.
  declared_skipped=$(printf '%s\n' "$block" | sed -nE 's/^[[:space:]]*skipped:[[:space:]]*([0-9]+).*/\1/p' | head -1)
  declared_skipped=${declared_skipped:-0}
  body_skipped=$(printf '%s\n' "$body" | grep -ciE "${FIELD_PRE}status${FIELD_POST}skipped${VAL_TAIL}" || true)
  _cff_numeric "$f" "$body_skipped" || return 0
  gap=$((declared_total - body_status_rows))
  removals=$((declared_skipped - body_skipped))

  if [ "$gap" -lt 0 ]; then
    _cff_miss "residual: ${f} body carries ${body_status_rows} findings but total: says ${declared_total} — total was shrunk or a finding was added without it"
    CFF_MISSES=$((CFF_MISSES + 1))
    return 0
  fi
  if [ "$gap" -ne "$removals" ]; then
    _cff_miss "residual: ${f} gap is ${gap} (total ${declared_total} − ${body_status_rows} in body) but skipped: ${declared_skipped} − ${body_skipped} retained = ${removals} removals — the gap must EQUAL the removals, not merely bound them"
    CFF_MISSES=$((CFF_MISSES + 1))
    return 0
  fi

  # 1b — agreement, per state. Each counter equals its body count plus the
  # human-triage removals, which only `skipped` can carry.
  for s in $STATES; do
    declared=$(printf '%s\n' "$block" | sed -nE "s/^[[:space:]]*${s}:[[:space:]]*([0-9]+).*/\1/p" | head -1)
    declared=${declared:-0}
    actual=$(printf '%s\n' "$body" | grep -ciE "${FIELD_PRE}status${FIELD_POST}${s}${VAL_TAIL}" || true)
    _cff_numeric "$f" "$actual" || return 0
    [ "$s" = skipped ] && actual=$((actual + gap))
    if [ "$declared" -ne "$actual" ]; then
      _cff_miss "residual: ${f} declares ${s}: ${declared} but the body carries ${actual} — a counter that disagrees with the body is what /cepa:sweep reads"
      CFF_MISSES=$((CFF_MISSES + 1))
    fi
  done

  # Severity counters are verifiable only where there have been no removals —
  # `skipped` has no severity breakdown, so a removed finding's severity is
  # unrecoverable. Reported, not silently passed.
  if [ "$gap" -gt 0 ]; then
    _cff_info "residual: ${f} has ${gap} removal(s) — p1/p2/p3 cannot be re-derived from the body and were not checked"
  elif [ "$sev_missing" -eq 0 ]; then
    for s in p1 p2 p3; do
      declared=$(printf '%s\n' "$block" | sed -nE "s/^[[:space:]]*${s}:[[:space:]]*([0-9]+).*/\1/p" | head -1)
      up=$(printf '%s' "$s" | tr '[:lower:]' '[:upper:]')
      actual=$(printf '%s\n' "$body" | grep -ciE "${FIELD_PRE}severity${FIELD_POST}${up}${VAL_TAIL}" || true)
      _cff_numeric "$f" "$actual" || return 0
      if [ "${declared:-0}" -ne "$actual" ]; then
        _cff_miss "residual: ${f} declares ${s}: ${declared} but the body carries ${actual} ${up} finding(s) — a balanced total hides a wrong distribution"
        CFF_MISSES=$((CFF_MISSES + 1))
      fi
    done
  fi
  return 0
}

# --rows <file> — the spec's verification view: every matched field row, as
# written, then the two totals. Prints FILE PROSE; never for a writer's path.
_cff_rows() {
  local f="$1" s re n rc
  local -x LC_ALL=C
  for s in status severity; do
    # The value classes are the tallies' own: `[a-z_-]+` (two values sharing a
    # prefix must not merge into one row) and `P[123]`. The row TOTAL is what
    # the `### N` comparison needs, so it is printed on its own line.
    case "$s" in
      status)   re="${FIELD_PRE}status${FIELD_POST}[a-z_-]+" ;;
      severity) re="${FIELD_PRE}severity${FIELD_POST}P[123]" ;;
    esac
    grep -oiE "$re" "$f"
    rc=$?
    [ "$rc" -le 1 ] || return 2
    n=$(grep -ciE "$re" "$f")
    printf -- '-- %s rows: %s\n' "$s" "$n"
  done
  return 0
}

_cff_main() {
  # Diagnostics in a stable language; the patterns use POSIX classes.
  export LC_ALL=C
  set -u
  case "${1:-}" in
    -h|--help) sed -n '2,45p' "$0"; return 0 ;;
    --rows)
      [ $# -eq 2 ] || { printf 'usage: %s --rows FILE\n' "${0##*/}" >&2; return 2; }
      [ -r "$2" ] || { printf 'not readable: %s\n' "$2" >&2; return 2; }
      _cff_rows "$2"
      return $? ;;
    '') printf 'usage: %s FILE...   (a check over no file is not a pass)\n' "${0##*/}" >&2
        return 2 ;;
  esac
  local f
  cff_reset
  for f in "$@"; do cff_check_file "$f"; done
  # Every file passed must be accounted for. A path through cff_check_file
  # that drops a file without a MISS of its own fails here instead of passing.
  if [ "$(cff_accounted)" -ne "$#" ]; then
    _cff_miss "residual: checked $# findings file(s) but accounted for only $(cff_accounted) — some file was dropped by a path that emits no finding of its own"
    CFF_MISSES=$((CFF_MISSES + 1))
  fi
  printf -- '-- %s MISS — %s of %s file(s) verified (%s counter_convention:, %s with a non-tallyable shape) --\n' \
    "$CFF_MISSES" "$CFF_FILES" "$#" "$CFF_SKIPPED" "$CFF_PARTIAL"
  [ "$CFF_MISSES" -eq 0 ] || return 1
  return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  _cff_main "$@"
  exit $?
fi

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
#   Leg 1 runs from plugins/cepa/scripts/check-findings-file.sh, SOURCED below
#   — the one shipped copy every findings-file writer also runs. This script
#   walks todos/ and calls it per file; legs 2-4 remain here, repo-only.
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
# FOR WHOEVER WIRES THE NEXT CONSUMER — THIS script's output is written for a
# human or a CI log. Its MISS/WARN messages interpolate repo-tracked file paths
# and line numbers (never file prose, deliberately), and at the time of writing
# no workflow, command, skill, or agent reads ITS stdout. Its leg-1 lines come
# from the sourced rule (counters and required fields), whose standalone output the findings-file
# writers DO read — that relay point is the `cepa:file-todos` `## Self-check`
# section, and it carries its own §7 clause. The moment anything reads THIS
# script's stdout
# — a sweep summarizer, a CI-annotation-to-agent bridge — that consumer
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
# check-model-pins.sh:90-98 with the full measurement; cited rather than
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

# --- the counting rule: ONE copy, shipped in the plugin ---------------------
# Leg 1 and the field-spelling pattern live in
# plugins/cepa/scripts/check-findings-file.sh, which every command that writes
# a findings file also runs as its self-check (`cepa:file-todos` `## Self-check`).
# Sourced, never restated: this checker held its own copy of the pattern
# while the spec was fixed four times beside it, and saw ZERO status rows on
# 18 of 24 real bold-spelling files while exiting 0. That file's header owns
# the sourced contract; its body owns every leg-1 rationale that used to be
# here, and its fields leg (each finding's required fields), whose MISS lines
# land in this checker's leg 1 and fail it — not in the WARN-only legs 2-4.
#
# Located from THIS script's own path, never from the cwd or the installed
# plugin: a repo checker that sourced whatever copy happened to be installed
# would verify this tree against some other version's rule.
# CEPA_FINDINGS_CHECKER exists for MUTATION TESTING only — the controls point
# it at a deliberately broken copy — and the controls refuse it in CI.
# Refused in CI here too, not only in the controls: CI runs THIS script
# directly, and an override in the job environment would verify the tree
# against a rule nobody reviewed.
if [ -n "${CEPA_FINDINGS_CHECKER:-}" ] && [ -n "${CI:-}" ]; then
  miss "residual: CEPA_FINDINGS_CHECKER is set in CI — refusing to source a counting rule nobody reviewed"
  echo "-- 1 MISS, 0 WARN --"
  exit 1
fi
FINDINGS_CHECKER=${CEPA_FINDINGS_CHECKER:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/plugins/cepa/scripts/check-findings-file.sh}
if [ -r "$FINDINGS_CHECKER" ] && . "$FINDINGS_CHECKER" && declare -F cff_check_file >/dev/null; then
  :
else
  miss "residual: could not load the counting rule from ${FINDINGS_CHECKER} — leg 1 cannot run, and a leg that cannot run is not a pass"
  echo "-- 1 MISS, 0 WARN --"
  echo "FAIL: a parsed counter disagrees with the body it summarizes, a finding lacks a required field, or a check could not run."
  exit 1
fi

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
  cff_check_file "$f"
done
misses=$((misses + CFF_MISSES))
leg1_files=$CFF_FILES
leg1_skipped=$CFF_SKIPPED
leg1_partial=$CFF_PARTIAL
leg1_unreadable=$CFF_UNREADABLE
leg1_nototal=$CFF_NOTOTAL

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
# silently. Every early `return` inside cff_check_file (the sourced counting
# rule) emits its own MISS; this reconciles the totals so a FUTURE return added
# there without one cannot go unnoticed: the arithmetic fails even though no
# individual check does. The sum is the counting rule's own cff_accounted, so
# the two cannot disagree about which counters exist.
#
# This is the accounting check-model-pins.sh learned to keep after a truncated
# walk reported `5 of 5 roots`. Same lesson, per-file rather than per-root.
#
# The real counting rule cannot redden this on any file — every path through it
# lands in exactly one counter. What reddens it is a counting rule that drops a
# file, so the control plants exactly that: check-findings-file-controls.sh
# `src-tripwire` sources a stub through CEPA_FINDINGS_CHECKER.
leg1_accounted=$(cff_accounted)
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
  echo "FAIL: a parsed counter disagrees with the body it summarizes, a finding lacks a required field, or a check could not run."
  exit 1
fi
if [ "$warns" -gt 0 ]; then
  echo "WARN-ONLY: prose and checkbox disagree somewhere. Legs 2-4 do not fail the run in this cut."
fi
exit 0

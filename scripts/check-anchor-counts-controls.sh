#!/usr/bin/env bash
# Controls for scripts/check-anchor-counts.sh — proves the gate actually GATES.
# Read-only with respect to this repository: every case is planted into a
# throwaway fixture repo under $TMPDIR, never into the working tree.
#
# Two halves:
#
#   CASES — each plants a minimal tree and asserts rc plus the exact MISS and
#     (where it matters) WARN counts, and for red cases the finding text. The
#     headline pair is `count_red` / `count_green`: `## Commands (11)` plus
#     `[x](#commands-11)` goes RED; `## Commands` plus `[x](#commands)` goes
#     GREEN. `quoted_span` and `quoted_fence` plant the QUOTED form of that
#     defect — CLAUDE.md's absence rule: a clean corpus diff proves nothing
#     about a shape the corpus does not hold, and CLAUDE.md:39 really does
#     quote `[the full table](#commands-11)` in a code span.
#   MUTANTS — every `# GUARD:<name>` line in the checker is removed in turn
#     and the cases are re-run. Each mutant must turn at least one case red,
#     AND at least one case that no other mutant also turns red. CLAUDE.md:
#     "Adding a leg to ANY checker can silently uncover an existing leg" — a
#     green suite is not evidence that each leg is covered, so this suite
#     measures it instead of asserting it. A guard marker that is missing, or
#     present twice, is FATAL: a mutant that changed nothing kills nothing and
#     would read as a guard with no coverage.
#
# The `real` case runs the checker over the ACTUAL tree and asserts 0 MISS, so
# a change in what the live tree produces reddens this suite instead of
# passing silently. It is not re-run under mutants.
#
# Adding a guard: mark its line `# GUARD:<name>`, add its replacement to MUT
# below, and add a case it uniquely kills. The suite fails until all three
# exist.
#
# Usage: bash scripts/check-anchor-counts-controls.sh
# Exit: 0 when every case and every mutant behaves as recorded. 1 otherwise.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$ROOT/scripts/check-anchor-counts.sh"
[ -f "$CHECKER" ] || { echo "FATAL: missing $CHECKER"; exit 1; }

pass=0; fail=0
WORK="$(mktemp -d -t cepa-anchor-controls.XXXXXX)" || { echo "FATAL: mktemp failed"; exit 1; }
# EXIT trap, not a per-branch rm — check-fenced-block-state-controls.sh's
# header records why.
trap 'rm -rf "$WORK"' EXIT

# Replacement for each guard line (leading whitespace is kept).
MUT=(
  "leg0|if False:"
  "leg1|if False:"
  "leg2|if False:"
  "leg3|if False:"
  "fence|pass"
  "codespan|pass"
  "punct|pass"
  "dup|pass"
  "htmlanchor|pass"
  "xfile|if False:"
  "exclude|files = [f for f in sys.stdin.read().splitlines() if f]"
)

# ---------------------------------------------------------------------------
# Fixture construction. Each case is a directory holding a git repo with
# scripts/ (the checker under test is copied in per run) and its .md files.
# ---------------------------------------------------------------------------
CASES=()
mk() {  # $1 case name; then pairs of (path, content)
  local d="$WORK/cases/$1"; shift
  mkdir -p "$d/scripts"
  git -C "$d" init -q 2>/dev/null || { echo "FATAL: git init failed in $d"; exit 1; }
  while [ $# -ge 2 ]; do
    mkdir -p "$d/$(dirname "$1")"
    printf '%s\n' "$2" > "$d/$1"
    shift 2
  done
  git -C "$d" add -A -- . ':!scripts' 2>/dev/null
}

# Every case also carries base.md so leg 0 is satisfied by default.
BASE='# Base'

# name | want_rc | want_miss | want_warn ('-' = not asserted) | required text ('-' = none)
spec() { CASES+=("$1|$2|$3|$4|$5"); }

mk count_red  base.md "$BASE" a.md $'## Commands (11)\n\nSee [x](#commands-11).'
spec count_red 1 1 - "heading 'Commands (11)' carries a count"

mk count_unlinked base.md "$BASE" a.md $'## Agents (4)\n\nNo link points here; an outside URL still could.'
spec count_unlinked 1 1 - "heading 'Agents (4)' carries a count"

mk count_green base.md "$BASE" a.md $'## Commands\n\nSee [x](#commands).'
spec count_green 0 0 0 -

mk broken_link base.md "$BASE" a.md $'## Commands\n\nSee [x](#commands-11).'
spec broken_link 1 1 - "no heading in a.md slugs to #commands-11"

mk quoted_span base.md "$BASE" a.md $'## Commands\n\nThe link `[the full table](#commands-11)` was removed.'
spec quoted_span 0 0 0 -

mk quoted_fence base.md "$BASE" a.md $'## Commands\n\n```markdown\n## Commands (11)\n[x](#commands-11)\n```\n\n~~~\n## Agents (4)\n~~~'
spec quoted_fence 0 0 0 -

mk ordinal base.md "$BASE" a.md $'## Step 3\n\nSee [x](#step-3).'
spec ordinal 0 0 1 "confirm it is an ordinal or version"

mk version base.md "$BASE" a.md $'## Django 5.2 `notes`\n\nSee [x](#django-52-notes).'
spec version 0 0 - -

mk dup base.md "$BASE" a.md $'## Notes\n\none\n\n## Notes\n\nSee [x](#notes-1).'
spec dup 0 0 - -

mk html_anchor base.md "$BASE" a.md $'<a id="custom-target"></a>\n\nSee [x](#custom-target).'
spec html_anchor 0 0 0 -

mk xfile_ok base.md "$BASE" a.md 'See [x](sub/b.md#only-in-b).' sub/b.md $'## Only in B'
spec xfile_ok 0 0 0 -

mk xfile_broken base.md "$BASE" a.md 'See [x](sub/b.md#nope).' sub/b.md $'## Only in B'
spec xfile_broken 1 1 - "no heading in sub/b.md slugs to #nope"

mk untracked base.md "$BASE" a.md 'See [x](gone.md#anything).'
spec untracked 1 1 - "which is not a tracked .md in scope"

mk excluded base.md "$BASE" todos/review.md $'## Findings (3)\n\n[x](#nowhere)' memory/tasks.d/x.md $'## Items (2)'
spec excluded 0 0 0 -

mk empty
spec empty 1 1 - "a probe that read nothing is not a clean tree"

# ---------------------------------------------------------------------------
# Runner. Prints one token per failing case; empty output = all as recorded.
# ---------------------------------------------------------------------------
run_case() {  # $1 checker file, $2 spec line; echoes "" on match, else a reason
  local chk="$1" name want_rc want_miss want_warn want_text d out rc m w
  IFS='|' read -r name want_rc want_miss want_warn want_text <<<"$2"
  d="$WORK/cases/$name"
  cp "$chk" "$d/scripts/check-anchor-counts.sh"
  out="$(bash "$d/scripts/check-anchor-counts.sh" 2>&1)"; rc=$?
  m="$(printf '%s\n' "$out" | grep -c '^MISS:')"
  w="$(printf '%s\n' "$out" | grep -c '^WARN:')"
  if [ "$rc" != "$want_rc" ]; then echo "rc=$rc want $want_rc"; return; fi
  if [ "$m" != "$want_miss" ]; then echo "MISS=$m want $want_miss"; return; fi
  if [ "$want_warn" != "-" ] && [ "$w" != "$want_warn" ]; then echo "WARN=$w want $want_warn"; return; fi
  if [ "$want_text" != "-" ] && ! printf '%s\n' "$out" | grep -qF -- "$want_text"; then echo "missing text: $want_text"; return; fi
  echo ""
}

echo "== cases (unmutated checker)"
for c in "${CASES[@]}"; do
  r="$(run_case "$CHECKER" "$c")"
  if [ -z "$r" ]; then pass=$((pass + 1)); echo "PASS ${c%%|*}"
  else fail=$((fail + 1)); echo "FAIL ${c%%|*} — $r"; fi
done

echo "== real tree"
out="$(bash "$CHECKER" 2>&1)"; rc=$?
if [ "$rc" = 0 ] && printf '%s\n' "$out" | grep -q '^-- 0 MISS'; then
  pass=$((pass + 1)); echo "PASS real — $(printf '%s\n' "$out" | tail -1)"
else
  fail=$((fail + 1)); echo "FAIL real — rc=$rc"; printf '%s\n' "$out" | grep '^MISS' | head -5
fi

# ---------------------------------------------------------------------------
# Mutants. Build each, record which cases it kills, then check uniqueness.
# ---------------------------------------------------------------------------
echo "== mutants"
markers="$(grep -oE '# GUARD:[a-z0-9]+' "$CHECKER" | sed 's/# GUARD://' | sort)"
listed="$(for e in "${MUT[@]}"; do printf '%s\n' "${e%%|*}"; done | sort)"
if [ "$markers" != "$listed" ]; then
  fail=$((fail + 1))
  echo "FAIL guard inventory — markers in checker and MUT table disagree:"
  diff <(printf '%s\n' "$markers") <(printf '%s\n' "$listed") | sed 's/^/  /'
fi

declare -A KILLS
for e in "${MUT[@]}"; do
  g="${e%%|*}"; rep="${e#*|}"
  mf="$WORK/mut-$g.sh"
  n="$(grep -c "# GUARD:$g\$" "$CHECKER")"
  if [ "$n" != 1 ]; then
    fail=$((fail + 1)); echo "FAIL mutant $g — marker found $n time(s), want exactly 1 (a mutant that changed nothing kills nothing)"
    continue
  fi
  G="$g" REP="$rep" python3 - "$CHECKER" "$mf" <<'PY'
import os, re, sys
src = open(sys.argv[1]).read().split("\n")
g, rep = os.environ["G"], os.environ["REP"]
out = []
for ln in src:
    if ln.endswith(f"# GUARD:{g}"):
        ln = re.match(r"^\s*", ln).group(0) + rep
    out.append(ln)
open(sys.argv[2], "w").write("\n".join(out))
PY
  if cmp -s "$CHECKER" "$mf"; then
    fail=$((fail + 1)); echo "FAIL mutant $g — mutated file is identical to the checker"; continue
  fi
  k=""
  for c in "${CASES[@]}"; do
    [ -n "$(run_case "$mf" "$c")" ] && k="$k ${c%%|*}"
  done
  KILLS[$g]="$k"
done

for g in "${!KILLS[@]}"; do
  k="${KILLS[$g]}"
  if [ -z "$k" ]; then
    fail=$((fail + 1)); echo "FAIL mutant $g — SURVIVED: no case goes red with this guard removed"; continue
  fi
  uniq=""
  for c in $k; do
    shared=0
    for o in "${!KILLS[@]}"; do
      [ "$o" = "$g" ] && continue
      case " ${KILLS[$o]} " in *" $c "*) shared=1 ;; esac
    done
    [ "$shared" = 0 ] && uniq="$uniq $c"
  done
  if [ -z "$uniq" ]; then
    fail=$((fail + 1)); echo "FAIL mutant $g — killed only by cases other mutants also kill:$k"
  else
    pass=$((pass + 1)); echo "PASS mutant $g — killed by$k (unique:$uniq)"
  fi
done

echo "-- $pass/$((pass + fail)) checks passed --"
[ "$fail" = 0 ]

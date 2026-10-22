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
#     about a shape the corpus does not hold, and CLAUDE.md's anchors rule
#     really does quote `[the full table](#commands-11)` in a code span.
#   MUTANTS — every `# GUARD:<name>` line in the checker is removed in turn
#     and the cases are re-run. Each mutant must turn at least one case red,
#     AND at least one case that no other mutant also turns red — except a
#     mutant of a guard that ENCLOSES this one (see `encloses`). CLAUDE.md:
#     "Adding a leg to ANY checker can silently uncover an existing leg" — a
#     green suite is not evidence that each leg is covered, so this suite
#     measures it instead of asserting it. A guard marker that is missing, or
#     present twice, is a FAIL: a mutant that changed nothing kills nothing and
#     would read as a guard with no coverage. So is a mutant that crashes — a
#     Traceback reddens every case, which would otherwise read as full
#     coverage.
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
# `declare -A` needs bash 4. On bash 3.2 (macOS) KILLS[$g] silently becomes an
# arithmetic index and every mutant collapses into one slot.
[ "${BASH_VERSINFO[0]}" -ge 4 ] || { echo "FATAL: bash >= 4 required (have $BASH_VERSION)"; exit 1; }

pass=0; fail=0
WORK="$(mktemp -d -t cepa-anchor-controls.XXXXXX)" || { echo "FATAL: mktemp failed"; exit 1; }
# EXIT trap, not a per-branch rm: a list of per-branch cleanups has to stay
# complete as branches are added, and a trap does not.
trap 'rm -rf "$WORK"' EXIT

# Replacement for each guard line (leading whitespace is kept). Each one must
# be a single statement that still parses — a mutant that crashes would turn
# every case red and read as full coverage, so a Traceback under a mutant is a
# FAIL of the mutant, not a kill (see the mutant loop).
MUT=(
  "exclude|files = [f for f in raw if f]"
  "infostring|FENCE_RE = re.compile(r\"^[ \\t]*(\`{3,}|~{3,})\")"
  "blockquote|HEADING_RE = re.compile(r\"^ {0,3}()(#{1,6})[ \\t]+(.*?)(?:[ \\t]+#+)?[ \\t]*\$\")"
  "linkre|INLINE_LINK_RE = re.compile(r\"\\]\\(\\s*()([^)\\s>]+)(?:\\s+\\\"[^\\\"]*\\\")?\\s*\\)\")"
  "anchorattr|HTML_ANCHOR_RE = re.compile(r\"<a\\s[^>]*\\b(?:id|name)=[\\\"']([^\\\"']+)[\\\"']\", re.I)"
  "codekeep|pass"
  "entity|pass"
  "punct|pass"
  "fence|lines, open_fence = lines, None"
  "comments|pass"
  "unterminated|if False:"
  "dup|if False:"
  "codespan|pass"
  "htmlanchor|pass"
  "leg0|if False:"
  "leg1|if False:"
  "refdef|targets += []"
  "href|targets += []"
  "scheme|pass"
  "unquote|pass"
  "xfile|if False:"
  "pathunquote|pass"
  "rooted|dest = path"
  "relative|dest = os.path.normpath(path)"
  "dirreadme|pass"
  "nonmd|pass"
  "exclinks|pass"
  "top|pass"
  "leg2|if False:"
  "leg3|if False:"
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
B=$'## Only in B'

# name | want_rc | want_miss | want_warn ('-' = not asserted) | required text ('-' = none)
spec() { CASES+=("$1|$2|$3|$4|$5"); }

# --- the headline pair and the legs ---
mk count_red  base.md "$BASE" a.md $'## Commands (11)\n\nSee [x](#commands-11).'
spec count_red 1 1 1 "heading 'Commands (11)' carries a count"
mk count_green base.md "$BASE" a.md $'## Commands\n\nSee [x](#commands).'
spec count_green 0 0 0 -
mk count_unlinked base.md "$BASE" a.md $'## Agents (4)\n\nNo link points here; an outside URL still could.'
spec count_unlinked 1 1 - "heading 'Agents (4)' carries a count"
mk count_closing_hashes base.md "$BASE" a.md $'## Agents (4) ##'
spec count_closing_hashes 1 1 - "heading 'Agents (4)' carries a count"
mk not_a_count base.md "$BASE" a.md $'## Django (5.2)\n\n## Agents (12 total)\n\n## Step 3'
spec not_a_count 0 0 0 -
mk broken_link base.md "$BASE" a.md $'## Commands\n\nSee [x](#commands-11).'
spec broken_link 1 1 - "no heading in a.md slugs to #commands-11"
mk case_mismatch base.md "$BASE" a.md $'## H\n\nSee [y](#H).'
spec case_mismatch 1 1 - "slugs to #H"
mk ordinal base.md "$BASE" a.md $'## Step 3\n\nSee [x](#step-3).'
spec ordinal 0 0 1 "confirm it is an ordinal or version"
mk empty
spec empty 1 1 - "a probe that read nothing is not a clean tree"
mk no_headings base.md 'no heading here' a.md 'nor here'
spec no_headings 1 1 - "a probe that read nothing is not a clean tree"

# --- quoted forms: the defect shape inside a record must not fire ---
mk quoted_span base.md "$BASE" a.md $'## Commands\n\nThe link `[the full table](#commands-11)` was removed.'
spec quoted_span 0 0 0 -
mk quoted_anchor base.md "$BASE" a.md $'## Commands\n\nWe removed `<a id="commands-11"></a>`.\n\nSee [x](#commands-11).'
spec quoted_anchor 1 1 0 "slugs to #commands-11"
mk quoted_fence base.md "$BASE" a.md $'## Commands\n\n````markdown\n```\n## Commands (11)\n```\n[x](#commands-11)\n````\n\n~~~\n## Agents (4)\n~~~'
spec quoted_fence 0 0 0 -
mk comment_heading base.md "$BASE" a.md $'<!--\n## Hidden\n<a id="ghost"></a>\n-->\n\nSee [x](#hidden) and [y](#ghost).'
spec comment_heading 1 2 - "slugs to #hidden"
mk unterminated base.md "$BASE" a.md $'## Top\n\n```\ncode\n## Commands (11)\n[x](#nope)'
spec unterminated 1 1 - "fence is never closed"
mk infostring base.md "$BASE" a.md $'## Top\n\n```x``` is inline code, not a fence\n\n## Agents (4)'
spec infostring 1 1 - "heading 'Agents (4)' carries a count"

# --- slug fidelity ---
mk version base.md "$BASE" a.md $'## Django 5.2 notes\n\nSee [x](#django-52-notes).'
spec version 0 0 - -
mk code_underscore base.md "$BASE" a.md $'## `__init__` notes\n\nSee [x](#__init__-notes).'
spec code_underscore 0 0 0 -
mk entity base.md "$BASE" a.md $'## A &amp; B\n\nSee [x](#a--b).'
spec entity 0 0 0 -
mk dup base.md "$BASE" a.md $'## Notes\n\none\n\n## Notes\n\nSee [x](#notes-1).'
spec dup 0 0 1 "duplicate-heading suffix"
mk dup_collision base.md "$BASE" a.md $'## Foo\n\n## Foo\n\n## Foo 1\n\nSee [x](#foo-1-1).'
spec dup_collision 0 0 - -
mk blockquote base.md "$BASE" a.md $'> ## Agents (4)'
spec blockquote 1 1 - "heading 'Agents (4)' carries a count"
mk list_heading base.md "$BASE" a.md $'- ## Agents (4)'
spec list_heading 1 1 - "heading 'Agents (4)' carries a count"
mk html_anchor base.md "$BASE" a.md $'<a id="custom-target"></a>\n\nSee [x](#custom-target).'
spec html_anchor 0 0 0 -
mk data_attr base.md "$BASE" a.md $'<a data-id="dd"></a>\n\nSee [x](#dd).'
spec data_attr 1 1 - "slugs to #dd"
mk unquote base.md "$BASE" a.md $'## Café\n\nSee [x](#caf%C3%A9).'
spec unquote 0 0 0 -

# --- link forms ---
mk title_forms base.md "$BASE" a.md $'## Commands\n\n[a](#commands "T") [b](#nope \'T\') [c](#nope2 (T)) [d](<#nope3>)'
spec title_forms 1 3 0 "slugs to #nope"
mk refdef base.md "$BASE" a.md $'## H\n\n[r]: #nope\n[s]: <#h> "t"\n[^1]: see #foo'
spec refdef 1 1 - "slugs to #nope"
mk href base.md "$BASE" a.md $'## H\n\n<a href="#nope">x</a> <a href="#h">y</a>'
spec href 1 1 - "slugs to #nope"
mk top base.md "$BASE" a.md $'## H\n\n[Back to top](#) and [top](#top).'
spec top 0 0 0 -
mk external base.md "$BASE" a.md $'## H\n\n[x](https://github.com/o/r/blob/main/README.md#commands-11) [y](mailto:a@b#c)'
spec external 0 0 0 -
mk nonmd base.md "$BASE" a.md $'## H\n\n[x](scripts/x.sh#L10)'
spec nonmd 0 0 0 -

# --- cross-file resolution ---
mk xfile_ok base.md "$BASE" a.md 'See [x](sub/b.md#only-in-b).' sub/b.md "$B"
spec xfile_ok 0 0 0 -
mk xfile_broken base.md "$BASE" a.md 'See [x](sub/b.md#nope).' sub/b.md "$B"
spec xfile_broken 1 1 - "no heading in sub/b.md slugs to #nope"
mk relative base.md "$BASE" a.md $'## H' sub/b.md $'## B\n\n[y](c.md#q) [z](../a.md#h)' sub/c.md $'## Q'
spec relative 0 0 0 -
mk rooted base.md "$BASE" a.md 'See [x](/sub/b.md#only-in-b).' sub/b.md "$B"
spec rooted 0 0 0 -
mk path_escape base.md "$BASE" a.md 'See [x](my%20b.md#only-in-b).' "my b.md" "$B"
spec path_escape 0 0 0 -
mk dir_readme base.md "$BASE" a.md 'See [x](sub/#nope) and [y](sub#only-in-b).' sub/README.md "$B"
spec dir_readme 1 1 - "no heading in sub/README.md slugs to #nope"
mk untracked base.md "$BASE" a.md 'See [x](gone.md#anything).'
spec untracked 1 1 - "which is not a tracked .md in scope"
mk excluded base.md "$BASE" todos/review.md $'## Findings (3)\n\n[x](#nowhere)' memory/tasks.d/x.md $'## Items (2)'
spec excluded 0 0 0 -
mk into_excluded base.md "$BASE" a.md 'See [x](todos/review.md#whatever).' todos/review.md $'## Findings'
spec into_excluded 0 0 0 -

# ---------------------------------------------------------------------------
# Runner. Prints one token per failing case; empty output = all as recorded.
# ---------------------------------------------------------------------------
run_case() {  # $1 checker file, $2 spec line; echoes "" on match, else a reason
  local chk="$1" name want_rc want_miss want_warn want_text d out rc m w
  IFS='|' read -r name want_rc want_miss want_warn want_text <<<"$2"
  d="$WORK/cases/$name"
  cp "$chk" "$d/scripts/check-anchor-counts.sh" || { echo "cp failed"; return; }
  out="$(bash "$d/scripts/check-anchor-counts.sh" 2>&1)"; rc=$?
  if printf '%s\n' "$out" | grep -q '^Traceback'; then echo "TRACEBACK"; return; fi
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
  if G="$g" REP="$rep" python3 - "$CHECKER" "$mf" <<'PY'
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
  then :; else
    fail=$((fail + 1)); echo "FAIL mutant $g — the mutant builder failed"; continue
  fi
  if cmp -s "$CHECKER" "$mf"; then
    fail=$((fail + 1)); echo "FAIL mutant $g — mutated file is identical to the checker"; continue
  fi
  k=""; crashed=""
  for c in "${CASES[@]}"; do
    r="$(run_case "$mf" "$c")"
    [ "$r" = TRACEBACK ] && crashed="$crashed ${c%%|*}"
    [ -n "$r" ] && k="$k ${c%%|*}"
  done
  if [ -n "$crashed" ]; then
    fail=$((fail + 1)); echo "FAIL mutant $g — the mutated checker CRASHED on:$crashed (a crash is not a kill)"
    continue
  fi
  KILLS[$g]="$k"
done

# encloses O G — true when O's kill set STRICTLY contains G's. A broad guard
# (leg 2 reports every unresolved link; xfile routes every cross-file link)
# necessarily kills every case a guard nested inside it detects, so demanding
# uniqueness against it is impossible by construction. Strict containment is
# the exemption, and it is deliberately narrow: two guards with IDENTICAL kill
# sets do not enclose each other, so both fail — that is the "a later leg
# became a second trigger for the only control" shape CLAUDE.md names.
encloses() {
  local x
  for x in ${KILLS[$2]}; do
    case " ${KILLS[$1]} " in *" $x "*) ;; *) return 1 ;; esac
  done
  [ "$(wc -w <<<"${KILLS[$1]}")" -gt "$(wc -w <<<"${KILLS[$2]}")" ]
}

for g in "${!KILLS[@]}"; do
  k="${KILLS[$g]}"
  if [ -z "$k" ]; then
    fail=$((fail + 1)); echo "FAIL mutant $g — SURVIVED: no case goes red with this guard removed"; continue
  fi
  uniq=""
  for c in $k; do
    shared=""
    for o in "${!KILLS[@]}"; do
      [ "$o" = "$g" ] && continue
      case " ${KILLS[$o]} " in *" $c "*) ;; *) continue ;; esac
      encloses "$o" "$g" || shared="$shared $o"
    done
    [ -z "$shared" ] && uniq="$uniq $c"
  done
  if [ -z "$uniq" ]; then
    fail=$((fail + 1)); echo "FAIL mutant $g — every case it kills is also killed by a guard that does not enclose it:$k"
  else
    pass=$((pass + 1)); echo "PASS mutant $g — killed by$k (unique:$uniq)"
  fi
done

echo "-- $pass/$((pass + fail)) checks passed --"
[ "$fail" = 0 ]

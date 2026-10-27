#!/usr/bin/env bash
# Controls for scripts/check-writeback-gap.sh — proves the check actually
# REPORTS. Read-only with respect to this repository: every synthetic case is
# planted into a throwaway fixture repo under $TMPDIR, never into the working
# tree. The `real_*` cases read this repo's own history and need it whole —
# the workflow checks out with fetch-depth: 0. A shallow clone makes them
# FAIL, never skip.
#
# Two halves:
#
#   CASES — each runs `--body-file body.txt --ref <ref>` and asserts rc, the
#     exact MISS and WARN counts, a required string and (where it matters) a
#     forbidden one. The headline pair is the instance the check exists for:
#     `real_pr17_pre` runs PR #17's body (committed verbatim as
#     scripts/fixtures/writeback-gap/pr17-body.txt) against `86332d8^`, the
#     tree before PR #79's write-back, and must name all four deferred
#     findings; `real_pr17_post` runs it against `86332d8` and must name ### 2
#     alone — the finding that stays open on purpose. `real_negative` cites a
#     file with 0 deferred findings and must report no WARN.
#   MUTANTS — every `# GUARD:<name>` line in the checker is replaced in turn
#     and the cases are re-run. Each mutant must turn at least one case red
#     that NO other mutant also turns red. CLAUDE.md: "Adding a leg to ANY
#     checker can silently uncover an existing leg", and coord@main declined
#     an enclosing-guard exception to that rule on 2026-10-22 (3acefe4), so
#     there is none here. A guard marker that is missing or present twice is a
#     FAIL, and so is a mutant that changes nothing.
#
# Adding a guard: mark its line `# GUARD:<name>`, add its replacement to MUT
# below, and add a case it uniquely kills. The suite fails until all three
# exist.
#
# Usage: bash scripts/check-writeback-gap-controls.sh
# Exit: 0 when every case and every mutant behaves as recorded. 1 otherwise.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$ROOT/scripts/check-writeback-gap.sh"
export CEPA_FINDINGS_CHECKER="$ROOT/plugins/cepa/scripts/check-findings-file.sh"
PR17="$ROOT/scripts/fixtures/writeback-gap/pr17-body.txt"
for f in "$CHECKER" "$CEPA_FINDINGS_CHECKER" "$PR17"; do
  [ -f "$f" ] || { echo "FATAL: missing $f"; exit 1; }
done
[ "${BASH_VERSINFO[0]}" -ge 4 ] || { echo "FATAL: bash >= 4 required (have $BASH_VERSION)"; exit 1; }

pass=0; fail=0
WORK="$(mktemp -d -t cepa-writeback-controls.XXXXXX)" || { echo "FATAL: mktemp failed"; exit 1; }
trap 'rm -rf "$WORK"' EXIT

# Replacement for each guard line (leading whitespace is kept). Each must be
# one statement that still parses.
MUT=(
  "accept|printf '%s\\n' \"\$t\""
  "deferred|grep -niE \"\${FIELD_PRE}status\${FIELD_POST}deferred\${VAL_TAIL}\" <<<\"\$lines\" | cut -d: -f1 > \"\$WORK/hits\""
  "ref|sha=\"\$ref\""
  "absent|:"
  "nobody|:"
  "norows|:"
  "outside|:"
)

# ---------------------------------------------------------------------------
# Fixtures. A case directory holds body.txt and, for a synthetic case, a git
# repo with one commit of the todos/ files given. A `.real` marker runs the
# case from $ROOT instead; a `.gha` marker sets GITHUB_ACTIONS=true.
# ---------------------------------------------------------------------------
CASES=()
mk() {  # $1 case name, $2 body; then pairs of (path, content)
  local d="$WORK/cases/$1"; mkdir -p "$d"
  printf '%s\n' "$2" > "$d/body.txt"; shift 2
  git -C "$d" init -q 2>/dev/null || { echo "FATAL: git init failed in $d"; exit 1; }
  while [ $# -ge 2 ]; do
    mkdir -p "$d/$(dirname "$1")"
    printf '%s\n' "$2" > "$d/$1"
    shift 2
  done
  git -C "$d" add -A -- . ':!body.txt' 2>/dev/null
  git -C "$d" -c user.name=c -c user.email=c@c commit -q --allow-empty -m fixture 2>/dev/null \
    || { echo "FATAL: commit failed in $d"; exit 1; }
}
mkreal() {  # $1 case name, $2 body file
  local d="$WORK/cases/$1"; mkdir -p "$d"
  cp "$2" "$d/body.txt"; : > "$d/.real"
}

# name | ref | want_rc | want_miss | want_warn | required text | forbidden text ('-' = none)
spec() { CASES+=("$1|$2|$3|$4|$5|$6|$7"); }

FM=$'---\nsummary:\n  total: 1\n---\n'
CITE='See [the review](todos/a.md).'

# --- the headline instance, on this repo's own history ---
mkreal real_pr17_pre "$PR17"
spec real_pr17_pre '86332d8^' 0 0 1 "todos/review-2026-07-12-115234.md, which holds 4 deferred finding(s): ### 1, ### 2, ### 3, ### 4 at" -
mkreal real_pr17_post "$PR17"
spec real_pr17_post 86332d8 0 0 1 "todos/review-2026-07-12-115234.md, which holds 1 deferred finding(s): ### 2 at" -
printf 'Gauntlet: [review](todos/review-2026-07-12-145044.md)\n' > "$WORK/neg-body.txt"
mkreal real_negative "$WORK/neg-body.txt"
spec real_negative 86332d8 0 0 0 "cites todos/review-2026-07-12-145044.md: 0 deferred of" -

# --- status spellings the shipped pattern reads ---
mk bold "$CITE" todos/a.md "${FM}"$'### 1\n- **status:** deferred'
spec bold HEAD 0 0 1 "1 deferred finding(s): ### 1 at" -
mk indented "$CITE" todos/a.md "${FM}"$'### 1\n  status: deferred'
spec indented HEAD 0 0 1 "1 deferred finding(s): ### 1 at" -
mk positional "$CITE" todos/a.md "${FM}"$'### 1\n- **confidence:** 90 · **status:** deferred'
spec positional HEAD 0 0 1 "1 deferred finding(s): ### 1 at" -
mk capital "$CITE" todos/a.md "${FM}"$'### 1\n- Status: Deferred'
spec capital HEAD 0 0 1 "1 deferred finding(s): ### 1 at" -
mk tail_comment "$CITE" todos/a.md "${FM}"$'### 1\n- status: deferred (decided 2026-07-12, awaiting a verification)'
spec tail_comment HEAD 0 0 1 "1 deferred finding(s): ### 1 at" -
mk not_deferred "$CITE" todos/a.md "${FM}"$'### 1\n- status: deferred-later\n\n### 2\n- status: applied'
spec not_deferred HEAD 0 0 0 "0 deferred of 2 finding(s)" -
mk clean "$CITE" todos/a.md "${FM}"$'### 1\n- status: applied\n\n### 2\n- status: completed'
spec clean HEAD 0 0 0 "0 deferred of 2 finding(s)" -
mk subheading "$CITE" todos/a.md "${FM}"$'### 1\n- status: applied\n\n#### Note\n- status: deferred'
spec subheading HEAD 0 0 1 "1 deferred finding(s): ### 1 at" -
mk range "$CITE" todos/a.md "${FM}"$'### 4\n- status: deferred\n\n### 4-6\n- status: deferred\n\n### 10\n- status: deferred'
spec range HEAD 0 0 1 "3 deferred finding(s): ### 4, ### 4-6, ### 10 at" -
mk outside "$CITE" todos/a.md "${FM}"$'### 1\n- status: applied\n\n## Notes\n- status: deferred'
spec outside HEAD 0 0 1 "1 deferred row(s) outside any ### N heading" -

# --- quoted forms: a deferred status inside a record must not fire ---
mk quoted_prose "$CITE" todos/a.md "${FM}"$'### 1\n- status: applied\n\n**Fix:** set\n`status: deferred` on the row.'
spec quoted_prose HEAD 0 0 0 "0 deferred of 1 finding(s)" -
mk quoted_fence "$CITE" todos/a.md "${FM}"$'### 1\n- status: applied\n\n```yaml\n- status: deferred\n```'
spec quoted_fence HEAD 0 0 0 "0 deferred of 1 finding(s)" -
mk frontmatter_counter "$CITE" todos/a.md $'---\nsummary:\n  deferred: 3\n---\n### 1\n- status: applied'
spec frontmatter_counter HEAD 0 0 0 "0 deferred of 1 finding(s)" -

# --- citation forms ---
D="${FM}"$'### 1\n- status: deferred'
mk forms $'./todos/a.md and /todos/b.md\nhttps://github.com/o/r/blob/main/todos/c.md\n[x](todos/d.md)' \
  todos/a.md "$D" todos/b.md "$D" todos/c.md "$D" todos/d.md "$D"
spec forms HEAD 0 0 4 "4 citation(s)" -
mk dedup $'[todos/a.md](todos/a.md) and again `todos/a.md`' todos/a.md "$D"
spec dedup HEAD 0 0 1 "1 citation(s)" -
mk nested $'plugins/x/todos/a.md, mytodos/a.md, todos/sub/a.md' todos/a.md "$D"
spec nested HEAD 0 0 0 "cites no todos/*.md file" -
mk nocite 'Nothing cited here.' todos/a.md "$D"
spec nocite HEAD 0 0 0 "cites no todos/*.md file" -
mk absent 'See todos/gone.md.' todos/a.md "$D"
spec absent HEAD 0 0 1 "todos/gone.md, which is not a file at" -

# --- probes that did not reach their target ---
mk norows "$CITE" todos/a.md "${FM}"$'### 1\nA finding with no fields.'
spec norows HEAD 1 1 0 "ZERO status rows" -
mk nobody "$CITE" todos/a.md $'### 1\n- status: deferred'
spec nobody HEAD 1 1 0 "none survived body extraction" -
mk badref "$CITE" todos/a.md "$D"
spec badref no-such-ref 1 1 0 "does not resolve to a commit" -

# --- the body is untrusted ---
mk inject $'::error::forged\n::stop-commands::x\ntodos/$(touch PWNED).md todos/a.md\r' todos/a.md "$D"
spec inject HEAD 0 0 1 "1 deferred finding(s): ### 1 at" "::error"
mk annotate "$CITE" todos/a.md "$D"
: > "$WORK/cases/annotate/.gha"
spec annotate HEAD 0 0 1 "::warning title=Write-back gap::the body cites todos/a.md" -

# ---------------------------------------------------------------------------
# Runner. Echoes "" when the case behaves as recorded, else the reason.
# ---------------------------------------------------------------------------
run_case() {  # $1 checker file, $2 spec line
  local chk="$1" name ref want_rc want_miss want_warn want_text forbid d dir out rc m w gha=false
  IFS='|' read -r name ref want_rc want_miss want_warn want_text forbid <<<"$2"
  d="$WORK/cases/$name"; dir="$d"
  [ -e "$d/.real" ] && dir="$ROOT"
  [ -e "$d/.gha" ] && gha=true
  rm -f "$dir/PWNED"
  out="$(cd "$dir" && GITHUB_ACTIONS=$gha bash "$chk" --body-file "$d/body.txt" --ref "$ref" 2>&1)"; rc=$?
  m="$(grep -c '^MISS' <<<"$out")"
  w="$(grep -c '^WARN' <<<"$out")"
  if [ -e "$dir/PWNED" ]; then rm -f "$dir/PWNED"; echo "the body EXECUTED a command"; return; fi
  if [ "$rc" != "$want_rc" ]; then echo "rc=$rc want $want_rc"; return; fi
  if [ "$m" != "$want_miss" ]; then echo "MISS=$m want $want_miss"; return; fi
  if [ "$w" != "$want_warn" ]; then echo "WARN=$w want $want_warn"; return; fi
  if [ "$want_text" != - ] && ! grep -qF -- "$want_text" <<<"$out"; then echo "missing text: $want_text"; return; fi
  if [ "$forbid" != - ] && grep -qF -- "$forbid" <<<"$out"; then echo "forbidden text present: $forbid"; return; fi
  echo ""
}

echo "== cases (unmutated checker)"
for c in "${CASES[@]}"; do
  r="$(run_case "$CHECKER" "$c")"
  if [ -z "$r" ]; then pass=$((pass + 1)); echo "PASS ${c%%|*}"
  else fail=$((fail + 1)); echo "FAIL ${c%%|*} — $r"; fi
done

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
    fail=$((fail + 1)); echo "FAIL mutant $g — marker found $n time(s), want exactly 1"
    continue
  fi
  if ! G="$g" REP="$rep" python3 - "$CHECKER" "$mf" <<'PY'
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
  then
    fail=$((fail + 1)); echo "FAIL mutant $g — the mutant builder failed"; continue
  fi
  if cmp -s "$CHECKER" "$mf"; then
    fail=$((fail + 1)); echo "FAIL mutant $g — mutated file is identical to the checker"; continue
  fi
  if ! bash -n "$mf" 2>/dev/null; then
    fail=$((fail + 1)); echo "FAIL mutant $g — the mutated checker does not parse (a crash is not a kill)"; continue
  fi
  k=""
  for c in "${CASES[@]}"; do
    r="$(run_case "$mf" "$c")"
    [ -n "$r" ] && k="$k ${c%%|*}"
  done
  KILLS[$g]="$k"
done

for g in "${!KILLS[@]}"; do
  k="${KILLS[$g]}"
  if [ -z "$k" ]; then
    fail=$((fail + 1)); echo "FAIL mutant $g — SURVIVED: no case goes red with this guard replaced"; continue
  fi
  uniq=""
  for c in $k; do
    shared=""
    for o in "${!KILLS[@]}"; do
      [ "$o" = "$g" ] && continue
      case " ${KILLS[$o]} " in *" $c "*) shared="$shared $o" ;; esac
    done
    [ -z "$shared" ] && uniq="$uniq $c"
  done
  if [ -z "$uniq" ]; then
    fail=$((fail + 1)); echo "FAIL mutant $g — every case it kills is also killed by another guard:$k"
  else
    pass=$((pass + 1)); echo "PASS mutant $g — killed by$k (unique:$uniq)"
  fi
done

echo "-- $pass/$((pass + fail)) checks passed --"
[ "$fail" = 0 ]

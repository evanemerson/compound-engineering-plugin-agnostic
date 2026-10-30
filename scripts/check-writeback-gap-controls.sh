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
#     FAIL, and so is a mutant that changes nothing or that CRASHES (a shell
#     error reddens a case without testing the predicate it replaced).
#
# Every case runs with a stub `gh` first on PATH, answering from the case's
# own files, so the `--pr`, `--commit` and `--replay` modes are covered and no
# case can reach the network.
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
# one statement that still parses. Read from a quoted heredoc, so no entry is
# re-escaped for the shell.
MUT=()
while IFS= read -r l; do [ -n "$l" ] && MUT+=("$l"); done <<'EOF'
gha|printf '::warning title=Write-back gap::%s\n' "$m"
accept|if [[ "$name" =~ $CITE_NAME ]]; then printf 'A %s\n' "$name"; else printf 'X\n'; fi
deferred|grep -niE "${FIELD_PRE}status${FIELD_POST}deferred${VAL_TAIL}" <<<"$lines" | cut -d: -f1 > "$WORK/hits"
ref|sha="$ref"
rejected|:
absent|:
mode|:
fence|:
nobody|:
nofindings|:
norows|:
idsuniq|ids="$(sed -n 's/^D //p' <<<"$out" | grep -v '^-$' | sort -t- -k1,1n -k2,2n | sed 's/^/### /' | paste -sd, - | sed 's/,/, /g')"
nduniq|nd="$(sed -n 's/^D //p' <<<"$out" | grep -v '^-$' | grep -c .)"
outside|:
flagged|:
subject|:
zerototal|zero=0
EOF

# A stub `gh`, FIRST on PATH for every case, so no case can reach the network.
# It answers from files in the case's .gh/ directory (already in the shape
# `--jq` would print), and exits 1 when that directory is absent or holds
# `fail`.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
d="${STUB_GH:-}"
{ [ -n "$d" ] && [ -d "$d" ] && [ ! -e "$d/fail" ]; } || exit 1
a="$*"
case "$a" in
  *"pulls?state=closed"*) cat "$d/list" ;;
  *"/commits/"*"/pulls"*) s="${a#*/commits/}"; s="${s%%/*}"; [ ! -e "$d/assoc-$s" ] || cat "$d/assoc-$s" ;;
  *"merge_commit_sha //"*) n="${a#*/pulls/}"; n="${n%% *}"; cat "$d/merge-$n" ;;
  *"/pulls/"*) n="${a#*/pulls/}"; n="${n%% *}"; cat "$d/body-$n" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$WORK/bin/gh"

# The real_* cases need 86332d8 and its parent. Say so once, by name, rather
# than leave three bare "ref does not resolve" failures to be decoded.
if ! git -C "$ROOT" cat-file -e '86332d8^{commit}' 2>/dev/null || ! git -C "$ROOT" cat-file -e '86332d8^^{commit}' 2>/dev/null; then
  fail=$((fail + 1)); echo "FAIL preflight — 86332d8 or its parent is not in this clone (shallow?): check out with fetch-depth: 0"
fi

# ---------------------------------------------------------------------------
# Fixtures. A case directory holds body.txt and, for a synthetic case, a git
# repo with one commit of the todos/ files given (a path `@symlink:P` makes P a
# symlink to its content; MK_MSG sets the commit subject). A `.real` marker
# runs the case from $ROOT instead; a `.gha` marker sets GITHUB_ACTIONS=true;
# .gh/ holds the stub's answers.
# ---------------------------------------------------------------------------
CASES=()
mk() {  # $1 case name, $2 body; then pairs of (path, content)
  local d="$WORK/cases/$1" p; mkdir -p "$d/.gh"
  printf '%s\n' "$2" > "$d/body.txt"; shift 2
  git -C "$d" init -q 2>/dev/null || { echo "FATAL: git init failed in $d"; exit 1; }
  while [ $# -ge 2 ]; do
    p="${1#@symlink:}"
    mkdir -p "$d/$(dirname "$p")"
    if [ "$p" != "$1" ]; then ln -s "$2" "$d/$p"; else printf '%s\n' "$2" > "$d/$p"; fi
    shift 2
  done
  git -C "$d" add -A -- . ':!body.txt' ':!.gh' 2>/dev/null
  git -C "$d" -c user.name=c -c user.email=c@c commit -q --allow-empty -m "${MK_MSG:-fixture}" 2>/dev/null \
    || { echo "FATAL: commit failed in $d"; exit 1; }
}
mkreal() {  # $1 case name, $2 body file
  local d="$WORK/cases/$1"; mkdir -p "$d"
  cp "$2" "$d/body.txt"; : > "$d/.real"
}
head_of() { git -C "$WORK/cases/$1" rev-parse HEAD; }
stub() {  # $1 case, $2 answer file, $3 content
  printf '%s\n' "$3" > "$WORK/cases/$1/.gh/$2"
}

# name | args (@BODY = the case's body.txt, @HEAD = its fixture commit) |
# want_rc | want_miss | want_warn | required text | forbidden texts, ^-separated
# ('-' = none)
spec() { CASES+=("$1|$2|$3|$4|$5|$6|$7"); }
BF='--body-file @BODY --ref'

FM=$'---\nsummary:\n  total: 1\n---\n'
CITE='See [the review](todos/a.md).'
D="${FM}"$'### 1\n- status: deferred'

# --- the headline instance, on this repo's own history ---
mkreal real_pr17_pre "$PR17"
spec real_pr17_pre "$BF 86332d8^" 0 0 1 "todos/review-2026-07-12-115234.md, which holds 4 deferred finding(s): ### 1, ### 2, ### 3, ### 4 at" -
mkreal real_pr17_post "$PR17"
spec real_pr17_post "$BF 86332d8" 0 0 1 "todos/review-2026-07-12-115234.md, which holds 1 deferred finding(s): ### 2 at" -
printf 'Gauntlet: [review](todos/review-2026-07-12-145044.md)\n' > "$WORK/neg-body.txt"
mkreal real_negative "$WORK/neg-body.txt"
spec real_negative "$BF 86332d8" 0 0 0 "cites todos/review-2026-07-12-145044.md: 0 deferred of" -

# --- status spellings the shipped pattern reads ---
mk bold "$CITE" todos/a.md "${FM}"$'### 1\n- **status:** deferred'
spec bold "$BF HEAD" 0 0 1 "1 deferred finding(s): ### 1 at" "::warning"
mk indented "$CITE" todos/a.md "${FM}"$'### 1\n  status: deferred'
spec indented "$BF HEAD" 0 0 1 "1 deferred finding(s): ### 1 at" -
mk positional "$CITE" todos/a.md "${FM}"$'### 1\n- **confidence:** 90 · **status:** deferred'
spec positional "$BF HEAD" 0 0 1 "1 deferred finding(s): ### 1 at" -
mk capital "$CITE" todos/a.md "${FM}"$'### 1\n- Status: Deferred'
spec capital "$BF HEAD" 0 0 1 "1 deferred finding(s): ### 1 at" -
mk tail_comment "$CITE" todos/a.md "${FM}"$'### 1\n- status: deferred (decided 2026-07-12, awaiting a verification)'
spec tail_comment "$BF HEAD" 0 0 1 "1 deferred finding(s): ### 1 at" -
mk not_deferred "$CITE" todos/a.md "${FM}"$'### 1\n- status: deferred-later\n\n### 2\n- status: applied'
spec not_deferred "$BF HEAD" 0 0 0 "0 deferred of 2 finding(s)" -
mk clean "$CITE" todos/a.md "${FM}"$'### 1\n- status: applied\n\n### 2\n- status: completed'
spec clean "$BF HEAD" 0 0 0 "0 deferred of 2 finding(s)" -
mk subheading "$CITE" todos/a.md "${FM}"$'### 1\n- status: applied\n\n#### Note\n- status: deferred'
spec subheading "$BF HEAD" 0 0 1 "1 deferred finding(s): ### 1 at" -
mk range "$CITE" todos/a.md "${FM}"$'### 4\n- status: deferred\n\n### 4-6\n- status: deferred\n\n### 10\n- status: deferred'
spec range "$BF HEAD" 0 0 1 "3 deferred finding(s): ### 4, ### 4-6, ### 10 at" -
mk dup_ids "$CITE" todos/a.md "${FM}"$'### 1\n- status: deferred\n- **status:** deferred'
spec dup_ids "$BF HEAD" 0 0 1 "finding(s): ### 1 at" -
mk dup_count "$CITE" todos/a.md "${FM}"$'### 1\n- status: deferred\n- **status:** deferred'
spec dup_count "$BF HEAD" 0 0 1 "1 deferred finding(s)" -
mk outside "$CITE" todos/a.md "${FM}"$'### 1\n- status: applied\n\n## Notes\n- status: deferred'
spec outside "$BF HEAD" 0 0 1 "1 deferred row(s) outside any ### N heading" -
mk h1_boundary "$CITE" todos/a.md "${FM}"$'### 1\n- status: applied\n\n# Appendix\n- status: deferred'
spec h1_boundary "$BF HEAD" 0 0 1 "1 deferred row(s) outside any ### N heading" -
mk mixed "$CITE" todos/a.md "${FM}"$'### 1\n- status: deferred\n\n## Notes\n- status: deferred'
spec mixed "$BF HEAD" 0 0 1 "1 deferred finding(s): ### 1; 1 deferred row(s) outside any ### N heading" -

# --- quoted forms: a deferred status inside a record must not fire ---
mk quoted_prose "$CITE" todos/a.md "${FM}"$'### 1\n- status: applied\n\n**Fix:** set\n`status: deferred` on the row.'
spec quoted_prose "$BF HEAD" 0 0 0 "0 deferred of 1 finding(s)" -
mk quoted_fence "$CITE" todos/a.md "${FM}"$'### 1\n- status: applied\n\n```yaml\n- status: deferred\n```'
spec quoted_fence "$BF HEAD" 0 0 0 "0 deferred of 1 finding(s)" -
mk frontmatter_counter "$CITE" todos/a.md $'---\nsummary:\n  deferred: 3\n---\n### 1\n- status: applied'
spec frontmatter_counter "$BF HEAD" 0 0 0 "0 deferred of 1 finding(s)" -

# --- citation forms ---
mk forms $'./todos/a.md and /todos/b.md\nhttps://github.com/o/r/blob/main/todos/c.md\n[x](todos/d.md)\n[y](../todos/e.md)\nhttps://github.com/o/r/blob/fix/wt/x/todos/f.md and https://github.com/o/r/tree/main/todos/g.md' \
  todos/a.md "$D" todos/b.md "$D" todos/c.md "$D" todos/d.md "$D" todos/e.md "$D" todos/f.md "$D" todos/g.md "$D"
spec forms "$BF HEAD" 0 0 7 "7 citation(s)" -
mk dedup $'[todos/a.md](todos/a.md) and again `todos/a.md`' todos/a.md "$D"
spec dedup "$BF HEAD" 0 0 1 "1 citation(s)" -
mk nested $'plugins/x/todos/a.md, mytodos/a.md, todos/sub/a.md' todos/a.md "$D"
spec nested "$BF HEAD" 0 0 0 "cites no todos/*.md file" -
mk mdx 'See todos/a.mdx.' todos/a.md "$D"
spec mdx "$BF HEAD" 0 0 0 "holds a todos/ token in a form that is not a citation" -
mk nocite 'Nothing cited here.' todos/a.md "$D"
spec nocite "$BF HEAD" 0 0 0 "cites no todos/*.md file" "not a citation"
mk absent 'See todos/gone.md.' todos/a.md "$D"
spec absent "$BF HEAD" 0 0 1 "todos/gone.md, which is not a file at" -
mk symlink 'See todos/s.md.' todos/a.md "$D" @symlink:todos/s.md a.md
spec symlink "$BF HEAD" 1 1 0 "is not a regular file" -
mk multi "$CITE and todos/b.md" todos/a.md "${FM}"$'### 1\nno fields' todos/b.md "$D"
spec multi "$BF HEAD" 1 1 1 "todos/b.md, which holds 1 deferred finding(s): ### 1 at" -

# --- probes that did not reach their target ---
mk norows "$CITE" todos/a.md "${FM}"$'### 1\nA finding with no fields.'
spec norows "$BF HEAD" 1 1 0 "ZERO status rows" -
mk nobody "$CITE" todos/a.md $'### P1-1 thing\n- status: deferred'
spec nobody "$BF HEAD" 1 1 0 "none survived body extraction" -
mk nobody_bom "$CITE" todos/a.md $'\xef\xbb\xbf---\nsummary:\n  total: 1\n---\n### 1\n- status: deferred'
spec nobody_bom "$BF HEAD" 1 1 0 "none survived body extraction" -
mk nofindings "$CITE" todos/a.md $'# A prompt\n\nNo findings here.'
spec nofindings "$BF HEAD" 0 0 1 "it was not checked as a findings file" -
mk zerototal "$CITE" todos/a.md $'---\nsummary:\n  total: 0\n---\n# Review (clean)\n\nNothing found.'
spec zerototal "$BF HEAD" 0 0 0 "declares total: 0 and holds no finding" -
mk fence_unclosed "$CITE" todos/a.md "${FM}"$'### 1\n- status: applied\n\n```bash\necho x\n\n### 2\n- status: deferred'
spec fence_unclosed "$BF HEAD" 1 1 0 "fence open" -
mk fence_tilde "$CITE" todos/a.md "${FM}"$'### 1\n- status: applied\n\n~~~md\n```\n~~~\n\n### 2\n- status: deferred'
spec fence_tilde "$BF HEAD" 1 1 0 "fence open" -
mk badref "$CITE" todos/a.md "$D"
spec badref "$BF no-such-ref" 1 1 0 "does not resolve to a commit" -

# --- the body is untrusted ---
mk inject $'::error::forged\n::stop-commands::x\ntodos/$(touch PWNED).md todos/a.md::error::y [z](todos/a.md%0a::error::w)\r' todos/a.md "$D"
spec inject "$BF HEAD" 0 0 1 "1 deferred finding(s): ### 1 at" "::error^forged^stop-commands^PWNED^\$("
mk annotate "$CITE" todos/a.md "$D"
: > "$WORK/cases/annotate/.gha"
spec annotate "$BF HEAD" 0 0 1 "::warning title=Write-back gap::the body cites todos/a.md" -

# --- the API modes, against the stub ---
mk pr_ok '-' todos/a.md "$D"
stub pr_ok body-17 "$CITE"
spec pr_ok "--pr 17 --ref HEAD" 0 0 1 "PR #17 cites todos/a.md, which holds 1 deferred" -
mk pr_fail '-' todos/a.md "$D"
spec pr_fail "--pr 17" 1 1 0 "PR #17: fetching its body failed" -
mk usage_bad '-' todos/a.md "$D"
spec usage_bad "--pr 1;id" 2 0 0 - -
mk commit_assoc '-' todos/a.md "$D"
stub commit_assoc "assoc-$(head_of commit_assoc)" 17
stub commit_assoc body-17 "$CITE"
spec commit_assoc "--commit @HEAD" 0 0 1 "PR #17 cites todos/a.md" -
mk commit_direct '-' todos/a.md "$D"
spec commit_direct "--commit @HEAD" 0 0 0 "(a direct push)" -
MK_MSG='feat: x (#17)' mk commit_subject '-' todos/a.md "$D"
stub commit_subject "merge-17" "$(head_of commit_subject)"
stub commit_subject body-17 "$CITE"
spec commit_subject "--commit @HEAD" 0 0 1 "PR #17 cites todos/a.md" -
MK_MSG='feat: x (#17)' mk commit_subject_other '-' todos/a.md "$D"
stub commit_subject_other "merge-17" 0000000000000000000000000000000000000001
spec commit_subject_other "--commit @HEAD" 0 0 0 "(a direct push)" -
mk commit_fail '-' todos/a.md "$D"
: > "$WORK/cases/commit_fail/.gh/fail"
spec commit_fail "--commit @HEAD" 1 1 0 "looking up its merged PR failed" -
mk replay_ok '-' todos/a.md "$D"
stub replay_ok list "$(printf '18 %s %s\n17 %s %s' "$(head_of replay_ok)" "$(printf 'nothing' | base64 -w0)" "$(head_of replay_ok)" "$(printf '%s' "$CITE" | base64 -w0)")"
spec replay_ok "--replay" 0 0 1 "-- replay flagged: #17 --" -
mk replay_empty '-' todos/a.md "$D"
stub replay_empty list ''
spec replay_empty "--replay" 1 1 0 "a replay over nothing is not a pass" -
mk replay_badrow '-' todos/a.md "$D"
stub replay_badrow list 'x y z'
spec replay_badrow "--replay" 1 2 0 "malformed row" -

# ---------------------------------------------------------------------------
# Runner. Echoes "" when the case behaves as recorded, else the reason.
# ---------------------------------------------------------------------------
run_case() {  # $1 checker file, $2 spec line
  local chk="$1" name args want_rc want_miss want_warn want_text forbid d dir out rc m w gha=false head x
  local -a argv forbids
  IFS='|' read -r name args want_rc want_miss want_warn want_text forbid <<<"$2"
  d="$WORK/cases/$name"; dir="$d"
  [ -e "$d/.real" ] && dir="$ROOT"
  [ -e "$d/.gha" ] && gha=true
  head="$(git -C "$d" rev-parse HEAD 2>/dev/null)"
  args="${args//@BODY/$d/body.txt}"; args="${args//@HEAD/$head}"
  read -ra argv <<<"$args"
  rm -f "$dir/PWNED"
  out="$(cd "$dir" && PATH="$WORK/bin:$PATH" STUB_GH="$d/.gh" GITHUB_ACTIONS=$gha bash "$chk" "${argv[@]}" 2>&1)"; rc=$?
  m="$(grep -c '^MISS' <<<"$out")"
  w="$(grep -c '^WARN' <<<"$out")"
  if [ -e "$dir/PWNED" ]; then rm -f "$dir/PWNED"; echo "the body EXECUTED a command"; return; fi
  # A shell error is a crash, not a verdict: a mutant that dies under `set -u`
  # reddens a case without testing the predicate it replaced.
  if grep -qE 'unbound variable|command not found|syntax error|integer expression expected' <<<"$out"; then echo CRASH; return; fi
  if [ "$rc" != "$want_rc" ]; then echo "rc=$rc want $want_rc"; return; fi
  if [ "$m" != "$want_miss" ]; then echo "MISS=$m want $want_miss"; return; fi
  if [ "$w" != "$want_warn" ]; then echo "WARN=$w want $want_warn"; return; fi
  if [ "$want_text" != - ] && ! grep -qF -- "$want_text" <<<"$out"; then echo "missing text: $want_text"; return; fi
  if [ "$forbid" != - ]; then
    IFS='^' read -ra forbids <<<"$forbid"
    for x in "${forbids[@]}"; do
      if grep -qF -- "$x" <<<"$out"; then echo "forbidden text present: $x"; return; fi
    done
  fi
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
  k=""; crashed=""
  for c in "${CASES[@]}"; do
    r="$(run_case "$mf" "$c")"
    [ "$r" = CRASH ] && crashed="$crashed ${c%%|*}"
    [ -n "$r" ] && k="$k ${c%%|*}"
  done
  if [ -n "$crashed" ]; then
    fail=$((fail + 1)); echo "FAIL mutant $g — the mutated checker CRASHED on:$crashed (a crash is not a kill)"
    continue
  fi
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

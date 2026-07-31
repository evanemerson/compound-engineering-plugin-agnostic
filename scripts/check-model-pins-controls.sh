#!/usr/bin/env bash
# Controls for scripts/check-model-pins.sh — proves the checker still
# responds the way its record says it does. Read-only with respect to this
# repository: every case is planted into a throwaway copy of the tree, never
# into the working tree.
#
# WHY THIS EXISTS. The checker's leg 4 shipped broken three times in a row
# during one PR, and each review round caught the previous round's fix. All
# three defects had the same shape — a control suite that exercised only the
# branch it happened to reach:
#
#   round 1  a delimiter bug dropped every UNQUALIFIED citation (all 7
#            anchors this repo defines). All four controls in use put a word
#            before the section sign, so all four took the QUALIFIED branch
#            and the unqualified branch ran zero times.
#   round 2  a wrong-owner citation whose owner token was separated from its
#            anchor by a line break silently took the permissive branch. All
#            three qualified controls were single-line.
#   round 3  a widening reached three of the checker's four file-selection
#            sites, so a `.markdown` file was readable by leg 4 and invisible
#            to the legs that check dispatch pins.
#
# The remedy was to record 24 cases as explicit case BODIES rather than
# category names — "qualified" and "unqualified" were both *believed* covered
# in round 1. This file is those bodies made runnable, because a hand-run
# suite decays back to category coverage as soon as the reasoning ages out of
# someone's head.
#
# A case that asserts only a COUNT passes when the checker misses for an
# unrelated reason, which is how a control suite ends up proving nothing. So
# every case asserts the exact MISS/WARN counts AND a regex the output must
# match — usually the specific message naming the planted anchor.
#
# Cases that expect ZERO misses are not filler: they are the false-positive
# guards. Two of them (10a, 10b) pin a RECORDED LIMIT rather than correct
# behavior — see their case bodies before "fixing" them.
#
# Usage:
#   bash scripts/check-model-pins-controls.sh              # run all
#   bash scripts/check-model-pins-controls.sh --list       # ids and titles
#   bash scripts/check-model-pins-controls.sh --only 7,10a # a subset
#   bash scripts/check-model-pins-controls.sh --keep       # keep fixtures
set -u

KEEP=0
ONLY=''
LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1 ;;
    --list) LIST=1 ;;
    --only) shift; ONLY="${1:-}" ;;
    --only=*) ONLY="${1#--only=}" ;;
    -h|--help) sed -n '1,60p' "$0"; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  printf 'FATAL: not inside a git work tree — the fixture is built from `git ls-files`\n' >&2
  exit 2
}
# `CEPA_PIN_CHECKER` exists for MUTATION TESTING: point the suite at a
# deliberately broken copy of the checker and confirm the controls go red. A
# control suite that passes on a broken checker proves nothing, and that is
# not hypothetical here — all three defects named above shipped past a green
# hand-run suite. The run header prints the path actually used, so an override
# cannot hide. CI must never set it.
CHECKER="${CEPA_PIN_CHECKER:-$REPO_ROOT/scripts/check-model-pins.sh}"
[ -r "$CHECKER" ] || { printf 'FATAL: no checker at %s\n' "$CHECKER" >&2; exit 2; }

# The section sign in every planted citation and every expected message is
# CONSTRUCTED here, never written literally below. `scripts/` is one of leg
# 4's citation roots, it is scanned whole, and leg 4 has no prose-suppression
# hatch (autonomy §9f) — so a literal deliberately-broken anchor in this file
# would be a real citation to a heading that does not exist, and this suite
# would fail the very checker it tests. Building them at runtime keeps leg 4
# scanning `scripts/` with NO exemption: the file genuinely contains no such
# citation, rather than carrying one the checker has been told to ignore.
# Narrowing the checker to make its own controls pass would have been the
# other way out, and it is the wrong one.
#
# Citations to REAL sections (autonomy §9f, above and below) stay literal on
# purpose — those should resolve, and leg 4 should check that they do.
SS=$'\302\247'

# ---------------------------------------------------------------------------
# Case registry
# ---------------------------------------------------------------------------
# reg <id> <title> <expect_misses> <expect_warns> <expect_re> <forbid_re> <why>
#
# expect_misses / expect_warns: an exact integer, or `+` for "at least one"
# (used only where the exact count is a property of how many citations the
# repo happens to contain today, which is not what the case is about).
IDS=(); TITLES=(); EXP_MISS=(); EXP_WARN=(); EXP_RE=(); FORBID_RE=(); WHY=()
reg() {
  IDS+=("$1"); TITLES+=("$2"); EXP_MISS+=("$3"); EXP_WARN+=("$4")
  EXP_RE+=("$5"); FORBID_RE+=("$6"); WHY+=("$7")
}

# The message the checker emits for an unresolvable UNQUALIFIED citation, and
# for an unresolvable QUALIFIED one. Backticks in the real text are matched
# with `.` so the patterns need no backtick escaping.
UNQUAL_9Q="${SS}9q is cited but no .* has a '### 9q\\.' heading"
# Qualified misses: <anchor> cited as `<owner>` but that skill has no heading.
qual_miss() { printf "%s%s is cited as .%s. %s%s but %s/SKILL\\.md has no '### %s\\.' heading" \
  "$SS" "$2" "$1" "$SS" "$2" "$1" "$2"; }

# --- Leg 4: citation shapes (the round-1 class) -----------------------------
# Cases 1-5 are the unqualified shapes. Case 6 is their control: a plain
# English word before the anchor must NOT take the qualified branch.
#
# Verified by re-introducing the round-1 defect into a copy of the checker
# (the `|` row delimiter back to a tab, in both the emit and the parse):
# cases 1-5 and 19 go red, and case 6 stays GREEN. That asymmetry is the
# whole point. Case 6's row carries a non-empty qualifier field, so it
# survives the field collapse that swallows every genuinely unqualified
# citation — which is exactly why a suite made only of case-6-shaped controls
# passed while the defect shipped. Case 6 is not redundant with 1-5; it is
# what isolates the empty qualifier field as the cause.
#
# The same run confirmed the checker's BASELINE stayed at 0 MISS under that
# defect. The baseline gate cannot catch it. Only these cases can.
reg 1 'line-initial unqualified citation' 1 0 "$UNQUAL_9Q" '' \
  'round 1: every unqualified citation was silently dropped'
reg 2 'parenthesized citation' 1 0 "$UNQUAL_9Q" '' \
  'a leading ( leaves no qualifier token'
reg 3 'quoted citation' 1 0 "$UNQUAL_9Q" '' \
  'a leading double quote leaves no qualifier token'
reg 4 'em-dashed citation' 1 0 "$UNQUAL_9Q" '' \
  'an em dash is outside the qualifier charset'
reg 5 'leading-dash token before the anchor' 1 0 "$UNQUAL_9Q" '' \
  'the checker blanks a qualifier starting with - (sanitization)'
reg 6 'plain word qualifier — control for cases 1-5' 1 0 "$UNQUAL_9Q" '' \
  'a non-skill word must fall to the unqualified branch, not claim ownership'

reg 7 'wrong owner, lowercase' 1 0 "$(qual_miss grounding 9c)" '' \
  'the qualified branch must reject an owner that does not define the anchor'
reg 8 'wrong owner, capitalized' 1 0 "$(qual_miss grounding 9c)" '' \
  'qualifier case folding — `Grounding` must resolve like `grounding`'
reg 9 'correct owner resolves clean' 0 0 '' '^MISS ' \
  'false-positive guard: a correct qualified citation must not fail the build'

# Case 10 pins a RECORDED LIMIT (cepa:autonomy §9f), not correct behavior.
# The checker captures exactly ONE token immediately preceding the anchor, so
# a wrong owner separated from its anchor — by a line break or by an
# intervening word — silently takes the permissive unqualified branch. Both
# shapes are live in this repo's prose. `forbid_re` is the wrong-owner
# message: if the hole is ever closed, these two cases FAIL loudly and point
# at themselves for update, instead of passing for the wrong reason.
reg 10a 'recorded limit — wrong owner separated by a line break' 0 0 '' \
  'cited as .grounding.' 'cepa:autonomy §9f: grep is line-based; this repo hard-wraps'
reg 10b 'recorded limit — wrong owner separated by an intervening word' 0 0 '' \
  'cited as .grounding.' 'cepa:autonomy §9f: reflow does not fix the intervening-word shape'

reg 11 'multi-letter anchor' 1 0 "$(qual_miss autonomy 9qz)" '' \
  'a single-letter character class made grep -o truncate a two-letter anchor'
reg 12 'uppercase anchor' 1 0 "$(qual_miss autonomy 9q)" '' \
  'anchors are matched case-insensitively and lowercased before lookup'
reg 13 'range second endpoint' 1 0 "$(qual_miss autonomy 9q)" '' \
  'without range expansion the second half of every range is verified by nothing'
reg 14 'triple range' 1 0 "$(qual_miss autonomy 9q)" '' \
  'expansion must not stop after the first hyphen'
reg 15 'hyphenated English after an anchor' 0 0 '' '^MISS ' \
  'round 2: an unnumbered range tail invented anchors from ordinary prose'

# --- Leg 4: root accounting (the round-1 exit-code class) -------------------
reg 16 'citation root removed' 1 0 \
  "leg 4 citation root '\\.github' does not exist" '' \
  'round 1: a vanished root passed at 0 MISS while INFO still reported all five'
reg 17 'root present, include set matches nothing' 1 0 \
  "leg 4 root '\\.github' holds no file matching the --include set" '' \
  'a renamed directory or a stale --include set scans nothing and looks clean'
reg 18 'root present with files but zero citations' 0 0 '' '^MISS ' \
  'round 2: asserting matches-per-root failed the build on an innocent copy edit'
reg 19 'NUL byte in a scanned file' 1 0 "$UNQUAL_9Q" '' \
  'without -a, GNU grep calls the file binary, prints nothing, and exits 0'
reg 20 'empty anchor index' '+' 0 '0 anchors defined by' 'unbound variable' \
  'set -u plus an empty associative array must degrade, never crash'

# --- Leg 4 vs legs 2-3: extension parity (the round-3 class) ----------------
# Handled by a bespoke comparison in run_one; the counts below are asserted
# for BOTH extensions and the two outputs must be byte-identical after
# normalizing the extension.
reg 24 'identical content in .md and .markdown behaves identically' 2 1 \
  'zzcontrol' '' \
  'round 3: a widening reached three of four file-selection sites'

# --- Legs 1-3 regressions --------------------------------------------------
# Scope note: the residual that asked for this harness scoped it to the leg-4
# cases. These four were also hand-run during that PR and have the identical
# "run by hand" gap; a file named check-model-pins-controls.sh that covers
# one of four legs is itself a coverage claim that is not true.
reg L1 'leg 1 — agent frontmatter names an unsanctioned tier' 1 0 \
  'is not a sanctioned tier' '' \
  '`inherit` rides the invoking session tier; presence of a key is not a pin'
reg L2 'leg 2 — dispatch instruction with no pin in its block' 0 1 \
  'dispatch instruction with no pin' '' \
  'generic subagents have no frontmatter, so their pin lives in prose'
reg L3a 'leg 3 — mode-conditional with the headless branch deleted' 1 0 \
  'must name both branches' '' \
  'leg 2 is satisfied by any ONE tier, so a deleted branch would pass clean'
reg L3b 'leg 3 — inverted mode-conditional pair' 1 0 \
  'headless tier costs MORE' '' \
  'an unattended run must never cost more than the attended one it mirrors'

if [ "$LIST" -eq 1 ]; then
  i=0
  while [ "$i" -lt "${#IDS[@]}" ]; do
    printf '%-5s %s\n' "${IDS[$i]}" "${TITLES[$i]}"
    i=$((i + 1))
  done
  exit 0
fi

# ---------------------------------------------------------------------------
# Planting
# ---------------------------------------------------------------------------
# Most leg-4 cases append one line to the fixture's README.md. That file is a
# citation root scanned ONLY by leg 4 — legs 2-3 scan plugins/* — so a
# citation case cannot perturb the other legs' counts.
say() { printf '\n%s\n' "$2" >> "$1/README.md"; }

# A command file carrying, at once: an unpinned dispatch instruction (leg 2),
# an INVERTED mode-conditional marker (leg 3), and an unresolvable citation
# (leg 4). Case 24 writes it under two different extensions.
write_zzcontrol() {
  local dir="$1" ext="$2"
  cat > "${dir}/plugins/cepa/commands/zzcontrol.${ext}" <<EOF
# zzcontrol

Dispatch each persona as a generic subagent.

<!-- model-pin: mode-conditional interactive=haiku headless=opus -->

The rule is recorded in autonomy ${SS}9zz.
EOF
}

# Case 24 compares two whole checker runs, so the two things that legitimately
# differ between them — the fixture path in the run header, and the planted
# file's extension — are normalized away. `.markdown` is rewritten BEFORE
# `.md`, or the longer name would be mangled into `zzcontrol.EXTarkdown`.
norm_case24() {
  sed -e 's#^== cepa model-pin check: .*#== cepa model-pin check: FIXTURE ==#' \
      -e 's/zzcontrol\.markdown/zzcontrol.EXT/g' \
      -e 's/zzcontrol\.md/zzcontrol.EXT/g'
}

plant() {
  local id="$1" d="$2" f
  case "$id" in
    1)  say "$d" "${SS}9q applies here." ;;
    2)  say "$d" "This rule (${SS}9q) applies." ;;
    3)  say "$d" "This rule \"${SS}9q\" applies." ;;
    4)  say "$d" "This rule — ${SS}9q — applies." ;;
    5)  say "$d" "See -x ${SS}9q here." ;;
    6)  say "$d" "See see ${SS}9q here." ;;
    7)  say "$d" "The rule is in \`grounding\` ${SS}9c." ;;
    8)  say "$d" "The rule is in \`Grounding\` ${SS}9c." ;;
    9)  say "$d" "The rule is in \`cepa:autonomy\` ${SS}9c." ;;
    10a) say "$d" "The rule is in \`cepa:grounding\`
${SS}9c." ;;
    10b) say "$d" "The rule is in the \`cepa:grounding\` contract (${SS}9c)." ;;
    11) say "$d" "See autonomy ${SS}9qz for the rule." ;;
    12) say "$d" "See autonomy ${SS}9Q for the rule." ;;
    13) say "$d" "See autonomy ${SS}9c-9q for the rule." ;;
    14) say "$d" "See autonomy ${SS}9c-9d-9q for the rule." ;;
    15) say "$d" "It is the ${SS}9c-style ladder." ;;
    16) mv "$d/.github" "$d/.github-gone" ;;
    17) mv "$d/.github/workflows/model-pins.yml" "$d/.github/workflows/model-pins.txt" ;;
    18) sed -i "s/${SS}\\([0-9]\\)/section \\1/g" "$d/README.md" ;;
    19) printf '\n%s\n' "${SS}9q applies here." >> "$d/CLAUDE.md"
        printf '\0' >> "$d/CLAUDE.md" ;;
    # The only skill defining lettered sections; blanking its headings empties
    # the whole anchor index.
    20) sed -i 's/^### \([0-9][0-9]*[A-Za-z][A-Za-z]*\)\./### x\1./' \
          "$d/plugins/cepa/skills/autonomy/SKILL.md" ;;
    24) write_zzcontrol "$d" md ;;
    24b) write_zzcontrol "$d" markdown ;;
    L1) f=$(cd "$d" && find plugins -path '*/agents/*' -name '*.md' -type f | sort | head -1)
        [ -n "$f" ] || return 1
        sed -i '1,/^---[[:space:]]*$/!b; s/^model:.*/model: inherit/' "$d/$f" ;;
    L2) cat > "$d/plugins/cepa/commands/zzl2.md" <<'EOF'
# zzl2

Dispatch each reviewer as a generic subagent and collect the findings.
EOF
        ;;
    L3a) cat > "$d/plugins/cepa/commands/zzl3a.md" <<'EOF'
# zzl3a

<!-- model-pin: mode-conditional interactive=opus -->
EOF
        ;;
    L3b) cat > "$d/plugins/cepa/commands/zzl3b.md" <<'EOF'
# zzl3b

<!-- model-pin: mode-conditional interactive=haiku headless=opus -->
EOF
        ;;
    *) printf 'no plant recipe for case %s\n' "$id" >&2; return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Fixture + checker invocation
# ---------------------------------------------------------------------------
TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/cepa-pin-controls.XXXXXX") || exit 2
cleanup() {
  [ "$KEEP" -eq 1 ] && { printf 'fixtures kept at %s\n' "$TMPROOT"; return; }
  rm -rf "$TMPROOT"
}
trap cleanup EXIT INT TERM

PRISTINE="$TMPROOT/pristine"
mkdir -p "$PRISTINE"

# Tracked paths with WORKING-TREE content: the harness must validate the
# checker as it currently is on disk, which is exactly when you want to run
# it. This also inherits .gitignore, so no docs/, no .env.local, no .git.
# Tracked-but-deleted paths are filtered out — tar aborts on them.
LIST="$TMPROOT/filelist"
( cd "$REPO_ROOT" && git ls-files -z ) > "$LIST.z" || exit 2
( cd "$REPO_ROOT" && while IFS= read -r -d '' p; do
    [ -e "$p" ] && printf '%s\0' "$p"
  done < "$LIST.z" ) > "$LIST"
( cd "$REPO_ROOT" && tar --null -cf - -T "$LIST" ) | ( cd "$PRISTINE" && tar -xf - ) || {
  printf 'FATAL: could not materialize the fixture\n' >&2; exit 2; }

CHK_OUT=''; CHK_RC=0; CHK_MISS=''; CHK_WARN=''
run_checker() {
  CHK_OUT=$(cd "$1" && bash "$CHECKER" 2>&1)
  CHK_RC=$?
  local verdict
  verdict=$(printf '%s\n' "$CHK_OUT" | grep -oE '^-- [0-9]+ MISS, [0-9]+ WARN --$' | tail -1)
  # A missing verdict line is a FAILURE, never a zero. The checker can die
  # before printing it, and reading "no verdict" as "0 MISS" is the same
  # silent-pass shape this whole suite exists to catch.
  [ -n "$verdict" ] || { CHK_MISS=''; CHK_WARN=''; return 1; }
  CHK_MISS=$(printf '%s' "$verdict" | sed 's/^-- \([0-9]*\) MISS.*/\1/')
  CHK_WARN=$(printf '%s' "$verdict" | sed 's/.*, \([0-9]*\) WARN --$/\1/')
  return 0
}

count_ok() {  # count_ok <actual> <expected: int or +>
  case "$2" in
    '+') [ "$1" -gt 0 ] ;;
    *)   [ "$1" -eq "$2" ] ;;
  esac
}

# ---------------------------------------------------------------------------
# Baseline gate
# ---------------------------------------------------------------------------
printf '== control suite for %s ==\n' "${CHECKER#"$REPO_ROOT"/}"
if ! run_checker "$PRISTINE" || [ "$CHK_MISS" != 0 ] || [ "$CHK_WARN" != 0 ] || [ "$CHK_RC" -ne 0 ]; then
  printf 'FATAL: baseline is not clean — every case expectation is a delta from it,\n'
  printf '       so a dirty baseline makes the whole suite meaningless.\n'
  printf '       got: %s MISS, %s WARN, exit %s\n\n' "${CHK_MISS:-?}" "${CHK_WARN:-?}" "$CHK_RC"
  printf '%s\n' "$CHK_OUT"
  exit 1
fi
printf 'baseline: 0 MISS, 0 WARN, exit 0\n\n'

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

fail_case() {  # fail_case <id> <title> <reason>
  printf 'FAIL  %-4s %s\n' "$1" "$2"
  printf '        %s\n' "$3"
  printf '        --- checker output ---\n'
  printf '%s\n' "$CHK_OUT" | sed 's/^/        | /'
  failed=$((failed + 1))
  FAILED_IDS="${FAILED_IDS}${1} "
}

run_one() {
  local i="$1" id="${IDS[$1]}" title="${TITLES[$1]}"
  local dir="$TMPROOT/case-$id"
  ran=$((ran + 1))

  cp -a "$PRISTINE" "$dir" || { fail_case "$id" "$title" 'could not copy fixture'; return; }
  plant "$id" "$dir" || { fail_case "$id" "$title" 'plant step failed'; return; }

  if ! run_checker "$dir"; then
    fail_case "$id" "$title" 'checker printed no "-- N MISS, M WARN --" verdict line'
    return
  fi

  if ! count_ok "$CHK_MISS" "${EXP_MISS[$i]}" || ! count_ok "$CHK_WARN" "${EXP_WARN[$i]}"; then
    fail_case "$id" "$title" \
      "expected ${EXP_MISS[$i]} MISS / ${EXP_WARN[$i]} WARN, got ${CHK_MISS} MISS / ${CHK_WARN} WARN"
    return
  fi

  if [ -n "${EXP_RE[$i]}" ] && ! printf '%s\n' "$CHK_OUT" | grep -qE "${EXP_RE[$i]}"; then
    fail_case "$id" "$title" "counts matched but output does not match: ${EXP_RE[$i]}"
    return
  fi

  if [ -n "${FORBID_RE[$i]}" ] && printf '%s\n' "$CHK_OUT" | grep -qE "${FORBID_RE[$i]}"; then
    fail_case "$id" "$title" "output must NOT match, but does: ${FORBID_RE[$i]}"
    return
  fi

  # Case 24 is a COMPARISON, not a single observation: the same content under
  # both markdown extensions must produce byte-identical output. Asserting
  # only the .md counts would have passed happily while .markdown was
  # invisible to legs 2-3, which is exactly what shipped in round 3.
  if [ "$id" = 24 ]; then
    local alt="$TMPROOT/case-24-markdown" a b
    a=$(printf '%s\n' "$CHK_OUT" | norm_case24)
    cp -a "$PRISTINE" "$alt" || { fail_case "$id" "$title" 'could not copy fixture'; return; }
    plant 24b "$alt" || { fail_case "$id" "$title" 'plant step failed (.markdown)'; return; }
    if ! run_checker "$alt"; then
      fail_case "$id" "$title" '.markdown run printed no verdict line'
      return
    fi
    b=$(printf '%s\n' "$CHK_OUT" | norm_case24)
    if [ "$a" != "$b" ]; then
      CHK_OUT=$(printf '%s\n' '--- .md vs .markdown ---'; diff <(printf '%s\n' "$a") <(printf '%s\n' "$b"))
      fail_case "$id" "$title" '.md and .markdown produced different output'
      return
    fi
  fi

  printf 'PASS  %-4s %s\n' "$id" "$title"
  passed=$((passed + 1))
}

i=0
while [ "$i" -lt "${#IDS[@]}" ]; do
  selected "${IDS[$i]}" && run_one "$i"
  i=$((i + 1))
done

# A suite that asserted nothing is not a pass — the same rule the checker
# applies to its own `checked == 0` guard.
if [ "$ran" -eq 0 ]; then
  printf '\nFATAL: no controls ran (--only matched nothing?) — a suite that asserts nothing is not a pass\n'
  exit 1
fi

printf '\n-- %d/%d controls passed --\n' "$passed" "$ran"
if [ "$failed" -gt 0 ]; then
  printf 'FAIL: the checker no longer behaves the way its record claims. Failed: %s\n' "$FAILED_IDS"
  exit 1
fi
exit 0

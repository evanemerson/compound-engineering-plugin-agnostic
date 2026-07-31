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
# HOW A CASE EARNS ITS PLACE: `cepa:autonomy` §9f. The `why` field of every
# `reg` below names the mutant that case kills, and is printed on failure.
#
# THREE RULES the first cut got wrong, all reproduced by review:
#
#   1. Assert the EXIT CODE, not just the counts. The checker's whole
#      enforcement value is its non-zero exit — that is what fails CI.
#      Mutating its final `exit 1` to `exit 0` left every count and message
#      identical and passed 26/26 while turning CI into a permanent green.
#   2. Assert the FIXTURE IS COMPLETE. The builder is a pipeline; without
#      `pipefail` a source-side `tar` failure (one unreadable tracked file)
#      produced a truncated tree that the baseline gate happily accepted,
#      because a tree missing files is CLEANER, not dirtier.
#   3. A plant that can silently no-op needs a post-plant assertion. A `sed`
#      that matches nothing exits 0, and a zero-MISS case then re-asserts the
#      baseline and prints PASS forever.
#
# Cases that expect ZERO misses are not filler: they are the false-positive
# guards, and they are what kill the "loosen a predicate" mutants that no
# positive case can reach. Two of them (10a, 10b) pin a RECORDED LIMIT rather
# than correct behavior — see their case bodies before "fixing" them.
#
# Usage:
#   bash scripts/check-model-pins-controls.sh              # run all
#   bash scripts/check-model-pins-controls.sh --list       # ids and titles
#   bash scripts/check-model-pins-controls.sh --only 7,10a # a subset
#   bash scripts/check-model-pins-controls.sh --keep       # keep fixtures
set -u
# The fixture is materialized by a pipeline whose failure mode is a silently
# truncated tree. `pipefail` is load-bearing, not hygiene.
set -o pipefail

KEEP=0
ONLY=''
LIST_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1 ;;
    --list) LIST_ONLY=1 ;;
    # A bare trailing `--only` used to shift past the end, leave ONLY empty,
    # and silently run all cases — an argument error that widens the run.
    --only) shift; [ $# -gt 0 ] || { printf -- '--only needs a value\n' >&2; exit 2; }; ONLY="$1" ;;
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
# control suite that passes on a broken checker proves nothing.
#
# Resolved to an ABSOLUTE path immediately. A relative override was resolved
# against the invoking cwd by the readability probe and against the FIXTURE by
# the invocation — two different files, and the run header printed the
# unresolved string, so an override could read as an ordinary run.
CHECKER=$(readlink -f "${CEPA_PIN_CHECKER:-$REPO_ROOT/scripts/check-model-pins.sh}" 2>/dev/null) || CHECKER=''
[ -n "$CHECKER" ] && [ -r "$CHECKER" ] || {
  printf 'FATAL: no readable checker at %s\n' "${CEPA_PIN_CHECKER:-$REPO_ROOT/scripts/check-model-pins.sh}" >&2
  exit 2
}
# CI must never set the override. Enforced, not merely asserted in a comment.
if [ -n "${CEPA_PIN_CHECKER:-}" ] && [ -n "${CI:-}" ]; then
  printf 'FATAL: CEPA_PIN_CHECKER is set in CI — the suite would validate a checker nobody reviewed\n' >&2
  exit 2
fi

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
#
# <why> names the mutant the case kills. It is PRINTED on failure — an editor
# who makes a control go red needs the reason at the failure site, not in a
# case body they have to go find.
IDS=(); TITLES=(); EXP_MISS=(); EXP_WARN=(); EXP_RE=(); FORBID_RE=(); WHY=()
reg() {
  IDS+=("$1"); TITLES+=("$2"); EXP_MISS+=("$3"); EXP_WARN+=("$4")
  EXP_RE+=("$5"); FORBID_RE+=("$6"); WHY+=("$7")
}

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
  'kills: the round-1 tab delimiter that dropped every unqualified citation'
reg 2 'parenthesized citation' 1 0 "$UNQUAL_9Q" '' \
  'kills: same; a leading ( leaves no qualifier token'
reg 3 'quoted citation' 1 0 "$UNQUAL_9Q" '' \
  'kills: same; a leading double quote leaves no qualifier token'
reg 4 'em-dashed citation' 1 0 "$UNQUAL_9Q" '' \
  'kills: same; an em dash is outside the qualifier charset'
reg 5 'leading-dash token before the anchor' 1 0 "$UNQUAL_9Q" '' \
  'kills: removal of the leading-dash blanking (qualifier sanitization)'
reg 6 'plain word qualifier — control for cases 1-5' 1 0 "$UNQUAL_9Q" '' \
  'isolates the empty qualifier field as the cause: this one SURVIVES the round-1 mutant'

reg 7 'wrong owner, lowercase' 1 0 "$(qual_miss grounding 9c)" '' \
  'kills: removal of the owners membership test in the qualified branch'
reg 8 'wrong owner, capitalized' 1 0 "$(qual_miss grounding 9c)" '' \
  'kills: removal of the qualifier lowercasing'
reg 9 'correct owner resolves clean' 0 0 '' '^MISS ' \
  'false-positive guard: a correct qualified citation must not fail the build'
reg 25 'wrong owner behind a `cepa:` prefix' 1 0 "$(qual_miss grounding 9c)" '' \
  'kills: removal of qual=${qual##*:}; the dominant citation style in this repo is `cepa:<skill>`'

# Cases 10a/10b pin a RECORDED LIMIT — see `cepa:autonomy` §9f for the
# mechanism. They assert 0 MISS because that is what the checker does today,
# NOT because it is right. If the limit is ever closed these go red on the
# count assertion and say so in their titles.
reg 10a 'recorded limit — wrong owner separated by a line break' 0 0 '' \
  'cited as .grounding.' 'pins current behavior; goes red when the limit closes (autonomy §9f)'
reg 10b 'recorded limit — wrong owner separated by an intervening word' 0 0 '' \
  'cited as .grounding.' 'pins current behavior; reflow does not fix this shape (autonomy §9f)'

reg 11 'multi-letter anchor' 1 0 "$(qual_miss autonomy 9qz)" '' \
  'kills: an unquantified character class, which makes grep -o truncate a two-letter anchor'
reg 12 'uppercase anchor' 1 0 "$(qual_miss autonomy 9q)" '' \
  'kills: removal of the anchor lowercasing'
reg 13 'range second endpoint' 1 0 "$(qual_miss autonomy 9q)" '' \
  'kills: removal of hyphen-range expansion'
reg 14 'triple range' 1 0 "$(qual_miss autonomy 9q)" '' \
  'kills: an expansion that stops after the first hyphen'
reg 15 'hyphenated English after an anchor' 0 0 '' '^MISS ' \
  'kills: an unnumbered range tail, which invents anchors from ordinary prose'

# The three prose-regression guards. These use REAL anchors preceded by
# ordinary English words — the opposite direction from case 6, which uses a
# fake anchor. The checker's own comment justifies this branch: "ordinary
# prose sits directly before an anchor constantly ... treating those as owner
# claims would MISS dozens of clean citations." Dropped from the first cut of
# this file while four artifacts claimed they had landed.
reg 21 'prose regression — a word before a real anchor (per)' 0 0 '' '^MISS ' \
  'kills: treating any preceding token as an owner claim'
reg 22 'prose regression — a word before a real anchor (the)' 0 0 '' '^MISS ' \
  'kills: same, on a two-character anchor'
reg 23 'prose regression — a word before a real anchor (tier)' 0 0 '' '^MISS ' \
  'kills: same; these three are why the qualifier must match a real skill name'

# --- Leg 4: root accounting -------------------------------------------------
# One case per CITE_ROOTS entry, so dropping any root from the list is caught
# by name. The first cut covered `.github` explicitly, `README.md` and
# `CLAUDE.md` incidentally, `plugins` by accident (case 24's fixture happens
# to live there), and `scripts` by nothing at all.
reg 16 'citation root removed' 1 0 \
  "leg 4 citation root '\\.github' does not exist" '' \
  'kills: removal of the root-existence check, which let a vanished root pass at 0 MISS'
reg 17 'root present, include set matches nothing' 1 0 \
  "leg 4 root '\\.github' holds no file matching the --include set" '' \
  'kills: removal of the file-coverage probe'
reg 18 'root present with files but zero citations' 0 0 '' '^MISS ' \
  'false-positive guard: a root may legitimately cite nothing (a copy edit must not fail the build)'
reg 19 'NUL byte in a leg-4 scanned file' 1 0 "$UNQUAL_9Q" '' \
  'kills: removal of -a from the leg-4 grep (GNU grep calls the file binary and exits 0)'
reg 20 'empty anchor index' '+' 0 '(^| )0 anchors defined by' 'unbound variable' \
  'kills: a crash on set -u with an empty associative array; must degrade, not die'
reg 26 'broken citation under the `plugins` root' 1 0 "$UNQUAL_9Q" '' \
  'kills: dropping `plugins` from CITE_ROOTS'
reg 27 'broken citation under the `scripts` root' 1 0 "$UNQUAL_9Q" '' \
  'kills: dropping `scripts` from CITE_ROOTS — the root the runtime-built section sign exists for'
reg 28 'broken citation in a .yml under `.github`' 1 0 "$UNQUAL_9Q" '' \
  'kills: dropping --include=*.yml, which would make the workflow files unscanned'
reg 29 'no citations anywhere' '+' 0 'checked no .* citation' '' \
  'kills: removal of the checked==0 guard — a scan that verifies nothing is not a pass'

# --- Leg 4 vs legs 2-3: extension parity (the round-3 class) ----------------
reg 24 'identical content in .md and .markdown behaves identically' 2 1 \
  'zzcontrol' '' \
  'kills: a file-selection widening that reaches some of the four sites but not all'

# --- Leg 1: agent frontmatter ----------------------------------------------
reg L1 'agent frontmatter names an unsanctioned tier' 1 0 \
  'is not a sanctioned tier' '' \
  'kills: accepting any non-empty model: value; `inherit` rides the invoking session tier'
reg L1b 'agent frontmatter has an empty model:' 1 0 \
  'model: is empty/null' '' \
  'kills: removal of the empty/null branch — a present-but-empty key is not a pin'
reg L1c 'agent directories exist but hold no definitions' 1 0 \
  'hold no agent definitions' '' \
  'kills: removal of the agent_count==0 guard — a discovery that finds nothing is not a pass'
reg L1d 'a SYMLINKED agent definition is still checked' 1 0 \
  'is not a sanctioned tier' '' \
  'kills: dropping -L from leg 1 discovery — an unfollowed symlink is a file nobody checked'

# --- Leg 2: dispatch instructions in prose ---------------------------------
reg L2 'dispatch instruction with no pin in its block' 0 1 \
  'dispatch instruction with no pin' '' \
  'kills: removal of leg 2 entirely'
reg L2b 'dispatch whose only nearby `model:` is prose, with no tier' 0 1 \
  'dispatch instruction with no pin' '' \
  'kills: loosening PIN_RE to bare `model:`, which lets an unpinned dispatch hide in pin documentation'
reg L2c 'dispatch whose pin sits in the PRECEDING block' 0 1 \
  'dispatch instruction with no pin' '' \
  'kills: widening block_range to the whole file, or to blocks before the dispatch'
reg L2d 'every DISPATCH_RE alternation fires' 0 8 \
  'dispatch instruction with no pin' '' \
  'kills: narrowing DISPATCH_RE — one case per trigger shape, so a dropped alternation is named'
reg L2e 'dispatch prose under `agents/`, not just commands and skills' 0 1 \
  'dispatch instruction with no pin' '' \
  'kills: narrowing the legs 2-3 scan roots back to commands+skills (a documented past hole)'
reg L2f 'NUL byte in a file legs 2-3 scan' 1 0 \
  'unreadable during leg 2 scan' '' \
  'kills: removal of the legs 2-3 NUL probe; case 19 plants in CLAUDE.md, which legs 2-3 never read'
reg L2g 'the prose-suppression marker works' 0 0 '' '^WARN ' \
  'false-positive guard: documentation of a dispatch must be closable without deleting it'
reg L2h 'a correctly pinned dispatch is silent' 0 0 '' '^WARN ' \
  'false-positive guard: leg 2 must not warn on the thing it is asking for'

# --- Leg 3: mode-conditional pairs -----------------------------------------
reg L3a 'mode-conditional with the headless branch deleted' 1 0 \
  'must name both branches' '' \
  'kills: removal of the malformed branch — leg 2 is satisfied by any ONE tier'
reg L3b 'inverted pair (haiku/opus)' 1 0 \
  'headless tier costs MORE' '' \
  'kills: removal of the inversion check'
reg L3c 'mode-conditional naming an unsanctioned tier' 1 0 \
  'names a tier outside' '' \
  'kills: removal of the unsanctioned branch — the third arm, uncovered by L3a and L3b'
reg L3d 'inverted pair (sonnet/opus)' 1 0 \
  'headless tier costs MORE' '' \
  'kills: a corrupted TIER_RANK table; L3b alone passes if sonnet and opus are ranked equal'
reg L3e 'a correctly ordered pair is silent' 0 0 '' '^MISS ' \
  'false-positive guard: leg 3 must not reject the shape it is asking for'

if [ "$LIST_ONLY" -eq 1 ]; then
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

# Case 24 compares two whole checker runs, so the two things that legitimately
# differ between them — the fixture path in the run header, and the planted
# file's extension — are normalized away. `.markdown` is rewritten BEFORE
# `.md`, or the longer name would be mangled into `zzcontrol.EXTarkdown`.
norm_case24() {
  sed -e 's#^== cepa model-pin check: .*#== cepa model-pin check: FIXTURE ==#' \
      -e 's/zzcontrol\.markdown/zzcontrol.EXT/g' \
      -e 's/zzcontrol\.md/zzcontrol.EXT/g'
}

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

# A file has a NUL byte iff stripping NULs changes its length. A bash string
# cannot hold a NUL, so grepping for one is grepping for the empty pattern.
has_nul() { [ "$(tr -d '\000' < "$1" | wc -c)" -ne "$(wc -c < "$1")" ]; }

plant() {
  local id="$1" d="$2" f before
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
    25) say "$d" "The rule is in \`cepa:grounding\` ${SS}9c." ;;
    10a) say "$d" "The rule is in \`cepa:grounding\`
${SS}9c." ;;
    10b) say "$d" "The rule is in the \`cepa:grounding\` contract (${SS}9c)." ;;
    11) say "$d" "See autonomy ${SS}9qz for the rule." ;;
    12) say "$d" "See autonomy ${SS}9Q for the rule." ;;
    13) say "$d" "See autonomy ${SS}9c-9q for the rule." ;;
    14) say "$d" "See autonomy ${SS}9c-9d-9q for the rule." ;;
    15) say "$d" "It is the ${SS}9c-style ladder." ;;
    21) say "$d" "The rule is per ${SS}9a here." ;;
    22) say "$d" "The rule is the ${SS}2b here." ;;
    23) say "$d" "The rule is tier ${SS}9c here." ;;

    16) mv "$d/.github" "$d/.github-gone" ;;
    17) mv "$d/.github/workflows/model-pins.yml" "$d/.github/workflows/model-pins.txt" ;;
    # A sed that matches nothing exits 0. Assert the plant actually landed:
    # README.md's lettered citations must exist before and be gone after, or
    # this case silently degrades into a second copy of the baseline.
    18) before=$(grep -c "${SS}[0-9][A-Za-z]" "$d/README.md" || true)
        [ "${before:-0}" -gt 0 ] || return 1
        sed -i "s/${SS}\\([0-9]\\)/section \\1/g" "$d/README.md"
        grep -q "${SS}[0-9][A-Za-z]" "$d/README.md" && return 1
        : ;;
    19) printf '\n%s\n' "${SS}9q applies here." >> "$d/CLAUDE.md"
        printf '\0' >> "$d/CLAUDE.md"
        has_nul "$d/CLAUDE.md" || return 1 ;;
    # autonomy/SKILL.md is the only skill defining lettered sections; blanking
    # its headings empties the whole anchor index.
    20) before=$(grep -c '^### [0-9][0-9]*[A-Za-z][A-Za-z]*\.' "$d/plugins/cepa/skills/autonomy/SKILL.md" || true)
        [ "${before:-0}" -gt 0 ] || return 1
        sed -i 's/^### \([0-9][0-9]*[A-Za-z][A-Za-z]*\)\./### x\1./' \
          "$d/plugins/cepa/skills/autonomy/SKILL.md"
        grep -q '^### [0-9][0-9]*[A-Za-z][A-Za-z]*\.' "$d/plugins/cepa/skills/autonomy/SKILL.md" && return 1
        : ;;
    26) printf '# zzcite\n\nThe rule is %s9q here.\n' "$SS" > "$d/plugins/cepa/commands/zzcite.md" ;;
    27) printf '#!/usr/bin/env bash\n# The rule is %s9q here.\n' "$SS" > "$d/scripts/zzcite.sh" ;;
    28) printf '\n# The rule is %s9q here.\n' "$SS" >> "$d/.github/workflows/model-pins.yml" ;;
    # Strip every section sign from every scanned root, so leg 4 finds nothing
    # to check at all.
    29) before=$(grep -rc "$SS" "$d/README.md" || true)
        [ "${before:-0}" -gt 0 ] || return 1
        find "$d/plugins" "$d/.github" "$d/scripts" -type f \
          \( -name '*.md' -o -name '*.markdown' -o -name '*.sh' -o -name '*.yml' -o -name '*.yaml' \) \
          -exec sed -i "s/${SS}/S-/g" {} +
        sed -i "s/${SS}/S-/g" "$d/CLAUDE.md" "$d/README.md" ;;

    24) write_zzcontrol "$d" md ;;
    24b) write_zzcontrol "$d" markdown ;;

    L1) f=$(cd "$d" && find plugins -path '*/agents/*' -name '*.md' -type f | sort | head -1)
        [ -n "$f" ] || return 1
        sed -i '1,/^---[[:space:]]*$/!b; s/^model:.*/model: inherit/' "$d/$f"
        grep -q '^model: inherit' "$d/$f" || return 1 ;;
    L1b) f=$(cd "$d" && find plugins -path '*/agents/*' -name '*.md' -type f | sort | head -1)
        [ -n "$f" ] || return 1
        sed -i '1,/^---[[:space:]]*$/!b; s/^model:.*/model:/' "$d/$f"
        grep -qx 'model:' "$d/$f" || return 1 ;;
    L1c) find "$d/plugins" -path '*/agents/*' \( -name '*.md' -o -name '*.markdown' \) -type f -delete
        [ -z "$(find "$d/plugins" -path '*/agents/*' -name '*.md' -type f)" ] || return 1 ;;
    # The symlink is created HERE, in the case dir, after the fixture copy —
    # the fixture's own refuse-on-tracked-symlink guard covers content this
    # suite did not author, and does not constrain a deliberate plant.
    L1d) printf -- '---\nname: zzl1d\nmodel: inherit\n---\n\n# zzl1d\n' \
           > "$d/plugins/cepa/zzl1d-target.md"
        ln -s ../zzl1d-target.md "$d/plugins/cepa/agents/zzl1d.md"
        [ -L "$d/plugins/cepa/agents/zzl1d.md" ] || return 1
        [ -r "$d/plugins/cepa/agents/zzl1d.md" ] || return 1 ;;

    L2) cat > "$d/plugins/cepa/commands/zzl2.md" <<'EOF'
# zzl2

Dispatch each reviewer as a generic subagent and collect the findings.
EOF
        ;;
    L2b) cat > "$d/plugins/cepa/commands/zzl2b.md" <<'EOF'
# zzl2b

Dispatch each reviewer now.

The `model:` key is documented at length elsewhere in this repository.
EOF
        ;;
    L2c) cat > "$d/plugins/cepa/commands/zzl2c.md" <<'EOF'
# zzl2c

model: sonnet

Dispatch each reviewer now.

Nothing in this block pins anything.
EOF
        ;;
    # One line per DISPATCH_RE alternation, each in its own block, so a
    # narrowed regex loses a countable number of WARNs instead of going quiet.
    L2d) cat > "$d/plugins/cepa/commands/zzl2d.md" <<'EOF'
# zzl2d

Dispatch each reviewer now.

This is a generic subagent path.

Subagents are dispatched from here.

Add a Task tool call at this point.

Set subagent_type on the call.

Launch all reviewers at once.

Spawn a helper subagent here.

We use several subagents here.
EOF
        ;;
    L2e) cat > "$d/plugins/cepa/agents/zzl2e.md" <<'EOF'
---
name: zzl2e
description: control fixture
model: sonnet
---

# zzl2e

Dispatch each reviewer as a generic subagent.

Nothing in this block pins anything.
EOF
        ;;
    L2f) printf '# zzl2f\n\nDispatch each reviewer as a generic subagent.\n' \
           > "$d/plugins/cepa/commands/zzl2f.md"
        printf '\0' >> "$d/plugins/cepa/commands/zzl2f.md"
        has_nul "$d/plugins/cepa/commands/zzl2f.md" || return 1 ;;
    L2g) cat > "$d/plugins/cepa/commands/zzl2g.md" <<'EOF'
# zzl2g

Dispatch each reviewer as a generic subagent. <!-- model-pin: prose -->
EOF
        ;;
    L2h) cat > "$d/plugins/cepa/commands/zzl2h.md" <<'EOF'
# zzl2h

Dispatch each reviewer as a generic subagent with `model: sonnet`.
EOF
        ;;

    L3a) printf '# zzl3a\n\n<!-- model-pin: mode-conditional interactive=opus -->\n' \
           > "$d/plugins/cepa/commands/zzl3a.md" ;;
    L3b) printf '# zzl3b\n\n<!-- model-pin: mode-conditional interactive=haiku headless=opus -->\n' \
           > "$d/plugins/cepa/commands/zzl3b.md" ;;
    L3c) printf '# zzl3c\n\n<!-- model-pin: mode-conditional interactive=fable headless=fable -->\n' \
           > "$d/plugins/cepa/commands/zzl3c.md" ;;
    L3d) printf '# zzl3d\n\n<!-- model-pin: mode-conditional interactive=sonnet headless=opus -->\n' \
           > "$d/plugins/cepa/commands/zzl3d.md" ;;
    L3e) printf '# zzl3e\n\n<!-- model-pin: mode-conditional interactive=opus headless=sonnet -->\n' \
           > "$d/plugins/cepa/commands/zzl3e.md" ;;

    *) printf 'no plant recipe for case %s\n' "$id" >&2; return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Fixture + checker invocation
# ---------------------------------------------------------------------------
TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/cepa-pin-controls.XXXXXX") || exit 2
cleanup() {
  [ "$KEEP" -eq 1 ] && { printf 'fixtures kept at %s\n' "$TMPROOT"; return; }
  # A failed cleanup used to be silent, so a leaked full-tree copy per run
  # accumulated with nothing to notice it.
  rm -rf "$TMPROOT" 2>/dev/null || printf 'WARN: fixture leaked at %s\n' "$TMPROOT" >&2
}
trap cleanup EXIT INT TERM

PRISTINE="$TMPROOT/pristine"
mkdir -p "$PRISTINE"

# Tracked paths with WORKING-TREE content: the harness must validate the
# checker as it currently is on disk, which is exactly when you want to run
# it. `git ls-files` also lists only TRACKED files, so untracked working-tree
# files and anything never committed (`.env.local`, `cepa.local.md`) are
# absent — but note that is a property of tracking, not of `.gitignore`: a
# file committed in spite of an ignore rule would be included.
#
# `[ -r "$p" ]`, not `[ -e "$p" ]`: a tracked-but-deleted path must be skipped
# (tar aborts on it) and a tracked-but-unreadable path must be FATAL. Silently
# omitting the second is how a truncated fixture reported a clean baseline.
FILELIST="$TMPROOT/filelist"
( cd "$REPO_ROOT" && git ls-files -z ) > "$FILELIST.z" || exit 2
unreadable=''
tracked=0
while IFS= read -r -d '' p; do
  tracked=$((tracked + 1))
  if [ -e "$REPO_ROOT/$p" ] && [ ! -r "$REPO_ROOT/$p" ]; then unreadable="${unreadable}${p} "; fi
done < "$FILELIST.z"
if [ -n "$unreadable" ]; then
  printf 'FATAL: tracked but unreadable, so the fixture would be silently incomplete: %s\n' "$unreadable" >&2
  exit 2
fi
( cd "$REPO_ROOT" && while IFS= read -r -d '' p; do
    [ -r "$p" ] && printf '%s\0' "$p"
  done < "$FILELIST.z" ) > "$FILELIST"
expected_files=$(tr -cd '\0' < "$FILELIST" | wc -c)
( cd "$REPO_ROOT" && tar --null -cf - -T "$FILELIST" ) | ( cd "$PRISTINE" && tar -xf - ) || {
  printf 'FATAL: could not materialize the fixture\n' >&2; exit 2; }

# `pipefail` catches a failing producer; this catches everything else that can
# shorten the tree — a TOCTOU delete between listing and archiving, a partial
# extract, a full disk. The suite's every claim is a claim about this tree.
actual_files=$(find "$PRISTINE" -type f -o -type l | wc -l)
if [ "$actual_files" -ne "$expected_files" ]; then
  printf 'FATAL: fixture is incomplete — %s of %s tracked files materialized\n' \
    "$actual_files" "$expected_files" >&2
  exit 2
fi

# Writes here use shell redirection, which FOLLOWS symlinks. A tracked symlink
# survives `git ls-files | tar` as a symlink, so an append aimed at the
# fixture's README.md would land wherever that link points — outside the
# fixture, outside the repo, as the invoking user. Reproduced. The checker has
# no need for tracked symlinks, so refuse rather than dereference (which would
# trade this for pulling the linked file's CONTENT into the fixture).
if find "$PRISTINE" -type l -print -quit | grep -q .; then
  printf 'FATAL: tracked symlink in the fixture — refusing to run, because planting writes follow it out of the fixture\n' >&2
  find "$PRISTINE" -type l | sed "s#^$PRISTINE/#  #" >&2
  exit 2
fi

CHK_OUT=''; CHK_RC=0; CHK_MISS=''; CHK_WARN=''
run_checker() {
  # Bounded: a hung checker would otherwise hang the suite and the CI job
  # until the job timeout, with no diagnostic.
  CHK_OUT=$(cd "$1" && timeout 300 bash "$CHECKER" 2>&1)
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

# The checker exits non-zero iff it reported anything. That exit code is the
# entire mechanism by which CI fails, and asserting only counts and messages
# left it untested: mutating the final `exit 1` to `exit 0` passed 26/26.
expected_rc() {  # expected_rc <expect_misses> <expect_warns>
  if [ "$1" = 0 ] && [ "$2" = 0 ]; then printf 0; else printf 1; fi
}

# ---------------------------------------------------------------------------
# Baseline gate
# ---------------------------------------------------------------------------
printf '== control suite for %s ==\n' "$CHECKER"
if ! run_checker "$PRISTINE" || [ "$CHK_MISS" != 0 ] || [ "$CHK_WARN" != 0 ] || [ "$CHK_RC" -ne 0 ]; then
  printf 'FATAL: baseline is not clean — every case expectation is a delta from it,\n'
  printf '       so a dirty baseline makes the whole suite meaningless.\n'
  printf '       If the lines below name files in this repo, they are REAL policy\n'
  printf '       violations in the tree, not a broken harness.\n'
  printf '       got: %s MISS, %s WARN, exit %s\n\n' "${CHK_MISS:-?}" "${CHK_WARN:-?}" "$CHK_RC"
  printf '%s\n' "$CHK_OUT"
  exit 1
fi

# The checker's INFO lines are its own coverage accounting. A zero in any of
# them means it scanned nothing and said so politely.
baseline_bad=''
printf '%s\n' "$CHK_OUT" | grep -qE 'agent definitions checked: [1-9]' || baseline_bad="${baseline_bad}agent-definitions "
printf '%s\n' "$CHK_OUT" | grep -qE 'citations checked: [1-9]'         || baseline_bad="${baseline_bad}citations "
printf '%s\n' "$CHK_OUT" | grep -qE '[1-9][0-9]* anchors defined by [1-9]' || baseline_bad="${baseline_bad}anchors/skills "
printf '%s\n' "$CHK_OUT" | grep -qE 'across ([1-9][0-9]*) of \1 roots'  || baseline_bad="${baseline_bad}roots-scanned "
if [ -n "$baseline_bad" ]; then
  printf 'FATAL: baseline reports zero coverage in: %s\n' "$baseline_bad"
  printf '       A clean run over nothing is not a clean run.\n\n'
  printf '%s\n' "$CHK_OUT"
  exit 1
fi
printf 'baseline: 0 MISS, 0 WARN, exit 0; %s tracked files; coverage counters non-zero\n\n' "$expected_files"

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
  printf 'FAIL  %-4s %s\n' "${IDS[$i]}" "${TITLES[$i]}"
  printf '        %s\n' "$2"
  printf '        why this case exists: %s\n' "${WHY[$i]}"
  printf '        --- checker output ---\n'
  printf '%s\n' "$CHK_OUT" | sed 's/^/        | /'
  failed=$((failed + 1))
  FAILED_IDS="${FAILED_IDS}${IDS[$i]} "
}

run_one() {
  local i="$1" id="${IDS[$1]}" title="${TITLES[$1]}" exp_rc
  local dir="$TMPROOT/case-$id"
  ran=$((ran + 1))

  cp -a "$PRISTINE" "$dir" || { fail_case "$i" 'could not copy fixture'; return; }
  plant "$id" "$dir" || { fail_case "$i" 'plant step failed or landed as a no-op'; return; }

  if ! run_checker "$dir"; then
    fail_case "$i" 'checker printed no "-- N MISS, M WARN --" verdict line'
    return
  fi

  if ! count_ok "$CHK_MISS" "${EXP_MISS[$i]}" || ! count_ok "$CHK_WARN" "${EXP_WARN[$i]}"; then
    fail_case "$i" \
      "expected ${EXP_MISS[$i]} MISS / ${EXP_WARN[$i]} WARN, got ${CHK_MISS} MISS / ${CHK_WARN} WARN"
    return
  fi

  exp_rc=$(expected_rc "${EXP_MISS[$i]}" "${EXP_WARN[$i]}")
  if [ "$CHK_RC" -ne "$exp_rc" ]; then
    fail_case "$i" "counts matched but the checker exited ${CHK_RC}, expected ${exp_rc} — the exit code is what fails CI"
    return
  fi

  if [ -n "${EXP_RE[$i]}" ] && ! printf '%s\n' "$CHK_OUT" | grep -qE "${EXP_RE[$i]}"; then
    fail_case "$i" "counts matched but output does not match: ${EXP_RE[$i]}"
    return
  fi

  if [ -n "${FORBID_RE[$i]}" ] && printf '%s\n' "$CHK_OUT" | grep -qE "${FORBID_RE[$i]}"; then
    fail_case "$i" "output must NOT match, but does: ${FORBID_RE[$i]}"
    return
  fi

  # Case 24 is a COMPARISON, not a single observation: the same content under
  # both markdown extensions must produce byte-identical output. Asserting
  # only the .md counts would have passed happily while .markdown was
  # invisible to legs 2-3, which is exactly what shipped in round 3.
  if [ "$id" = 24 ]; then
    local alt="$TMPROOT/case-24-markdown" a b
    a=$(printf '%s\n' "$CHK_OUT" | norm_case24)
    cp -a "$PRISTINE" "$alt" || { fail_case "$i" 'could not copy fixture'; return; }
    plant 24b "$alt" || { fail_case "$i" 'plant step failed (.markdown)'; return; }
    if ! run_checker "$alt"; then
      fail_case "$i" '.markdown run printed no verdict line'
      return
    fi
    b=$(printf '%s\n' "$CHK_OUT" | norm_case24)
    if [ "$a" != "$b" ]; then
      CHK_OUT=$(printf '%s\n' '--- .md vs .markdown ---'; diff <(printf '%s\n' "$a") <(printf '%s\n' "$b"))
      fail_case "$i" '.md and .markdown produced different output'
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

# A filtered run must never read as a full one. `--only 9` passing is
# "1/1 controls passed, exit 0" — the same shape a complete green run has.
if [ -n "$ONLY" ]; then
  printf '\n** PARTIAL RUN — only %s ran; %d of %d controls were not exercised **\n' \
    "$ONLY" "$(( ${#IDS[@]} - ran ))" "${#IDS[@]}"
fi
printf '\n-- %d/%d controls passed --\n' "$passed" "$ran"
if [ "$failed" -gt 0 ]; then
  printf 'FAIL: the checker no longer behaves the way its record claims. Failed: %s\n' "$FAILED_IDS"
  exit 1
fi
exit 0

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

# Unqualified misses: <anchor> cited, defined by no skill at all.
unqual_miss() { printf "%s%s is cited but no .* has a '### %s\\.' heading" "$SS" "$1" "$1"; }
UNQUAL_9Q=$(unqual_miss 9q)
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
# Case 5 plants `-x`, which is not a skill name with OR without the dash
# blanking, so it takes the unqualified branch either way and cannot see the
# sanitization go. Reaching the qualified branch needs a dash attached to a
# REAL owner in the repo's dominant `cepa:<skill>` style, because the `##*:`
# prefix strip runs AFTER the blanking: drop the blanking and `-cepa:grounding`
# becomes `grounding`, a skill that does not own the anchor.
reg 39 'a dash-attached qualifier is not an owner claim' 0 0 '' '^MISS ' \
  'kills: the leading-dash blanking in qualifier sanitization, which case 5 exercises but cannot kill'

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
reg 17 'root present, no file of a scannable extension' 1 0 \
  "leg 4 root '\\.github' holds no non-empty scannable file" '' \
  'kills: removal of the file-coverage probe (case 36 covers its zero-byte half)'
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
reg 37 'broken citation in a .yaml under `.github`' 1 0 "$UNQUAL_9Q" '' \
  'kills: dropping `yaml` from CITE_EXTS. Case 28 plants a .yml and nothing planted a .yaml, so half of leg 4 own extension set had no case behind it'
reg 29 'no citations anywhere' '+' 0 'checked no .* citation' '' \
  'kills: removal of the checked==0 guard — a scan that verifies nothing is not a pass'
reg 30 'a SYMLINKED file inside a citation root is still read' 1 0 "$UNQUAL_9Q" '' \
  'kills: grep -R reverted to -r — grep follows symlinks named on the command line but NOT during recursion'
reg 31 'a filesystem cycle under `plugins` is reported' 1 0 \
  'discovery failed .*File system loop detected' '' \
  'kills: dropping the stderr/exit-status check from leg 1 discovery — find skips a cycle, warns on stderr, and exits 1'
reg 35 'a filesystem cycle under `scripts` is reported' 1 0 \
  "leg 4 discovery failed on root 'scripts' .*File system loop detected" '' \
  'kills: checking traversal status for only SOME roots — case 31 lives under plugins, so leg 4 per-root coverage needs its own case'
reg 33 'an unreadable SUBTREE under a citation root is reported' 1 0 \
  "leg 4 discovery failed on root 'scripts' .*Permission denied" '' \
  'kills: discarding find exit status/stderr — a partial walk returns a truncated non-empty list and reports full coverage'
reg 34 'an unreadable FILE in a citation root is reported' 1 0 \
  'leg 4 read failed on root' '' \
  'kills: removal of the grep exit>1 branch, which is also the only guard against an ARG_MAX exec failure'
reg 36 'a root whose only scannable files are empty is reported' 1 0 \
  "leg 4 root '\\.github' holds no non-empty scannable file" '' \
  'kills: counting listed files instead of readable content — a truncating merge leaves a root that scans nothing'
# Runs under a SHORT timeout (see CASE_TIMEOUT): the regression this guards is
# a HANG, not a wrong answer, so the failure has to be bounded or the suite
# hangs with it.
reg 32 'a symlink to a character device does not hang the scan' 0 0 '' '^MISS ' \
  'kills: leg 4 reverting to `grep -R` over raw paths — it opens whatever a symlink points at, with no type check, and blocks forever on /dev/zero or a writerless FIFO'

# --- Leg 4: the anchor INDEX ------------------------------------------------
# The lookup has two sides and they are separate constructs. Everything above
# tests the CITATION side; these test the side that builds ANCHOR_OWNERS from
# each skill's own headings. The sweep found all four of these surviving at
# once, which is what a whole untested side of a comparison looks like.
reg 38 'no SKILL.md anywhere' '+' 0 \
  'no plugins/\*/skills/\*/SKILL\.md found' '' \
  'kills: the zero-skill-files guard. Case 20 blanks the HEADINGS and keeps the files, so skill_files stays non-zero there and this guard never runs'
reg 40 'a mid-line heading mention does not define an anchor' 1 0 \
  "$(unqual_miss 9zz)" '' \
  'kills: the ^ anchor on the heading index (LOOSENING) — prose that MENTIONS a heading would define it, so a citation resolves against prose instead of against a section'
# A BOM is only observable on line 1, so this fixture puts the heading there.
# Prepending one to a real SKILL.md is invisible to this construct: line 1 is
# the frontmatter delimiter and the headings are further down.
reg 41 'a BOM before a line-1 heading still defines its anchor' 0 0 '' '^MISS ' \
  'kills: the BOM/CRLF normalization when building the index — a BOM-led skill file would define no anchors, so every citation into it MISSes'
reg 42 'heading letters are matched case-insensitively' 0 0 '' '^MISS ' \
  'kills: the lowercasing on the INDEX side. Case 12 lowercases the CITATION side and passes either way — two sides, two constructs'

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
  'kills: dropping -L from leg 1 file discovery — an unfollowed symlink is a file nobody checked'
reg L1e 'a SYMLINKED agents/ directory is still discovered' 1 0 \
  'is not a sanctioned tier' '' \
  'kills: dropping -L from leg 1 AGENT_DIRS discovery — every definition in that directory goes unchecked'
reg L1f 'one definition reachable through two symlinked agents/ dirs is checked once' 1 0 \
  'is not a sanctioned tier' '' \
  'kills: removal of resolved-path dedup — -L makes the same file reachable twice, inflating the coverage counter and double-reporting one defect'

# The leg-1 constructs the first cut never reached. The mutation sweep found
# them by enumerating leg 1 and the shared frontmatter sanitizers construct by
# construct: 11 of its 21 undeclared survivors lived here, the mirror image of
# the first control cut putting 22 of its 26 cases on leg 4.
#
# NOTE THE COUNTS. An agent definition is also ordinary markdown under
# `plugins/`, so legs 2-3 read it and leg 4 scans it for citations. A mode-000
# definition therefore produces FOUR misses — leg 1's readability guard, leg 2's
# and leg 3's own read-error arms, and leg 4's per-root grep exiting 2 — and a
# mode-000 file under `commands/` produces three. That coupling is a property of
# the checker, not of these fixtures: no location under `plugins/` is visible to
# leg 1 and invisible to the others. The count is asserted as what the checker
# actually does, and the EXP_RE is what pins each case to the leg it is about.
reg L1g 'an UNREADABLE agent definition is refused by leg 1' 4 0 \
  'unreadable \(a file that cannot be checked is not a pass\)' '' \
  'kills: leg 1 per-file readability guard. With it gone the file falls through to the parser, reads as having no model: key, and reports the SAME count under a different defect — only the message separates them'
# The BOM is the load-bearing half, measured rather than assumed: `\r` is in
# [[:space:]] under LC_ALL=C, so a CRLF frontmatter still satisfies the awk
# `^---[[:space:]]*$` test and its trailing \r is stripped by the value sed
# anyway. CRLF alone cannot fail this construct. Both are planted because the
# normalization covers both; only the BOM can go red.
reg L1h 'a UTF-8 BOM before the frontmatter still reads as pinned' 0 0 '' '^MISS ' \
  'kills: the BOM/CRLF normalization before leg 1 frontmatter parsing — a BOM makes line 1 fail the ^--- test, so a correctly pinned file reports as unpinned'
reg L1i 'a file with NO frontmatter is not pinned by a model: line in its body' 1 0 \
  'no model: key in frontmatter' '' \
  'kills: the awk no-frontmatter guard (LOOSENING) — prose would satisfy leg 1. Also pins the miss COUNT for this branch, which prints its message either way'
reg L1j 'a model: line AFTER the frontmatter closes is not a pin' 1 0 \
  'no model: key in frontmatter' '' \
  'kills: the closing-delimiter exit (LOOSENING) — a tier named in the body would satisfy leg 1. Also pins the miss COUNT for this branch'
reg L1k 'an inline comment after the tier does not break the pin' 0 0 '' '^MISS ' \
  'kills: inline-comment stripping in the leg 1 value — `model: sonnet  # note` would stop reading as a pin'
reg L1m 'a capitalized tier value still reads as a pin' 0 0 '' '^MISS ' \
  'kills: the lowercasing of the leg 1 VALUE. Case 8 lowercases a leg 4 qualifier, which is a different construct and passes either way'
reg L1n 'a truncated tier is not a tier' 1 0 \
  'model: son is not a sanctioned tier' '' \
  'kills: grep -qx -> grep -q (LOOSENING), which makes the value a substring PATTERN so `son` validates against sonnet'
reg L1p 'the top tier is not sanctioned for automatic dispatch' 1 0 \
  'model: fable is not a sanctioned tier' '' \
  'kills: admitting fable to ALLOWED_TIERS. L3c plants fable in a mode-conditional marker, where tier_rank rejects it independently — so leg 1 had no fable plant behind it'

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
reg L2i 'a SYMLINKED plugin directory is still scanned' 0 1 \
  'dispatch instruction with no pin' '' \
  'kills: dropping -L from legs 2-3 SCAN_DIRS discovery — a whole plugin scanned by nothing'
# This case kills NO registered mutant, and that is the finding it records.
# It was written to kill leg 2 grep read-error arm; the sweep then showed it
# staying GREEN under that mutant, because leg 2 readability probe reads the
# whole file first and refuses it before the arm runs. The arm is now a
# declared survivor (see the STATED LIMIT at check-model-pins.sh:311). What
# this fixture actually covers is that probe — a construct NOTHING in the
# registry sabotages. Kept for exactly that reason: it is the only case
# standing behind it, and editing leg 2 read-error arm will not move it.
reg L2j 'an UNREADABLE file under a scanned plugin is refused by leg 2' 3 0 \
  'unreadable during leg 2 scan' '' \
  'covers leg 2 readability probe, which no mutant sabotages — NOT a kill for the grep read-error arm, which is a declared survivor. L3f is the sibling that does kill a live mutant, because leg 3 has no probe'

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
# A SECOND case over the same fixture shape as L2j, deliberately, not a second
# assertion bolted onto it. The checker's own comment says leg 3 must not lean
# on leg 2 catching an unreadable file first, because that is loop order rather
# than a guarantee — so the two read-error arms are two constructs, and each
# needs a case that names the leg in its expected message.
reg L3f 'the same unreadable file is refused by leg 3 on its own' 3 0 \
  'unreadable during leg 3 scan' '' \
  'kills: leg 3 own read-error arm — with it gone, leg 3 is silent on a file it could not read whenever leg 2 happens to be silent too'
reg L3g 'a run-on token does not satisfy the interactive= branch' 1 0 \
  'must name both branches' '' \
  'kills: the left word boundary on interactive= (LOOSENING). `noninteractive=opus headless=sonnet` would otherwise declare the attended branch and pass as a well-ordered pair'

# --- The verdict and exit path ----------------------------------------------
# Counts and exit status are asserted by every case above. The line PREFIX is
# not: a checker that renamed `MISS ` to `Miss ` would keep every count, every
# exit code and every message body intact, and only the machine-readable half
# of its output would be gone. So one case anchors the prefix explicitly.
reg V1 'findings are prefixed with the MISS token' 1 0 \
  "^MISS model-pin: ${SS}9q is cited but" '' \
  'kills: a change to the MISS line prefix — invisible to counts, to the exit code and to every message assertion in this file, which all match on the body'

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

# Every file under one or more directories that leg 4 would scan, by its
# extension set. Cases 17, 29 and 36 all assert something about whole ROOTS, so
# they need all of them: a case that neutralizes one file BY NAME stops being
# that case the moment a sibling is added, and its failure mode is a clean PASS.
#
# `-L` mirrors leg 4's own discovery idiom (`find -L ... -type f`). Without it,
# a symlinked `.yml` under a root is invisible here while the checker still
# reads it — so a post-plant assertion would pass while the root stayed
# covered, and the case would go red for a reason that has nothing to do with
# the checker.
#
# THE EXTENSION LIST IS A SECOND COPY of `CITE_EXTS` in check-model-pins.sh:525
# (`$MD_EXTS sh yml yaml`), and it is not derived from it. What actually
# happens when they diverge, stated correctly because the previous wording here
# claimed a mechanism the code does not have: an extension added to CITE_EXTS
# and not here does NOT fail the plant — this helper simply cannot see such a
# file, so the post-assertion passes and `plant` returns 0. It surfaces one
# step later as a failed CASE (the root stays covered, so 17/36's expected MISS
# never appears), and only when a file of that extension exists under the root
# at the time. Red either way, never a quiet pass — but the failure names the
# case, not the divergence, so keep this list in step with CITE_EXTS by hand.
scannable_in() {  # scannable_in <dir>... ; extra find predicates after a `--`
  local dirs=() pred=()
  while [ $# -gt 0 ]; do
    case "$1" in --) shift; pred=("$@"); break ;; *) dirs+=("$1") ;; esac
    shift
  done
  find -L "${dirs[@]}" -type f \( -name '*.md' -o -name '*.markdown' -o -name '*.sh' \
    -o -name '*.yml' -o -name '*.yaml' \) "${pred[@]+"${pred[@]}"}" 2>/dev/null
}

# `scannable_in` sends find's stderr to /dev/null and is read through `$(...)`,
# so a missing or unreadable directory yields empty output at a NON-ZERO exit —
# byte-identical to "the plant worked, nothing scannable is left". A
# post-assertion that only tests emptiness therefore reads a broken fixture as a
# successful plant, which is the documented signal these two cases were rewritten
# to escape in the first place. Capture the status and require BOTH.
scannable_gone() {  # scannable_gone <dir>... ; extra find predicates after a `--`
  local left rc
  left=$(scannable_in "$@"); rc=$?
  [ "$rc" -eq 0 ] && [ -z "$left" ]
}

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
    # 17 and 36 neutralize a whole ROOT, so they must act on EVERY scannable
    # file under it rather than on `model-pins.yml` by name. Adding a second
    # workflow file left `.github` still scannable and the expected MISS never
    # appeared: both cases degraded into second copies of the baseline while
    # still reporting PASS. Reproduced when mutation-sweep.yml landed —
    # `2/2 passed` became `FAIL 17` / `FAIL 36`. Assert the plant landed in
    # both directions (something was there; nothing scannable is left), so a
    # future extension added to CITE_EXTS and not to scannable_in() shows up
    # as a failed plant rather than as a quiet pass.
    17) [ -n "$(scannable_in "$d/.github")" ] || return 1
        while IFS= read -r p; do mv "$p" "$p.txt" || return 1; done < <(scannable_in "$d/.github")
        scannable_gone "$d/.github" || return 1
        : ;;
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
        # Routed through scannable_in so the extension set lives in ONE place
        # in this file. A private fourth copy here was missed by the same diff
        # that added the helper — the duplicated-literal signal, live.
        while IFS= read -r p; do sed -i "s/${SS}/S-/g" "$p" || return 1
        done < <(scannable_in "$d/plugins" "$d/.github" "$d/scripts")
        sed -i "s/${SS}/S-/g" "$d/CLAUDE.md" "$d/README.md" ;;

    # The target sits at the fixture root, which is NOT a citation root, so the
    # symlink under scripts/ is the only path by which leg 4 can reach it.
    30) printf 'The rule is %s9q here.\n' "$SS" > "$d/zzcite-target.md"
        ln -s ../zzcite-target.md "$d/scripts/zzcite-link.sh"
        [ -L "$d/scripts/zzcite-link.sh" ] || return 1
        [ -r "$d/scripts/zzcite-link.sh" ] || return 1 ;;
    # A CONTAINED two-node cycle, holding no files. A loop pointing at the tree
    # root also works but is a bad control: `find` detects the cycle only on the
    # second descent, so one full extra pass happens first and legs 2-3 re-scan
    # the whole repo through the link — dozens of WARNs from unrelated prose.
    # The case would then pass on the flood rather than on the probe.
    31) mkdir -p "$d/plugins/zzloopdir"
        ln -s ../zzloopdir "$d/plugins/zzloopdir/self"
        [ -L "$d/plugins/zzloopdir/self" ] || return 1
        [ -d "$d/plugins/zzloopdir/self/self" ] || return 1 ;;
    33) mkdir -p "$d/scripts/zzsub"
        printf '#!/bin/sh\n' > "$d/scripts/zzsub/z.sh"
        chmod 000 "$d/scripts/zzsub"
        [ -r "$d/scripts/zzsub" ] && return 1
        : ;;
    34) printf '#!/bin/sh\n' > "$d/scripts/zzunread.sh"
        chmod 000 "$d/scripts/zzunread.sh"
        [ -r "$d/scripts/zzunread.sh" ] && return 1
        : ;;
    35) mkdir -p "$d/scripts/zzloopdir"
        ln -s ../zzloopdir "$d/scripts/zzloopdir/self"
        [ -d "$d/scripts/zzloopdir/self/self" ] || return 1 ;;
    36) [ -n "$(scannable_in "$d/.github")" ] || return 1
        while IFS= read -r p; do : > "$p" || return 1; done < <(scannable_in "$d/.github")
        scannable_gone "$d/.github" -- -size +0c || return 1
        : ;;

    37) printf '# zzcite\n# The rule is %s9q here.\n' "$SS" > "$d/.github/zzcite.yaml" ;;
    38) [ -n "$(find "$d/plugins" -path '*/skills/*/SKILL.md' -type f)" ] || return 1
        find "$d/plugins" -path '*/skills/*/SKILL.md' -type f -delete
        [ -z "$(find "$d/plugins" -path '*/skills/*/SKILL.md' -type f)" ] || return 1
        : ;;
    39) say "$d" "See -cepa:grounding ${SS}9c here." ;;
    # The mention must NOT be at the start of a line, or the clean checker
    # defines the anchor too and the case degrades into a second baseline.
    #
    # BOTH assertions are needed, and the positive one is the load-bearing
    # half. Asserting only the negative — "the line did not land at column 0" —
    # is VACUOUSLY TRUE when nothing landed at all: redirect the append at a
    # path that cannot be written and the case still printed PASS, because the
    # 1 MISS it expects comes from `say` rather than from the distinguishing
    # fixture. Reproduced. That is this file's own rule 3, in the one shape it
    # does not cover in so many words: a plant whose expected count survives
    # its own no-op.
    40) printf 'Prose that mentions the heading ### 9zz. must not define it.\n' \
          >> "$d/plugins/cepa/skills/autonomy/SKILL.md"
        grep -q 'mentions the heading ### 9zz\.' \
          "$d/plugins/cepa/skills/autonomy/SKILL.md" || return 1
        grep -q '^### 9zz\.' "$d/plugins/cepa/skills/autonomy/SKILL.md" && return 1
        say "$d" "The rule is ${SS}9zz here." ;;
    # The heading is on LINE 1 because that is the only line a BOM can reach.
    # A printf that silently dropped the BOM would leave a working skill file
    # behind and this case would pass forever, so the bytes are asserted.
    41) mkdir -p "$d/plugins/cepa/skills/zzskillbom"
        printf '\xEF\xBB\xBF### 9zy. Control heading\n\nBody.\n' \
          > "$d/plugins/cepa/skills/zzskillbom/SKILL.md"
        head -c 3 "$d/plugins/cepa/skills/zzskillbom/SKILL.md" | od -An -tx1 \
          | grep -q 'ef bb bf' || return 1
        say "$d" "The rule is ${SS}9zy here." ;;
    42) mkdir -p "$d/plugins/cepa/skills/zzskillup"
        printf '### 9ZQ. Control heading\n\nBody.\n' \
          > "$d/plugins/cepa/skills/zzskillup/SKILL.md"
        grep -q '^### 9ZQ\.' "$d/plugins/cepa/skills/zzskillup/SKILL.md" || return 1
        say "$d" "The rule is ${SS}9zq here." ;;
    V1) say "$d" "${SS}9q applies here." ;;
    L1f) mkdir -p "$d/plugins/zzsrc" "$d/plugins/zzp1" "$d/plugins/zzp2"
        printf -- '---\nname: zzl1f\nmodel: inherit\n---\n\n# zzl1f\n' \
          > "$d/plugins/zzsrc/zzl1f.md"
        ln -s ../zzsrc "$d/plugins/zzp1/agents"
        ln -s ../zzsrc "$d/plugins/zzp2/agents"
        [ -d "$d/plugins/zzp1/agents" ] && [ -d "$d/plugins/zzp2/agents" ] || return 1
        : ;;
    # /dev/zero, not a FIFO: both hang `grep -R` identically, and a character
    # device needs no cleanup and cannot leave a blocked writer behind. The
    # file is named `.sh` so it is inside leg 4's extension set — the point is
    # that the extension matches and the TYPE does not.
    32) [ -c /dev/zero ] || return 1
        ln -s /dev/zero "$d/scripts/zzdev.sh"
        [ -L "$d/scripts/zzdev.sh" ] || return 1
        [ -c "$d/scripts/zzdev.sh" ] || return 1 ;;

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
    # The `agents` entry itself is the symlink, so leg 1's DIRECTORY discovery
    # has to follow it before any file discovery gets a chance.
    L1e) mkdir -p "$d/plugins/zzsrc" "$d/plugins/zzplug"
        printf -- '---\nname: zzl1e\nmodel: inherit\n---\n\n# zzl1e\n' \
          > "$d/plugins/zzsrc/zzl1e.md"
        ln -s ../zzsrc "$d/plugins/zzplug/agents"
        [ -L "$d/plugins/zzplug/agents" ] || return 1
        [ -d "$d/plugins/zzplug/agents" ] || return 1 ;;

    # mode 000, so leg 1's readability guard is the construct under test. The
    # same file is unreadable to legs 2, 3 and 4 as well — see this case's
    # `reg` note for why the expected count is four and not one.
    L1g) printf -- '---\nname: zzl1g\nmodel: sonnet\n---\n\n# zzl1g\n' \
           > "$d/plugins/cepa/agents/zzl1g.md"
        chmod 000 "$d/plugins/cepa/agents/zzl1g.md"
        [ -r "$d/plugins/cepa/agents/zzl1g.md" ] && return 1
        : ;;
    # A printf that silently failed to emit the BOM would leave an ordinary
    # pinned file behind — a second copy of the baseline, reporting PASS
    # forever. Assert the bytes landed.
    L1h) printf '\xEF\xBB\xBF---\r\nname: zzl1h\r\nmodel: sonnet\r\n---\r\n\r\n# zzl1h\r\n' \
           > "$d/plugins/cepa/agents/zzl1h.md"
        head -c 3 "$d/plugins/cepa/agents/zzl1h.md" | od -An -tx1 | grep -q 'ef bb bf' || return 1
        : ;;
    L1i) printf '# zzl1i\n\nThis definition has no frontmatter at all.\n\nmodel: sonnet\n' \
           > "$d/plugins/cepa/agents/zzl1i.md" ;;
    L1j) printf -- '---\nname: zzl1j\ndescription: control fixture\n---\n\n# zzl1j\n\nmodel: sonnet\n' \
           > "$d/plugins/cepa/agents/zzl1j.md" ;;
    L1k) printf -- '---\nname: zzl1k\nmodel: sonnet  # deliberate, per the ladder\n---\n\n# zzl1k\n' \
           > "$d/plugins/cepa/agents/zzl1k.md" ;;
    L1m) printf -- '---\nname: zzl1m\nmodel: Sonnet\n---\n\n# zzl1m\n' \
           > "$d/plugins/cepa/agents/zzl1m.md" ;;
    L1n) printf -- '---\nname: zzl1n\nmodel: son\n---\n\n# zzl1n\n' \
           > "$d/plugins/cepa/agents/zzl1n.md" ;;
    L1p) printf -- '---\nname: zzl1p\nmodel: fable\n---\n\n# zzl1p\n' \
           > "$d/plugins/cepa/agents/zzl1p.md" ;;
    # The plugin directory itself is the symlink — and its target lives OUTSIDE
    # `plugins/`, so nothing else can reach the file.
    L2i) mkdir -p "$d/zzplugsrc/commands"
        cat > "$d/zzplugsrc/commands/zzl2i.md" <<'EOF'
# zzl2i

Dispatch each reviewer as a generic subagent.
EOF
        ln -s ../zzplugsrc "$d/plugins/zzplugin"
        [ -L "$d/plugins/zzplugin" ] || return 1
        [ -d "$d/plugins/zzplugin" ] || return 1 ;;

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

    # L2j and L3f plant the SAME shape under two names on purpose: legs 2 and 3
    # report an unreadable file through separate constructs, and each case
    # names the leg it is about in its expected message. (An earlier note here
    # claimed a single combined case "would go green the moment either leg
    # started leaning on the other" — that is wrong, and measurably so: a
    # combined case asserting both messages would fail on the count as well as
    # on the regex. The split is redundant rather than stronger. Kept because
    # two named messages diagnose faster than one, and corrected here because
    # an unmeasured claim sitting beside measured ones is how the next reader
    # learns the wrong lesson.)
    L2j) printf '# zzl2j\n\nNothing in this file can be read.\n' \
           > "$d/plugins/cepa/commands/zzl2j.md"
        chmod 000 "$d/plugins/cepa/commands/zzl2j.md"
        [ -r "$d/plugins/cepa/commands/zzl2j.md" ] && return 1
        : ;;
    L3f) printf '# zzl3f\n\nNothing in this file can be read.\n' \
           > "$d/plugins/cepa/commands/zzl3f.md"
        chmod 000 "$d/plugins/cepa/commands/zzl3f.md"
        [ -r "$d/plugins/cepa/commands/zzl3f.md" ] && return 1
        : ;;
    # `noninteractive=` runs straight into the key leg 3 looks for. With the
    # left word boundary gone it reads as a well-ordered opus/sonnet pair and
    # the whole marker passes; with it, the interactive branch is MISSING.
    L3g) printf '# zzl3g\n\n<!-- model-pin: mode-conditional noninteractive=opus headless=sonnet -->\n' \
           > "$d/plugins/cepa/commands/zzl3g.md" ;;

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
  # Cases 33/34 plant unreadable paths; rm cannot descend into a mode-000
  # directory, so restore traversal bits first or every run leaks a full tree.
  chmod -R u+rwX "$TMPROOT" 2>/dev/null
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

# Per-case bound. A case whose regression is a HANG rather than a wrong answer
# has to fail fast, or the suite hangs with the defect it is testing for.
case_timeout() { case "$1" in 32) printf 20 ;; *) printf 120 ;; esac; }

CHK_OUT=''; CHK_RC=0; CHK_MISS=''; CHK_WARN=''
run_checker() {  # run_checker <dir> [timeout_seconds]
  # Bounded: a hung checker would otherwise hang the suite and the CI job
  # until the job timeout, with no diagnostic. `-k 30`: TERM alone is not a
  # bound — a checker that ignores or never reaches the handler (the mutants
  # this suite exists for get to be arbitrary) would turn one case's 120s
  # into the sweep's 900s outer abort; KILL keeps a hang a CASE failure.
  CHK_OUT=$(cd "$1" && timeout -k 30 "${2:-120}" bash "$CHECKER" 2>&1)
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
  # BASELINE-ABORT is a machine token PARSED BY scripts/run-mutation-sweep.sh.
  # It precedes the prose deliberately: the sweep used to grep this sentence,
  # so an ordinary copy edit here would have made a re-anchorable mutant report
  # as a broken environment. Change the token only together with that parser.
  printf 'BASELINE-ABORT dirty\n'
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
  printf 'BASELINE-ABORT zero-coverage\n'
  printf 'FATAL: baseline reports zero coverage in: %s\n' "$baseline_bad"
  printf '       A clean run over nothing is not a clean run.\n\n'
  printf '%s\n' "$CHK_OUT"
  exit 1
fi
printf 'baseline: 0 MISS, 0 WARN, exit 0; %s tracked files; coverage counters non-zero\n\n' "$expected_files"

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
passed=0; failed=0; ran=0; errored=0
FAILED_IDS=''
ERRORED_IDS=''

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

# A case that could not be SET UP is not a case that failed its assertion, and
# the two must not share a token. `FAIL  <id>` is parsed by
# scripts/run-mutation-sweep.sh as "a control went red", i.e. as a mutant kill;
# a fixture copy or a plant that no-ops means the control never ran at all.
# Reproduced before this split: simulating one ENOSPC fixture copy flipped a
# genuinely-surviving mutant from SURVIVED-UNDECLARED/exit 1 to CAUGHT/exit 0 —
# an environment failure re-entering as a verdict, which is exactly what
# `cepa:autonomy` §9f's HARNESS-ERROR row exists to forbid.
#
# PARSED BY scripts/run-mutation-sweep.sh — the `ERROR  ` prefix and the
# `-- N setup errors --` line below are a machine contract, not prose. Change
# them only together with that file's classifier.
error_case() {  # error_case <index> <reason>
  local i="$1"
  printf 'ERROR %-4s %s\n' "${IDS[$i]}" "${TITLES[$i]}"
  printf '        setup failed, so this control never ran: %s\n' "$2"
  errored=$((errored + 1))
  ERRORED_IDS="${ERRORED_IDS}${IDS[$i]} "
}

run_one() {
  local i="$1" id="${IDS[$1]}" title="${TITLES[$1]}" exp_rc
  local dir="$TMPROOT/case-$id"
  ran=$((ran + 1))

  cp -a "$PRISTINE" "$dir" || { error_case "$i" 'could not copy fixture'; return; }
  # "returned non-zero" is the whole claim this can make. A plant that no-ops
  # SILENTLY is caught only by its own post-plant assertion, which is why every
  # arm that can no-op carries one — the message used to say "or landed as a
  # no-op", which promised a detection the mechanism does not perform.
  plant "$id" "$dir" || { error_case "$i" 'plant step returned non-zero'; return; }

  if ! run_checker "$dir" "$(case_timeout "$id")"; then
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
    cp -a "$PRISTINE" "$alt" || { error_case "$i" 'could not copy fixture'; return; }
    plant 24b "$alt" || { error_case "$i" 'plant step failed (.markdown)'; return; }
    if ! run_checker "$alt" "$(case_timeout "$id")"; then
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
# Emitted BEFORE the trailer and on every run, zero included, so a consumer can
# tell "no setup errors" from "this suite is too old to report them". A control
# that could not be set up is not evidence about the checker in either
# direction, so it is never folded into passed/failed.
printf '\n-- %d setup errors --\n' "$errored"
if [ "$errored" -gt 0 ]; then
  printf 'ERROR: %d control(s) could not be set up, so this run is not evidence about\n' "$errored"
  printf '       the checker. Errored: %s\n' "$ERRORED_IDS"
fi
printf '\n-- %d/%d controls passed --\n' "$passed" "$ran"
if [ "$errored" -gt 0 ]; then
  exit 1
fi
if [ "$failed" -gt 0 ]; then
  printf 'FAIL: the checker no longer behaves the way its record claims. Failed: %s\n' "$FAILED_IDS"
  exit 1
fi
exit 0

#!/usr/bin/env bash
# cepa model-pin check — read-only. Verifies that no subagent dispatch in
# this plugin's source can fall through to the invoking session's model
# tier. Run from the repo root. Never modifies anything.
#
#   Leg 1: every agent definition declares a model: whose value is in the
#   sanctioned tier set. Presence is not enough — the point is a CEILING,
#   so an unrecognized tier is a MISS even though a key exists.
#   Leg 2: dispatch instructions in command and skill bodies carry a pin
#   nearby, or an explicit prose-suppression marker.
#   Leg 3: a dispatch declared mode-conditional (autonomy §9d) names both
#   branch tiers IN THE MARKER, both are sanctioned, and the headless tier
#   never costs more than the interactive one. Leg 2 is satisfied by any ONE
#   sanctioned tier, so deleting the headless branch of a pair would
#   otherwise pass clean — the silent-regression class this repo keeps
#   shipping.
#
#   Leg 3's STATED LIMIT: it checks the pair's shape and direction, never
#   whether the values match the tier §9c's ladder mandates for that
#   dispatch. `interactive=haiku headless=haiku` passes — both sanctioned,
#   not inverted — while silently downgrading a panel §9c puts at opus.
#   Closing that needs a path→expected-tier table in this script, which is
#   the hardcoded-coupling class CLAUDE.md documents drifting three times.
#   So it is deliberately a human review obligation, recorded here rather
#   than left to look covered.
#
#   Leg 3 reads the MARKER, never the surrounding prose. An earlier cut
#   inferred the pair by counting distinct tier literals in the marker's
#   block, which failed three ways at once: a correct declaration written as
#   a blank-line-separated list MISSed (block scoping spans one boundary, not
#   two) and its cheapest remedy was DELETING the marker — turning leg 3 off
#   at that site; `haiku`+`sonnet` passed as happily as `opus`+`sonnet`,
#   so a silent downgrade of the interactive branch was green; and a tier
#   belonging to an unrelated neighbouring block counted toward the pair.
#   Counting tokens in prose cannot express "these two, in this direction."
#
#   Leg 4: every section citation of the form (section-sign, number, letter)
#   resolves to a heading in the skill that owns it. Scope and stated limits
#   live in autonomy §9f — read them there.
#
# All four legs fail the run. A warning channel that can never fail is not
# enforcement — so leg 2's escape hatch is an explicit, diff-reviewable
# marker on the line that needs it:
#
#     <!-- model-pin: prose -->
#
# Why legs 1 and 2 differ: registered agents make an omission greppable in
# frontmatter; generic subagents (a Task call seeded from a prompt
# template, no registered agent type) have no frontmatter to fall back on,
# so their pin lives in prose and only a heuristic can find it. See
# docs/solutions/logic-errors/unpinned-subagent-dispatches-inherit-the-session-model.md
set -u

ok()   { printf 'OK   %s\n' "$1"; }
miss() { printf 'MISS %s\n' "$1"; }
warn() { printf 'WARN %s\n' "$1"; }
info() { printf 'INFO %s\n' "$1"; }

# The sanctioned tiers. `inherit` is deliberately absent: it is a choice to
# spend at the invoking session's tier. So is `fable` — the top tier is
# reserved for work a person opted into, never for automatic dispatch.
ALLOWED_TIERS='sonnet opus haiku'
# The markdown extension set, declared ONCE. There are four file-selection
# sites — leg 1's discovery, legs 2-3's discovery, and leg 4's citation scan
# and coverage probe — and `find` and `grep` want different syntax for the
# same fact. Round 2 widened three of the four with `*.markdown` and left
# legs 2-3 on `*.md`, which made a `.markdown` file readable by leg 4 and
# invisible to the legs that check dispatch pins: an inverted
# mode-conditional pair in one shipped as `0 MISS, 0 WARN`. That is the
# construct-vs-instance class CLAUDE.md documents, and this script had
# already been bitten once by an unscanned-file hole (see the leg 2-3 scan
# roots comment). Derive both forms here so a future widening cannot land at
# three sites out of four.
MD_EXTS='md markdown'
find_name_args=()
grep_include_args=()
for _e in $MD_EXTS; do
  [ "${#find_name_args[@]}" -eq 0 ] || find_name_args+=(-o)
  find_name_args+=(-name "*.${_e}")
  grep_include_args+=("--include=*.${_e}")
done
# Leg 4 additionally reads shell and workflow files; markdown is shared.
CITE_INCLUDES=("${grep_include_args[@]}" --include='*.sh' --include='*.yml' --include='*.yaml')
SUPPRESS_MARKER='model-pin: prose'
# A dispatch whose tier branches on invocation mode (autonomy §9d) declares
# both literals IN the marker:
#
#     <!-- model-pin: mode-conditional interactive=opus headless=sonnet -->
#
# Self-contained and single-line on purpose: the declaration cannot drift
# with prose reflow, and leg 3 can check the identity and direction of the
# pair rather than merely counting tier words near it.
MODECOND_MARKER='model-pin: mode-conditional'
# Cost order, cheapest first. Used ONLY to assert headless <= interactive —
# an unattended run must never cost more than the attended one it mirrors.
# This is the invariant behind the whole mode-conditional idea; without it
# the pin could be inverted and still pass as "a branch exists".
TIER_RANK_haiku=1
TIER_RANK_sonnet=2
TIER_RANK_opus=3
tier_rank() {
  case "$1" in
    haiku) printf '%s' "$TIER_RANK_haiku" ;;
    sonnet) printf '%s' "$TIER_RANK_sonnet" ;;
    opus) printf '%s' "$TIER_RANK_opus" ;;
    *) printf '0' ;;
  esac
}
# Block scoping replaces the old fixed-line window; see block_range().

misses=0
warns=0

echo "== cepa model-pin check: $(pwd) =="

# Agent directories are discovered, not hardcoded: a plugin split or a
# rename must surface as a changed count, never as a quiet zero.
mapfile -t AGENT_DIRS < <(find -L plugins -type d -name agents 2>/dev/null | sort)
if [ "${#AGENT_DIRS[@]}" -eq 0 ]; then
  miss "no plugins/*/agents directory found — run from the plugin source repo root"
  echo "-- 1 MISS, 0 WARN --"
  exit 1
fi
info "agent directories: ${AGENT_DIRS[*]}"

# --- Leg 1: agent frontmatter ----------------------------------------------
# -L follows symlinked definitions; a symlink silently skipped is a file
# nobody checked. Both markdown extensions are matched for the same reason.
agent_count=0
while IFS= read -r f; do
  agent_count=$((agent_count + 1))

  if [ ! -r "$f" ]; then
    miss "model-pin: ${f} — unreadable (a file that cannot be checked is not a pass)"
    misses=$((misses + 1))
    continue
  fi

  # Normalize before parsing: a CRLF first line or a UTF-8 BOM otherwise
  # reads as "no frontmatter" and reports a pinned file as unpinned.
  fm_model=$(sed $'1s/^\xEF\xBB\xBF//; s/\r$//' "$f" 2>/dev/null |
    awk 'NR==1 && $0 !~ /^---[[:space:]]*$/{exit} NR==1{next} /^---[[:space:]]*$/{exit} /^model:/{print; exit}')

  if [ -z "$fm_model" ]; then
    miss "model-pin: ${f} — no model: key in frontmatter (dispatches at the invoking session's tier)"
    misses=$((misses + 1))
    continue
  fi

  # Strip the key, an inline # comment, surrounding quotes and whitespace,
  # then lowercase. `model: Inherit  # deliberate` must not read as a pin.
  value=$(printf '%s' "$fm_model" |
    sed 's/^model:[[:space:]]*//; s/[[:space:]]*#.*$//; s/^["'"'"']//; s/["'"'"']$//; s/[[:space:]]*$//' |
    tr '[:upper:]' '[:lower:]')

  case "$value" in
    ""|"~"|null)
      miss "model-pin: ${f} — model: is empty/null (resolves to the invoking session's tier)"
      misses=$((misses + 1)) ;;
    *)
      if printf '%s\n' $ALLOWED_TIERS | grep -qx -- "$value"; then
        ok "model-pin: ${f##*/} → ${value}"
      else
        miss "model-pin: ${f} — model: ${value} is not a sanctioned tier (${ALLOWED_TIERS// /, }); \`inherit\` rides the session's tier and the top tier is never dispatched automatically"
        misses=$((misses + 1))
      fi ;;
  esac
done < <(find -L "${AGENT_DIRS[@]}" \( "${find_name_args[@]}" \) -type f 2>/dev/null | sort)

if [ "$agent_count" -eq 0 ]; then
  miss "model-pin: agent directories exist but hold no agent definitions — check the path and extensions before trusting this run"
  misses=$((misses + 1))
fi
info "agent definitions checked: ${agent_count}"

# --- Leg 2: dispatch instructions in prose ---------------------------------
# The trigger set is deliberately broad. A false positive costs one
# suppression marker in a diff; a false negative is the defect this check
# exists to prevent.
DISPATCH_RE='[Dd]ispatch(es|ing)? (each|every|all|the selected|a Task|it|them)|generic sub-?agent|[Ss]ub-?agents? (are |is )?(dispatch|drafted|seeded|launch|spawn)|Task tool call|subagent_type|[Ll]aunch (these|ALL|all|each|every) |[Ss]pawn .*[Ss]ub-?agent|use .*[Ss]ub-?agents'
# A pin is `model:` followed by a sanctioned tier — NOT the bare string
# `model:`, which matches prose about pins and lets a genuinely unpinned
# dispatch hide in the files densest with pin documentation.
PIN_RE='model:[[:space:]]*`?('"${ALLOWED_TIERS// /|}"')'

# Scope a dispatch instruction to its own markdown block plus the block
# immediately after it — where an author actually writes the pin. A fixed
# ±N-line window is unusable here: the files densest with pin
# DOCUMENTATION are exactly the ones where a real unpinned dispatch would
# hide behind a `model: sonnet` belonging to unrelated prose nearby.
# Blocks are blank-line delimited. A pin in a PRECEDING block does not
# count — move it or mark the line.
block_range() {
  awk -v n="$2" '
    /^[[:space:]]*$/ { blank[NR]=1 }
    { last=NR }
    END {
      lo=1; for (i=n-1; i>=1; i--) if (blank[i]) { lo=i+1; break }
      e=last; for (i=n; i<=last; i++) if (blank[i]) { e=i-1; break }
      j=e+1; while (j<=last && blank[j]) j++
      hi=e; if (j<=last) { hi=last; for (i=j; i<=last; i++) if (blank[i]) { hi=i-1; break } }
      print lo, hi
    }' "$1"
}

scan_body() {
  local f="$1" ln grc hits range
  grep -c '' "$f" >/dev/null 2>&1 || { printf 'UNREADABLE\n'; return; }

  # A single NUL byte makes GNU grep treat the file as binary: the notice
  # goes to stderr (discarded below), stdout is empty, exit is 0 — so every
  # dispatch in the file reads as "no matches" and the run passes clean. The
  # readability probe above does not catch it. `-a` on the scanning greps
  # keeps them reading, and this check still reports the file as damaged
  # rather than silently scanning a file nobody meant to ship.
  # Detected by byte count, not by grepping for the byte: a bash string
  # cannot hold a NUL, so a `$'\0'` pattern is the EMPTY pattern — it matches
  # every file and reported the whole tree unreadable.
  if [ "$(tr -d '\000' < "$f" 2>/dev/null | wc -c)" -ne "$(wc -c < "$f" 2>/dev/null)" ]; then
    printf 'UNREADABLE\n'; return
  fi

  # grep exit 1 is "no matches"; anything higher is an error we must not
  # read as a clean file.
  hits=$(grep -naE "$DISPATCH_RE" "$f" 2>/dev/null)
  grc=$?
  if [ "$grc" -gt 1 ]; then printf 'UNREADABLE\n'; return; fi
  [ -n "$hits" ] || return 0

  while IFS= read -r line; do
    ln=${line%%:*}
    range=$(block_range "$f" "$ln")
    local scope
    scope=$(sed -n "${range% *},${range#* }p" "$f")
    printf '%s' "$scope" | grep -qE "$PIN_RE" && continue
    printf '%s' "$scope" | grep -qF "$SUPPRESS_MARKER" && continue
    printf '%s\n' "$ln"
  done <<< "$hits"
}

# --- Leg 3: mode-conditional dispatches declare both branches --------------
# Every rejection carries what it actually read, so a failure is actionable
# without reopening the diff.
scan_conditional() {
  local f="$1" ln hits grc line marker inter head ri rh range scope

  # Same grep discipline as leg 2: exit 1 is "no markers", anything higher is
  # an error. Leg 3 must not lean on leg 2's readability probe catching the
  # same file first — that is an accident of loop order, not a guarantee.
  hits=$(grep -naF "$MODECOND_MARKER" "$f" 2>/dev/null)
  grc=$?
  if [ "$grc" -gt 1 ]; then printf 'UNREADABLE\n'; return; fi
  [ -n "$hits" ] || return 0

  while IFS= read -r line; do
    ln=${line%%:*}
    marker=${line#*:}

    # The prose-suppression hatch applies here too. Leg 3 without a hatch
    # made documentation of the marker syntax into load-bearing CI content
    # whose only escape was deleting the marker being documented.
    range=$(block_range "$f" "$ln")
    scope=$(sed -n "${range% *},${range#* }p" "$f")
    printf '%s' "$scope" | grep -qF "$SUPPRESS_MARKER" && continue

    inter=$(printf '%s' "$marker" |
      sed -n 's/.*[^a-z]interactive=\([a-z]*\).*/\1/p' | tr '[:upper:]' '[:lower:]')
    head=$(printf '%s' "$marker" |
      sed -n 's/.*[^a-z]headless=\([a-z]*\).*/\1/p' | tr '[:upper:]' '[:lower:]')

    if [ -z "$inter" ] || [ -z "$head" ]; then
      printf '%s\tmalformed\tinteractive=%s headless=%s\n' \
        "$ln" "${inter:-MISSING}" "${head:-MISSING}"
      continue
    fi

    ri=$(tier_rank "$inter"); rh=$(tier_rank "$head")
    if [ "$ri" -eq 0 ] || [ "$rh" -eq 0 ]; then
      printf '%s\tunsanctioned\tinteractive=%s headless=%s\n' "$ln" "$inter" "$head"
      continue
    fi
    if [ "$rh" -gt "$ri" ]; then
      printf '%s\tinverted\tinteractive=%s headless=%s\n' "$ln" "$inter" "$head"
      continue
    fi
  done <<< "$hits"
}

# Scanned tree. Leg 1's directories are DISCOVERED so a plugin split shows
# up as a changed count; legs 2-3 hardcoded `commands` + `skills`, which left
# `agents/**`, `references/**`, and the repo's own READMEs unscanned. A
# mode-conditional marker placed in an unscanned file was checked by nothing
# and read as full compliance — verified by dropping one into
# agents/review/adversarial-reviewer.md and getting 0 MISS, 0 WARN. Scan all
# markdown under every plugin instead, for leg 1's stated reason.
mapfile -t SCAN_DIRS < <(find -L plugins -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
if [ "${#SCAN_DIRS[@]}" -eq 0 ]; then
  miss "model-pin: no plugins/* directory to scan for dispatch prose"
  misses=$((misses + 1))
fi
info "prose scan roots: ${SCAN_DIRS[*]:-none}"

for d in "${SCAN_DIRS[@]}"; do
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      if [ "$hit" = "UNREADABLE" ]; then
        miss "model-pin: ${f} — unreadable during leg 2 scan (not a pass)"
        misses=$((misses + 1))
        continue
      fi
      warn "model-pin: ${f}:${hit} — dispatch instruction with no pin in its block or the next (pin it, or mark the line <!-- ${SUPPRESS_MARKER} -->)"
      warns=$((warns + 1))
    done < <(scan_body "$f")

    while IFS=$'\t' read -r cln ckind cdetail; do
      [ -n "$cln" ] || continue
      if [ "$cln" = "UNREADABLE" ]; then
        miss "model-pin: ${f} — unreadable during leg 3 scan (not a pass)"
        misses=$((misses + 1))
        continue
      fi
      case "$ckind" in
        malformed)
          miss "model-pin: ${f}:${cln} — ${MODECOND_MARKER} must name both branches in the marker as interactive=<tier> headless=<tier> (read: ${cdetail}); autonomy §9d" ;;
        unsanctioned)
          miss "model-pin: ${f}:${cln} — mode-conditional names a tier outside ${ALLOWED_TIERS// /, } (read: ${cdetail}); autonomy §9b" ;;
        inverted)
          miss "model-pin: ${f}:${cln} — headless tier costs MORE than interactive (read: ${cdetail}); an unattended run must never exceed the attended one, autonomy §9c-9d" ;;
      esac
      misses=$((misses + 1))
    done < <(scan_conditional "$f")
  done < <(find -L "$d" \( "${find_name_args[@]}" \) -type f 2>/dev/null | sort)
done

# --- Leg 4: §N<letter> citations resolve ------------------------------------
# Cross-cutting policy is cited by sub-letter from ~10 files. Nothing verified
# that a cited §9c still names the thing the citing file assumes, so a future
# reorder or insert in the owning skill would silently invalidate the
# citations that make the consolidation work — the same silent-drift shape as
# the allowed-tools and hardcoded-count classes.
#
# SCOPE and STATED LIMITS live in `cepa:autonomy` §9f's does-NOT-cover table —
# read them there, not here. The one fact that belongs at this site because it
# constrains the CODE below: leg 4 checks that a citation RESOLVES to a
# heading, and matches only `§N<letter>`. Bare `§N` (§7 among them) is out of
# scope by construction. Widening to bare `§N` is a deliberate decision, not a
# tidy-up: §7's relay-point clauses are required instantiations, so a widened
# leg must exclude §7 by NUMBER and say why, inline.
#
# Ownership is RESOLVED, not assumed. The anchor->skill index is built from
# every skill's own headings, so a second skill introducing lettered sections
# is covered with no edit here. An earlier cut hardcoded autonomy/SKILL.md,
# which made the check a property of one file's path.
CITE_ROOTS='plugins CLAUDE.md README.md .github scripts'

# --- filesystem-loop probe (guards every leg's traversal) -------------------
# Every traversal here follows symlinks (`find -L`, `grep -R`), because a
# symlink silently skipped is a file nobody checked. That makes a filesystem
# LOOP reachable — and GNU find and grep both handle one the same way: warn on
# STDERR, skip the cyclic branch, exit 0. Every traversal in this script sends
# stderr to /dev/null, so without this probe a loop would silently truncate
# coverage: the exact failure the symlink-following exists to prevent,
# reintroduced by it.
#
# Probed ONCE for the whole construct rather than at each of the seven
# traversal sites — the site-by-site version of this rule is what left four of
# those seven asymmetric in the first place. CITE_ROOTS contains `plugins`, so
# it covers what all four legs walk.
#
# Broken symlinks are deliberately NOT flagged: `-type f` is false for them and
# there is no content to check.
loop_warn=$(find -L $CITE_ROOTS -type d 2>&1 >/dev/null | grep -i 'loop' | head -1)
if [ -n "$loop_warn" ]; then
  miss "model-pin: filesystem loop under a scan root — traversal is silently truncated there (${loop_warn})"
  misses=$((misses + 1))
fi

# Anchors and qualifiers are matched case-insensitively and lowercased before
# lookup. `[A-Za-z]+` not `[a-z]`: a single-letter class makes grep -o truncate
# a two-letter anchor to its first letter, so a typo'd anchor validates against
# the wrong heading.
#
# The range tail is `-[0-9]+[A-Za-z]+`, NUMBERED on both sides. An unnumbered
# tail swallowed ordinary hyphenated English: an anchor followed by a hyphen
# and a plain word (as in "the ...9c-style ladder") parsed as a range whose
# second endpoint was that word, inventing an anchor that resolves to nothing
# and failing the build on innocent prose. So the convention this enforces is
# that ranges are written fully numbered; a range whose tail omits the number
# checks only its first anchor.
#
# NOTE for anyone documenting this leg: it has no prose-suppression hatch (legs
# 2 and 3 do). Every root is scanned whole, so an example anchor written with a
# literal section sign becomes a real citation and MISSes. Describe such
# examples in words. Recorded in autonomy §9f.
CITE_RE='(`?[A-Za-z0-9_.:-]+`?[[:space:]]+)?§[0-9]+[A-Za-z]+(-[0-9]+[A-Za-z]+)*'
declare -A ANCHOR_OWNERS
declare -A SKILL_NAMES
skill_files=0
anchor_count=0
while IFS= read -r sk; do
  [ -r "$sk" ] || continue
  skill_files=$((skill_files + 1))
  sname=$(basename "$(dirname "$sk")" | tr '[:upper:]' '[:lower:]')
  SKILL_NAMES["$sname"]=1
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    [ -n "${ANCHOR_OWNERS["$a"]:-}" ] || anchor_count=$((anchor_count + 1))
    ANCHOR_OWNERS["$a"]="${ANCHOR_OWNERS["$a"]:-} $sname"
  done < <(sed $'1s/^\xEF\xBB\xBF//; s/\r$//' "$sk" 2>/dev/null |
    grep -aoE '^### [0-9]+[A-Za-z]+\.' 2>/dev/null |
    sed 's/^### //; s/\.$//' | tr '[:upper:]' '[:lower:]')
done < <(find -L plugins -path '*/skills/*/SKILL.md' -type f 2>/dev/null | sort)

if [ "$skill_files" -eq 0 ]; then
  miss "model-pin: no plugins/*/skills/*/SKILL.md found — §N<letter> citation targets unverifiable"
  misses=$((misses + 1))
fi

# Scan PER ROOT, and account for every one. A single `grep -r` over all roots
# returns matches from the survivors and exits 2 when one is missing — so
# renaming a root away left the run at 0 MISS while the INFO line still
# reported the configured count. Three distinct outcomes, none collapsible:
# missing root, grep error (exit >1), and a root that matched nothing.
# `-a` keeps grep reading a file containing a NUL byte; without it GNU grep
# calls the file binary, prints nothing to stdout, and exits 0 — every
# citation in it reads as absent. Leg 2 carries the same guard, but it scans
# only plugins/*, so the four roots added here were covered by nothing.
cite_raw=''
roots_scanned=0
for r in $CITE_ROOTS; do
  if [ ! -e "$r" ]; then
    miss "model-pin: leg 4 citation root '${r}' does not exist — coverage shrank silently"
    misses=$((misses + 1)); continue
  fi
  rout=$(grep -RahoE "$CITE_RE" "${CITE_INCLUDES[@]}" "$r" 2>/dev/null)
  rrc=$?
  if [ "$rrc" -gt 1 ]; then
    miss "model-pin: leg 4 grep failed on root '${r}' (exit ${rrc}) — an unreadable root is not a pass"
    misses=$((misses + 1)); continue
  fi
  if [ "$rrc" -eq 1 ]; then
    # Zero MATCHES is legitimate — a root whose prose cites no lettered section
    # today is fine, and `README.md` and `.github` each hold exactly one
    # citation, so asserting matches turned any copy edit into a red build
    # whose cheapest remedy was deleting the root. Assert instead that files
    # were READ: that is the actual hazard (a renamed directory, or an
    # --include set matching nothing there). Total-zero stays covered by the
    # `checked` guard below.
    rfiles=$(grep -RalE '' "${CITE_INCLUDES[@]}" "$r" 2>/dev/null | grep -c .)
    if [ "$rfiles" -eq 0 ]; then
      miss "model-pin: leg 4 root '${r}' holds no file matching the --include set — nothing was scanned there"
      misses=$((misses + 1)); continue
    fi
  fi
  roots_scanned=$((roots_scanned + 1))
  cite_raw="${cite_raw}${rout}"$'\n'
done
cite_raw=$(printf '%s' "$cite_raw" | grep -v '^$' | sort -u)

# One preceding token is captured so a citation can NAME its owner. It counts
# as a qualifier only when it matches a real skill name (below); ordinary prose
# sits directly before an anchor constantly ("per §9a", "the §2b", "tier §9c")
# and treating those as owner claims would MISS dozens of clean citations. The
# charset is the qualifier's only bound, so it is also its sanitization: no
# spaces, no leading dash, no path separators.
cite_pairs=''
while IFS= read -r m; do
  [ -n "$m" ] || continue
  qual=${m%%§*}
  rest=$(printf '%s' "${m#*§}" | tr '[:upper:]' '[:lower:]')
  qual=$(printf '%s' "$qual" | tr -d '`' |
    sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')
  case "$qual" in -*) qual='' ;; esac
  qual=${qual##*:}
  # Expand a hyphen-joined range (§9c-9d) into independent anchors. Without
  # this the second half of every range is verified by nothing — and one such
  # range lives in this script's own leg-3 message.
  first_num=''
  IFS='-' read -r -a parts <<< "$rest"
  for p in "${parts[@]}"; do
    [ -n "$p" ] || continue
    case "$p" in
      [0-9]*[a-z]) first_num=$(printf '%s' "$p" | sed 's/[a-z]*$//') ;;
      [a-z]*) p="${first_num}${p}" ;;
      *) continue ;;
    esac
    # `|` and NOT a tab: tab is IFS whitespace, so `read` collapses a leading
    # empty field and an UNQUALIFIED citation ("(§9c", line-initial "§9c")
    # arrives with the anchor in the qualifier slot and an empty anchor —
    # which the loop below then skips. That silently dropped every unqualified
    # citation in the repo, including CLAUDE.md's own §9a-§9f block. The
    # qualifier charset cannot contain `|`.
    cite_pairs="${cite_pairs}${qual}|${p}"$'\n'
  done
done <<< "$cite_raw"

cite_pairs=$(printf '%s' "$cite_pairs" | grep -v '^$' | sort -u)

checked=0
while IFS='|' read -r q a; do
  [ -n "${a:-}" ] || continue
  checked=$((checked + 1))
  owners="${ANCHOR_OWNERS["$a"]:-}"
  if [ -n "$q" ] && [ -n "${SKILL_NAMES["$q"]:-}" ]; then
    # Qualified: the citation names its owner, so check THAT skill.
    case " $owners " in
      *" $q "*) : ;;
      *)
        miss "model-pin: §${a} is cited as \`${q}\` §${a} but ${q}/SKILL.md has no '### ${a}.' heading — a citation that resolves to nothing"
        misses=$((misses + 1)) ;;
    esac
  else
    # Unqualified: any skill defining the anchor resolves it (autonomy §9f
    # records the ambiguity this accepts).
    if [ -z "$owners" ]; then
      miss "model-pin: §${a} is cited but no plugins/*/skills/*/SKILL.md has a '### ${a}.' heading — a citation that resolves to nothing"
      misses=$((misses + 1))
    fi
  fi
done <<< "$cite_pairs"

# Counted from rows that actually reached the check, never from the raw match
# set — an INFO line that counts rows nothing looked at is how a coverage hole
# reports as coverage.
if [ "$checked" -eq 0 ] && [ "$skill_files" -gt 0 ]; then
  miss "model-pin: leg 4 checked no §N<letter> citation — a scan that verifies nothing is not a pass"
  misses=$((misses + 1))
fi

info "§N<letter> citations checked: ${checked} distinct (qualifier, anchor) pairs across ${roots_scanned} of $(printf '%s\n' $CITE_ROOTS | grep -c .) roots; ${anchor_count} anchors defined by ${skill_files} skill files"

# --- verdict ---------------------------------------------------------------
echo "-- ${misses} MISS, ${warns} WARN --"
if [ "$misses" -gt 0 ] || [ "$warns" -gt 0 ]; then
  echo "FAIL: a dispatch can run at the invoking session's tier, or a check could not run."
  exit 1
fi
exit 0

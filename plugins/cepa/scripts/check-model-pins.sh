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
# All three legs fail the run. A warning channel that can never fail is not
# enforcement — so leg 2's escape hatch is an explicit, diff-reviewable
# marker on the line that needs it:
#
#     <!-- model-pin: prose -->
#
# Why two legs: registered agents make an omission greppable in
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
mapfile -t AGENT_DIRS < <(find plugins -type d -name agents 2>/dev/null | sort)
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
done < <(find -L "${AGENT_DIRS[@]}" \( -name '*.md' -o -name '*.markdown' \) -type f 2>/dev/null | sort)

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
mapfile -t SCAN_DIRS < <(find plugins -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
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
  done < <(find -L "$d" -name '*.md' -type f 2>/dev/null | sort)
done

# --- Leg 4: §9 citations resolve --------------------------------------------
# §9 is cited by sub-letter from ~10 files. Nothing verified that a cited
# §9c still names the thing the citing file assumes, so a future reorder or
# insert in autonomy/SKILL.md would silently invalidate the citations that
# make the consolidation work — the same silent-drift shape as the
# allowed-tools and hardcoded-count classes. Cheap structural check: every
# cited sub-letter must have a matching heading.
AUTONOMY='plugins/cepa/skills/autonomy/SKILL.md'
if [ -r "$AUTONOMY" ]; then
  cited=$(grep -rhoE '§9[a-z]' --include='*.md' --include='*.sh' \
    plugins CLAUDE.md README.md 2>/dev/null | sort -u)
  for c in $cited; do
    letter=${c#§9}
    if ! grep -qE "^### 9${letter}\." "$AUTONOMY"; then
      miss "model-pin: §9${letter} is cited but autonomy/SKILL.md has no '### 9${letter}.' heading — a citation that resolves to nothing"
      misses=$((misses + 1))
    fi
  done
  info "§9 citations checked: $(printf '%s\n' $cited | grep -c .)"
else
  miss "model-pin: ${AUTONOMY} unreadable — §9 citation targets unverifiable"
  misses=$((misses + 1))
fi

# --- verdict ---------------------------------------------------------------
echo "-- ${misses} MISS, ${warns} WARN --"
if [ "$misses" -gt 0 ] || [ "$warns" -gt 0 ]; then
  echo "FAIL: a dispatch can run at the invoking session's tier, or a check could not run."
  exit 1
fi
exit 0

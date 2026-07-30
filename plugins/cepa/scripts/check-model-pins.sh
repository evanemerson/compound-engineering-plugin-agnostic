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
#   Leg 3: a dispatch declared mode-conditional (autonomy §9d) carries BOTH
#   of its branch tiers. Leg 2 is satisfied by any ONE sanctioned tier, so
#   deleting the headless branch of an interactive/headless pair would
#   otherwise pass clean — the silent-regression class this repo keeps
#   shipping.
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
# both literals. The marker is what makes that structure checkable; without
# it, leg 3 has no way to tell "one tier, correctly" from "two tiers, one
# since deleted".
MODECOND_MARKER='model-pin: mode-conditional'
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

  # grep exit 1 is "no matches"; anything higher is an error we must not
  # read as a clean file.
  hits=$(grep -nE "$DISPATCH_RE" "$f" 2>/dev/null)
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
# Reports the tiers it DID find, so a failure names the surviving branch
# instead of only the missing one — the message has to be actionable without
# reopening the diff.
scan_conditional() {
  local f="$1" ln hits range scope found n
  hits=$(grep -nF "$MODECOND_MARKER" "$f" 2>/dev/null) || return 0
  [ -n "$hits" ] || return 0

  while IFS= read -r line; do
    ln=${line%%:*}
    range=$(block_range "$f" "$ln")
    scope=$(sed -n "${range% *},${range#* }p" "$f")
    found=$(printf '%s' "$scope" | grep -oE "$PIN_RE" |
      sed 's/^model:[[:space:]]*//; s/^`//' |
      tr '[:upper:]' '[:lower:]' | sort -u | tr '\n' ' ')
    found=${found% }
    n=$(printf '%s\n' $found | grep -c .)
    [ "$n" -ge 2 ] && continue
    printf '%s\t%s\n' "$ln" "${found:-none}"
  done <<< "$hits"
}

for d in plugins/cepa/commands plugins/cepa/skills; do
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

    while IFS=$'\t' read -r cln ctiers; do
      [ -n "$cln" ] || continue
      miss "model-pin: ${f}:${cln} — declared ${MODECOND_MARKER} but only one branch tier is present (found: ${ctiers}); a conditional dispatch states both literals (autonomy §9d)"
      misses=$((misses + 1))
    done < <(scan_conditional "$f")
  done < <(find -L "$d" -name '*.md' -type f 2>/dev/null | sort)
done

# --- verdict ---------------------------------------------------------------
echo "-- ${misses} MISS, ${warns} WARN --"
if [ "$misses" -gt 0 ] || [ "$warns" -gt 0 ]; then
  echo "FAIL: a dispatch can run at the invoking session's tier, or a check could not run."
  exit 1
fi
exit 0

#!/usr/bin/env bash
# cepa model-pin check — read-only. Verifies that no subagent dispatch in
# this plugin's source can fall through to the invoking session's model
# tier. Run from the repo root. Never modifies anything.
#
#   Leg 1 (hard, MISS → exit 1): every agent definition declares a model:
#   key whose value is not `inherit`.
#   Leg 2 (heuristic, WARN → exit 0): dispatch instructions in command and
#   skill bodies that carry no model: string nearby.
#
# Why both legs: registered agents make an omission greppable in
# frontmatter; generic subagents (a Task call seeded from a prompt
# template, no registered agent type) have no frontmatter to fall back on,
# so their pin lives in prose and nothing structural can enforce it. Leg 2
# is deliberately noisy rather than silent — see
# docs/solutions/logic-errors/unpinned-subagent-dispatches-inherit-the-session-model.md
set -u

ok()   { printf 'OK   %s\n' "$1"; }
miss() { printf 'MISS %s\n' "$1"; }
warn() { printf 'WARN %s\n' "$1"; }
info() { printf 'INFO %s\n' "$1"; }

AGENT_DIR="plugins/cepa/agents"
CMD_DIR="plugins/cepa/commands"
SKILL_DIR="plugins/cepa/skills"
misses=0
warns=0

echo "== cepa model-pin check: $(pwd) =="

if [ ! -d "$AGENT_DIR" ]; then
  miss "no ${AGENT_DIR}/ — run from the plugin source repo root"
  exit 1
fi

# --- Leg 1: agent frontmatter (hard) ---------------------------------------
# Read only the frontmatter block (first --- to the next ---); a `model:`
# mentioned in the body is prose, not a pin.
agent_count=0
while IFS= read -r f; do
  agent_count=$((agent_count + 1))
  fm_model=$(awk 'NR==1 && $0!="---"{exit} NR==1{next} /^---[[:space:]]*$/{exit} /^model:/{print; exit}' "$f")
  if [ -z "$fm_model" ]; then
    miss "model-pin: ${f} — no model: key in frontmatter (dispatches at the invoking session's tier)"
    misses=$((misses + 1))
    continue
  fi
  value=$(printf '%s' "$fm_model" | sed 's/^model:[[:space:]]*//; s/[[:space:]]*$//' | tr -d '"'"'")
  case "$value" in
    inherit)
      miss "model-pin: ${f} — model: inherit (an explicit choice to spend at the session's tier)"
      misses=$((misses + 1)) ;;
    "")
      miss "model-pin: ${f} — model: key present but empty"
      misses=$((misses + 1)) ;;
    *)
      ok "model-pin: ${f##*/} → ${value}" ;;
  esac
done < <(find "$AGENT_DIR" -name '*.md' -type f | sort)
info "agent definitions checked: ${agent_count}"

# --- Leg 2: dispatch instructions in prose (heuristic) ----------------------
# Match dispatch-instruction lines, then look for a model: pin within the
# surrounding block. False positives are expected and acceptable at WARN;
# a silent miss is the failure this check exists to prevent.
WINDOW=12
DISPATCH_RE='[Dd]ispatch (each|every|the selected|all) |generic subagent|using Task tool calls|[Ll]aunch these [0-9]+ agents|[Ss]pawn .*[Ss]ub-?[Aa]gent'

scan_body() {
  local f="$1"
  local total
  total=$(wc -l < "$f")
  grep -nE "$DISPATCH_RE" "$f" 2>/dev/null | cut -d: -f1 | while IFS= read -r ln; do
    local lo=$((ln - WINDOW)); [ "$lo" -lt 1 ] && lo=1
    local hi=$((ln + WINDOW)); [ "$hi" -gt "$total" ] && hi="$total"
    if ! sed -n "${lo},${hi}p" "$f" | grep -q 'model:'; then
      printf '%s:%s\n' "$f" "$ln"
    fi
  done
}

for d in "$CMD_DIR" "$SKILL_DIR"; do
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      warn "model-pin: ${hit} — dispatch instruction with no model: within ±${WINDOW} lines"
      warns=$((warns + 1))
    done < <(scan_body "$f")
  done < <(find "$d" -name '*.md' -type f | sort)
done

# --- verdict ---------------------------------------------------------------
echo "-- ${misses} MISS, ${warns} WARN --"
if [ "$misses" -gt 0 ]; then
  echo "FAIL: an agent definition can dispatch at the invoking session's tier."
  exit 1
fi
if [ "$warns" -gt 0 ]; then
  echo "PASS with warnings: review each dispatch site above and either pin it or"
  echo "confirm the match is prose, not a dispatch."
fi
exit 0

#!/usr/bin/env bash
# cepa fenced-block state-crossing check — read-only. Enforces residual 2g
# (memory/tasks.d/2026-09-26-forced-phi-scrub-verification.md) over every
# command file. Run from the repo root. Never modifies anything.
#
# 2g's rule is cited, not restated: read it in that shard. The one-line form
# this script mechanizes is its reviewable clause — every variable used in
# block N was either assigned in block N or is a documented literal.
#
# WHY A CHECKER AND NOT ANOTHER CORRECTED BLOCK. Six instances of the class
# have shipped on the brain-writeback surface alone. Instances 5 and 6 were
# each written BY the session enforcing the rule, in the block it was adding,
# with 2g's text on screen. Every one was found by RUNNING the extracted block,
# never by reading the diff. Review is measurably not holding this, so the
# deliverable is a gate.
#
# THE EXTRACTION HALF IS scripts/extract-fenced-blocks.py (PR #80). This script
# is the GATE half: it runs that script's --report across every command file,
# applies the allowlist below, and fails on anything left. It deliberately does
# not re-implement parsing — a second parser would drift from the one whose
# own first cut was wrong in this exact class (its ASSIGN_RE lacked re.M, so
# the broken and fixed shapes of compound.md produced identical reports).
#
#   Leg 1 (MISS): a `>> 2g DEFECT CANDIDATES` line — a name assigned in an
#     EARLIER block, used here, re-assigned nowhere in this one. That earlier
#     block was a different process, so the name is unset at this point. This
#     is the class itself and it is MISS-able immediately: the signal is
#     mechanical, and the tree has zero hits today.
#   Leg 2 (MISS): a used-not-assigned name that is not in the allowlist. The
#     allowlist is the substance of this gate — see below.
#   Leg 2s (MISS): a `sourced`-class name used in a block that does NOT source
#     anything. This leg is load-bearing and its absence was a real hole, found
#     by mutation-testing the controls rather than by reading the code. Leg 1
#     rests on the extractor's cross-block signal, which only fires when the
#     name was ASSIGNED in an earlier block — and a name set by a sourced
#     script is never recorded as assigned, so for `CEPA_ROOT` (2g instances
#     2, 4 AND 5) leg 1 can never fire. Without this leg the allowlist admitted
#     the name in every block unconditionally, and the reconstructed
#     instance-5 shape PASSED: `0 MISS` on a block that expands to
#     /scripts/brain-client.sh and exits 127. A gate that green-lights the
#     exact defect it was built for is worse than no gate, because it is cited
#     as evidence.
#   Leg 2f (MISS): more than one FRAGMENT-marked block in a file. A fragment
#     marker exempts a block from leg 2s by declaring it is concatenated after
#     an earlier block in the same Bash call — an unverifiable promise, so the
#     cap is what keeps it an exception rather than an off switch. See the
#     FRAGMENT MARKER comment in the body.
#   Leg 3 (MISS): an allowlist entry that matched nothing in this run. A
#     suppression that no longer suppresses anything is how an allowlist
#     becomes a list of names nobody has re-checked. Removing the entry is the
#     fix, and it costs one line.
#
# WHY LEG 3 IS A MISS AND NOT A WARN. The failure it prevents is the one this
# repo keeps paying for: a guard that still looks present while the thing it
# guarded moved. An entry allowlisted today can become a real violation
# tomorrow — `$CEPA_ROOT` is allowlisted because resolve-plugin-root.sh sets
# it, and the day a block stops sourcing that script the same name becomes
# instance 7. A stale-entry MISS is what forces the re-read. The cost is that
# deleting a command file reddens this check until its entries are pruned,
# which is the intended prompt, not a false positive.
#
# WHY THE ALLOWLIST IS PER-NAME AND NOT PER-SITE. A per-site allowlist
# (file+block+name) would pin each legitimate use and catch a name that spread
# to a new block without its guard. It is also what makes an allowlist
# unmaintainable: compound.md's resolve loop appears in three blocks and would
# need three entries that move on every edit. The names here are global facts
# about the harness (what it exports) and about the command contract (what the
# prose tells the agent to substitute), so a per-name list states the fact
# once. The cost, recorded rather than left implicit: a name that is a
# documented literal in one file and a real cross-block leak in another would
# pass. Leg 1 is the backstop for exactly that shape — it fires on the
# cross-block signal regardless of the allowlist.
#
# STATED LIMITS — none of these can read as a pass:
#   * It cannot see WHICH names a sourced script sets — only that a block
#     sources something. So leg 2s proves a `sourced` name's block sources
#     SOMETHING, not that the sourced thing sets that particular name. A block
#     that sources an unrelated script would satisfy it. Narrowing that needs
#     the checker to read the sourced file, which is a different tool; the
#     `reason` field is the record of the by-hand check in the meantime.
#   * It only inspects ```bash fences. A ```sh or unlabeled fence carrying
#     shell is invisible. Leg 0 below counts fence labels and WARNs on any
#     shell-looking label other than `bash`, so a new label announces itself
#     instead of silently shrinking coverage.
#   * `while read -r NAME` was invisible to the extractor when this was
#     written, which surfaced `id` in compound.md as a false candidate. Fixed
#     in extract-fenced-blocks.py in the same PR (READ_RE); the allowlist does
#     NOT carry an `id` entry, because papering a parser gap into a suppression
#     is how the next loop variable becomes an unexamined pass.
#   * It proves a name is re-resolved in its own block. It does NOT prove the
#     re-resolution is CORRECT — instance 5 was a re-assignment in the right
#     block that expanded to the wrong path. Running the block remains the only
#     thing that catches that, which is what --emit is for.
#
# Usage: bash scripts/check-fenced-block-state.sh
# Exit: 0 when zero MISS. 1 on any MISS. WARN never fails.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

EXTRACT="scripts/extract-fenced-blocks.py"
CMD_DIR="plugins/cepa/commands"

[ -f "$EXTRACT" ] || { echo "MISS: missing $EXTRACT (the extraction half)"; exit 1; }
[ -d "$CMD_DIR" ] || { echo "MISS: missing $CMD_DIR"; exit 1; }

# ---------------------------------------------------------------------------
# THE ALLOWLIST — the substance of this gate.
#
# A checker that flagged all 8 candidate-carrying blocks would be noise and
# would be ignored. Each entry is `NAME|class|reason`. The class is one of:
#
#   env       an environment variable an operator or the harness may export.
#             Legitimate ONLY when every use is `${NAME:-}` / `${NAME:+...}`
#             guarded, which leg 2b verifies — an unguarded use under `set -u`
#             is a crash, not a literal.
#   literal   a placeholder the command's own prose tells the agent to
#             substitute before running the block. It is textually present in
#             the block, so it does not cross a boundary in shell state.
#   sourced   set by a script the block sources. extract-fenced-blocks.py
#             cannot see these, so each one is a by-hand check recorded here.
#
# Adding an entry is a claim about the harness or the contract. State the
# evidence in the reason; "it looked fine" is not a reason.
# ---------------------------------------------------------------------------
ALLOW=(
  "CLAUDE_PLUGIN_ROOT|env|Instance 1 of 2g's class: NOT exported into the Bash tool's shell. Allowlisted because every use is \${CLAUDE_PLUGIN_ROOT:-} inside a resolve-loop that tries other paths, so an empty value is the designed case, not a defect."
  "CEPA_PLUGIN_ROOT|env|Operator-set override naming the plugin root when auto-resolution fails; setup.md's own error message tells the operator to set it. Always \${CEPA_PLUGIN_ROOT:-} guarded."
  "CEPA_DEV|env|Opt-in dev switch; \${CEPA_DEV:+...} expands to nothing when unset, which is the production path."
  "BRAIN_ENV_FILE|env|Operator override for the brain env file, matching brain-client.sh's _load_env precedence. Always \${BRAIN_ENV_FILE:-} guarded."
  "CEPA_ROOT|sourced|Set by plugins/cepa/scripts/resolve-plugin-root.sh, which each block sources BEFORE use. Checked by hand: the resolve loop and the \${CEPA_ROOT:-} emptiness gate are in the same block as every use. 2g instances 2, 4 and 5 were all this name, so leg 1 is the live guard here."
  # NO `RUN` ENTRY, deliberately, and this is the record of why. $RUN looks
  # like the archetypal documented literal, so an entry for it reads as
  # obviously correct — and leg 3 rejected it on the first run. compound.md
  # RE-ASSIGNS `RUN="<short-run-id>"` in all three blocks that use it (lines
  # 242, 316, 539), which is precisely 2j's fix, so it never reaches the
  # candidate list and an entry would suppress nothing forever. Allowlisting
  # it would also hide the regression that matters: if a later edit dropped one
  # of those re-assignments, $RUN becomes a genuine instance and leg 1 must
  # fire. Measured 2026-10-03: with the entry present, 1 MISS from leg 3.
  # NO `REPO` or `DOC` ENTRY either, and for a sharper reason than $RUN's.
  # Both ARE documented literals, so entries for them read as correct — and
  # both are assigned in the one block that uses them (compound.md block 1,
  # `REPO="<repo>"; DOC="<doc-path>"`). Their only other appearance is inside a
  # COMMENT in block 0. Until the extractor stripped full-line comments from
  # the uses scan they surfaced as candidates and these entries looked
  # load-bearing; once the probe was corrected, leg 3 reported both as stale.
  # Measured 2026-10-03. Recorded because "it is obviously a literal" is not
  # the test — "does any block actually use it unassigned" is.
)

miss=0
warn=0
hit_names=()

say_miss() { echo "MISS: $*"; miss=$((miss + 1)); }
say_warn() { echo "WARN: $*"; warn=$((warn + 1)); }

in_list() {
  # $1 needle, $2 space-delimited haystack (both ends padded with a space).
  case "$2" in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

# `frag_blocks` is set per file in the loop below. A named predicate rather
# than a `case` inline in an `if` condition: a `[ ... ]` used AS an `if`
# condition does not trip `set -e`, and residual 2i records a 2^63 seal
# falling THROUGH to success for exactly that reason. An explicit function
# keeps the test readable and its sense obvious at the call site.
is_fragment() { in_list "$1" "$frag_blocks"; }

allow_field() {
  # $1 name, $2 field index (2=class, 3=reason)
  local n="$1" idx="$2" e
  for e in "${ALLOW[@]}"; do
    if [ "${e%%|*}" = "$n" ]; then printf '%s\n' "$e" | cut -d'|' -f"$idx"; return 0; fi
  done
  return 1
}

# ---------------------------------------------------------------------------
# Leg 0 — coverage. The report only reads ```bash fences, so a shell block
# under another label is invisible to legs 1 and 2. Announce it.
# ---------------------------------------------------------------------------
for f in "$CMD_DIR"/*.md; do
  while read -r lbl; do
    case "$lbl" in
      bash|text|markdown|json|yaml|'') ;;
      sh|shell|console|zsh|bats)
        say_warn "$f declares a \`\`\`$lbl fence — shell-looking, but only \`\`\`bash is inspected. Relabel it bash or extend this check."
        ;;
      *) ;;
    esac
  done < <(grep -oE '^[ \t]*```[a-zA-Z]*' "$f" 2>/dev/null | sed 's/[ \t]*```//')
done

# ---------------------------------------------------------------------------
# Legs 1 and 2 — the report, per command file.
# ---------------------------------------------------------------------------
total_blocks=0
cand_blocks=0

for f in "$CMD_DIR"/*.md; do
  report="$(python3 "$EXTRACT" "$f" --report 2>&1)" || {
    # A tool error is not a finding — this repo has a recorded incident for
    # reporting one as the other. Say which it is.
    say_miss "$EXTRACT failed on $f (harness error, not a 2g finding):"
    printf '%s\n' "$report" | sed 's/^/        /'
    continue
  }

  case "$report" in 'no ```bash blocks'*) continue ;; esac

  # The report prints a block's `used-not-assigned` line BEFORE its sourcing
  # note, so leg 2s cannot be decided during a single forward pass. Pre-scan
  # the report and record which blocks source something, then decide below.
  # Deliberately a pre-scan rather than a deferred queue: the ordering is the
  # extractor's to choose, and a checker that silently depends on it is one
  # output-format tweak away from passing everything.
  sourcing_blocks=" "
  sb=-1
  while IFS= read -r l; do
    case "$l" in
      block\ *) sb="${l#block }"; sb="${sb%%:*}" ;;
      *'sources a script'*) sourcing_blocks="$sourcing_blocks$sb " ;;
    esac
  done < <(printf '%s\n' "$report")

  # ---- FRAGMENT MARKER -------------------------------------------------
  # A block can declare itself a FRAGMENT: not a standalone shell, but text
  # meant to be concatenated after an earlier block in the SAME Bash call.
  # compound-refresh.md's writeback block is the real instance — its own first
  # comment says "PASTE THIS AFTER the resolver loop + health gate above, in
  # ONE block", and the prose above it states the requirement twice. Flagging
  # it would be a false positive on a contract that is already explicit.
  #
  # The marker must be INSIDE the block, so a file cannot exempt a block
  # remotely and an author editing the block sees the claim. It is recognised
  # as a comment containing both PASTE THIS AFTER and ONE block.
  #
  # WHY AT MOST ONE PER FILE, and this is the load-bearing restriction. A
  # marker is an unverifiable promise about assembly, so it is the obvious
  # route to disabling this gate wholesale: mark every block and the file is
  # exempt. One per file keeps it a documented exception rather than a switch,
  # and a second marker is a MISS below. If a file genuinely needs two, that is
  # a design signal to collapse the blocks, not to raise the cap.
  # A SET of marked blocks, not a single `frag_blk`. Mutation-tested
  # 2026-10-03: a scalar holding the LAST marked block made the exemption
  # depend on block ORDER — with two markers, block 1 was exempt and block 0
  # was not, so the two-marker case stayed red through block 0 and removing the
  # cap killed nothing. The cap looked tested and was not.
  frag_blocks=" "
  frag_count=0
  # The report does not carry block bodies, so re-derive fragment status from
  # the SOURCE: --emit writes each block, then inspect its text.
  fdir="$(mktemp -d -t cepa-fbs.XXXXXX)"
  if python3 "$EXTRACT" "$f" --emit "$fdir" >/dev/null 2>&1; then
    for bf in "$fdir"/b*.sh; do
      [ -f "$bf" ] || continue
      bn="$(basename "$bf" .sh)"; bn="${bn#b}"
      if grep -q 'PASTE THIS AFTER' "$bf" 2>/dev/null &&
         grep -q 'ONE block' "$bf" 2>/dev/null; then
        frag_count=$((frag_count + 1))
        frag_blocks="$frag_blocks$bn "
      fi
    done
  fi
  rm -rf "$fdir"
  # Over the cap, NO block is exempt. Failing closed is the point: the
  # alternative (honour the first marker, reject the rest) would let a file
  # keep one exemption while being told off for the others, so the loudest
  # case still passes its real finding through. A capped-out file gets its
  # markers ignored entirely and sees every leg-2s finding it was hiding.
  if [ "$frag_count" -gt 1 ]; then
    say_miss "$f declares $frag_count fragment blocks (PASTE THIS AFTER + ONE block). At most ONE is allowed: a marker is an unverifiable promise about assembly, so many markers is a way to switch this gate off. Collapse the blocks instead. NOTE: while over the cap, NO block is exempt, so the leg-2s findings below are the ones the markers were suppressing."
    frag_blocks=" "
  fi

  blk=-1
  while IFS= read -r line; do
    case "$line" in
      block\ *) blk="${line#block }"; blk="${blk%%:*}"; total_blocks=$((total_blocks + 1)) ;;

      *'2g DEFECT CANDIDATES: '*)
        # Leg 1. The cross-block signal — unconditional, allowlist does not
        # apply. A name re-assigned nowhere in the block that uses it is unset
        # there, whatever class it belongs to.
        names="${line#*CANDIDATES: }"
        say_miss "$f block $blk: 2g violation — $names assigned in an earlier block, used here, re-assigned nowhere in this one. Each is UNSET at this point (a different process). Re-resolve it in this block, or pass it through a file."
        ;;

      '  used-not-assigned: '*)
        names="${line#  used-not-assigned: }"
        [ "$names" = "(none)" ] && continue
        cand_blocks=$((cand_blocks + 1))
        # Split on ", " without mangling: the extractor joins with exactly that.
        old="$IFS"; IFS=','
        for raw in $names; do
          n="${raw# }"
          [ -n "$n" ] || continue
          if cls="$(allow_field "$n" 2)"; then
            hit_names+=("$n")
            # Leg 2b — an `env` entry's legitimacy rests on every use being
            # default-guarded. An unguarded `$NAME` under `set -u` aborts the
            # block, so the allowlist claim would be false.
            if [ "$cls" = env ]; then
              if grep -qE "\\\$\{?$n\}?([^:+}]|$)" "$f" 2>/dev/null &&
                 ! grep -qE "\\\$\{$n:[-+]" "$f" 2>/dev/null; then
                say_miss "$f block $blk: \$$n is allowlisted as \`env\` but is used without a \${$n:-} / \${$n:+} default. Under \`set -u\` that aborts the block, so the allowlist's claim does not hold."
              fi
            fi
            # Leg 2s — a `sourced` name is only legitimate in a block that
            # actually sources something. See the header: leg 1 structurally
            # cannot cover this class, so without this check the allowlist
            # admits the name everywhere and the instance-5 shape passes.
            if [ "$cls" = sourced ] && ! is_fragment "$blk"; then
              if ! in_list "$blk" "$sourcing_blocks"; then
                say_miss "$f block $blk: \$$n is allowlisted as \`sourced\`, but this block sources NOTHING — so the name is UNSET here (2g: a different process). The earlier block that sourced it does not help. Re-source the resolver in this block, or declare the block a fragment (see $(basename "$0")'s FRAGMENT MARKER). NOTE: leg 1 cannot catch this, because a sourced name is never recorded as 'assigned'."
              fi
            fi
          else
            say_miss "$f block $blk: \$$n is used but assigned nowhere in this block and is NOT allowlisted. Either assign it in this block, pass it through the filesystem (2g), or add it to ALLOW in $(basename "$0") with its class and the evidence."
          fi
        done
        IFS="$old"
        ;;
    esac
  done < <(printf '%s\n' "$report")
done

# ---------------------------------------------------------------------------
# Leg 3 — stale allowlist entries.
# ---------------------------------------------------------------------------
for e in "${ALLOW[@]}"; do
  n="${e%%|*}"
  found=0
  for h in ${hit_names[@]+"${hit_names[@]}"}; do
    [ "$h" = "$n" ] && { found=1; break; }
  done
  [ "$found" -eq 1 ] || say_miss "allowlist entry \$$n matched nothing in this run. A suppression that suppresses nothing is a name nobody has re-checked — delete the entry (one line), or find out why its use disappeared."
done

# ---------------------------------------------------------------------------
# Report. State the probe beside the count (CLAUDE.md) — a bare number invites
# re-reasoning about what was measured instead of re-running it.
# ---------------------------------------------------------------------------
echo
echo "probe: python3 $EXTRACT <file> --report, over $CMD_DIR/*.md"
echo "scope: $total_blocks \`\`\`bash block(s); $cand_blocks carried used-not-assigned names"
echo "allowlist: ${#ALLOW[@]} entr(ies)"
echo "result: $miss MISS, $warn WARN"

[ "$miss" -eq 0 ] || exit 1
exit 0

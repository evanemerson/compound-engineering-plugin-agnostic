#!/usr/bin/env bash
# cepa brain backfill — resumable work-queue manager for the one-time load of
# a repo's existing docs/solutions into the brain. It does the MECHANICAL,
# network-free parts: enumerate unprocessed docs, hand out bounded batches,
# and record completion idempotently. The agent does the per-doc work
# (decompose → PHI-scrub → writeback → PATCH evidence_only) via
# brain-client.sh, then calls `done` to mark the doc processed.
#
# Idempotent by design: a doc already in the state log is never handed out
# again, so re-runs after an interruption resume without duplicate writes
# (agent_memories has no upsert — dedup depends on this + stable idkeys).
#
# Usage (run from the repo root, which must have opted in via cepa.local.md):
#   brain-backfill.sh next   <repo> <batch-size>   # print up to N unprocessed doc paths
#   brain-backfill.sh done   <repo> <docpath>      # record a doc as processed
#   brain-backfill.sh status <repo>                # counts: total / done / remaining
# State log (gitignored): .brain-backfill-state.log — one processed docpath per line.
set -euo pipefail

_die() { printf 'brain-backfill: %s\n' "$1" >&2; exit 2; }
STATE="${BRAIN_BACKFILL_STATE:-.brain-backfill-state.log}"

_all_docs() {
  # participating dev-knowledge corpus: solution docs (skip .gitkeep) + CONCEPTS.md
  find docs/solutions -name '*.md' -not -name '.gitkeep' 2>/dev/null | sort
  [ -f CONCEPTS.md ] && echo "CONCEPTS.md" || true
}

cmd="${1:-}"; shift || true
case "$cmd" in
  next)
    [ -n "${1:-}" ] && [ -n "${2:-}" ] || _die "next needs <repo> <batch-size>"
    batch="$2"; touch "$STATE"; n=0
    while IFS= read -r doc; do
      [ -n "$doc" ] || continue
      # already processed? (exact-line match against the state log)
      if grep -qxF "$doc" "$STATE"; then continue; fi
      printf '%s\n' "$doc"
      n=$((n + 1))
      [ "$n" -ge "$batch" ] && break
    done < <(_all_docs)
    ;;
  done)
    [ -n "${1:-}" ] && [ -n "${2:-}" ] || _die "done needs <repo> <docpath>"
    touch "$STATE"
    grep -qxF "$2" "$STATE" || printf '%s\n' "$2" >> "$STATE"
    ;;
  status)
    [ -n "${1:-}" ] || _die "status needs <repo>"
    touch "$STATE"
    total="$(_all_docs | grep -c . || true)"
    donen="$(grep -c . "$STATE" || true)"
    printf 'repo=%s total=%s done=%s remaining=%s\n' "$1" "$total" "$donen" "$((total - donen))"
    ;;
  *)
    _die "unknown command: '${cmd}' (next|done|status)"
    ;;
esac

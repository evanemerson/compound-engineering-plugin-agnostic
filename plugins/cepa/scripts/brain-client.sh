#!/usr/bin/env bash
# cepa brain client — thin transport for the OB1 Agent Memory API.
# Contract + governance live in the cepa:brain skill; this script only moves
# JSON over HTTP with the auth key kept OFF the command line (curl --config,
# mode 600), and provides the PHI-scrub + stable-idempotency helpers the
# producer/backfill share. It NEVER decides what to write — the caller
# (agent) builds the typed memory_payload; this just transports it.
#
# Credentials come from a gitignored .env.local in the repo root:
#   BRAIN_URL=https://<ref>.functions.supabase.co/agent-memory
#   MCP_ACCESS_KEY=...
# The Supabase service_role / OpenRouter keys NEVER live here (server-only).
# Optional, for the `participants` resolver (fail-closed if unresolved):
#   BRAIN_PARTICIPANTS_FILE=/abs/path/to/brain-ops/brain-participants.tsv
# If unset, falls back to a sibling <repo-parent>/brain-ops checkout.
#
# Usage:
#   brain-client.sh health
#   brain-client.sh recall   <payload.json>
#   brain-client.sh writeback <payload.json>
#   brain-client.sh review   <memory_id> <confirm|evidence_only|reject|supersede|mark_stale>
#   brain-client.sh participants                        # resolve + emit registry (fail-closed, exit 3 if unresolved)
#   brain-client.sh scrub    <infile> <outfile>     # PHI redaction pass
#   brain-client.sh idkey    <repo> <docpath> <index>   # stable idempotency_key
# Bodies are passed as FILES, never as argv, so untrusted content is never
# spliced into a shell line (cepa:autonomy §7).
set -euo pipefail

_die() { printf 'brain-client: %s\n' "$1" >&2; exit 2; }

_load_env() {
  local envf="${BRAIN_ENV_FILE:-.env.local}"
  if [ -f "$envf" ]; then
    # shellcheck disable=SC1090
    set -a; . "$envf"; set +a
  fi
  [ -n "${BRAIN_URL:-}" ] || _die "BRAIN_URL not set (check .env.local)"
  [ -n "${MCP_ACCESS_KEY:-}" ] || _die "MCP_ACCESS_KEY not set (check .env.local)"
}

# curl with the auth header supplied via a mode-600 config file, so the key
# never appears in argv (ps-visible). The temp file is always cleaned up.
_curl() {
  local method="$1" path="$2" body="${3:-}"
  local cfg; cfg="$(mktemp)"
  chmod 600 "$cfg"
  # shellcheck disable=SC2064
  trap "rm -f '$cfg'" RETURN
  {
    printf 'header = "x-brain-key: %s"\n' "$MCP_ACCESS_KEY"
    printf 'header = "content-type: application/json"\n'
    printf 'request = "%s"\n' "$method"
    printf 'max-time = 20\n'
    # bounded retry: curl retries only transient/timeout/5xx (and 408/429),
    # NEVER 4xx — so a 422 unsafe-content or 401 bad-key fails fast, while a
    # transient 5xx or connection drop gets one retry. Writeback is idempotent
    # (stable content idkey), so a retry can never duplicate a row.
    printf 'retry = 1\nretry-connrefused\n'
    printf 'silent\nshow-error\nfail-with-body\n'
    if [ -n "$body" ]; then printf 'data = "@%s"\n' "$body"; fi
  } > "$cfg"
  curl --config "$cfg" "${BRAIN_URL%/}${path}"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  health)
    _load_env
    _curl GET /health
    ;;
  recall)
    [ -f "${1:-}" ] || _die "recall needs a payload file"
    _load_env
    _curl POST /recall "$1"
    ;;
  writeback)
    [ -f "${1:-}" ] || _die "writeback needs a payload file"
    _load_env
    _curl POST /writeback "$1"
    ;;
  review)
    [ -n "${1:-}" ] && [ -n "${2:-}" ] || _die "review needs <memory_id> <action>"
    case "$2" in confirm|evidence_only|reject|supersede|mark_stale) ;; *) _die "bad review action: $2" ;; esac
    _load_env
    local_body="$(mktemp)"; chmod 600 "$local_body"
    # shellcheck disable=SC2064
    trap "rm -f '$local_body'" EXIT
    printf '{"action":"%s"}' "$2" > "$local_body"
    _curl PATCH "/memories/$1/review" "$local_body"
    ;;
  scrub)
    # Defense-in-depth PHI redaction for brain_phi_scrub repos. Redacts SSN
    # (dash / space / dot separated), long digit runs (MRN/account-shaped),
    # and DOB-like dates in BOTH US month-first (MM/DD/YYYY, MM-DD-YYYY) and
    # ISO-8601 (YYYY-MM-DD, the common log/DB format). NOT a substitute for
    # the operator's no-real-PHI certification (names are not caught — see
    # the cepa:brain skill's stated scope).
    [ -f "${1:-}" ] && [ -n "${2:-}" ] || _die "scrub needs <infile> <outfile>"
    sed -E \
      -e 's/[0-9]{3}[ .-][0-9]{2}[ .-][0-9]{4}/[REDACTED-PHI-SSN]/g' \
      -e 's/\b[0-9]{7,12}\b/[REDACTED-PHI-ID]/g' \
      -e 's#\b(0[1-9]|1[0-2])[/-](0[1-9]|[12][0-9]|3[01])[/-](19|20)[0-9]{2}\b#[REDACTED-PHI-DOB]#g' \
      -e 's/\b(19|20)[0-9]{2}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])\b/[REDACTED-PHI-DOB]/g' \
      "$1" > "$2"
    ;;
  participants)
    # Resolve + emit the brain participant registry, fail-closed. The manifest
    # lives with the brain-ops setup repo, NOT inside any consuming repo, so the
    # path is resolved in a fixed order and NEVER guessed:
    #   1. $BRAIN_PARTICIPANTS_FILE  (set in .env.local — authoritative override)
    #   2. sibling checkout: <repo-parent>/brain-ops/brain-participants.tsv
    # If neither resolves, exit 3 (NOT 0/2): the caller degrades to running
    # recall with every cross-repo hit provenance-labeled and no memory trusted
    # as cleared — per the cepa:brain "Portfolio scope" contract. Output is the
    # normalized registry (comments/blanks stripped): "<project_id>\t<status>".
    _pf="${BRAIN_PARTICIPANTS_FILE:-}"
    if [ -z "$_pf" ] || [ ! -f "$_pf" ]; then
      _root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
      _sib="$(dirname "$_root")/brain-ops/brain-participants.tsv"
      [ -f "$_sib" ] && _pf="$_sib" || _pf=""
    fi
    [ -n "$_pf" ] && [ -f "$_pf" ] || { printf 'brain-client: participant manifest not found (set BRAIN_PARTICIPANTS_FILE in .env.local or place brain-ops beside this repo)\n' >&2; exit 3; }
    grep -vE '^[[:space:]]*(#|$)' "$_pf"
    ;;
  idkey)
    # CONTENT-derived idempotency_key so re-runs of an UNCHANGED doc dedup
    # (agent_memories has no upsert — a repeated key is skipped) while an
    # EDITED doc gets a new key and its atoms actually persist. The API
    # appends its own row index (<key>:<n>) per atom, so this is the base.
    # Pair with `review <id> mark_stale` on the prior memories for the path.
    [ -n "${1:-}" ] && [ -n "${2:-}" ] && [ -f "${3:-}" ] || _die "idkey needs <repo> <docpath> <payloadfile>"
    _sha="$(sha256sum "$3" | cut -c1-12)"
    printf '%s:%s:%s\n' "$1" "$2" "$_sha"
    ;;
  *)
    _die "unknown command: '${cmd}' (health|recall|writeback|review|participants|scrub|idkey)"
    ;;
esac

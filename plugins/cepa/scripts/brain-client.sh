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
#
# Usage:
#   brain-client.sh health
#   brain-client.sh recall   <payload.json>
#   brain-client.sh writeback <payload.json>
#   brain-client.sh review   <memory_id> <confirm|evidence_only|reject|supersede|mark_stale>
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
    # Defense-in-depth PHI redaction for brain_phi_scrub repos. Conservative:
    # redacts SSN, long digit runs (MRN/account-shaped), and DOB-like dates.
    # NOT a substitute for the operator's no-real-PHI certification.
    [ -f "${1:-}" ] && [ -n "${2:-}" ] || _die "scrub needs <infile> <outfile>"
    sed -E \
      -e 's/[0-9]{3}-[0-9]{2}-[0-9]{4}/[REDACTED-PHI-SSN]/g' \
      -e 's/\b[0-9]{7,12}\b/[REDACTED-PHI-ID]/g' \
      -e 's#\b(0[1-9]|1[0-2])[/-](0[1-9]|[12][0-9]|3[01])[/-](19|20)[0-9]{2}\b#[REDACTED-PHI-DOB]#g' \
      "$1" > "$2"
    ;;
  idkey)
    # Stable idempotency_key so re-runs dedup (agent_memories has no upsert;
    # a repeated key is skipped, not updated). Keyed on (repo, docpath, index),
    # NOT on content, so an edited doc keeps its identity for supersede.
    [ -n "${1:-}" ] && [ -n "${2:-}" ] && [ -n "${3:-}" ] || _die "idkey needs <repo> <docpath> <index>"
    printf '%s:%s:%s\n' "$1" "$2" "$3"
    ;;
  *)
    _die "unknown command: '${cmd}' (health|recall|writeback|review|scrub|idkey)"
    ;;
esac

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
#   brain-client.sh scrub-required [cepa.local.md]  # 0=required 1=no 2=undecidable
#       The ONE executable home of the forced-scrub rule (cepa:brain skill's
#       `## Compliance` section). Callers gate on it instead of re-deriving it
#       with their own regexes — which is how the two writeback commands came
#       to disagree (residual 2h). Exit 2 means REFUSE TO SEND, never "no".
#   brain-client.sh idkey    <repo> <docpath> <payloadfile>  # stable idempotency_key (hashes the payload)
# Bodies are passed as FILES, never as argv, so untrusted content is never
# spliced into a shell line (cepa:autonomy §7).
set -euo pipefail

_die() { printf 'brain-client: %s\n' "$1" >&2; exit 2; }

# Fail LOCALLY on a payload missing the mandatory envelope, instead of letting
# the API answer 400. Under the cepa:brain mid-run degrade rule a single non-2xx
# disables the brain for the REST OF THE RUN, so a malformed body costs every
# later call too — and the failure reads as an outage rather than as the caller
# bug it is. Three shapes this catches: a caller that never learned the envelope
# (the payload spec lived only in the skill, not at the build site), a caller
# that INVENTED a plausible-looking value for a field whose value must be an
# exact literal, and a builder that silently produced nothing — `jq -n ... > "$f"`
# leaves an EMPTY file when jq is not installed, and `[ -f "$f" ]` happily
# accepts it.
# grep, not jq: jq is NOT a dependency of this script and is absent on at least
# one operator host. This is a presence/literal check, not JSON validation.
_assert_envelope() {
  local f="$1" kind="$2"
  [ -s "$f" ] || _die "$kind payload '$f' is empty — the builder produced no output (jq missing? redirect clobbered?)"
  grep -q '"schema_version"' "$f" \
    || _die "$kind payload '$f' has no schema_version — the API 400s and the brain degrades for the whole run (see the cepa:brain skill)"
  # PRESENCE is not enough: schema_version must be one EXACT literal, and a
  # caller with no envelope at the build site invents a plausible one instead.
  # On 2026-08-22 a compound run burned its writeback on "1.0", "1", 1, and
  # "v1" in turn — each present, each a 400. The API also accepts a parallel
  # `openbrain.openclaw.*` literal (a different client's contract); cepa is the
  # agent_memory client, so anything but its own literal is a caller bug here.
  local want="openbrain.agent_memory.${kind}.v1"
  grep -q "\"schema_version\"[[:space:]]*:[[:space:]]*\"${want}\"" "$f" \
    || _die "$kind payload '$f' has a schema_version that is not the required literal \"${want}\" — the value is not a version number to choose, and any other string 400s (see the cepa:brain skill)"
  grep -q '"workspace_id"' "$f" \
    || _die "$kind payload '$f' has no workspace_id — set it from BRAIN_WORKSPACE_ID in .env.local"
  # Writeback's one required body field. Its shape is an OBJECT of typed arrays
  # (lessons/constraints/failures/…, each an array of plain strings), NOT a list
  # of {type, content} objects — the shape an agent reaches for when the build
  # site says only "atoms". A payload with `atoms` and no `memory_payload` is a
  # 400; catch it here rather than spending the call.
  if [ "$kind" = writeback ]; then
    grep -q '"memory_payload"' "$f" \
      || _die "writeback payload '$f' has no memory_payload — it is a required OBJECT of typed arrays (lessons/constraints/failures), not a list of typed atom objects (see the cepa:brain skill)"
  fi
  # An EMPTY value is the worktree failure mode, not a typo: `. ./.env.local`
  # in a linked worktree finds no file, leaves BRAIN_WORKSPACE_ID unset, and
  # the heredoc interpolates "". The key is present, so a presence check passes
  # and only the API rejects it.
  grep -Eq '"workspace_id"[[:space:]]*:[[:space:]]*""' "$f" \
    && _die "$kind payload '$f' has an EMPTY workspace_id — BRAIN_WORKSPACE_ID was unset when the payload was built (in a git worktree, .env.local lives in the main checkout)"
  return 0
}

_load_env() {
  local envf="${BRAIN_ENV_FILE:-.env.local}"
  # A linked git worktree has NO .env.local — the file is gitignored, so it
  # exists only in the main checkout and is never copied by `git worktree add`.
  # Without this fallback every brain call from a worktree either dies on
  # "BRAIN_URL not set" or, worse, builds an envelope with an EMPTY
  # workspace_id and 400s — which the mid-run degrade rule turns into a
  # silent brain outage for the whole run. Resolve the main checkout via
  # git-common-dir (which points at the REAL .git even from a worktree).
  if [ ! -f "$envf" ] && [ -z "${BRAIN_ENV_FILE:-}" ]; then
    local common
    if common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
       && [ -f "${common%/.git}/.env.local" ]; then
      envf="${common%/.git}/.env.local"
    fi
  fi
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
    [ $# -eq 0 ] || _die "health takes no arguments, got $#"
    _load_env
    _curl GET /health
    ;;
  recall)
    [ -f "${1:-}" ] || _die "recall needs a payload file"
    [ $# -eq 1 ] || _die "recall takes exactly 1 argument, got $#"
    _assert_envelope "$1" recall
    _load_env
    _curl POST /recall "$1"
    ;;
  writeback)
    [ -f "${1:-}" ] || _die "writeback needs a payload file"
    [ $# -eq 1 ] || _die "writeback takes exactly 1 argument, got $#"
    _assert_envelope "$1" writeback
    _load_env
    _curl POST /writeback "$1"
    ;;
  review)
    [ -n "${1:-}" ] && [ -n "${2:-}" ] || _die "review needs <memory_id> <action>"
    [ $# -eq 2 ] || _die "review takes exactly 2 arguments, got $# — <memory_id> <action> are LITERALS, not a payload file"
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
    [ $# -eq 2 ] || _die "scrub takes exactly 2 arguments, got $#"
    # REFUSE infile == outfile. The shell truncates the redirect target before
    # sed ever opens the input, so `scrub f f` empties f and exits 0 — the
    # redirect succeeded, so no `||` gate at any call site can catch it, and
    # `set -euo pipefail` does not fire either. The caller loses the payload it
    # just built and the failure surfaces one verb later as a confusing empty-
    # envelope rejection. Refuse here so the whole class dies for every caller
    # (compound, compound-refresh, brain-backfill) instead of relying on each
    # one to carry a warning. Compare the resolved paths, not the strings: a
    # caller composing "$P" and "./$P" means the same file.
    # Compare the FILES, not the spellings. An earlier version compared
    # dirname+basename strings, which a symlinked infile or a hardlinked
    # outfile walks straight past: the guard passes, the redirect truncates
    # the target, sed then reads the now-empty file through the link, and
    # scrub EXITS 0 having destroyed the payload — the exact failure this
    # guard exists to stop, in a different spelling. Both measured.
    _out_dir="$(cd "$(dirname -- "$2")" 2>/dev/null && pwd -P)"
    [ -n "$_out_dir" ] || _die "scrub outfile directory does not exist: '$2'"
    _out_path="$_out_dir/$(basename -- "$2")"
    _in_real="$(readlink -f -- "$1" 2>/dev/null || printf '%s' "$1")"
    _out_real="$(readlink -f -- "$_out_path" 2>/dev/null || printf '%s' "$_out_path")"
    [ "$_in_real" != "$_out_real" ] \
      || _die "scrub infile and outfile must differ — '$1' and '$2' resolve to the same file; the shell would truncate it before sed reads it (exit 0, payload gone). Scrub to a sidecar, then move it over."
    # Hardlinks share an inode while resolving to different paths, so the
    # path compare above cannot see them. Only meaningful if the outfile
    # already exists.
    if [ -e "$_out_path" ] && [ -r "$1" ]; then
      _in_ino="$(stat -c %i -- "$1" 2>/dev/null || echo x)"
      _out_ino="$(stat -c %i -- "$_out_path" 2>/dev/null || echo y)"
      [ "$_in_ino" != "$_out_ino" ] \
        || _die "scrub infile and outfile are the same inode (hardlinked) — writing the outfile would destroy the input. Scrub to a fresh sidecar path."
    fi
    # Create the outfile mode-600 BEFORE any content lands in it. A bare `>`
    # redirect creates at the umask (0644 on a default box), so the scrubbed
    # doc content — which still holds every non-numeric identifier the scrub
    # does not catch — is world-readable for the duration of the sed. Refuse
    # to follow a pre-existing symlink while we are here: the outfile path is
    # predictable (`<payload>.scrubbed`), so a planted link would otherwise
    # redirect the write to a target of someone else's choosing.
    [ ! -L "$2" ] || _die "scrub outfile '$2' is a symlink — refusing to write through it"
    : > "$2" || _die "scrub cannot create outfile '$2'"
    chmod 600 "$2"
    sed -E \
      -e 's/[0-9]{3}[ .-][0-9]{2}[ .-][0-9]{4}/[REDACTED-PHI-SSN]/g' \
      -e 's/\b[0-9]{7,12}\b/[REDACTED-PHI-ID]/g' \
      -e 's#\b(0[1-9]|1[0-2])[/-](0[1-9]|[12][0-9]|3[01])[/-](19|20)[0-9]{2}\b#[REDACTED-PHI-DOB]#g' \
      -e 's/\b(19|20)[0-9]{2}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])\b/[REDACTED-PHI-DOB]/g' \
      "$1" > "$2"
    ;;
  scrub-required)
    # DECIDE the forced-scrub condition in ONE executable place. Before this
    # verb, compound.md and compound-refresh.md each re-derived it with their
    # own regexes — and they diverged: refresh scrubbed unconditionally while
    # compound scrubbed only when forced, so a participating repo that was
    # neither flagged nor `## Compliance` got opposite treatment from two
    # commands that are supposed to be siblings (residual 2h,
    # memory/tasks.d/2026-09-26-forced-phi-scrub-verification.md). A rule
    # re-implemented per caller is a rule that drifts; the cepa:brain skill's
    # `## Compliance` section is normative and this verb is its one
    # instantiation.
    #
    # EXIT STATUS IS THE ANSWER — there is no "maybe":
    #   0 = scrub REQUIRED      1 = not required      2 = cannot decide (_die)
    # Callers gate on 0, and MUST treat 2 as required-but-unknown (i.e. refuse
    # to send), never as "not required". An unresolvable config is the one
    # state that must not fall through to the unscrubbed path.
    #
    # POLICY AS OF v1.27.0: forced-only. Required iff `brain_phi_scrub:` is
    # truthy OR a `## Compliance` heading exists. A brain participant that is
    # neither gets NO scrub. That preserves memory fidelity for non-PHI repos
    # (the scrub is numeric-only and content-blind — it mangles `PR #1234567`
    # into a redaction, residual 2e), and it makes compound.md's prior
    # behavior the unified one. Changing the policy means editing THIS BLOCK
    # ONLY — that is the whole point of the verb.
    [ $# -le 1 ] || _die "scrub-required takes at most 1 argument (<cepa.local.md>), got $#"
    _cl="${1:-}"
    if [ -z "$_cl" ]; then
      # Resolve the way `_load_env` above resolves .env.local — same helper,
      # same `%/.git` strip, same captured status — for the same measured
      # reason: cepa.local.md is GITIGNORED, so in a linked worktree it exists
      # ONLY in the main checkout. Use --git-common-dir, NOT --show-toplevel:
      # toplevel returns the worktree's own root where the file is absent,
      # which would make this verb answer "not required" on a HIPAA repo.
      # Measured 2026-09-26: common-dir resolves, toplevel does not. A bare
      # relative path also fails whenever the command is invoked from a
      # subdirectory.
      _cl="cepa.local.md"
      if [ ! -f "$_cl" ]; then
        # CAPTURE the status; do not let the assignment carry it. `git
        # rev-parse` exits 128 outside a work tree, and as the last command of
        # a `||` list the assignment INHERITS that 128 — so `set -euo pipefail`
        # killed the script here, at exit 128 with completely EMPTY output,
        # before either _die below could run. Measured 2026-09-29: rc=128,
        # stdout+stderr both empty. Callers do fail closed on 128, so it was
        # never a leak — but a bare 128 with no message reads as "the client is
        # broken" rather than "you are not in a git repo", which is this repo's
        # documented misdiagnosis class (a 127/128 is a path bug, never an
        # outage). The two _die messages exist to say that; they have to be
        # reachable.
        _common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || _common=""
        [ -n "$_common" ] || _die "scrub-required cannot resolve cepa.local.md: not in a git work tree and no ./cepa.local.md — the forced-scrub condition cannot be evaluated; refuse to send rather than treating this as not-required"
        # Strip `/.git` exactly as _load_env does, so a normal repo and a
        # linked worktree both land on the main checkout's root.
        #
        # KNOWN GAP, shared with _load_env and deliberately not papered over:
        # under `git init --separate-git-dir` the common-dir has no `.git`
        # component, so `%/.git` strips nothing and this resolves to the
        # gitdir instead of the work tree. Measured 2026-09-29: rc=2 on such a
        # repo whose cepa.local.md sits in the work tree. That fails CLOSED —
        # a suppressed writeback, never an unscrubbed send — which is why it is
        # recorded rather than guessed at: inventing untested resolution logic
        # on a PHI gate is the larger risk. A separate-gitdir repo that
        # participates in the brain passes the path explicitly:
        #   brain-client.sh scrub-required /path/to/cepa.local.md
        _cl="${_common%/.git}/cepa.local.md"
      fi
    fi
    # NOT FOUND IS NOT "NO". Writeback only runs for a repo whose
    # cepa.local.md declares `brain:`, so an unreadable file here means the
    # condition cannot be evaluated — exit 2 and let the caller refuse.
    [ -f "$_cl" ] || _die "scrub-required cannot resolve cepa.local.md ('$_cl') — the forced-scrub condition cannot be evaluated; refuse to send rather than treating this as not-required"
    [ -r "$_cl" ] || _die "scrub-required cannot read '$_cl' — condition unevaluable; refuse to send"
    # Match PERMISSIVELY: a miss here fails OPEN (it sends unscrubbed PHI),
    # while a false positive costs one needless scrub. So -i for case, a
    # leading-space allowance for markdown list indentation, `\b` rather than
    # a space-or-EOL anchor (`## Compliance: HIPAA` and `##Compliance` are
    # both declarations, and both missed by a stricter pattern), and
    # quoted/`yes` flag values. Both greps are guarded so a no-match cannot
    # abort under `set -e`.
    if grep -Eiq '^[[:space:]]*-?[[:space:]]*brain_phi_scrub:[[:space:]]*["'"'"']?(true|yes)' "$_cl"; then
      printf 'required: brain_phi_scrub declared in %s\n' "$_cl"; exit 0
    fi
    if grep -Eiq '^[[:space:]]*#{1,6}[[:space:]]*compliance\b' "$_cl"; then
      printf 'required: ## Compliance section present in %s\n' "$_cl"; exit 0
    fi
    printf 'not-required: no brain_phi_scrub flag and no ## Compliance in %s\n' "$_cl"
    exit 1
    ;;
  participants)
    [ $# -eq 0 ] || _die "participants takes no arguments, got $#"
    # Resolve + emit the brain participant registry, fail-closed. The manifest
    # lives with the brain-ops setup repo, NOT inside any consuming repo, so the
    # path is resolved in a fixed order and NEVER guessed:
    #   1. $BRAIN_PARTICIPANTS_FILE  (set in .env.local — authoritative override)
    #   2. sibling checkout: <repo-parent>/brain-ops/brain-participants.tsv
    # If neither resolves, exit 3 (NOT 0/2): the caller degrades to running
    # recall with every cross-repo hit provenance-labeled and no memory trusted
    # as cleared — per the cepa:brain "Portfolio scope" contract.
    #
    # EXIT SEMANTICS (the caller MUST distinguish these):
    #   0 + rows   → registry resolved, emit the validated rows.
    #   0 + EMPTY  → registry resolved but has NO active/retracted repos → the
    #                researcher drops ALL cross-repo hits (every project_id is
    #                "absent"). This is NOT the same as exit 3.
    #   3          → manifest unresolved → degrade to provenance-labeled recall.
    #   2 (_die)   → misconfigured explicit override (config error, not degrade).
    _pf="${BRAIN_PARTICIPANTS_FILE:-}"
    # An explicit override that doesn't resolve is a config error, not a silent
    # fall-through to the sibling — surface it (exit 2) rather than mask it.
    [ -z "$_pf" ] || [ -f "$_pf" ] || _die "BRAIN_PARTICIPANTS_FILE set but not a readable file: $_pf"
    if [ -z "$_pf" ]; then
      _root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
      _sib="$(dirname "$_root")/brain-ops/brain-participants.tsv"
      [ -f "$_sib" ] && _pf="$_sib" || _pf=""
    fi
    [ -n "$_pf" ] && [ -f "$_pf" ] || { printf 'brain-client: participant manifest not found (set BRAIN_PARTICIPANTS_FILE in .env.local or place brain-ops beside this repo)\n' >&2; exit 3; }
    # Emit ONLY schema-valid rows: "<project_id>\t<active|retracted>". This IS
    # the cepa:autonomy §7 strip AT THE RELAY POINT: the manifest is cross-repo
    # content (lives in brain-ops), so any comment, blank, malformed, CR-tainted,
    # or injection line is DROPPED here — never relayed into the researcher
    # prompt. `|| true` makes a zero-valid-row file exit 0-with-empty (the valid
    # "drop-all" registry above), NOT grep's exit 1 which the caller can't read.
    tr -d '\r' < "$_pf" | grep -E $'^[A-Za-z0-9._-]+\t(active|retracted)$' || true
    ;;
  idkey)
    # CONTENT-derived idempotency_key so re-runs of an UNCHANGED doc dedup
    # (agent_memories has no upsert — a repeated key is skipped) while an
    # EDITED doc gets a new key and its atoms actually persist. The API
    # appends its own row index (<key>:<n>) per atom, so this is the base.
    # Pair with `review <id> mark_stale` on the prior memories for the path.
    [ -n "${1:-}" ] && [ -n "${2:-}" ] && [ -f "${3:-}" ] || _die "idkey needs <repo> <docpath> <payloadfile>"
    [ $# -eq 3 ] || _die "idkey takes exactly 3 arguments, got $# — arg 3 is the payload FILE and there is no 4th (the API appends its own row index per atom)"
    # Arg 3 must be the payload writeback will SEND, not the source doc. A
    # readable-file check alone accepts `idkey <repo> doc.md doc.md`, which
    # hashes content that does not change when the extracted atoms do — so a
    # re-run reuses the key and, with no upsert, the improved atoms are
    # SKIPPED rather than written. That exact call shipped to 7 brain-ops
    # sites (fixed 2026-08-23) and to compound.md (finding 4 of the
    # 2026-08-22 review). Same envelope check writeback runs, so a doc, an
    # empty builder output, or a recall payload all fail here instead of
    # silently producing a plausible key.
    _assert_envelope "$3" writeback
    _sha="$(sha256sum "$3" | cut -c1-12)"
    printf '%s:%s:%s\n' "$1" "$2" "$_sha"
    ;;
  *)
    _die "unknown command: '${cmd}' (health|recall|writeback|review|participants|scrub|scrub-required|idkey)"
    ;;
esac

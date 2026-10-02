#!/usr/bin/env bash
# Controls for plugins/cepa/scripts/brain-client.sh's ARGUMENT GUARDS — proves
# a wrong-but-plausible invocation still fails LOUDLY. Read-only with respect
# to this repository and to the network: every case runs against temp files,
# and no case reaches a subcommand that would open a connection.
#
# WHY THIS EXISTS, and it is not hypothetical for this script. The same defect
# class landed three times, and every instance was SILENT — the caller got a
# plausible-looking result and no error:
#
#   2026-08-06  `review` was handed a payload FILE where <memory_id> <action>
#               literals belong. All 20 promotions failed quietly enough that
#               the rows sat stranded in `pending`, where recall drops them —
#               and the writeback still read as successful.
#   2026-08-22  `idkey <repo> doc.md doc.md` (compound.md, finding 4 of that
#               day's review). Arg 3 is hashed to build the idempotency_key,
#               so hashing the SOURCE DOC produced a key that does not change
#               when the extracted atoms do. agent_memories has no upsert — a
#               repeated key is SKIPPED — so a re-run silently dropped the
#               improved atoms.
#   2026-08-23  The identical call at 7 brain-ops sites (commit b95575f).
#
# PR #56 fixed the usage comment that TAUGHT the wrong call (it documented arg
# 3 as `<index>`, a leftover from the pre-content-hash design). PR #57 made the
# wrong call fail: arg 3 now runs the same `_assert_envelope` that `writeback`
# runs, and every subcommand pins its arity. THIS suite keeps both dead.
#
# WHY A SUITE AND NOT A COMMENT: this repo's recorded failure mode is a fix
# that regresses because nothing tested it — CLAUDE.md documents three separate
# instances (hardcoded counts across #6/#7/#8; allowed-tools twice on
# 2026-07-10). A guard that silently stops guarding is indistinguishable from a
# guard that works, because both produce a green run.
#
# WHAT THIS DOES NOT COVER, stated rather than left implicit:
#   - No transport. `health`, and the POST/PATCH half of `recall`/`writeback`/
#     `review`, need BRAIN_URL + MCP_ACCESS_KEY and a live API. Cases here stop
#     at the guards, which run BEFORE `_load_env`. Ordering is itself pinned by
#     the `*-noenv` cases: a guard moved after `_load_env` would start
#     depending on credentials, and would pass locally for the wrong reason.
#   - Not the scrub REGEXES, only that scrub's output still satisfies the
#     envelope `idkey` demands (the dpc-pro/helm prompts hash the scrubbed
#     file, so a scrub that broke the envelope would break those call sites).
#   - Not brain-ops' prompts. They live in another repo; verified read-only via
#     `gh api` on 2026-09-12, all 7 sites passing the payload file.
#
# HOW A CASE EARNS ITS PLACE: `cepa:autonomy` §9f. The `why` field of every
# `reg` below names the mutant that case kills, and is printed on failure.
#
# Usage:
#   bash scripts/check-brain-client-args.sh              # run all
#   bash scripts/check-brain-client-args.sh --list       # ids/titles
#   bash scripts/check-brain-client-args.sh --only doc3,arity4
#   bash scripts/check-brain-client-args.sh --keep       # keep fixtures
set -u
set -o pipefail

KEEP=0
ONLY=''
LIST_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1 ;;
    --list) LIST_ONLY=1 ;;
    # A bare trailing `--only` must not shift past the end, leave ONLY empty,
    # and silently run all cases — an argument error that WIDENS the run.
    --only) shift; [ $# -gt 0 ] || { printf -- '--only needs a value\n' >&2; exit 2; }; ONLY="$1" ;;
    --only=*) ONLY="${1#--only=}" ;;
    -h|--help) sed -n '1,60p' "$0"; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  printf 'FATAL: not inside a git work tree\n' >&2
  exit 2
}

# `CEPA_BRAIN_CLIENT` exists for MUTATION TESTING: point the suite at a
# deliberately broken copy and confirm the controls go red. A control suite
# that passes on a broken client proves nothing. Resolved to an ABSOLUTE path
# immediately — a relative override resolves against two different directories
# depending on the call site, and the header would print the unresolved string,
# so an override could read as an ordinary run.
CLIENT=$(readlink -f "${CEPA_BRAIN_CLIENT:-$REPO_ROOT/plugins/cepa/scripts/brain-client.sh}" 2>/dev/null) || CLIENT=''
[ -n "$CLIENT" ] && [ -r "$CLIENT" ] || {
  printf 'FATAL: no readable client at %s\n' "${CEPA_BRAIN_CLIENT:-$REPO_ROOT/plugins/cepa/scripts/brain-client.sh}" >&2
  exit 2
}
# CI must never set the override. Enforced, not merely asserted in a comment.
if [ -n "${CEPA_BRAIN_CLIENT:-}" ] && [ -n "${CI:-}" ]; then
  printf 'FATAL: CEPA_BRAIN_CLIENT is set in CI — the suite would validate a client nobody reviewed\n' >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Fixture
# ---------------------------------------------------------------------------
FIX=$(mktemp -d) || { printf 'FATAL: mktemp failed\n' >&2; exit 2; }
cleanup() { [ "$KEEP" -eq 1 ] && { printf '\nfixtures kept: %s\n' "$FIX"; return 0; }; rm -rf "$FIX"; }
trap cleanup EXIT

# A VALID writeback payload — the shape compound.md builds and the only thing
# `idkey` may legitimately hash. Envelope fields are exact literals, not
# version numbers to choose: `_assert_envelope` rejects "1.0"/"1"/"v1", which
# a 2026-08-22 compound run burned its writeback discovering.
cat > "$FIX/payload.json" <<'EOF'
{"schema_version":"openbrain.agent_memory.writeback.v1","workspace_id":"evan-portfolio","project_id":"helm","memory_payload":{"lessons":["atoms v1"]}}
EOF
# Same doc, EDITED atoms. Must yield a DIFFERENT key, or improved atoms dedup
# away against the prior row — the whole point of a content-derived key.
cat > "$FIX/payload2.json" <<'EOF'
{"schema_version":"openbrain.agent_memory.writeback.v1","workspace_id":"evan-portfolio","project_id":"helm","memory_payload":{"lessons":["atoms v2 improved"]}}
EOF
# A cepa.local.md for the `scrub-required` arity case. It must EXIST, or that
# case would pass on the file-missing guard instead of the arity guard it names
# — a test green for the wrong reason. Contents are deliberately a plain
# participant (no flag, no `## Compliance`), so arity is the only thing left to
# fail on.
cat > "$FIX/cepa.local.md" <<'EOF'
## Integrations
- brain: enabled
EOF
# cwd for the `sr_nongit` case: a directory with NO cepa.local.md and, with
# GIT_CEILING_DIRECTORIES set by the runner, no reachable .git above it. Both
# conditions are required — the silent-128 path needs the local file absent AND
# git to fail, so a fixture holding either one would pass vacuously.
mkdir -p "$FIX/nongit"
# A recall payload: valid JSON, valid envelope, WRONG KIND. `idkey` builds a
# writeback key, so this must be refused — a readable-file check accepts it.
cat > "$FIX/recall.json" <<'EOF'
{"schema_version":"openbrain.agent_memory.recall.v1","workspace_id":"evan-portfolio","query":"x"}
EOF
# The 2026-08-22 defect's actual argument: a source doc.
printf '# A solution doc\n\nProse a human wrote.\n' > "$FIX/doc.md"
# `jq -n ... > f` leaves an EMPTY file when jq is absent (it is absent on the
# primary dev machine, per CLAUDE.md), and `[ -f ]` happily accepts it.
: > "$FIX/empty.json"
# --- re-Write gate fixtures (residual 2i) -----------------------------------
# A payload with a KNOWN marker count, for the scrub-seal success case.
printf '{"schema_version":"openbrain.agent_memory.writeback.v1","workspace_id":"ws","memory_payload":{"lessons":["[REDACTED-PHI-SSN] and [REDACTED-PHI-ID]"]}}' > "$FIX/sealcount.json"
# A non-numeric seal. The payload must EXIST and be readable, or the case would
# pass on the file-missing guard instead of the seal-validation guard it names.
printf '{"a":"[REDACTED-PHI-SSN]"}' > "$FIX/sealed.json"
printf 'garbage\n' > "$FIX/sealed.json.phiseal"
# An EMPTY seal — distinct from a missing one, since `[ -f ]` accepts it.
printf '{"a":"[REDACTED-PHI-SSN]"}' > "$FIX/emptyseal.json"
: > "$FIX/emptyseal.json.phiseal"
# The honest path: payload and seal agree. Count the markers rather than
# hardcoding, so editing the payload above cannot make this green for the wrong
# reason.
printf '{"a":"[REDACTED-PHI-SSN]","b":"[REDACTED-PHI-ID]"}' > "$FIX/intact.json"
printf '%s\n' "$(grep -o 'REDACTED-PHI' "$FIX/intact.json" | grep -c '')" > "$FIX/intact.json.phiseal"
# THE SINGLE-LINE DEFECT: two markers on ONE line, one then dropped.
# compound.md emits single-line JSON, so this is the real shape.
#
# The seal is written by `scrub-seal` ITSELF, not hardcoded. That distinction
# is load-bearing and was found by mutation-testing this very case: with a
# hardcoded `2`, a line-counting mutant reads 1 at verify time, `1 -lt 2` still
# fails, and the case passes FOR THE WRONG REASON — it never exercises the
# counting at all. Sealing with the code under test makes both sides use the
# same counter, so a line-counting mutant seals 1, reads 1, and reports
# "intact" — which is exactly the blindness being pinned, and this case then
# fails as it should. A fixture that hardcodes the expected side of a
# comparison cannot test the thing computing it.
printf '{"a":"[REDACTED-PHI-SSN]","b":"[REDACTED-PHI-ID]"}' > "$FIX/oneline.json"
bash "$CLIENT" scrub-seal "$FIX/oneline.json" >/dev/null 2>&1 \
  || { printf 'FATAL: fixture setup failed — scrub-seal could not seal oneline.json\n' >&2; exit 2; }
printf '{"a":"123-45-6789","b":"[REDACTED-PHI-ID]"}' > "$FIX/oneline.json"

# Present-but-empty workspace_id: the git-worktree failure mode. `.env.local`
# is gitignored, so it exists only in the main checkout; a heredoc in a linked
# worktree interpolates "". A presence check passes and only the API rejects it.
cat > "$FIX/emptyws.json" <<'EOF'
{"schema_version":"openbrain.agent_memory.writeback.v1","workspace_id":"","memory_payload":{"lessons":["x"]}}
EOF

# ---------------------------------------------------------------------------
# Case registry
# ---------------------------------------------------------------------------
# reg <id> <title> <expect_rc> <expect_re> <why> <args...>
#
# <expect_re> is matched against combined stdout+stderr. An empty <expect_re>
# asserts only the exit code.
#
# <why> names the mutant the case kills. It is PRINTED on failure — an editor
# who makes a control go red needs the reason at the failure site, not in a
# case body they have to go find.
IDS=(); TITLES=(); EXP_RC=(); EXP_RE=(); WHY=(); ARGS=()
reg() {
  IDS+=("$1"); TITLES+=("$2"); EXP_RC+=("$3"); EXP_RE+=("$4"); WHY+=("$5")
  shift 5
  # Arguments are stored NUL-joined: a path with a space must survive the
  # round-trip as one argument, and re-splitting on whitespace at call time
  # would silently change the arity the case is pinning.
  local joined='' a
  for a in "$@"; do joined="${joined}${a}"$'\001'; done
  ARGS+=("$joined")
}

# --- the three recorded incidents -------------------------------------------
# THE 2026-08-22 / 08-23 DEFECT, verbatim. If exactly one case in this file
# survives, it is this one.
reg doc3 'idkey rejects the source doc as arg 3' 2 'has no schema_version' \
  'kills: removal of the `_assert_envelope "$3" writeback` line in idkey — the guard that stops a source doc from producing a plausible key' \
  idkey helm doc.md "$FIX/doc.md"
# THE 2026-08-06 DEFECT. `review`'s action is a literal from a closed set; a
# payload file there stranded 20 rows in `pending`.
reg revfile 'review rejects a payload file as the action' 2 'bad review action' \
  'kills: removal of the review action enumeration — a file path would become an accepted action and strand rows in pending' \
  review some-memory-id "$FIX/payload.json"
# The variant the stale `<index>` comment invited: the author appends an index
# after the payload. Pre-#57 this was silently IGNORED and returned a key.
reg arity4 'idkey rejects a stray 4th argument' 2 'takes exactly 3 arguments, got 4' \
  'kills: removal of idkey arity — a trailing index is silently ignored and the call returns a usable-looking key, exactly what the pre-#56 comment taught' \
  idkey helm doc.md "$FIX/payload.json" 7

# --- idkey arg-3 content, beyond the recorded instance ----------------------
# Valid envelope, WRONG KIND. Distinguishes "checks the envelope" from "checks
# the writeback envelope" — a mutant that asserts `recall` instead of
# `writeback` passes every case above and fails only here.
reg kind 'idkey rejects a recall payload as arg 3' 2 'not the required literal' \
  'kills: changing idkey _assert_envelope kind from writeback to recall — every other arg-3 case still passes' \
  idkey helm doc.md "$FIX/recall.json"
reg mt 'idkey rejects an empty payload file' 2 'is empty' \
  'kills: removal of the `[ -s ]` empty check — `jq -n > f` with jq absent leaves an empty file that `[ -f ]` accepts' \
  idkey helm doc.md "$FIX/empty.json"
reg ews 'idkey rejects an empty workspace_id' 2 'EMPTY workspace_id' \
  'kills: removal of the empty-workspace_id check — the git-worktree failure mode, which a presence-only check passes' \
  idkey helm doc.md "$FIX/emptyws.json"
reg nofile 'idkey rejects a nonexistent arg 3' 2 'idkey needs' \
  'kills: removal of the `[ -f "$3" ]` existence check' \
  idkey helm doc.md "$FIX/does-not-exist.json"
# A DIRECTORY is not a file. `[ -f ]` is correct here and `[ -e ]` is not;
# sha256sum on a directory fails at a later, more confusing point.
reg dir3 'idkey rejects a directory as arg 3' 2 'idkey needs' \
  'kills: weakening `[ -f "$3" ]` to `[ -e "$3" ]`' \
  idkey helm doc.md "$FIX"

# --- arity across every subcommand ------------------------------------------
# Each pins one subcommand. A widening that reaches only SOME of them is this
# repo's documented shape (CLAUDE.md: a fix scoped to the reported instance
# leaves the rest of the construct live), so each gets its own case.
reg arity_rc 'recall rejects a stray 2nd argument' 2 'recall takes exactly 1 argument, got 2' \
  'kills: removal of recall arity' \
  recall "$FIX/recall.json" EXTRA
reg arity_wb 'writeback rejects a stray 2nd argument' 2 'writeback takes exactly 1 argument, got 2' \
  'kills: removal of writeback arity' \
  writeback "$FIX/payload.json" EXTRA
reg arity_rv 'review rejects a stray 3rd argument' 2 'review takes exactly 2 arguments, got 3' \
  'kills: removal of review arity' \
  review some-id confirm EXTRA
reg arity_sc 'scrub rejects a stray 3rd argument' 2 'scrub takes exactly 2 arguments, got 3' \
  'kills: removal of scrub arity' \
  scrub "$FIX/payload.json" "$FIX/out.json" EXTRA
reg arity_he 'health rejects any argument' 2 'health takes no arguments, got 1' \
  'kills: removal of health arity' \
  health EXTRA
reg arity_pa 'participants rejects any argument' 2 'participants takes no arguments, got 1' \
  'kills: removal of participants arity' \
  participants EXTRA
reg arity_sr 'scrub-required rejects a stray 2nd argument' 2 'scrub-required takes at most 1 argument' \
  'kills: removal of scrub-required arity' \
  scrub-required "$FIX/cepa.local.md" EXTRA
# THE ONE THAT MATTERS MOST for this verb: an unresolvable config must exit 2
# ("cannot decide"), never 1 ("not required"). Collapsing those two is the
# unscrubbed-egress path, so it gets its own case rather than resting on the
# arity check above.
reg sr_undecidable 'scrub-required exits 2 (not 1) on an unresolvable config' 2 'cannot resolve cepa.local.md' \
  'kills: a mutant that treats a missing cepa.local.md as not-required' \
  scrub-required "$FIX/definitely-absent-cepa.local.md"
# A non-git cwd must exit 2 WITH A MESSAGE. Shipped once as exit 128 and
# completely silent output: `git rev-parse` exits 128 outside a work tree, and
# as the last command of a `||` list the assignment inherited it, so
# `set -euo pipefail` killed the script before either _die could run. Callers
# fail closed on 128 so it was never a leak — but a bare 128 with no text reads
# as a broken client rather than "you are not in a git repo". This case asserts
# the DIAGNOSTIC, which is the half that regressed; `expect 2` alone would have
# passed on the silent form via a different code path.
# Runs with cwd inside $FIX/nongit — see the `*_nongit` arm in the runner,
# following the same id-suffix convention the `*_noenv` cases use.
reg sr_nongit 'scrub-required exits 2 with a message outside a git work tree' 2 'not in a git work tree' \
  'kills: letting git rev-parse status carry into the assignment (silent 128)' \
  scrub-required

# --- the re-Write gate (residual 2i) ----------------------------------------
# These pin the half of the gate that is mechanically checkable here: the
# argument and seal-validation guards. The BEHAVIOR — that a contaminating
# re-Write is actually caught between two fenced blocks — is not expressible in
# this suite, which is single-call and offline; it is measured by extracting
# compound.md's blocks and running them (see the PR body). Both halves are
# needed: this file would pass with a verb that validated perfectly and counted
# nothing.
reg arity_ss 'scrub-seal rejects a stray 2nd argument' 2 'scrub-seal takes exactly 1 argument' \
  'kills: removal of scrub-seal arity' \
  scrub-seal "$FIX/payload.json" EXTRA
reg arity_sv 'scrub-verify rejects a stray 2nd argument' 2 'scrub-verify takes exactly 1 argument' \
  'kills: removal of scrub-verify arity' \
  scrub-verify "$FIX/payload.json" EXTRA
# A MISSING seal must be exit 2 ("unevaluable"), never 0. This is the same
# shape as sr_undecidable and the same hazard: a gate that cannot be evaluated
# must not report success, or the re-Write check silently stops existing while
# every call site still looks gated.
reg sv_noseal 'scrub-verify exits 2 (not 0) when the seal is absent' 2 'UNEVALUABLE' \
  'kills: a mutant that treats a missing .phiseal as "nothing to check" and passes — the gate would stop existing while every call site still appears gated' \
  scrub-verify "$FIX/payload.json"
# A seal whose content is not a number must be 2, not an abort. `[ x -lt y ]`
# on non-numeric input dies under set -e with no diagnostic — unevaluable, but
# silently, which is the failure mode this whole suite exists to catch.
reg sv_badseal 'scrub-verify exits 2 on a non-numeric seal' 2 'non-numeric seal' \
  'kills: removal of the seal content validation — a garbage seal aborts the comparison with no message instead of refusing to send' \
  scrub-verify "$FIX/sealed.json"
# An EMPTY seal is distinct from a missing one (`[ -f ]` accepts it) and has
# its own guard, so it gets its own case.
reg sv_emptyseal 'scrub-verify exits 2 on an empty seal' 2 'EMPTY seal' \
  'kills: removal of the `[ -s ]` seal check — an empty seal reads as count "" and the comparison aborts silently' \
  scrub-verify "$FIX/emptyseal.json"
reg ss_nofile 'scrub-seal rejects a nonexistent payload' 2 'scrub-seal needs' \
  'kills: removal of the scrub-seal existence check — sealing a missing file would record 0, a count that can never fall' \
  scrub-seal "$FIX/does-not-exist.json"
# The false-positive floor for this verb pair: a SUCCESS case. A guard that
# rejects everything passes every rejection case above while breaking the real
# call site in compound.md. `scrub-seal` on a valid payload must exit 0 and
# report a count.
reg ss_ok 'scrub-seal succeeds on a readable payload' 0 'sealed: [0-9]+ redaction markers' \
  'kills: over-strict scrub-seal validation that rejects a legitimate payload — compound.md would suppress every writeback while each rejection case still passes' \
  scrub-seal "$FIX/sealcount.json"
# And verify must PASS on an untouched sealed payload — the honest-re-Write
# path. Pinned with a pre-built seal matching the fixture's real marker count.
reg sv_ok 'scrub-verify passes when the redactions are intact' 0 'redaction markers intact' \
  'kills: an off-by-one or inverted comparison that suppresses every honest writeback' \
  scrub-verify "$FIX/intact.json"
# THE COUNTING DEFECT, pinned. Two markers on ONE line with one dropped: the
# shipped-and-measured form, since compound.md emits single-line JSON. With
# `grep -c` (lines) both counts are 1 and this passes as intact; only
# occurrence counting sees 2 -> 1.
reg sv_oneline 'scrub-verify catches a dropped marker on a shared line' 1 'has 1 redaction markers but 2 were sealed' \
  'kills: counting matching LINES instead of occurrences — compound.md emits single-line JSON, so every marker shares one line and partial reintroduction is invisible' \
  scrub-verify "$FIX/oneline.json"

# --- guards must run BEFORE credentials -------------------------------------
# THE ORDERING INVARIANT, and it is the subtle one. Every guard above sits
# ahead of `_load_env`. A mutant that moves one after it still rejects the bad
# call — but only on a machine WITH credentials, and it would report a config
# error instead of the caller bug. These cases run with the env explicitly
# blanked, so a guard that drifted below `_load_env` fails here.
#
# BRAIN_ENV_FILE is pointed at a nonexistent path rather than left unset:
# `_load_env` defaults to `.env.local`, which EXISTS on the dev machine, so an
# unset variable would silently load real credentials and the case would pass
# for the wrong reason.
reg doc3_noenv 'idkey guard fires with no credentials' 2 'has no schema_version' \
  'kills: moving the idkey envelope guard below _load_env — it would then depend on credentials and pass locally for the wrong reason' \
  idkey helm doc.md "$FIX/doc.md"
reg arity_he_noenv 'health arity fires with no credentials' 2 'health takes no arguments' \
  'kills: moving health arity below _load_env, turning a caller bug into a config error' \
  health EXTRA

# --- the false-positive floor -----------------------------------------------
# Cases that expect SUCCESS are not filler: a guard that rejects everything
# passes every case above while breaking every real call site. These pin the
# calls compound.md and the brain-ops prompts actually make.
reg ok 'the valid 3-arg call still succeeds' 0 '^helm:docs/x\.md:[0-9a-f]{12}$' \
  'kills: over-strict arg-3 validation that rejects a legitimate payload — breaks every real call site while every rejection case still passes' \
  idkey helm docs/x.md "$FIX/payload.json"
reg okrc 'a valid recall payload passes the guards' 2 'BRAIN_URL not set' \
  'kills: an arg-1 guard on recall that rejects its own valid payload. Reaching _load_env IS the pass condition — the guards let it through' \
  recall "$FIX/recall.json"

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
N=${#IDS[@]}

if [ "$LIST_ONLY" -eq 1 ]; then
  for i in $(seq 0 $((N - 1))); do printf '%-16s %s\n' "${IDS[$i]}" "${TITLES[$i]}"; done
  exit 0
fi

selected() {
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; esac
  return 1
}

# Reject an --only naming an id that does not exist. Without this, a typo runs
# ZERO cases and reports a clean pass — a silent no-op, which is the same
# failure shape this whole suite exists to catch.
if [ -n "$ONLY" ]; then
  unknown=''
  for want in $(printf '%s' "$ONLY" | tr ',' ' '); do
    found=0
    for id in "${IDS[@]}"; do [ "$id" = "$want" ] && { found=1; break; }; done
    [ "$found" -eq 0 ] && unknown="${unknown}${want} "
  done
  [ -n "$unknown" ] && { printf 'FATAL: unknown case id(s): %s\n' "$unknown" >&2; exit 2; }
fi

printf 'brain-client argument controls\n'
printf 'client: %s\n\n' "$CLIENT"

pass=0; fail=0; skipped=0
for i in $(seq 0 $((N - 1))); do
  id="${IDS[$i]}"
  selected "$id" || { skipped=$((skipped + 1)); continue; }

  # Re-split the NUL-joined arguments. IFS is scoped to this expansion only.
  args=()
  while IFS= read -r -d $'\001' a; do args+=("$a"); done < <(printf '%s' "${ARGS[$i]}")

  # The `*_noenv` cases blank the environment; everything else inherits it.
  # Both forms point BRAIN_ENV_FILE at a path that cannot exist, so no case
  # can reach the network via a real .env.local. That is a hard property of
  # this suite, not a convention: it must stay read-only and offline.
  if case "$id" in *_nongit) true ;; *) false ;; esac; then
    # cwd OUTSIDE any git work tree. $FIX is a mktemp dir, but mktemp's parent
    # may itself sit inside a repo on some boxes, so the fixture sets
    # GIT_CEILING_DIRECTORIES to stop the upward .git search at $FIX — without
    # it this case could silently find an unrelated repo and pass for the wrong
    # reason. $CLIENT is absolute, so cd'ing away cannot break the invocation.
    out=$(cd "$FIX/nongit" && env -u BRAIN_URL -u MCP_ACCESS_KEY \
            GIT_CEILING_DIRECTORIES="$FIX" \
            BRAIN_ENV_FILE="$FIX/nonexistent.env" \
            bash "$CLIENT" "${args[@]}" 2>&1)
    rc=$?
  elif case "$id" in *_noenv) true ;; *) false ;; esac; then
    out=$(env -u BRAIN_URL -u MCP_ACCESS_KEY -u BRAIN_WORKSPACE_ID \
            BRAIN_ENV_FILE="$FIX/nonexistent.env" \
            bash "$CLIENT" "${args[@]}" 2>&1)
    rc=$?
  else
    out=$(env -u BRAIN_URL -u MCP_ACCESS_KEY \
            BRAIN_ENV_FILE="$FIX/nonexistent.env" \
            bash "$CLIENT" "${args[@]}" 2>&1)
    rc=$?
  fi

  ok=1; detail=''
  if [ "$rc" -ne "${EXP_RC[$i]}" ]; then
    ok=0; detail="expected rc=${EXP_RC[$i]}, got rc=$rc"
  elif [ -n "${EXP_RE[$i]}" ] && ! printf '%s' "$out" | grep -Eq -- "${EXP_RE[$i]}"; then
    ok=0; detail="output did not match /${EXP_RE[$i]}/"
  fi

  if [ "$ok" -eq 1 ]; then
    printf 'PASS  %-16s %s\n' "$id" "${TITLES[$i]}"
    pass=$((pass + 1))
  else
    printf 'FAIL  %-16s %s\n' "$id" "${TITLES[$i]}"
    printf '        %s\n' "$detail"
    printf '        why: %s\n' "${WHY[$i]}"
    printf '        got: %s\n' "$(printf '%s' "$out" | head -2 | tr '\n' ' ')"
    fail=$((fail + 1))
  fi
done

printf '\n-- %d/%d passed' "$pass" "$((pass + fail))"
[ "$skipped" -gt 0 ] && printf ', %d skipped' "$skipped"
printf ' --\n'

# A run that selected NOTHING must not report success. With --only validated
# above this is unreachable by typo, but a future selector bug would otherwise
# print "0/0 passed" and exit 0.
[ "$((pass + fail))" -eq 0 ] && { printf 'FATAL: no cases ran\n' >&2; exit 2; }
[ "$fail" -eq 0 ] || exit 1
exit 0

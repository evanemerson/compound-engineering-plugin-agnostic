#!/usr/bin/env bash
# cepa plugin-install freshness check — read-only. Warns when the plugin copy
# Claude Code actually LOADS lags this repo's last plugin-touching commit.
# Run from the repo root. Never modifies anything.
#
# WHY THIS EXISTS. On 2026-09-27 a session merged two PHI-scrub fixes (#71,
# #72), verified them on `main`, and reported them shipped — while the copy
# Claude Code loads sat at v1.26.5, three releases behind. Every `/cepa:*`
# invocation that session made ran the OLD contract, including the one whose
# defect the PRs closed. Nothing warned. `gh pr merge` moves GitHub, a local
# `git pull` moves this checkout, and NEITHER moves the installed copy.
# See memory/tasks.d/2026-09-27-main.md item 1.
#
# THERE ARE TWO HOPS, NOT ONE — and this is the part that is easy to get
# wrong. The install pipeline is:
#
#     this repo (origin/main)
#        │  git -C ~/.claude/plugins/marketplaces/cepa pull --ff-only
#        ▼
#     marketplace clone  ~/.claude/plugins/marketplaces/cepa
#        │  claude plugin update cepa@cepa   (copies into a versioned cache)
#        ▼
#     CACHE  ~/.claude/plugins/cache/cepa/cepa/<version>/   ← what LOADS
#
# A current clone does NOT mean a current plugin. Measured 2026-09-28: the
# clone was at v1.26.10 (fully caught up) while the cache Claude Code loads
# was still the v1.26.5 tree — `compound.md` there carries the PHI scrub as
# PROSE ONLY, the exact defect #72 fixed. Checking hop 1 alone would have
# reported that state clean. So this script checks both, and reports the CACHE
# as the authority on what is live.
#
# WHAT IT COMPARES. Not version strings — the repo's last commit that touched
# `plugins/`. A version bump is a claim; a commit reachable from the installed
# tree's recorded SHA is a fact. Repo-root docs deliberately do not bump the
# manifests (CLAUDE.md § Conventions), so a version compare goes stale in the
# opposite direction too: v1.26.10 == v1.26.10 while two plugin commits sit
# unshipped is exactly the state that would pass a version check.
#
# EXIT STATUS. 0 when the loaded copy is current or the answer is genuinely
# unknown (no clone, no python3, non-git install). 1 when a plugin-touching
# commit on this repo's base branch is NOT in the loaded copy. Never fails on
# an absent optional tool — an unknown answer is reported as UNKNOWN and does
# not gate, because a checker that fails closed on a missing `python3` trains
# people to skip it.
#
# NOT A GATE ON CI. This measures one developer machine's local install state,
# which no CI runner has and no commit can fix. It belongs in a pre-merge
# habit and in /cepa:setup's report, not in a workflow.

set -uo pipefail

MARKET="${CEPA_MARKETPLACE_DIR:-$HOME/.claude/plugins/marketplaces/cepa}"
CACHE_ROOT="${CEPA_PLUGIN_CACHE_DIR:-$HOME/.claude/plugins/cache/cepa/cepa}"
INSTALLED_JSON="${CEPA_INSTALLED_PLUGINS_JSON:-$HOME/.claude/plugins/installed_plugins.json}"

rc=0
warn()    { printf 'WARN    %s\n' "$*"; rc=1; }
ok()      { printf 'OK      %s\n' "$*"; }
info()    { printf 'INFO    %s\n' "$*"; }
unknown() { printf 'UNKNOWN %s\n' "$*"; }

echo "== cepa plugin-install freshness =="

# --- locate this repo and its base branch ----------------------------------
TOP=$(git rev-parse --show-toplevel 2>/dev/null) || {
  unknown "not inside a git repository — nothing to compare against"
  echo "== end plugin freshness (rc=0) =="
  exit 0
}

# Prefer origin/main: the question is "is the installed copy behind what has
# LANDED", not "behind my working branch". A local feature branch's unmerged
# plugin edits are not something the installed copy is expected to have, and
# comparing against HEAD would warn on every branch that touches plugins/ —
# noise that gets the check ignored. Fall back to HEAD only when there is no
# remote-tracking main (a fresh clone with no fetch, or a fork).
BASE=""
for ref in refs/remotes/origin/main refs/remotes/origin/master; do
  if git -C "$TOP" rev-parse --verify --quiet "$ref" >/dev/null; then
    BASE="${ref#refs/remotes/}"
    break
  fi
done
if [ -z "$BASE" ]; then
  BASE="HEAD"
  info "no origin/main or origin/master — comparing against local HEAD"
fi

# The last commit that touched shipped plugin content. Repo-root docs
# (CONCEPTS.md, todos/, memory/) are deliberately excluded by this pathspec:
# they do not ship in the plugin, so a docs-only commit must not report the
# install as stale. That is why 858ebbc (a handoff doc) is not the reference
# commit even though it is the tip of main.
REF_SHA=$(git -C "$TOP" log -1 --format=%H "$BASE" -- plugins/ 2>/dev/null)
if [ -z "$REF_SHA" ]; then
  unknown "no commit touching plugins/ found on $BASE — is this the cepa repo?"
  echo "== end plugin freshness (rc=0) =="
  exit 0
fi
REF_SUBJ=$(git -C "$TOP" log -1 --format=%s "$REF_SHA")
info "repo: $BASE last touched plugins/ at ${REF_SHA:0:7} — $REF_SUBJ"

# --- hop 1: the marketplace clone ------------------------------------------
# ERROR IS NOT "BEHIND". `merge-base --is-ancestor` has THREE outcomes: 0
# ancestor, 1 not-ancestor, 128 error (bad object, not a repo, corrupt clone).
# An `if`/`else` collapses 1 and 128 into the same arm, so a clone that cannot
# answer the question at all reports the confident sentence "is BEHIND" — a
# checker built to stop false confidence, emitting false confidence. Measured:
# `merge-base --is-ancestor <sha-from-another-repo> HEAD` returns 128.
# So resolve HEAD and verify the object is PRESENT first, and branch on the
# exact status afterwards. This mirrors hop 2's `cat-file -e` guard below; the
# asymmetry between the two was the defect.
if [ ! -d "$MARKET/.git" ]; then
  unknown "no git marketplace clone at $MARKET — non-git install, or cepa installed from elsewhere"
elif ! CLONE_HEAD_FULL=$(git -C "$MARKET" rev-parse HEAD 2>/dev/null); then
  unknown "marketplace clone at $MARKET has no resolvable HEAD (empty, bare, or corrupt) — hop 1 unverified"
elif ! git -C "$MARKET" cat-file -e "$REF_SHA^{commit}" 2>/dev/null; then
  # The commit is not an object in the clone at all. That is NOT the same as
  # "behind": a clone of a different remote, or one that has never fetched,
  # cannot be compared. Saying BEHIND here is a false alarm, and false alarms
  # are what teach an operator to ignore the check.
  unknown "marketplace clone does not contain object ${REF_SHA:0:7} — unfetched, or cloned from a different remote; hop 1 unverified"
elif git -C "$MARKET" merge-base --is-ancestor "$REF_SHA" "$CLONE_HEAD_FULL" 2>/dev/null; then
  ok "marketplace clone contains ${REF_SHA:0:7}"
else
  # Count from the clone's resolved HEAD, captured above. The earlier form
  # inlined `$(git -C "$MARKET" rev-parse HEAD)` UNQUOTED as a `--not` operand:
  # when that inner call failed it expanded to nothing, leaving the valid
  # command `rev-list --count <sha> --not -- plugins/`, which exits 0 and
  # prints a real-looking total. So `|| echo '?'` could never fire on the
  # failure it was written for — measured: it printed 66. Resolving HEAD into
  # a variable first, and failing the whole check if that resolution fails,
  # is what makes the count either right or absent.
  BEHIND=$(git -C "$TOP" rev-list --count "$REF_SHA" --not "$CLONE_HEAD_FULL" -- plugins/ 2>/dev/null) \
    || BEHIND='?'
  warn "marketplace clone is BEHIND: HEAD ${CLONE_HEAD_FULL:0:7} lacks ${REF_SHA:0:7} ($BEHIND plugin commit(s))"
  info "  refresh hop 1:  git -C $MARKET pull --ff-only"
fi

# --- hop 2: the versioned cache — this is what actually loads ---------------
# `installed_plugins.json` records the SHA the cache tree was built from. That
# record, not the clone's HEAD, is the authority on what a /cepa:* invocation
# executes. Read it with python3 because this repo cannot assume `jq`
# (CLAUDE.md § Conventions) — and treat an absent python3 as UNKNOWN rather
# than as a pass, so the gap is visible instead of silently skipped.
if ! command -v python3 >/dev/null 2>&1; then
  unknown "python3 unavailable — cannot read installed_plugins.json; LOADED copy unverified"
elif [ ! -f "$INSTALLED_JSON" ]; then
  unknown "no $INSTALLED_JSON — LOADED copy unverified"
else
  # Capture first and CHECK THE EXIT STATUS, rather than reading a
  # process-substitution's stdout and trusting it. python3 can die outside its
  # own try/except (kill, OOM, a SIGPIPE) and print nothing at all; a bare
  # `read` off that yields two empty variables that then flow into the
  # wildcard arm below and print `loaded copy: v` — a reassuring-looking line
  # describing nothing.
  #
  # Fields are TAB-separated, not space-separated. `read -r a b` splits on
  # IFS whitespace, so a version string containing a space desynchronizes the
  # two variables and shifts part of the version into the SHA. The values come
  # from installed_plugins.json — written by the Claude Code runtime, not by
  # this repo — so their shape is not ours to assume.
  if ! INST_RAW=$(python3 - "$INSTALLED_JSON" <<'PYEOF'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("PARSE-ERROR\t-"); raise SystemExit
try:
    e = d["plugins"]["cepa@cepa"][0]
except (KeyError, IndexError, TypeError):
    print("NOT-INSTALLED\t-"); raise SystemExit
# Strip whitespace so a padded value cannot smuggle a field separator.
v = str(e.get("version") or "?").strip() or "?"
s = str(e.get("gitCommitSha") or "-").strip() or "-"
print("%s\t%s" % (v, s))
PYEOF
  ); then
    unknown "python3 failed reading $INSTALLED_JSON (exit $?) — LOADED copy unverified"
    INST_VER='' INST_SHA=''
  else
    IFS=$'\t' read -r INST_VER INST_SHA <<EOF
$INST_RAW
EOF
  fi

  case "${INST_VER:-}" in
    '')
      # Empty means python3 emitted nothing, or the failure arm above already
      # reported. Never fall through to the version/SHA compare on an empty
      # value — that is how a garbled "v" line gets printed as if it were data.
      [ -n "$INST_RAW" ] && unknown "unparseable output from $INSTALLED_JSON reader — LOADED copy unverified" || true ;;
    PARSE-ERROR)
      unknown "could not parse $INSTALLED_JSON — format may have changed; LOADED copy unverified" ;;
    NOT-INSTALLED)
      unknown "cepa not listed in installed_plugins.json — LOADED copy unverified" ;;
    -*)
      # A leading dash would reach `git` as an option rather than a revision.
      unknown "implausible version '$INST_VER' in $INSTALLED_JSON — LOADED copy unverified" ;;
    *)
      info "loaded copy: v$INST_VER (cache $CACHE_ROOT/$INST_VER)"
      # Shape-check the SHA before it reaches a git revision argument. Two
      # distinct rejects, kept distinct on purpose:
      #   `-` (exactly)  = no SHA recorded -> the documented version-compare
      #                    fallback below, which announces its own weakness.
      #   anything else non-hex = a value we cannot use. Report UNKNOWN rather
      #                    than rewriting it to `-`: collapsing garbage into
      #                    the "none recorded" sentinel would make a corrupt
      #                    record indistinguishable from an absent one, and
      #                    the fallback would then print a confident
      #                    version-based verdict off a field it had silently
      #                    discarded. A leading dash also reaches git as an
      #                    OPTION, not a revision (measured: exit 129).
      if [ "$INST_SHA" != "-" ] && ! printf '%s' "$INST_SHA" | grep -Eq '^[0-9a-fA-F]{7,40}$'; then
        unknown "gitCommitSha in $INSTALLED_JSON is not a hex SHA ('$INST_SHA') — LOADED copy unverified"
      elif [ "$INST_SHA" = "-" ]; then
        # No recorded SHA: fall back to comparing the cached tree's own
        # manifest version against the repo's. Weaker than a SHA — it cannot
        # see plugin commits that did not bump the manifest — so say so
        # rather than reporting a clean pass off the weaker signal.
        REPO_VER=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
                     "$TOP/plugins/cepa/.claude-plugin/plugin.json" 2>/dev/null | head -1)
        if [ -n "$REPO_VER" ] && [ "$REPO_VER" != "$INST_VER" ]; then
          warn "loaded copy v$INST_VER != repo v$REPO_VER (no recorded SHA — version compare only)"
          info "  refresh hop 2:  claude plugin update cepa@cepa"
        else
          unknown "no gitCommitSha recorded — version matches ($INST_VER) but plugin commits that skipped a bump are invisible"
        fi
      elif ! git -C "$TOP" cat-file -e "$INST_SHA^{commit}" 2>/dev/null; then
        unknown "recorded SHA ${INST_SHA:0:7} is not an object in this repo — fetch, or the install came from a different remote"
      elif git -C "$TOP" merge-base --is-ancestor "$REF_SHA" "$INST_SHA" 2>/dev/null; then
        ok "LOADED copy contains ${REF_SHA:0:7} — the plugin Claude Code runs is current"
      else
        MISSING=$(git -C "$TOP" log --oneline "$INST_SHA..$BASE" -- plugins/ 2>/dev/null)
        N=$(printf '%s\n' "$MISSING" | grep -c . || true)
        warn "LOADED copy is BEHIND: v$INST_VER @ ${INST_SHA:0:7} is missing $N plugin commit(s)"
        printf '%s\n' "$MISSING" | sed 's/^/        missing: /'
        info "  refresh hop 2:  claude plugin update cepa@cepa   (then re-run this check)"
        echo
        echo "        A merged fix is NOT live until this hop completes. Any claim of"
        echo "        'verified against the installed copy' made while this warns is"
        echo "        a claim about code that is not running."
      fi ;;
  esac
fi

echo "== end plugin freshness (rc=$rc) =="
exit "$rc"

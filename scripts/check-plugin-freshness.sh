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
if [ ! -d "$MARKET/.git" ]; then
  unknown "no git marketplace clone at $MARKET — non-git install, or cepa installed from elsewhere"
else
  if git -C "$MARKET" merge-base --is-ancestor "$REF_SHA" HEAD 2>/dev/null; then
    ok "marketplace clone contains ${REF_SHA:0:7}"
  else
    CLONE_HEAD=$(git -C "$MARKET" rev-parse --short HEAD 2>/dev/null || echo '?')
    BEHIND=$(git -C "$TOP" rev-list --count "$REF_SHA" --not \
               $(git -C "$MARKET" rev-parse HEAD 2>/dev/null) -- plugins/ 2>/dev/null || echo '?')
    warn "marketplace clone is BEHIND: HEAD $CLONE_HEAD lacks ${REF_SHA:0:7} ($BEHIND plugin commit(s))"
    info "  refresh hop 1:  git -C $MARKET pull --ff-only"
  fi
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
  read -r INST_VER INST_SHA <<EOF
$(python3 - "$INSTALLED_JSON" <<'PYEOF'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("PARSE-ERROR -"); raise SystemExit
try:
    e = d["plugins"]["cepa@cepa"][0]
except (KeyError, IndexError, TypeError):
    print("NOT-INSTALLED -"); raise SystemExit
print(e.get("version", "?"), e.get("gitCommitSha") or "-")
PYEOF
)
EOF

  case "$INST_VER" in
    PARSE-ERROR)
      unknown "could not parse $INSTALLED_JSON — format may have changed; LOADED copy unverified" ;;
    NOT-INSTALLED)
      unknown "cepa not listed in installed_plugins.json — LOADED copy unverified" ;;
    *)
      info "loaded copy: v$INST_VER (cache $CACHE_ROOT/$INST_VER)"
      if [ "$INST_SHA" = "-" ]; then
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

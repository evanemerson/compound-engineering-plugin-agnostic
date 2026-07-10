#!/usr/bin/env bash
# cepa health check — read-only. Prints a fact report for /cepa:setup to
# interpret. Never modifies anything. Run from the project root.
set -u

ok()   { printf 'OK   %s\n' "$1"; }
miss() { printf 'MISS %s\n' "$1"; }
info() { printf 'INFO %s\n' "$1"; }

echo "== cepa health check: $(pwd) =="

# --- config file -----------------------------------------------------------
if [ -f cepa.local.md ]; then
  ok "cepa.local.md exists"
  for section in "## Stack" "## Review Agents (Active)" "## Autonomy" "## Integrations"; do
    if grep -q "^${section}" cepa.local.md; then ok "section: ${section}"; else miss "section: ${section}"; fi
  done
  grep -q "^## Compliance" cepa.local.md && ok "section: ## Compliance" || info "section: ## Compliance absent (fine if no compliance regime)"
  info "roster: $(grep -A30 '^## Review Agents' cepa.local.md | grep -c '^- [a-z!]' || true) agent lines"
else
  miss "cepa.local.md"
fi

# --- scaffold dirs ---------------------------------------------------------
for d in docs/plans docs/solutions todos memory; do
  [ -d "$d" ] && ok "dir: $d/" || miss "dir: $d/"
done
[ -f memory/tasks.md ] && ok "file: memory/tasks.md" || miss "file: memory/tasks.md"
if [ -d docs/solutions ]; then
  info "solution docs: $(find docs/solutions -name '*.md' -not -name '.gitkeep' 2>/dev/null | wc -l | tr -d ' ')"
fi
if [ -d todos ]; then
  info "review files: $(ls todos/review-*.md 2>/dev/null | wc -l | tr -d ' ')"
fi

# --- git -------------------------------------------------------------------
if git rev-parse --git-dir >/dev/null 2>&1; then
  ok "git repo (branch: $(git branch --show-current))"
  git check-ignore docs/plans >/dev/null 2>&1 && info "docs/plans is GITIGNORED (plans stay local)" || ok "docs/plans is tracked"
  git check-ignore todos >/dev/null 2>&1 && info "todos/ is GITIGNORED" || ok "todos/ is tracked"
else
  miss "not a git repository"
fi

# --- CI --------------------------------------------------------------------
if [ -d .github/workflows ] && ls .github/workflows/*.yml >/dev/null 2>&1; then
  ok "CI workflows: $(ls .github/workflows/*.yml | xargs -n1 basename | tr '\n' ' ')"
  grep -lq "pytest\|npm test\|astro build\|npm run build" .github/workflows/*.yml 2>/dev/null \
    && ok "a workflow runs tests or a build" \
    || miss "no workflow runs tests or a build (deploy/notify only)"
else
  miss "no .github/workflows — no CI gate"
fi

# --- plugin version drift --------------------------------------------------
IP="$HOME/.claude/plugins/installed_plugins.json"
if [ -f "$IP" ]; then
  installed=$(python3 -c "import json;d=json.load(open('$IP'));print(d['plugins']['cepa@cepa'][0]['version'])" 2>/dev/null || echo "?")
  info "installed cepa plugin: v${installed}"
else
  info "installed_plugins.json not found (non-standard install)"
fi

echo "== end health check =="

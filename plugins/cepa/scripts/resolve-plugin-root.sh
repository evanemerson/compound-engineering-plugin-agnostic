#!/usr/bin/env bash
# cepa plugin-root resolver — emits the absolute path of the installed
# `plugins/cepa` directory on stdout, or fails loudly naming every path it tried.
#
# WHY THIS EXISTS. `${CLAUDE_PLUGIN_ROOT}` is NOT exported into the shell the
# Bash tool runs. A command body that spells
#     bash "${CLAUDE_PLUGIN_ROOT}/scripts/brain-client.sh"
# therefore expands to `/scripts/brain-client.sh` and exits 127 with
# "No such file or directory". Measured 2026-09-25 in both a dispatched
# subagent and an ordinary command-body Bash call; brain writeback had been
# dead in /cepa:compound and /cepa:compound-refresh, and /cepa:setup's health
# check had been silently degrading to "perform the checks manually".
#
# That 127 signature reads as a MISSING BINARY, which is the misdiagnosis
# docs/solutions/integration-issues/false-unavailable-from-missing-cli-path-and-untracked-credential.md
# records: 42 review files carried a false "service unreachable" claim while the
# service was live and healthy. An unresolvable path must never be reported as
# an outage.
#
# Usage — source it (preferred; gets you BASH_SOURCE self-location):
#   . "<abs>/plugins/cepa/scripts/resolve-plugin-root.sh"   # sets $CEPA_ROOT
# or capture it:
#   CEPA_ROOT="$(bash "<abs>/plugins/cepa/scripts/resolve-plugin-root.sh")" || exit 1
#
# Override with CEPA_PLUGIN_ROOT (operator) — it wins over everything.

# Resolution order mirrors scripts/capture.py:817-851, deliberately: explicit
# override, then the sibling of a known plugin file, then PATH. capture.py's
# comment block records the bug NOT to repeat — Path("") is PosixPath("."),
# which is truthy AND exists, because "." is the working directory. Its guard
# passed and the client silently resolved to the working directory, so every
# call tried to execute a directory.
#
# The shell analogue of that trap is `[ -e "$x" ]` with $x empty or ".". So:
# every candidate below is validated by _cepa_is_root, which requires a
# DIRECTORY plus a marker file that is a real file (-f) and executable (-x).
# Never `-e`, and never "non-empty therefore usable".
_cepa_is_root() {
  local cand="${1:-}"
  # An empty candidate must fail BEFORE any test that would read it as ".".
  [ -n "$cand" ] || return 1
  [ -d "$cand" ] || return 1
  # Marker: the transport every consumer needs. A directory that merely exists
  # (a half-finished install, a same-named dir in the cwd) is rejected here
  # rather than accepted and executed.
  [ -f "$cand/scripts/brain-client.sh" ] || return 1
  [ -x "$cand/scripts/brain-client.sh" ] || return 1
  return 0
}

_cepa_abs() {
  # Absolutise without requiring realpath/readlink -f (absent on some hosts).
  local p="${1:-}"
  [ -n "$p" ] || return 1
  ( cd -- "$p" 2>/dev/null && pwd -P ) || return 1
}

_cepa_resolve_plugin_root() {
  local tried=() cand resolved

  # 1. Explicit operator override, then the harness variable. CLAUDE_PLUGIN_ROOT
  #    is honoured when it IS set — this resolver is a fallback for the unset
  #    case, not a replacement for a working harness.
  for cand in "${CEPA_PLUGIN_ROOT:-}" "${CLAUDE_PLUGIN_ROOT:-}"; do
    [ -n "$cand" ] || continue
    # An override MUST be absolute. A relative one ("." , "plugins/cepa", "")
    # means "resolve against whatever cwd this shell inherited" — unknowable
    # when the command body was written, and the exact shape of the capture.py
    # bug above: `.` is a real, existing directory, so absolutising it first
    # produces a plausible path that passes every -d/-f/-x test below. Stage a
    # scripts/brain-client.sh in the cwd and a "." override silently wins.
    # Reject the relative spelling itself; do not try to validate its result.
    case "$cand" in
      /*) ;;
      *) tried+=("$cand (from env — REJECTED: not an absolute path)"); continue ;;
    esac
    if resolved="$(_cepa_abs "$cand")" && _cepa_is_root "$resolved"; then
      printf '%s\n' "$resolved"; return 0
    fi
    tried+=("$cand (from env)")
  done

  # 2. Self-location — the shell equivalent of capture.py's sibling rule, and
  #    the case that actually fixes the unset-var bug: this file ships inside
  #    plugins/cepa/scripts/, so its own grandparent IS the plugin root.
  #    BASH_SOURCE[0] is set both when sourced and when executed.
  if [ -n "${BASH_SOURCE[0]:-}" ]; then
    if resolved="$(_cepa_abs "$(dirname -- "${BASH_SOURCE[0]}")/..")" \
       && _cepa_is_root "$resolved"; then
      printf '%s\n' "$resolved"; return 0
    fi
    tried+=("$(dirname -- "${BASH_SOURCE[0]}")/.. (self-location)")
  fi

  # 3. Known install locations. The marketplace clone is where a consuming repo
  #    finds it; plugins/cepa under the git root is for work in this repo.
  for cand in "$HOME"/.claude/plugins/marketplaces/*/plugins/cepa; do
    if resolved="$(_cepa_abs "$cand")" && _cepa_is_root "$resolved"; then
      printf '%s\n' "$resolved"; return 0
    fi
    # Unmatched globs come through literally; only report ones that could exist.
    case "$cand" in *'*'*) ;; *) tried+=("$cand (marketplace)") ;; esac
  done

  local gitroot
  if gitroot="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    if resolved="$(_cepa_abs "$gitroot/plugins/cepa")" \
       && _cepa_is_root "$resolved"; then
      printf '%s\n' "$resolved"; return 0
    fi
    tried+=("$gitroot/plugins/cepa (repo)")
  fi

  # 4. PATH — brain-client.sh's grandparent. Last because a stray copy on PATH
  #    may be a different version of the contract than the rest of the plugin.
  local onpath
  if onpath="$(command -v brain-client.sh 2>/dev/null)" && [ -n "$onpath" ]; then
    if resolved="$(_cepa_abs "$(dirname -- "$onpath")/..")" \
       && _cepa_is_root "$resolved"; then
      printf '%s\n' "$resolved"; return 0
    fi
    tried+=("$onpath (PATH)")
  fi

  # Fail LOUDLY, naming every path tried. A caller that cannot find its client
  # must report a resolution failure, never a service outage, and never exit 0.
  {
    printf 'cepa: could not resolve the plugin root.\n'
    printf 'Tried, in order:\n'
    local t
    for t in "${tried[@]}"; do printf '  - %s\n' "$t"; done
    printf 'Set CEPA_PLUGIN_ROOT to the absolute path of plugins/cepa.\n'
    printf 'This is a PATH-RESOLUTION failure, not a service outage —\n'
    printf 'do not report the brain or any other service as unavailable.\n'
  } >&2
  return 1
}

# Sourced: export $CEPA_ROOT for the caller. Executed: print it.
# $0 vs BASH_SOURCE[0] differ only when sourced.
if [ "${BASH_SOURCE[0]:-$0}" != "$0" ]; then
  CEPA_ROOT="$(_cepa_resolve_plugin_root)" || return 1
  export CEPA_ROOT
else
  _cepa_resolve_plugin_root
fi

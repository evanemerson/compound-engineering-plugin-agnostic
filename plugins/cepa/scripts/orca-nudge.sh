#!/usr/bin/env bash
# cepa Orca nudge — types one fixed line into an idle session's terminal, so
# that it reads the orchestration message it was just sent.
# `cepa:autonomy` §12b rule 1 ("Send, then nudge") owns WHEN to nudge; this
# script owns HOW, so the commands grant this script and not
# `terminal send`, which admits any text, any terminal and `--interrupt`.
#
# Usage: orca-nudge.sh <cli> <handle>
#   <cli>     §12a's printed `cli=` value: a plain command name or path whose
#             basename is orca-ide, orca-dev or (off Linux) orca, on PATH.
#   <handle>  the target terminal handle, `term_` and 36 hex-or-dash chars.
#
# Prints exactly one line, and its exit code says which:
#   0  Orca nudge sent to <handle>
#   1  Orca nudge skipped: <reason>   — the target is not idle, or unknown
#   2  Orca nudge refused: <reason>   — an argument failed its check
#   3  Orca nudge failed: <reason>    — the send itself failed
# The message send that came before it stands in every case.
#
# THE STATE GUARD. The nudge ends with Enter. While the target shows a question
# prompt (AskUserQuestion's "Enter to select", a permission prompt), that Enter
# picks the highlighted option: an operator decision made without the operator
# (#100 finding 3, measured by coord@main in the L26 probe). So the script
# sends only when the target's agent row says `done`, and skips on any other
# state, an unknown one, or no row. Measured 2026-10-30 on this box: the agent
# rows of `worktree ps --agent-wait --json` carry no terminal handle, only
# `paneKey`, and `paneKey` equals `<tabId>:<leafId>` from
# `terminal show --terminal <handle> --json`. So the script looks the handle
# up with `terminal show` (whose `handle` must echo the argument), and then
# matches that exact paneKey. It never matches by title.
#
# STATED LIMITS:
#   - The state is read, then the line is sent. A target that leaves `done`
#     between the two (the operator starts a turn) still gets the line.
#   - Each Orca call is bounded at 10 seconds plus a 2-second kill, as §12a's
#     status probe is. No `timeout` or no `python3` reads as skipped.
#   - The flags are from `terminal show --help`, `worktree ps --help` and
#     `terminal send --help` (2026-10-30). If Orca changes them, the nudge
#     reads as skipped or failed, and the send still stands.
set -u

cepa_nudge_cli=${1-}
cepa_nudge_term=${2-}

refuse() { echo "Orca nudge refused: $1"; exit 2; }
skip() { echo "Orca nudge skipped: $1"; exit 1; }

[ $# -eq 2 ] || refuse "usage: orca-nudge.sh <cli> <handle>"
case "$cepa_nudge_cli" in
  ''|-*|*[!A-Za-z0-9._/-]*) refuse "the cli is not a plain command name" ;;
esac
case "${cepa_nudge_cli##*/}" in
  orca-ide|orca-dev) ;;
  orca) [ "$(uname -s 2>/dev/null)" != Linux ] || refuse "bare orca on Linux is the screen reader" ;;
  *) refuse "the cli does not name an Orca CLI" ;;
esac
[[ $cepa_nudge_term =~ ^term_[0-9a-f-]{36}$ ]] || refuse "the handle is not a terminal handle"
command -v "$cepa_nudge_cli" >/dev/null 2>&1 || refuse "$cepa_nudge_cli is not on PATH"
command -v timeout >/dev/null 2>&1 || skip "no timeout command to bound the Orca calls"
command -v python3 >/dev/null 2>&1 || skip "no python3 to read the Orca output"

cepa_nudge_tmp=$(mktemp -d 2>/dev/null) || skip "mktemp failed"
trap 'rm -rf "$cepa_nudge_tmp"' EXIT

timeout -k 2 10 "$cepa_nudge_cli" terminal show --terminal "$cepa_nudge_term" --json \
  </dev/null >"$cepa_nudge_tmp/show.json" 2>/dev/null \
  || skip "terminal show failed or timed out"
timeout -k 2 10 "$cepa_nudge_cli" worktree ps --agent-wait --json \
  </dev/null >"$cepa_nudge_tmp/ps.json" 2>/dev/null \
  || skip "worktree ps failed or timed out"

# Prints `done`, or the reason not to nudge. The reason holds no Orca text
# except a state name, and only when that name is a plain word.
cepa_nudge_state=$(python3 -I - "$cepa_nudge_term" "$cepa_nudge_tmp/show.json" "$cepa_nudge_tmp/ps.json" <<'PY' 2>/dev/null
import json, re, sys
term, show_p, ps_p = sys.argv[1:4]
try:
    show, ps = json.load(open(show_p)), json.load(open(ps_p))
except (OSError, ValueError):
    print("the Orca output is not JSON"); sys.exit()
if show.get("ok") is not True or ps.get("ok") is not True:
    print('an Orca call did not return "ok": true'); sys.exit()
t = (show.get("result") or {}).get("terminal") or {}
tab, leaf = t.get("tabId"), t.get("leafId")
if t.get("handle") != term or not isinstance(tab, str) or not isinstance(leaf, str) or not tab or not leaf:
    print("terminal show did not describe this handle"); sys.exit()
key = tab + ":" + leaf
rows = [a for w in ((ps.get("result") or {}).get("worktrees") or [])
        for a in (w.get("agents") or []) if a.get("paneKey") == key]
if not rows:
    print("the target has no agent row"); sys.exit()
if len(rows) > 1:
    print("the target matches %d agent rows" % len(rows)); sys.exit()
state = rows[0].get("state")
if state == "done":
    print("done")
elif isinstance(state, str) and re.fullmatch(r"[a-z_-]{1,20}", state):
    print("the target is " + state)
else:
    print("the target state is unknown")
PY
) || cepa_nudge_state=
[ -n "$cepa_nudge_state" ] || skip "the Orca output could not be read"
[ "$cepa_nudge_state" = done ] || skip "$cepa_nudge_state"

# The text is fixed. Only the checked cli is substituted into it.
cepa_nudge_text="You have 1 orchestration message. Run $cepa_nudge_cli orchestration check --peek --json"
if ! timeout -k 2 10 "$cepa_nudge_cli" terminal send --terminal "$cepa_nudge_term" \
     --text "$cepa_nudge_text" --enter --json </dev/null >"$cepa_nudge_tmp/send.json" 2>/dev/null; then
  echo "Orca nudge failed: terminal send exited non-zero or timed out"; exit 3
fi
if ! python3 -I -c 'import json, sys; sys.exit(0 if json.load(open(sys.argv[1])).get("ok") is True else 1)' \
     "$cepa_nudge_tmp/send.json" >/dev/null 2>&1; then
  echo 'Orca nudge failed: terminal send did not return "ok": true'; exit 3
fi
echo "Orca nudge sent to $cepa_nudge_term"

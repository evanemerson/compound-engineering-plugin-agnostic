#!/usr/bin/env bash
# cepa Orca nudge — types one fixed line into an idle session's terminal, so
# that it reads the orchestration message it was just sent.
# `cepa:autonomy` §12b rule 1 ("Send, then nudge") owns WHEN to nudge; this
# script owns HOW, so the commands grant this script and not
# `terminal send`, which admits any text, any terminal and `--interrupt`.
#
# Usage: orca-nudge.sh <cli> <handle>
#   <cli>     §12a's printed `cli=` value: the bare name orca-ide, orca-dev or
#             (off Linux) orca, found on PATH. A path is accepted only when it
#             is absolute and equals ORCA_CLI_COMMAND, which Orca exports: any
#             other path could name a planted binary, which the script would
#             run and would type into another session (#100 review).
#   <handle>  the target terminal handle, `term_` and 36 hex-or-dash chars.
#
# Prints one result line, and its exit code says which:
#   0  Orca nudge sent to <handle>
#   1  Orca nudge skipped: <reason>   — the target is not idle, or unknown
#      (§12b rule 1: a skip leaves the message unread, so the delivery is not
#      done)
#   2  Orca nudge refused: <reason>   — an argument failed its check
#   3  Orca nudge failed: <reason>    — the send itself failed
# On exit 1, 2 or 3 it then prints one more line:
#   Ending first line: Needed from you: tell <handle> to check its Orca inbox
# §12b rule 1 says the session copies the text after `Ending first line: `
# verbatim as its ending's first line. Why: in the L26 re-probe (C2c,
# 2026-10-31) the script skipped correctly, and the session still wrote
# `Needed from you: nothing`. <handle> is printed only when it passes the
# handle check; any other value prints `the target session` in its place.
# The message send that came before it stands in every case.
#
# THE VSOCK RETRY. Under several concurrent WSL sessions, an Orca call can fail
# with stderr holding `UtilAcceptVsock` and `accept4 failed 110`: WSL's
# interop could not accept the connection to the Windows CLI (L26 re-probe,
# 2026-10-31, in §12a's status probe and in `orchestration send`). Each Orca
# call here is retried once, only when it exits non-zero with both texts in
# its stderr. Any other failure, and a second failure, is not retried.
# Not measured: whether the failed call reached Orca before it failed. For
# `terminal send` a retry could then type the line twice.
#
# THE STATE GUARD. The nudge ends with Enter. While the target shows a question
# prompt (AskUserQuestion's "Enter to select", a permission prompt), that Enter
# picks the highlighted option: an operator decision made without the operator
# (#100 finding 3, measured by coord@main in the L26 probe). So the script
# sends only when the target's agent row says `done`, and skips on any other
# state, an unknown one, or no row. An open AskUserQuestion shows `waiting`
# (measured by coord@main twice on 2026-10-30), so the guard skips it.
#
# THE BOUNDED WAIT. A `working` target is busy, not asking: the script
# re-reads its row every `cepa_nudge_poll` seconds for at most
# `cepa_nudge_wait` seconds (fixed below, never read from the environment).
# It nudges if the row turns `done`, skips with the new reason if the row turns
# to any other state, and skips with "still working" at the bound (operator
# decision, 2026-10-30, #100 finding 2). Every other state skips at once,
# with no wait. Measured 2026-10-30 on this box: the agent
# rows of `worktree ps --agent-wait --json` carry no terminal handle, only
# `paneKey`, and `paneKey` equals `<tabId>:<leafId>` from
# `terminal show --terminal <handle> --json`. So the script looks the handle
# up with `terminal show` (whose `handle` must echo the argument), and then
# matches that exact paneKey. It never matches by title.
#
# STATED LIMITS:
#   - The state is read, then the line is sent. A target that leaves `done`
#     between the two (the operator starts a turn) still gets the line.
#   - `done` comes from Claude Code's Stop hook, and typing at the prompt fires
#     no hook. So a nudge can submit a draft the operator has half-typed into
#     an idle target, with the nudge line appended. The operator accepted this
#     on 2026-10-30 and kept `--enter` (#100 finding 3).
#   - The row state while a permission prompt is open was not measured. The
#     guard skips it unless it reads `done`.
#   - The clock starts after the first `worktree ps`, and the wait can
#     overrun its bound by one more call. With every call at its 12-second
#     bound and no retry, a run takes at most about 170 seconds. With the
#     vsock retry on every call (each call then takes two bounds), it takes
#     at most about 220 seconds. That is longer than a default 2-minute tool
#     timeout: a caller that kills the run gets no line, and §12b rule 1
#     counts that as not delivered.
#   - The bound is wall-clock: a clock stepped back mid-wait lengthens it by
#     that step.
#   - Each Orca call is bounded at 10 seconds plus a 2-second kill, as §12a's
#     status probe is. No `timeout` or no `python3` reads as skipped.
#   - The flags are from `terminal show --help`, `worktree ps --help` and
#     `terminal send --help` (2026-10-30). If Orca changes them, the nudge
#     reads as skipped or failed, and the send still stands.
set -u

cepa_nudge_cli=${1-}
cepa_nudge_term=${2-}

cepa_nudge_valid_term() { [[ $cepa_nudge_term =~ ^term_[0-9a-f-]{36}$ ]]; }
# The ending's first line, for every outcome but sent (§12b rule 1).
cepa_nudge_ending() {
  if cepa_nudge_valid_term; then
    echo "Ending first line: Needed from you: tell $cepa_nudge_term to check its Orca inbox"
  else
    echo "Ending first line: Needed from you: tell the target session to check its Orca inbox"
  fi
}
refuse() { echo "Orca nudge refused: $1"; cepa_nudge_ending; exit 2; }
skip() { echo "Orca nudge skipped: $1"; cepa_nudge_ending; exit 1; }
fail() { echo "Orca nudge failed: $1"; cepa_nudge_ending; exit 3; }

[ $# -eq 2 ] || refuse "usage: orca-nudge.sh <cli> <handle>"
case "$cepa_nudge_cli" in
  ''|-*|*[!A-Za-z0-9._/-]*) refuse "the cli is not a plain command name" ;;
  /*) [ "$cepa_nudge_cli" = "${ORCA_CLI_COMMAND:-}" ] || refuse "a cli path must equal ORCA_CLI_COMMAND" ;;
  */*) refuse "a cli path must be absolute and equal ORCA_CLI_COMMAND" ;;
esac
case "${cepa_nudge_cli##*/}" in
  orca-ide|orca-dev) ;;
  orca) [ "$(uname -s 2>/dev/null)" != Linux ] || refuse "bare orca on Linux is the screen reader" ;;
  *) refuse "the cli does not name an Orca CLI" ;;
esac
cepa_nudge_valid_term || refuse "the handle is not a terminal handle"
command -v "$cepa_nudge_cli" >/dev/null 2>&1 || refuse "$cepa_nudge_cli is not on PATH"
command -v timeout >/dev/null 2>&1 || skip "no timeout command to bound the Orca calls"
command -v python3 >/dev/null 2>&1 || skip "no python3 to read the Orca output"

cepa_nudge_tmp=$(mktemp -d 2>/dev/null) || skip "mktemp failed"
trap 'rm -rf "$cepa_nudge_tmp"' EXIT

# One Orca call, bounded at 10 seconds plus a 2-second kill, its stdout to $1.
# Retried once, only on the WSL interop error (THE VSOCK RETRY, above).
cepa_nudge_orca() {
  local out=$1
  shift
  timeout -k 2 10 "$cepa_nudge_cli" "$@" </dev/null >"$out" 2>"$cepa_nudge_tmp/err" && return 0
  cepa_nudge_e=$(<"$cepa_nudge_tmp/err") || return 1
  [[ $cepa_nudge_e == *UtilAcceptVsock* && $cepa_nudge_e == *"accept4 failed 110"* ]] || return 1
  timeout -k 2 10 "$cepa_nudge_cli" "$@" </dev/null >"$out" 2>/dev/null
}

cepa_nudge_orca "$cepa_nudge_tmp/show.json" terminal show --terminal "$cepa_nudge_term" --json \
  || skip "terminal show failed or timed out"

# Sets cepa_nudge_state to `done`, or to the reason not to nudge. The reason
# holds no Orca text except a state name, and only when that name is a plain
# word.
cepa_nudge_read() {
cepa_nudge_orca "$cepa_nudge_tmp/ps.json" worktree ps --agent-wait --json \
  || skip "worktree ps failed or timed out"
cepa_nudge_state=$(python3 -I - "$cepa_nudge_term" "$cepa_nudge_tmp/show.json" "$cepa_nudge_tmp/ps.json" <<'PY' 2>/dev/null
import json, re, sys
term, show_p, ps_p = sys.argv[1:4]

def reason():
    try:
        show, ps = json.load(open(show_p)), json.load(open(ps_p))
    except (OSError, ValueError):
        return "the Orca output is not JSON"
    if show.get("ok") is not True or ps.get("ok") is not True:
        return 'an Orca call did not return "ok": true'
    t = (show.get("result") or {}).get("terminal") or {}
    tab, leaf = t.get("tabId"), t.get("leafId")
    if t.get("handle") != term or not isinstance(tab, str) or not isinstance(leaf, str) or not tab or not leaf:
        return "terminal show did not describe this handle"
    key = tab + ":" + leaf
    rows = [a for w in ((ps.get("result") or {}).get("worktrees") or [])
            for a in (w.get("agents") or []) if a.get("paneKey") == key]
    if not rows:
        return "the target has no agent row"
    if len(rows) > 1:
        return "the target matches %d agent rows" % len(rows)
    state = rows[0].get("state")
    if state == "done":
        return "done"
    elif isinstance(state, str) and re.fullmatch(r"[a-z_-]{1,20}", state):
        return "the target is " + state
    return "the target state is unknown"

# JSON of the wrong shape (a list, null, a non-object row) raises here.
try:
    print(reason())
except Exception:
    print("the Orca output has an unexpected shape")
PY
) || cepa_nudge_state=
[ -n "$cepa_nudge_state" ] || skip "the Orca output could not be read"
}

cepa_nudge_now() {
  cepa_nudge_t=$(date +%s 2>/dev/null)
  [[ $cepa_nudge_t =~ ^[0-9]+$ ]] || skip "date gave no clock for the wait"
}

cepa_nudge_wait=120
cepa_nudge_poll=10
cepa_nudge_read
if [ "$cepa_nudge_state" = "the target is working" ]; then
  cepa_nudge_now
  cepa_nudge_end=$((cepa_nudge_t + cepa_nudge_wait))
  while [ "$cepa_nudge_state" = "the target is working" ]; do
    cepa_nudge_now
    cepa_nudge_left=$((cepa_nudge_end - cepa_nudge_t))
    [ "$cepa_nudge_left" -gt 0 ] || skip "the target is still working after $cepa_nudge_wait seconds"
    sleep "$((cepa_nudge_left < cepa_nudge_poll ? cepa_nudge_left : cepa_nudge_poll))" \
      || skip "sleep failed in the wait"
    cepa_nudge_read
  done
fi
[ "$cepa_nudge_state" = done ] || skip "$cepa_nudge_state"

# The text is fixed. Only the checked cli is substituted into it.
cepa_nudge_text="You have 1 orchestration message. Run $cepa_nudge_cli orchestration check --peek --json"
if ! cepa_nudge_orca "$cepa_nudge_tmp/send.json" terminal send --terminal "$cepa_nudge_term" \
     --text "$cepa_nudge_text" --enter --json; then
  fail "terminal send exited non-zero or timed out"
fi
if ! python3 -I -c 'import json, sys; sys.exit(0 if json.load(open(sys.argv[1])).get("ok") is True else 1)' \
     "$cepa_nudge_tmp/send.json" >/dev/null 2>&1; then
  fail 'terminal send did not return "ok": true'
fi
echo "Orca nudge sent to $cepa_nudge_term"

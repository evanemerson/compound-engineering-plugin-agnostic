#!/usr/bin/env bash
# cepa Orca send — sends one orchestration message, proves Orca stored it, and
# only then runs the guarded nudge (orca-nudge.sh, beside this file).
# `cepa:autonomy` §12b rule 1 owns WHEN a session sends and whom it nudges;
# this script owns HOW a send is counted. A send counts only when Orca returns
# `"ok": true` with `result.message.id` shaped `msg_…`, AND a re-read of the
# inbox finds that id. Nothing else counts: not exit 0, not an `"id"` field.
#
# Usage: orca-send.sh <cli> <target> <type> <nudge|no-nudge>  <stdin
#   <cli>     §12a's printed `cli=` value, checked as orca-nudge.sh checks it.
#   <target>  a `term_` handle, or a `run:<id>` / `dispatch:<id>` address.
#   <type>    status, question, handoff, escalation or merge_ready.
#             Orca refuses `escalation` from a sender with no Dispatch.
#             worker_done and heartbeat carry Dispatch IDs: a dispatched
#             worker sends them with its preamble's own command.
#   <nudge|no-nudge>  `nudge` for a target that is not a Run coordinator
#             (only a `term_` handle); `no-nudge` for a Run coordinator.
#   stdin     line 1 is the subject; every line after it is the body. The
#             session writes both inside a quoted heredoc (`<<'CEPA_BODY'`),
#             so no character of either is expanded. The one exception is a
#             line that is exactly `CEPA_BODY`: it ends the heredoc, and the
#             lines after it run as shell commands. §12b rule 1 makes the
#             session indent such a line; this script never sees it.
#             Trailing newlines of the body are dropped.
#
# Prints one result line, then the nudge's lines when it runs. Exit codes:
#   0  Orca send stored: <msg id> for <recipient>, then either orca-nudge.sh's
#      `Orca nudge sent to <handle>`, this script's `Orca nudge not needed:
#      <reason>` (stored in a Run mailbox), or nothing more (no-nudge).
#   1, 2, 3  stored, then the nudge skipped, refused or failed: orca-nudge.sh's
#      own lines, its `Ending first line:` included, or this script's own
#      skip (stored for another handle; orca-nudge.sh missing or would not
#      start). The message stands.
#   4  Orca send refused: <reason>   — an argument failed its check; no call.
#   5  Orca send failed: no message stored — <reason>
#   On 4 and 5 it then prints:
#   Ending first line: Needed from you: paste the block below into <target>
#   <target> is printed only when it passes the target check; any other value
#   prints `the target session`.
#
# WHY (punch-list L33, measured 2026-10-31 on Orca 1.4.245, WSL, probe
# terminals in the `roles` worktree). A worker counted two sends as stored by
# grepping `"id"`. Every reply has a top-level `"id"`: a stored message's reply
# has a UUID there, a REFUSED one has `"id": "local"` or a UUID, so the grep
# matches both. Measured ways a send stores nothing:
#   - `--type worker_done` from a sender with no Dispatch: exit 1,
#     `"ok": false`, `missing_task_id` / `invalid_argument`. Behind a pipe the
#     exit code is the grep's, 0. (`escalation` and `ask` likewise:
#     `sender_not_assignee`, `dispatch_inactive`.)
#   - a command line of about 32 KB or more: subject+body of 31,500 chars
#     stored, 32,500 did not. WSL starts the Windows CLI through
#     powershell.exe, which fails `Invalid argument`: exit 1, EMPTY stdout.
#   - a body or subject that starts with `--`: `invalid_argument`.
#   - the WSL interop error (`UtilAcceptVsock` … `accept4 failed 110`):
#     non-zero exit, empty stdout (L26 re-probe).
# A `legacy_terminal_recipient` warning came with every stored send to a
# `term_` handle; a warning alone never means "not stored", and never "stored".
#
# THE RE-READ. `orchestration inbox --limit 200 --json` lists rows for every
# recipient, newest first (measured 2026-10-31: `--limit 3` returned sequences
# 180, 179, 178 of 180, and rows addressed to other sessions were listed), so
# a message stored seconds ago is inside the window. The id must be there with the `to_handle` the send
# reported. Orca can store a send for another mailbox than the one named: a
# send to a Run coordinator's `term_` handle was stored for `run:<id>`
# (msg_6d1566506a61). Such a row is a Run mailbox, which Orca prompts, so it
# gets no nudge.
#
# THE VSOCK RETRY follows orca-nudge.sh's rule: one retry, only on a non-zero
# exit whose stderr holds both `UtilAcceptVsock` and `accept4 failed 110`;
# never after a timeout. Unlike the nudge, it re-reads nothing before the
# retry.
#
# TIME BUDGET. Each Orca call is bounded at 15 s plus a 2 s kill, so with its
# retry a call takes at most 34 s: the send and the re-read take at most 68 s,
# plus the nudge's own bound (about 220 s, its header): about 290 s in all. Not measured: whether the failed send reached Orca, so the target
# can get the message twice (§12b rule 1 accepts that limit).
#
# STATED LIMITS:
#   - A row in the inbox is "stored", not "read". Reading is the nudge's job,
#     and rule 8's peek is the backstop.
#   - The size cap is 28,000 bytes of subject plus body, below the measured
#     limit. The Windows limit counts UTF-16 units of the whole command line,
#     so bytes over-count non-ASCII text: a cap in bytes is the safe side.
#   - If the inbox cannot be read or parsed, or the send timed out, the send is
#     reported failed even when it may have stored (the reason then says
#     "unconfirmed" or names the exit): a pasted copy then duplicates it. A duplicate is the accepted
#     cost; a lost message is not.
#   - The flags are from `orchestration send --help` and `inbox --help`
#     (Orca 1.4.245). If Orca changes them, the send fails loudly here.
set -u

cepa_send_cli=${1-}
cepa_send_target=${2-}
cepa_send_type=${3-}
cepa_send_mode=${4-}

cepa_send_valid_target() {
  [[ $cepa_send_target =~ ^(term_[0-9a-f-]{36}|run:[A-Za-z0-9_-]{1,64}|dispatch:[A-Za-z0-9_-]{1,64})$ ]]
}
cepa_send_ending() {
  if cepa_send_valid_target; then
    echo "Ending first line: Needed from you: paste the block below into $cepa_send_target"
  else
    echo "Ending first line: Needed from you: paste the block below into the target session"
  fi
}
refuse() { echo "Orca send refused: $1"; cepa_send_ending; exit 4; }
fail() { echo "Orca send failed: no message stored — $1"; cepa_send_ending; exit 5; }

[ $# -eq 4 ] || refuse "usage: orca-send.sh <cli> <target> <type> <nudge|no-nudge>"
case "$cepa_send_cli" in
  ''|-*|*[!A-Za-z0-9._/-]*) refuse "the cli is not a plain command name" ;;
  /*) [ "$cepa_send_cli" = "${ORCA_CLI_COMMAND:-}" ] || refuse "a cli path must equal ORCA_CLI_COMMAND" ;;
  */*) refuse "a cli path must be absolute and equal ORCA_CLI_COMMAND" ;;
esac
case "${cepa_send_cli##*/}" in
  orca-ide|orca-dev) ;;
  orca) [ "$(uname -s 2>/dev/null)" != Linux ] || refuse "bare orca on Linux is the screen reader" ;;
  *) refuse "the cli does not name an Orca CLI" ;;
esac
cepa_send_valid_target || refuse "the target is not a term_ handle, run: or dispatch: address"
case "$cepa_send_type" in
  status|question|handoff|escalation|merge_ready) ;;
  *) refuse "the type is not status, question, handoff, escalation or merge_ready" ;;
esac
case "$cepa_send_mode" in
  no-nudge) ;;
  nudge) [[ $cepa_send_target == term_* ]] || refuse "only a term_ handle is nudged" ;;
  *) refuse "the fourth argument is not nudge or no-nudge" ;;
esac
command -v "$cepa_send_cli" >/dev/null 2>&1 || refuse "$cepa_send_cli is not on PATH"

# The subject is line 1 of stdin, the body the rest. The braces keep bash's
# NUL-byte warning off the output.
IFS= read -r cepa_send_subject || [ -n "${cepa_send_subject:-}" ] || refuse "stdin has no subject line"
{ cepa_send_body=$(cat); } 2>/dev/null
[ -n "${cepa_send_subject//[[:space:]]/}" ] || refuse "the subject is empty"
[ -n "${cepa_send_body//[[:space:]]/}" ] || refuse "the body is empty"
[[ $cepa_send_subject != --* ]] || refuse "the subject starts with --, which Orca reads as a flag"
[[ $cepa_send_body != --* ]] || refuse "the body starts with --, which Orca reads as a flag"
cepa_send_bytes=$(LC_ALL=C; printf '%s%s' "$cepa_send_subject" "$cepa_send_body" | wc -c)
cepa_send_bytes=${cepa_send_bytes//[!0-9]/}
[ -n "$cepa_send_bytes" ] || refuse "the message size could not be measured"
[ "$cepa_send_bytes" -le 28000 ] \
  || refuse "subject and body are $cepa_send_bytes bytes; the limit is 28000 (WSL command-line limit)"

command -v timeout >/dev/null 2>&1 || fail "no timeout command to bound the Orca calls"
command -v python3 >/dev/null 2>&1 || fail "no python3 to read the Orca output"
cepa_send_tmp=$(mktemp -d 2>/dev/null) || fail "mktemp failed"
trap 'rm -rf "$cepa_send_tmp"' EXIT

# One Orca call, bounded at 15 seconds plus a 2-second kill, its stdout to $1.
# Sets cepa_send_rc. Retried once, only on the WSL interop error.
cepa_send_orca() {
  local out=$1 try
  shift
  for try in 1 2; do
    timeout -k 2 15 "$cepa_send_cli" "$@" </dev/null >"$out" 2>"$cepa_send_tmp/err" && { cepa_send_rc=0; return 0; }
    cepa_send_rc=$?
    [ "$try" = 1 ] && [ "$cepa_send_rc" != 124 ] && [ "$cepa_send_rc" != 137 ] || return 1
    { cepa_send_e=$(<"$cepa_send_tmp/err"); } 2>/dev/null || return 1
    [[ $cepa_send_e == *UtilAcceptVsock* && $cepa_send_e == *"accept4 failed 110"* ]] || return 1
  done
  return 1
}

cepa_send_orca "$cepa_send_tmp/send.json" orchestration send --to "$cepa_send_target" \
  --type "$cepa_send_type" --subject "$cepa_send_subject" --body "$cepa_send_body" --json

# Prints `<msg id> <recipient>`, or `FAIL <reason>`. The reason holds no Orca
# text except an error code that is a plain word.
cepa_send_got=$(python3 -I - "$cepa_send_tmp/send.json" "$cepa_send_rc" "$cepa_send_target" <<'PY' 2>/dev/null
import json, re, sys
path, rc, target = sys.argv[1], int(sys.argv[2]), sys.argv[3]
ADDR = r"(term_[0-9a-f-]{36}|run:[A-Za-z0-9_-]{1,64}|dispatch:[A-Za-z0-9_-]{1,64})"

def verdict():
    text = open(path, encoding="utf-8", errors="replace").read()
    if not text.strip():
        return "FAIL the send exited %d and printed nothing" % rc
    try:
        d = json.loads(text)
    except ValueError:
        return "FAIL the send exited %d and printed no JSON" % rc
    if not isinstance(d, dict):
        return "FAIL the send printed JSON of an unexpected shape"
    if d.get("ok") is not True:
        err = d.get("error") if isinstance(d.get("error"), dict) else {}
        code = err.get("code")
        tail = " (%s)" % code if isinstance(code, str) and re.fullmatch(r"[a-z_]{1,40}", code) else ""
        return 'FAIL Orca did not return "ok": true%s' % tail
    if rc != 0:
        return "FAIL the send exited %d" % rc
    r = d.get("result")
    m = r.get("message") if isinstance(r, dict) else None
    mid = m.get("id") if isinstance(m, dict) else None
    if not isinstance(mid, str) or not re.fullmatch(r"msg_[0-9a-f]{6,32}", mid):
        return "FAIL the reply has no result.message.id"
    to = m.get("to_handle")
    if to is None:
        to = target
    if not isinstance(to, str) or not re.fullmatch(ADDR, to):
        return "FAIL the reply names no valid recipient"
    return mid + " " + to

try:
    print(verdict())
except Exception:
    print("FAIL the send output could not be read")
PY
) || cepa_send_got=
case "$cepa_send_got" in
  '') fail "the send output could not be read" ;;
  'FAIL '*) fail "${cepa_send_got#FAIL }" ;;
esac
cepa_send_id=${cepa_send_got%% *}
cepa_send_to=${cepa_send_got#* }
[ -n "$cepa_send_to" ] && [ "$cepa_send_to" != "$cepa_send_got" ] || fail "the send output could not be read"

# THE RE-READ.
cepa_send_orca "$cepa_send_tmp/inbox.json" orchestration inbox --limit 200 --json \
  || fail "the inbox could not be re-read, so $cepa_send_id is unconfirmed"
python3 -I - "$cepa_send_tmp/inbox.json" "$cepa_send_id" "$cepa_send_to" <<'PY' >/dev/null 2>&1
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    rows = d["result"]["messages"] if d.get("ok") is True else []
    found = any(isinstance(x, dict) and x.get("id") == sys.argv[2] and x.get("to_handle") == sys.argv[3]
                for x in rows)
except Exception:
    sys.exit(2)
sys.exit(0 if found else 1)
PY
case $? in
  0) ;;
  1) fail "$cepa_send_id is not in the inbox for $cepa_send_to" ;;
  *) fail "the inbox could not be parsed, so $cepa_send_id is unconfirmed" ;;
esac

echo "Orca send stored: $cepa_send_id for $cepa_send_to"
[ "$cepa_send_mode" = nudge ] || exit 0
if [ "$cepa_send_to" != "$cepa_send_target" ]; then
  if [[ $cepa_send_to == run:* ]]; then
    echo "Orca nudge not needed: Orca stored it in $cepa_send_to, a Run mailbox it prompts"
    exit 0
  fi
  echo "Orca nudge skipped: Orca stored it for $cepa_send_to, not the target"
  echo "Ending first line: Needed from you: tell $cepa_send_to to check its Orca inbox"
  exit 1
fi
cepa_send_nudge="$(dirname "$0")/orca-nudge.sh"
if [ ! -f "$cepa_send_nudge" ]; then
  echo "Orca nudge skipped: orca-nudge.sh not found beside orca-send.sh"
  echo "Ending first line: Needed from you: tell $cepa_send_target to check its Orca inbox"
  exit 1
fi
rm -rf "$cepa_send_tmp"
trap - EXIT
bash "$cepa_send_nudge" "$cepa_send_cli" "$cepa_send_target"
cepa_send_nrc=$?
if [ "$cepa_send_nrc" -gt 3 ]; then
  echo "Orca nudge skipped: orca-nudge.sh would not start (exit $cepa_send_nrc)"
  echo "Ending first line: Needed from you: tell $cepa_send_target to check its Orca inbox"
  exit 1
fi
exit "$cepa_send_nrc"

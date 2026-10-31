#!/usr/bin/env bash
# cepa Orca send — sends one orchestration message, proves Orca stored it, and
# only then runs the guarded nudge (orca-nudge.sh, beside this file).
# `cepa:autonomy` §12b rule 1 owns WHEN a session sends and whom it nudges;
# this script owns HOW a send is counted. A send counts only when Orca returns
# `"ok": true` with `result.message.id` shaped `msg_…`, AND a re-read of the
# inbox finds that id. Nothing else counts: not exit 0, not an `"id"` field.
#
# Usage: orca-send.sh <cli> <target> <type> <nudge|no-nudge>  <stdin
#        orca-send.sh <cli> <question msg id> reply <nudge|no-nudge>  <stdin
#        orca-send.sh <cli> dispatch:ctx_<id> worker_done <succeeded|failed> task_<id>  <stdin
#   <cli>     §12a's printed `cli=` value, checked as orca-nudge.sh checks it.
#   <target>  a `term_` handle, or a `run:<id>` / `dispatch:<id>` address.
#   <type>    status, question, handoff, escalation or merge_ready.
#             Orca refuses `escalation` from a sender with no Dispatch.
#             heartbeat is not sent here: the preamble's own command sends it.
#   <nudge|no-nudge>  `nudge` for a target that is not a Run coordinator
#             (only a `term_` handle); `no-nudge` for a Run coordinator.
#   reply (§12b rule 7, punch-list L35): <target> is the question's message
#             id. stdin is the answer body only, with no subject line. With
#             `nudge`, the script nudges the handle Orca addressed the reply to
#             (the asker), never a handle the session names; a reply that Orca
#             stored in a `run:` or `dispatch:` mailbox gets no nudge.
#   worker_done (§12b rule 3, punch-list L35): a dispatched worker's final
#             report, with the preamble's Dispatch and Task IDs. It counts only
#             when Orca also returns `result.lifecycle` with that dispatch and
#             task and the action the outcome asks for (`succeeded` →
#             `completed`, `failed` → `failed`). It is never nudged.
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
#      start). The message stands. A reply also exits 1, with
#      `Orca reply misaddressed: …` in place of `Orca send stored` and no
#      nudge, when it came back to this session (ORCA_TERMINAL_HANDLE): Orca
#      addressed it to that handle, or the message it names is in the
#      re-read window with this session as its sender. The asker never gets
#      it.
#   4  Orca send refused: <reason>   — an argument failed its check; no call.
#   5  Orca send failed: no message stored — <reason>
#      Orca send failed: not proven stored — <reason>   — Orca returned
#      `"ok": true` and a msg_ id, but the recipient, the reply's thread or
#      the worker_done lifecycle did not match. It may be stored: a rerun can
#      duplicate it.
#   On 4 and 5 it then prints one line about the alert file (THE ALERT,
#   below): `Orca alert recorded: <file> (orca-health.sh reports it)`, or
#   `Orca alert not recorded: <reason>`. Last, it prints:
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
# never after a timeout. The retry is the same call with the same
# `--retry-request` id, which the script chose, so if the first try stored,
# Orca replays its result (same `msg_…`, `replayed: true`) and stores nothing
# more (measured L35, Orca 1.4.245). Different input under the same id is
# refused (`request_mismatch`).
#
# TIME BUDGET. Each Orca call is bounded at 15 s plus a 2 s kill, so with its
# retry a call takes at most 34 s: the send and the re-read take at most 68 s,
# plus the nudge's own bound (about 220 s, its header): about 290 s in all.
# A session that runs the block again after a failure makes a new request id,
# so that second run can still store a duplicate (§12b rule 1 accepts it).
#
# STATED LIMITS:
#   - The misaddressed-reply check needs ORCA_TERMINAL_HANDLE. Unset, a reply
#     Orca stored in this session's own `dispatch:` mailbox reads as stored
#     unless the message it names is in the 200-row window.
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
cepa_send_task=${5-}
cepa_send_outcome=

cepa_send_valid_target() {
  [[ $cepa_send_target =~ ^(term_[0-9a-f-]{36}|run:[A-Za-z0-9_-]{1,64}|dispatch:[A-Za-z0-9_-]{1,64})$ ]]
}
cepa_send_ending() {
  if [ "$cepa_send_type" = reply ]; then
    if [[ $cepa_send_target =~ ^msg_[0-9a-f]{6,32}$ ]]; then
      echo "Ending first line: Needed from you: paste the block below into the session that asked $cepa_send_target"
    else
      echo "Ending first line: Needed from you: paste the block below into the session that asked"
    fi
  elif [ "$cepa_send_type" = worker_done ]; then
    echo "Ending first line: Needed from you: paste the block below into the Run coordinator"
  elif cepa_send_valid_target; then
    echo "Ending first line: Needed from you: paste the block below into $cepa_send_target"
  else
    echo "Ending first line: Needed from you: paste the block below into the target session"
  fi
}
# THE ALERT (punch-list L34). Exit 4 and exit 5 print only into the sending
# session's own output, so a session that then ends its turn tells no one.
# Each of them also writes one alert file, which orca-health.sh (beside this
# script) reads at a coordinator's per-turn check (§12b rule 8) and turns into
# an operator question. One file per failure, never an append, so concurrent
# senders never share a write. Every field is checked or replaced before it is
# written; no Orca text goes in but the plain-word error code that is already
# in the reason. The directory is CEPA_ORCA_ALERT_DIR, else
# ${XDG_STATE_HOME:-$HOME/.local/state}/cepa/orca-alerts: on this machine,
# never in a repo. A file that cannot be written prints
# `Orca alert not recorded: <reason>`, and the exit code stays the same.
cepa_send_alert() {
  local kind=$1 why=$2 dir t repo wt me tgt typ tmp
  dir=${CEPA_ORCA_ALERT_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/cepa/orca-alerts}
  [[ $dir == /* ]] || { echo "Orca alert not recorded: the alert directory is not an absolute path"; return 0; }
  mkdir -p "$dir" 2>/dev/null || { echo "Orca alert not recorded: the alert directory could not be made"; return 0; }
  t=$(date +%s 2>/dev/null) || t=
  [[ $t =~ ^[0-9]{1,12}$ ]] || t=0
  repo=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || repo=
  case "$repo" in /*/.git) repo=${repo%/.git} repo=${repo##*/} ;; *) repo=unknown ;; esac
  [[ $repo =~ ^[A-Za-z0-9._@-]{1,100}$ ]] || repo=unknown
  wt=$(git rev-parse --show-toplevel 2>/dev/null) || wt=
  wt=${wt##*/}
  [[ $wt =~ ^[A-Za-z0-9._@-]{1,100}$ ]] || wt=unknown
  me=${ORCA_TERMINAL_HANDLE:-}
  [[ $me =~ ^term_[0-9a-f-]{36}$ ]] || me=unknown
  tgt=$cepa_send_target
  [[ $tgt =~ ^(msg_[0-9a-f]{6,32}|term_[0-9a-f-]{36}|run:[A-Za-z0-9_-]{1,64}|dispatch:[A-Za-z0-9_-]{1,64})$ ]] || tgt=invalid
  typ=$cepa_send_type
  [[ $typ =~ ^[a-z_]{1,20}$ ]] || typ=invalid
  why=$(LC_ALL=C; printf '%s' "${why:0:300}" | tr -c ' -~' '?')
  tmp=$(mktemp "$dir/.new.XXXXXXXX" 2>/dev/null) || { echo "Orca alert not recorded: mktemp failed in the alert directory"; return 0; }
  if printf '%s\n' "cepa-orca-alert 1" "time=$t" "kind=$kind" "repo=$repo" "worktree=$wt" \
      "sender=$me" "target=$tgt" "type=$typ" "reason=$why" >"$tmp" 2>/dev/null \
      && mv -f "$tmp" "$dir/$t-${tmp##*.new.}.alert" 2>/dev/null; then
    echo "Orca alert recorded: $t-${tmp##*.new.}.alert (orca-health.sh reports it)"
  else
    rm -f "$tmp" 2>/dev/null
    echo "Orca alert not recorded: the alert file could not be written"
  fi
}
refuse() { echo "Orca send refused: $1"; cepa_send_alert send_refused "$1"; cepa_send_ending; exit 4; }
fail() { echo "Orca send failed: no message stored — $1"; cepa_send_alert send_failed "$1"; cepa_send_ending; exit 5; }
# Orca returned "ok": true and a msg_ id, but the reply did not match: the
# message may be stored, so the line never says it stored nothing.
unproven() { echo "Orca send failed: not proven stored — $1"; cepa_send_alert send_unproven "$1"; cepa_send_ending; exit 5; }

[ $# -eq 4 ] || { [ $# -eq 5 ] && [ "$cepa_send_type" = worker_done ]; } \
  || refuse "usage: orca-send.sh <cli> <target> <type> <nudge|no-nudge>, or <cli> dispatch:<id> worker_done <outcome> <task id>"
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
case "$cepa_send_type" in
  status|question|handoff|escalation|merge_ready)
    cepa_send_valid_target || refuse "the target is not a term_ handle, run: or dispatch: address" ;;
  reply)
    [[ $cepa_send_target =~ ^msg_[0-9a-f]{6,32}$ ]] || refuse "a reply's target is not a msg_ message id" ;;
  worker_done)
    [[ $cepa_send_target =~ ^dispatch:ctx_[0-9a-f]{6,32}$ ]] || refuse "a worker_done target is not dispatch:ctx_<id>"
    [ $# -eq 5 ] || refuse "worker_done takes <outcome> <task id> after the type"
    [[ $cepa_send_task =~ ^task_[0-9a-f]{6,32}$ ]] || refuse "the task id is not task_<id>"
    case "$cepa_send_mode" in
      succeeded) cepa_send_outcome=completed ;;
      failed) cepa_send_outcome=failed ;;
      *) refuse "the worker_done outcome is not succeeded or failed" ;;
    esac
    cepa_send_outcome_arg=$cepa_send_mode
    cepa_send_mode=no-nudge ;;
  *) refuse "the type is not status, question, handoff, escalation, merge_ready, reply or worker_done" ;;
esac
case "$cepa_send_mode" in
  no-nudge) ;;
  nudge) [[ $cepa_send_target == term_* || $cepa_send_type == reply ]] || refuse "only a term_ handle is nudged" ;;
  *) refuse "the fourth argument is not nudge or no-nudge" ;;
esac
command -v "$cepa_send_cli" >/dev/null 2>&1 || refuse "$cepa_send_cli is not on PATH"

# The subject is line 1 of stdin, the body the rest. The braces keep bash's
# NUL-byte warning off the output.
# A reply has no subject: all of stdin is its body.
if [ "$cepa_send_type" = reply ]; then
  cepa_send_subject=
else
  IFS= read -r cepa_send_subject || [ -n "${cepa_send_subject:-}" ] || refuse "stdin has no subject line"
fi
{ cepa_send_body=$(cat); } 2>/dev/null
if [ "$cepa_send_type" != reply ]; then
  [ -n "${cepa_send_subject//[[:space:]]/}" ] || refuse "the subject is empty"
  [[ $cepa_send_subject != --* ]] || refuse "the subject starts with --, which Orca reads as a flag"
fi
[ -n "${cepa_send_body//[[:space:]]/}" ] || refuse "the body is empty"
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

# Every call carries a request id the script chose, so the vsock retry
# replays the first try instead of storing a second message (measured L35:
# the same --retry-request returned the same msg_ id with `replayed: true`).
cepa_send_req=$(python3 -I -c 'import uuid; print(uuid.uuid4())' 2>/dev/null)
[[ $cepa_send_req =~ ^[0-9a-f-]{36}$ ]] || fail "no request id could be made"
case "$cepa_send_type" in
  reply)
    cepa_send_orca "$cepa_send_tmp/send.json" orchestration reply --id "$cepa_send_target" \
      --body "$cepa_send_body" --retry-request "$cepa_send_req" --json ;;
  worker_done)
    cepa_send_orca "$cepa_send_tmp/send.json" orchestration send --type worker_done \
      --subject "$cepa_send_subject" --body "$cepa_send_body" --task-id "$cepa_send_task" \
      --dispatch-id "${cepa_send_target#dispatch:}" --outcome "$cepa_send_outcome_arg" \
      --retry-request "$cepa_send_req" --json ;;
  *)
cepa_send_orca "$cepa_send_tmp/send.json" orchestration send --to "$cepa_send_target" \
  --type "$cepa_send_type" --subject "$cepa_send_subject" --body "$cepa_send_body" \
  --retry-request "$cepa_send_req" --json ;;
esac

# Prints `<msg id> <recipient>`, or `FAIL <reason>`. The reason holds no Orca
# text except an error code that is a plain word.
cepa_send_got=$(python3 -I - "$cepa_send_tmp/send.json" "$cepa_send_rc" "$cepa_send_target" \
  "$cepa_send_type" "$cepa_send_task" "$cepa_send_outcome" <<'PY' 2>/dev/null
import json, re, sys
path, rc, target = sys.argv[1], int(sys.argv[2]), sys.argv[3]
typ, task, action = sys.argv[4], sys.argv[5], sys.argv[6]
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
    if typ == "reply":
        # A reply has no target handle to fall back on, and must answer the
        # question it names.
        if m.get("thread_id") != target:
            return "UNPROVEN the reply is not threaded on %s" % target
    elif to is None:
        to = target
    if typ == "worker_done":
        lc = r.get("lifecycle")
        if not isinstance(lc, dict) or lc.get("action") != action \
                or lc.get("dispatchId") != target[len("dispatch:"):] or lc.get("taskId") != task:
            return "UNPROVEN Orca did not record the dispatch as %s" % action
    if not isinstance(to, str) or not re.fullmatch(ADDR, to):
        return "UNPROVEN the reply names no valid recipient"
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
  'UNPROVEN '*) unproven "${cepa_send_got#UNPROVEN }" ;;
esac
cepa_send_id=${cepa_send_got%% *}
cepa_send_to=${cepa_send_got#* }
[ -n "$cepa_send_to" ] && [ "$cepa_send_to" != "$cepa_send_got" ] || fail "the send output could not be read"

# THE RE-READ.
cepa_send_orca "$cepa_send_tmp/inbox.json" orchestration inbox --limit 200 --json \
  || fail "the inbox could not be re-read, so $cepa_send_id is unconfirmed"
cepa_send_q=
[ "$cepa_send_type" = reply ] && cepa_send_q=$cepa_send_target
python3 -I - "$cepa_send_tmp/inbox.json" "$cepa_send_id" "$cepa_send_to" "$cepa_send_q" \
  "${ORCA_TERMINAL_HANDLE:-}" <<'PY' >/dev/null 2>&1
import json, re, sys
try:
    d = json.load(open(sys.argv[1]))
    rows = d["result"]["messages"] if d.get("ok") is True else []
    found = any(isinstance(x, dict) and x.get("id") == sys.argv[2] and x.get("to_handle") == sys.argv[3]
                for x in rows)
    # A reply answers the sender of the message it names. It came back here
    # when Orca addressed it to this session's handle, or when that message's
    # row is in the window and this session sent it.
    q, me = sys.argv[4], sys.argv[5]
    if not re.fullmatch(r"term_[0-9a-f-]{36}", me):
        me = ""
    mine = bool(q and me) and (sys.argv[3] == me or any(
        isinstance(x, dict) and x.get("id") == q and x.get("from_handle") == me for x in rows))
except Exception:
    sys.exit(2)
sys.exit(3 if found and mine else 0 if found else 1)
PY
case $? in
  0) ;;
  3) echo "Orca reply misaddressed: $cepa_send_id stored for $cepa_send_to, but $cepa_send_target was sent by this session, so the reply came back to it"
     echo "Ending first line: Needed from you: check which session asked $cepa_send_target"
     exit 1 ;;
  1) fail "$cepa_send_id is not in the inbox for $cepa_send_to" ;;
  *) fail "the inbox could not be parsed, so $cepa_send_id is unconfirmed" ;;
esac

echo "Orca send stored: $cepa_send_id for $cepa_send_to"
if [ "$cepa_send_type" = reply ]; then
  [ "$cepa_send_mode" = nudge ] || exit 0
  if [[ $cepa_send_to != term_* ]]; then
    echo "Orca nudge not needed: Orca stored it in $cepa_send_to, a mailbox Orca delivers"
    exit 0
  fi
  cepa_send_target=$cepa_send_to
fi
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

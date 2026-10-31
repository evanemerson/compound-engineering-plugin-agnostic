#!/usr/bin/env bash
# cepa Orca health — a coordinator's per-turn check for a failed send and a
# hung session (punch-list L34). `cepa:autonomy` §12b rule 8 owns WHEN it runs
# and what the session does with an alert; this script owns WHAT counts as one.
# It reads; it never sends, nudges, stops or releases anything.
#
# Usage: orca-health.sh <cli>                 report alerts
#        orca-health.sh <cli> ack <key>...    mark alerts as shown to the operator
#   <cli>  §12a's printed `cli=` value, checked as orca-send.sh checks it.
#   <key>  the text between `ORCA alert: ` and ` — ` on an alert line.
#
# Prints one `ORCA alert: <key> — <text>` line per alert not yet acked, then a
# summary line. Exit codes:
#   0  `ORCA health: ok — …` (no alert).
#   1  alerts, then `ORCA health: <n> alert(s) — ask the operator (§12b rule 8)`
#      and `Ending first line: Needed from you: check the Orca alerts below`.
#   4  `ORCA health refused: <reason>` — an argument failed its check.
#   An ack prints `ORCA ack: <key>` per key and exits 0, or 4 on a bad key.
#
# WHAT IS AN ALERT. Each source and bound below was measured on Orca 1.4.245
# (WSL), 2026-10-31, on Run run_bf28fea0ea31's 16 settled dispatches and on
# probe terminals in the `roles` worktree (PR body, punch-list L34):
#   send-failed:<file>   orca-send.sh exit 4 or 5 wrote an alert file for this
#                        repo (or for no known repo). Orca has no record of a
#                        send it never stored, so this file is the only trace.
#   exited:<dispatch>    a live dispatch whose liveness verdict is `exited`:
#                        Orca's positive proof the agent stopped, and no
#                        worker_done came.
#   waiting:<dispatch>   a live dispatch whose observation.agentWait is set:
#                        the worker is parked on a prompt only a human can
#                        answer (Orca: "a waiting worker is healthy, not
#                        failed", but nobody sees it unless told).
#   stale:<dispatch>:<last heartbeat>  no heartbeat for 30 minutes or more
#                        (dispatch.lastHeartbeatAt, else dispatchedAt). The
#                        longest gap a healthy worker on that Run left was
#                        20.5 minutes, against a 5-minute cadence. Orca's own
#                        liveness never reads heartbeats: an agent probe that
#                        sent none stayed `live` with no attention category.
#                        Not raised while the dispatch has attention `input`
#                        (a pending `ask` is itself a liveness signal) or is
#                        already `exited` or `waiting`.
#   long:<dispatch>      dispatched 180 minutes or more ago with no
#                        worker_done. The longest settled dispatch took 55.
#   question:<msg>       a `question` to this Run's mailbox with no reply
#                        threaded on it after 10 minutes (an `ask` waits 10 by
#                        default). Orca shows it as attention `input`.
#   awaited:<msg>        a `question` this session sent (from_handle is
#                        ORCA_TERMINAL_HANDLE) with no reply after 30 minutes.
#   orca-unreadable:<verb>:<hour>  an Orca call failed, so the Run's health is
#                        unknown. Its key carries the UTC hour, so an ack
#                        silences it for that hour only.
# NOT an alert: liveness `unverifiable`. Orca's guide calls it absence, never
# proof, and every settled shell or released worker reads that way.
# An `escalation` sets no attention category (measured), so it is read from
# the inbox by rule 5, not here.
#
# ACKS live in <alert dir>/acked/: an alert file moves there, and any other
# key is an empty marker file. A stale key carries the heartbeat time, so a
# worker that beats again and then goes quiet again alerts again.
#
# STATED LIMITS:
#   - It runs only when the coordinator runs a turn. An idle coordinator runs
#     none (rule 8's limit), so an idle Run is still unwatched.
#   - The alert files are on this machine. A send from another machine or
#     another Orca host leaves no file here.
#   - Its Run is the one `run-current` reports for this terminal. A session
#     with no bound Run gets only the file, question and awaited alerts.
#   - The inbox window is 200 rows, newest first (the whole store was 245 rows
#     on 2026-10-31). An older question is not seen.
#   - The bounds are fixed here, from one Run's history. A worker with a
#     longer honest gap will alert; that costs one question, a missed hang
#     costs the session.
set -u

cepa_h_cli=${1-}
cepa_h_dir=${CEPA_ORCA_ALERT_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/cepa/orca-alerts}

refuse() { echo "ORCA health refused: $1"; exit 4; }

[ $# -ge 1 ] || refuse "usage: orca-health.sh <cli> [ack <key>...]"
case "$cepa_h_cli" in
  ''|-*|*[!A-Za-z0-9._/-]*) refuse "the cli is not a plain command name" ;;
  /*) [ "$cepa_h_cli" = "${ORCA_CLI_COMMAND:-}" ] || refuse "a cli path must equal ORCA_CLI_COMMAND" ;;
  */*) refuse "a cli path must be absolute and equal ORCA_CLI_COMMAND" ;;
esac
case "${cepa_h_cli##*/}" in
  orca-ide|orca-dev) ;;
  orca) [ "$(uname -s 2>/dev/null)" != Linux ] || refuse "bare orca on Linux is the screen reader" ;;
  *) refuse "the cli does not name an Orca CLI" ;;
esac
[[ $cepa_h_dir == /* ]] || refuse "the alert directory is not an absolute path"

if [ $# -ge 2 ]; then
  [ "$2" = ack ] && [ $# -ge 3 ] || refuse "usage: orca-health.sh <cli> [ack <key>...]"
  shift 2
  for k in "$@"; do
    [[ $k =~ ^(send-failed|exited|waiting|stale|long|question|awaited|orca-unreadable):[A-Za-z0-9_.:-]{1,120}$ ]] \
      || refuse "not an alert key: the key holds a character outside [A-Za-z0-9_.:-] or names no alert kind"
    [[ $k != *..* ]] || refuse "not an alert key: the key holds .."
  done
  mkdir -p "$cepa_h_dir/acked" 2>/dev/null || refuse "the alert directory could not be made"
  for k in "$@"; do
    if [[ $k == send-failed:* ]]; then
      [ ! -f "$cepa_h_dir/${k#send-failed:}" ] || mv -f "$cepa_h_dir/${k#send-failed:}" "$cepa_h_dir/acked/" 2>/dev/null
    else
      : >"$cepa_h_dir/acked/$k" 2>/dev/null
    fi
    echo "ORCA ack: $k"
  done
  exit 0
fi

command -v "$cepa_h_cli" >/dev/null 2>&1 || refuse "$cepa_h_cli is not on PATH"
command -v timeout >/dev/null 2>&1 || refuse "no timeout command to bound the Orca calls"
command -v python3 >/dev/null 2>&1 || refuse "no python3 to read the Orca output"
cepa_h_tmp=$(mktemp -d 2>/dev/null) || refuse "mktemp failed"
trap 'rm -rf "$cepa_h_tmp"' EXIT

# One Orca call, bounded at 15 seconds plus a 2-second kill, its stdout to $1.
# Retried once, only on the WSL interop error (orca-send.sh's rule).
cepa_h_orca() {
  local out=$1 try rc e
  shift
  for try in 1 2; do
    timeout -k 2 15 "$cepa_h_cli" "$@" </dev/null >"$out" 2>"$cepa_h_tmp/err" && return 0
    rc=$?
    [ "$try" = 1 ] && [ "$rc" != 124 ] && [ "$rc" != 137 ] || return 1
    { e=$(<"$cepa_h_tmp/err"); } 2>/dev/null || return 1
    [[ $e == *UtilAcceptVsock* && $e == *"accept4 failed 110"* ]] || return 1
  done
  return 1
}

cepa_h_now=$(date +%s 2>/dev/null) || cepa_h_now=
[[ $cepa_h_now =~ ^[0-9]{1,12}$ ]] || refuse "date gave no clock"
cepa_h_repo=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || cepa_h_repo=
case "$cepa_h_repo" in /*/.git) cepa_h_repo=${cepa_h_repo%/.git} cepa_h_repo=${cepa_h_repo##*/} ;; *) cepa_h_repo=unknown ;; esac

# Each call's result is a file; a failed call leaves a marker the reader turns
# into an orca-unreadable alert.
cepa_h_orca "$cepa_h_tmp/run.json" orchestration run-current --json || : >"$cepa_h_tmp/run.fail"
cepa_h_run=
[ -f "$cepa_h_tmp/run.fail" ] || cepa_h_run=$(python3 -I -c '
import json, re, sys
d = json.load(open(sys.argv[1]))
r = (d.get("result") or {}).get("run") if d.get("ok") is True else None
i = r.get("id") if isinstance(r, dict) else None
print(i if isinstance(i, str) and re.fullmatch(r"run_[A-Za-z0-9_-]{1,64}", i) else "")
' "$cepa_h_tmp/run.json" 2>/dev/null) || : >"$cepa_h_tmp/run.fail"
mkdir -p "$cepa_h_tmp/show"
if [ -n "$cepa_h_run" ]; then
  if cepa_h_orca "$cepa_h_tmp/workers.json" orchestration worker-list --run "$cepa_h_run" --json; then
    # The live dispatches, at most 20, each read with worker-show.
    for d in $(python3 -I -c '
import json, re, sys
d = json.load(open(sys.argv[1]))
rows = d["result"]["workers"] if d.get("ok") is True else []
ids = [w.get("dispatchId") for w in rows if isinstance(w, dict)
       and (w.get("projection") or {}).get("outcome") == "in_progress"]
print(" ".join(i for i in ids[:20] if isinstance(i, str) and re.fullmatch(r"ctx_[0-9a-f]{6,32}", i)))
' "$cepa_h_tmp/workers.json" 2>/dev/null); do
      cepa_h_orca "$cepa_h_tmp/show/$d.json" orchestration worker-show --dispatch "$d" --json \
        || : >"$cepa_h_tmp/show/$d.fail"
    done
  else
    : >"$cepa_h_tmp/workers.fail"
  fi
fi
cepa_h_orca "$cepa_h_tmp/inbox.json" orchestration inbox --limit 200 --json || : >"$cepa_h_tmp/inbox.fail"

python3 -I - "$cepa_h_tmp" "$cepa_h_dir" "$cepa_h_now" "$cepa_h_run" "$cepa_h_repo" \
  "${ORCA_TERMINAL_HANDLE:-}" <<'PY'
import calendar, json, os, re, sys, time
tmp, adir, now, run, repo, me = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5], sys.argv[6]
HB_STALE, RUN_LONG, Q_WAIT, AWAIT = 30, 180, 10, 30   # minutes
SAFE = re.compile(r"[A-Za-z0-9_.:@-]{1,120}")
if not re.fullmatch(r"term_[0-9a-f-]{36}", me):
    me = ""
acked_dir = os.path.join(adir, "acked")
acked = set(os.listdir(acked_dir)) if os.path.isdir(acked_dir) else set()
alerts = []

def alert(key, text):
    if SAFE.fullmatch(key) and key not in acked:
        alerts.append((key, text))

def ts(s):
    # "2026-10-31T20:36:22Z" or "2026-10-31 20:35:34", both UTC.
    if not isinstance(s, str):
        return None
    m = re.fullmatch(r"(\d{4})-(\d\d)-(\d\d)[T ](\d\d):(\d\d):(\d\d)(?:\.\d+)?Z?", s)
    return calendar.timegm(tuple(int(x) for x in m.groups()) + (0, 0, 0)) if m else None

def mins(t):
    return (now - t) // 60

def hhmm(t):
    return time.strftime("%H:%M UTC", time.gmtime(t))

def load(name):
    p = os.path.join(tmp, name)
    if os.path.exists(p[:-5] + ".fail"):
        return None
    try:
        d = json.load(open(p))
    except Exception:
        return None
    return d if isinstance(d, dict) and d.get("ok") is True else None

hour = now // 3600
def unreadable(verb):
    alert("orca-unreadable:%s:%d" % (verb, hour),
          "Orca %s failed or was not ok, so this Run's health is unknown" % verb.replace("-", " "))

# 1. Alert files from orca-send.sh.
FIELD = {"kind": r"send_(refused|failed|unproven)", "time": r"\d{1,12}", "repo": r"[A-Za-z0-9._@-]{1,100}",
         "worktree": r"[A-Za-z0-9._@-]{1,100}", "sender": r"term_[0-9a-f-]{36}|unknown",
         "target": r"(term_[0-9a-f-]{36}|run:[A-Za-z0-9_-]{1,64}|dispatch:[A-Za-z0-9_-]{1,64}|msg_[0-9a-f]{6,32})|invalid",
         "type": r"[a-z_]{1,20}", "reason": r"[ -~]{0,300}"}
try:
    names = sorted(os.listdir(adir))
except OSError:
    names = []
for n in names:
    if not re.fullmatch(r"\d{1,12}-[A-Za-z0-9]{1,20}\.alert", n):
        continue
    try:
        lines = open(os.path.join(adir, n), encoding="ascii").read().splitlines()
    except Exception:
        alert("send-failed:" + n, "an alert file this script cannot read: %s" % n)
        continue
    f = dict(l.split("=", 1) for l in lines[1:] if "=" in l)
    if lines[:1] != ["cepa-orca-alert 1"] or any(not re.fullmatch(FIELD[k], f.get(k, "")) for k in FIELD):
        alert("send-failed:" + n, "an alert file in an unknown shape: %s" % n)
        continue
    if f["repo"] not in (repo, "unknown"):
        continue
    what = {"send_refused": "was refused before any Orca call",
            "send_failed": "stored nothing",
            "send_unproven": "was not proven stored"}[f["kind"]]
    alert("send-failed:" + n, "%s: a %s send to %s %s (%s), at %s, from %s" % (
        f["worktree"], f["type"], f["target"], what, f["reason"], hhmm(int(f["time"])), f["sender"]))

# 2. The bound Run's live dispatches.
if os.path.exists(os.path.join(tmp, "run.fail")):
    unreadable("run-current")
if run:
    if load("workers.json") is None:
        unreadable("worker-list")
    for n in sorted(os.listdir(os.path.join(tmp, "show"))):
        if not n.endswith(".fail"):
            continue
        unreadable("worker-show")
    for n in sorted(os.listdir(os.path.join(tmp, "show"))):
        if not n.endswith(".json"):
            continue
        d = load(os.path.join("show", n))
        if d is None:
            unreadable("worker-show")
            continue
        r = d.get("result") or {}
        disp = r.get("dispatch") or {}
        did = disp.get("id")
        if not (isinstance(did, str) and re.fullmatch(r"ctx_[0-9a-f]{6,32}", did)) or did != n[:-5]:
            unreadable("worker-show")
            continue
        p = r.get("projection") or {}
        if p.get("outcome") != "in_progress":
            continue
        cats = (p.get("attention") or {}).get("categories") or []
        verdict = (p.get("liveness") or {}).get("verdict")
        wait = (r.get("observation") or {}).get("agentWait")
        handle = (r.get("worker") or {}).get("agentTerminalHandle") or disp.get("assigneeHandle")
        who = did + (" (%s)" % handle if isinstance(handle, str) and re.fullmatch(r"term_[0-9a-f-]{36}", handle) else "")
        if verdict == "exited":
            alert("exited:" + did, "worker %s exited with no worker_done" % who)
            continue
        if wait:
            alert("waiting:" + did, "worker %s is parked on a prompt only a human can answer" % who)
            continue
        start = ts(disp.get("dispatchedAt"))
        hb = ts(disp.get("lastHeartbeatAt"))
        last = hb if hb is not None else start
        if "input" not in cats and last is not None and mins(last) >= HB_STALE:
            alert("stale:%s:%d" % (did, last), "worker %s sent no heartbeat for %d minutes (bound %d)%s" % (
                who, mins(last), HB_STALE, "" if hb is not None else ", none since its dispatch"))
        if start is not None and mins(start) >= RUN_LONG:
            alert("long:" + did, "worker %s has run %d minutes with no worker_done (bound %d)" % (
                who, mins(start), RUN_LONG))

# 3. Questions, from the inbox.
inbox = load("inbox.json")
if inbox is None:
    unreadable("inbox")
else:
    rows = [x for x in (inbox.get("result") or {}).get("messages") or [] if isinstance(x, dict)]
    answered = {x.get("thread_id") for x in rows if x.get("thread_id") and x.get("thread_id") != x.get("id")}
    for x in rows:
        mid, t = x.get("id"), ts(x.get("created_at"))
        if x.get("type") != "question" or t is None or mid in answered \
                or not (isinstance(mid, str) and re.fullmatch(r"msg_[0-9a-f]{6,32}", mid)):
            continue
        if run and x.get("to_handle") == "run:" + run and mins(t) >= Q_WAIT:
            alert("question:" + mid, "worker question %s has waited %d minutes for your reply (bound %d)" % (
                mid, mins(t), Q_WAIT))
        elif me and x.get("from_handle") == me and mins(t) >= AWAIT:
            to = x.get("to_handle")
            to = to if isinstance(to, str) and SAFE.fullmatch(to) else "its recipient"
            alert("awaited:" + mid, "your question %s to %s has had no reply for %d minutes (bound %d)" % (
                mid, to, mins(t), AWAIT))

seen = set()
for k, text in alerts:
    if k in seen:
        continue
    seen.add(k)
    print("ORCA alert: %s — %s" % (k, text))
if seen:
    print("ORCA health: %d alert%s — ask the operator (§12b rule 8)" % (len(seen), "" if len(seen) == 1 else "s"))
    print("Ending first line: Needed from you: check the Orca alerts below")
    sys.exit(1)
print("ORCA health: ok — %s" % ("Run %s checked" % run if run else "no bound Run; alert files and questions checked"))
PY
cepa_h_rc=$?
[ "$cepa_h_rc" -le 1 ] || { echo "ORCA health failed: the reader exited $cepa_h_rc"; echo "Ending first line: Needed from you: check this session's Orca health by hand"; exit 1; }
exit "$cepa_h_rc"

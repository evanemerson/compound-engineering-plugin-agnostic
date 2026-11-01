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
#   0  `ORCA health: ok — …` (no alert), or `ORCA health: unknown — …` (only
#      acked orca-unreadable alerts: still not read, already asked).
#   1  alerts, then `ORCA health: <n> alert(s) — ask the operator (§12b rule 8)`
#      and `Ending first line: Needed from you: check the Orca alerts below`.
#   4  `ORCA health refused: <reason>` — an argument failed its check.
#   An ack prints `ORCA ack: <key>` per key and exits 0; 1 when a marker could
#   not be written or an alert file is gone; 4 on a bad key.
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
#   orca-unreadable:<what>:<hour>  an Orca call failed, timed out, was not
#                        started (THE TIME BOUND, below), or returned a shape
#                        this reader does not know; or the alert directory
#                        could not be read; or more than 20 dispatches are
#                        live or worker-list has more pages. The Run's health
#                        is then unknown. Its key carries the UTC hour, so an
#                        ack silences it for that hour only, and while it is
#                        acked the summary reads `ORCA health: unknown — …`,
#                        never `ok`.
#   A reader crash prints `ORCA health failed: the reader crashed (<type>)`
#   and then an orca-unreadable:reader alert, never a bare exit 1.
# WHOSE ALERTS. A linked worktree's coordinator sees only alert files its own
# worktree wrote; the main checkout's sees the whole repo's; with no known
# repo on either side the file is shown. The ok line counts the files it did
# not show. Acks are per worktree (<alert dir>/acked/<worktree>/), so one
# coordinator's ack never hides an alert from another.
# THE REASON. An alert file's reason is shown only when it matches one that
# orca-send.sh writes (REASONS, below); any other text prints as
# `an unrecognised reason`, so a file another process planted cannot put
# words into the operator question (§12c). The gate checks that every literal
# reason in orca-send.sh is in that list.
# NOT an alert: liveness `unverifiable`. Orca's guide calls it absence, never
# proof, and every settled shell or released worker reads that way.
# An `escalation` sets no attention category (measured), so it is read from
# the inbox by rule 5, not here.
#
# ACKS are empty marker files named by key in <alert dir>/acked/<worktree>/;
# an alert file stays where it is. `ORCA ack:` prints only after the marker
# is written; a send-failed key with no such file prints `ORCA ack failed`.
# A stale key carries the heartbeat time and a waiting key the UTC hour, so a
# worker that beats again and goes quiet again, or stays parked, alerts again.
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
#     longer honest gap will alert: one blocked on a long background job (the
#     mutation sweep runs ~43 min) or in `check --wait` sends no heartbeat and
#     has no `input` category. That costs one question; a missed hang costs
#     the session.
#   - A send that failed and then succeeded on a rerun still leaves its alert
#     file; the operator acks it.
#   - `now` is this machine's clock and the Orca times are read as UTC (both
#     formats agreed on the measured Run). A skewed WSL clock shifts every
#     age; a time in the future reads as age 0, not as an alert.
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

# This checkout: the repo (as rule 6 names it), the worktree's directory name,
# and whether it is the main checkout. A linked worktree's coordinator sees
# only its own worktree's alert files; the main checkout's sees the repo's.
# One git call: its three lines are the common dir, the git dir and the top.
cepa_h_common= cepa_h_gitdir= cepa_h_wt=
{ IFS= read -r cepa_h_common && IFS= read -r cepa_h_gitdir && IFS= read -r cepa_h_wt; } < <(
  git rev-parse --path-format=absolute --git-common-dir --git-dir --show-toplevel 2>/dev/null) || :
case "$cepa_h_common" in /*/.git) cepa_h_repo=${cepa_h_common%/.git} cepa_h_repo=${cepa_h_repo##*/} ;; *) cepa_h_repo=unknown ;; esac
[[ $cepa_h_repo =~ ^[A-Za-z0-9._@-]{1,100}$ ]] || cepa_h_repo=unknown
cepa_h_wt=${cepa_h_wt##*/}
[[ $cepa_h_wt =~ ^[A-Za-z0-9._@-]{1,100}$ ]] || cepa_h_wt=unknown
cepa_h_main=0
[ -n "$cepa_h_gitdir" ] && [ "$cepa_h_gitdir" = "$cepa_h_common" ] && cepa_h_main=1
# Acks are this worktree's own: one coordinator's ack never hides an alert
# from another.
cepa_h_acked="$cepa_h_dir/acked/$cepa_h_wt"

if [ $# -ge 2 ]; then
  [ "$2" = ack ] && [ $# -ge 3 ] || refuse "usage: orca-health.sh <cli> [ack <key>...]"
  shift 2
  for k in "$@"; do
    [[ $k =~ ^(send-failed:[0-9]{1,12}-[A-Za-z0-9]{1,20}\.alert|(exited|long|question|awaited):[A-Za-z0-9_]{1,64}|(waiting|stale):[A-Za-z0-9_]{1,64}:[0-9]{1,12}|orca-unreadable:[a-z-]{1,20}:[0-9]{1,12})$ ]] \
      || refuse "not an alert key: $(printf '%s' "${k:0:80}" | tr -c 'A-Za-z0-9_.:-' '?')"
  done
  mkdir -p "$cepa_h_acked" 2>/dev/null || { echo "ORCA ack failed: the ack directory could not be made"; exit 1; }
  cepa_h_bad=0
  for k in "$@"; do
    if [[ $k == send-failed:* ]] && [ ! -f "$cepa_h_dir/${k#send-failed:}" ]; then
      echo "ORCA ack failed: $k — no such alert file"; cepa_h_bad=1
    elif : >"$cepa_h_acked/$k" 2>/dev/null; then
      echo "ORCA ack: $k"
    else
      echo "ORCA ack failed: $k — the ack marker could not be written"; cepa_h_bad=1
    fi
  done
  exit "$cepa_h_bad"
fi

command -v "$cepa_h_cli" >/dev/null 2>&1 || refuse "$cepa_h_cli is not on PATH"
command -v timeout >/dev/null 2>&1 || refuse "no timeout command to bound the Orca calls"
command -v python3 >/dev/null 2>&1 || refuse "no python3 to read the Orca output"
cepa_h_now=$(date +%s 2>/dev/null) || cepa_h_now=
[[ $cepa_h_now =~ ^[0-9]{1,12}$ ]] || refuse "date gave no clock"
cepa_h_tmp=$(mktemp -d 2>/dev/null) || refuse "mktemp failed"
trap 'rm -rf "$cepa_h_tmp"' EXIT

# THE TIME BOUND. Each call is bounded at 15 seconds plus a 2-second kill and
# retried once on the WSL interop error (orca-send.sh's rule). No call starts
# 90 seconds or more after the script did, and none starts after a call timed
# out: a wedged Orca would only stack more 17-second waits. A call that is not
# started counts as failed, so it raises orca-unreadable, never `ok`. Worst
# case about 90 + 34 = 124 seconds: run the block with a tool timeout of at
# least 3 minutes.
cepa_h_wedged=0
cepa_h_orca() {
  local out=$1 try rc e t
  shift
  for try in 1 2; do
    t=$(date +%s 2>/dev/null) || t=
    [[ $t =~ ^[0-9]{1,12}$ ]] && [ $((t - cepa_h_now)) -lt 90 ] && [ "$cepa_h_wedged" = 0 ] || return 1
    timeout -k 2 15 "$cepa_h_cli" "$@" </dev/null >"$out" 2>"$cepa_h_tmp/err" && return 0
    rc=$?
    if [ "$rc" = 124 ] || [ "$rc" = 137 ]; then cepa_h_wedged=1; return 1; fi
    [ "$try" = 1 ] || return 1
    { e=$(<"$cepa_h_tmp/err"); } 2>/dev/null || return 1
    [[ $e == *UtilAcceptVsock* && $e == *"accept4 failed 110"* ]] || return 1
  done
  return 1
}

# Each read writes its result to a file, or a `.fail` marker beside it. The
# two small readers exit non-zero on any shape they do not know, so a changed
# Orca reads as unreadable, never as an empty Run.
cepa_h_run=
if cepa_h_orca "$cepa_h_tmp/run.json" orchestration run-current --json; then
  cepa_h_run=$(python3 -I -c '
import json, re, sys
d = json.load(open(sys.argv[1]))
r = d["result"]["run"] if d.get("ok") is True else sys.exit(1)
if r is None:
    sys.exit(0)
i = r["id"]
if not (isinstance(i, str) and re.fullmatch(r"run_[A-Za-z0-9_-]{1,64}", i)):
    sys.exit(1)
print(i)
' "$cepa_h_tmp/run.json" 2>/dev/null) || { cepa_h_run=; : >"$cepa_h_tmp/run.fail"; }
else
  : >"$cepa_h_tmp/run.fail"
fi
mkdir -p "$cepa_h_tmp/show"
if [ -n "$cepa_h_run" ]; then
  cepa_h_ids=
  if cepa_h_orca "$cepa_h_tmp/workers.json" orchestration worker-list --run "$cepa_h_run" --json \
      && cepa_h_ids=$(python3 -I -c '
import json, re, sys
d = json.load(open(sys.argv[1]))
rows = d["result"]["workers"] if d.get("ok") is True else sys.exit(1)
if not isinstance(rows, list):
    sys.exit(1)
ids = []
for w in rows:
    i, o = w["dispatchId"], w["projection"]["outcome"]
    if not (isinstance(i, str) and re.fullmatch(r"ctx_[0-9a-f]{6,32}", i) and isinstance(o, str)):
        sys.exit(1)
    if o == "in_progress":
        ids.append(i)
page = d["result"].get("page")
if len(ids) > 20 or (isinstance(page, dict) and page.get("hasMore") is not False and "hasMore" in page):
    open(sys.argv[2], "w").close()
print(" ".join(ids[:20]))
' "$cepa_h_tmp/workers.json" "$cepa_h_tmp/capped" 2>/dev/null); then
    for d in $cepa_h_ids; do
      cepa_h_orca "$cepa_h_tmp/show/$d.json" orchestration worker-show --dispatch "$d" --json \
        || : >"$cepa_h_tmp/show/$d.fail"
    done
  else
    : >"$cepa_h_tmp/workers.fail"
  fi
fi
cepa_h_orca "$cepa_h_tmp/inbox.json" orchestration inbox --limit 200 --json || : >"$cepa_h_tmp/inbox.fail"

python3 -I - "$cepa_h_tmp" "$cepa_h_dir" "$cepa_h_now" "$cepa_h_run" "$cepa_h_repo" \
  "${ORCA_TERMINAL_HANDLE:-}" "$cepa_h_wt" "$cepa_h_main" "$cepa_h_acked" <<'PY'
import calendar, json, os, re, sys, time

def _crash(t, v, tb):
    # An uncaught error must not exit 1, which means "alerts".
    print("ORCA health failed: the reader crashed (%s)" % t.__name__, flush=True)
    os._exit(3)
sys.excepthook = _crash
tmp, adir, now, run, repo, me, wt, main, acked_dir = sys.argv[1:10]
now, main = int(now), main == "1"
HB_STALE, RUN_LONG, Q_WAIT, AWAIT = 30, 180, 10, 30   # minutes
SAFE = re.compile(r"[A-Za-z0-9_.:@-]{1,120}")
ADDR = r"(term_[0-9a-f-]{36}|run:[A-Za-z0-9_-]{1,64}|dispatch:[A-Za-z0-9_-]{1,64})"
MID = r"msg_[0-9a-f]{6,32}"
# The reason field is shown only when it is one orca-send.sh writes (security
# review of PR #109): any other text is replaced, so an alert file planted by
# another process cannot put words into the operator question.
REASONS = [re.compile(x) for x in (
    r"the (subject|body) is empty", r"the (subject|body) starts with --, which Orca reads as a flag",
    r"stdin has no subject line", r"the message size could not be measured",
    r"subject and body are \d{1,9} bytes; the limit is 28000 \(WSL command-line limit\)",
    r"the cli is not a plain command name", r"the cli does not name an Orca CLI",
    r"a cli path must (be absolute and )?equal ORCA_CLI_COMMAND", r"bare orca on Linux is the screen reader",
    r"[A-Za-z0-9._/-]{1,200} is not on PATH",
    r"orca-send\.sh takes no arguments; its fields go on stdin",
    r"stdin has no empty line after its fields",
    r"a line before the empty line is not a <name>: <value> field",
    r"a field name is not cli, target, type, nudge, outcome, task or session",
    r"the (cli|target|type|nudge|outcome|task|session) field is (given twice|missing)",
    r"the session name holds a character outside \[A-Za-z0-9\._@-\]",
    r"a worker_done takes outcome and task fields, not nudge",
    r"only a worker_done takes outcome and task fields",
    r"the target is not a term_ handle, run: or dispatch: address", r"a reply's target is not a msg_ message id",
    r"a worker_done target is not dispatch:ctx_<id>",
    r"the task id is not task_<id>", r"the worker_done outcome is not succeeded or failed",
    r"the type is not status, question, handoff, escalation, merge_ready, reply or worker_done",
    r"the nudge field is not nudge or no-nudge", r"only a term_ handle is nudged",
    r"no timeout command to bound the Orca calls", r"no python3 to read the Orca output", r"mktemp failed",
    r"no request id could be made", r"the send output could not be read",
    r"the send exited \d{1,3}( and printed (nothing|no JSON))?", r"the send printed JSON of an unexpected shape",
    r'Orca did not return "ok": true( \([a-z_]{1,40}\))?', r"the reply has no result\.message\.id",
    r"the reply names no valid recipient", r"the reply is not threaded on " + MID,
    r"Orca did not record the dispatch as (completed|failed)",
    MID + r" is not in the inbox for " + ADDR,
    r"the inbox could not be (parsed|re-read), so " + MID + r" is unconfirmed")]
if not re.fullmatch(r"term_[0-9a-f-]{36}", me):
    me = ""
hour = now // 3600
alerts, notes = [], []

def alert(key, text):
    alerts.append((key, text))

def unreadable(what, text=None):
    alert("orca-unreadable:%s:%d" % (what, hour),
          text or "Orca %s failed or was not readable, so this Run's health is unknown" % what.replace("-", " "))

def listdir(p, what):
    try:
        return sorted(os.listdir(p))
    except FileNotFoundError:
        return []
    except OSError:
        unreadable(what, "the %s could not be read, so its alerts are unknown" % what.replace("-", " "))
        return []

acked = set(listdir(acked_dir, "ack-dir"))

def ts(s):
    # "2026-10-31T20:36:22Z" or "2026-10-31 20:35:34", both UTC (the two
    # agreed on every row of the measured Run).
    if not isinstance(s, str):
        return None
    m = re.fullmatch(r"(\d{4})-(\d\d)-(\d\d)[T ](\d\d):(\d\d):(\d\d)(?:\.\d+)?Z?", s)
    try:
        return calendar.timegm(tuple(int(x) for x in m.groups()) + (0, 0, 0)) if m else None
    except (ValueError, OverflowError):
        return None

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

# 1. Alert files from orca-send.sh.
FIELD = {"kind": r"send_(refused|failed|unproven)", "time": r"\d{1,12}", "repo": r"[A-Za-z0-9._@-]{1,100}",
         "worktree": r"[A-Za-z0-9._@-]{1,100}", "sender": r"term_[0-9a-f-]{36}|unknown",
         "target": r"(msg_[0-9a-f]{6,32}|%s)|invalid" % ADDR[1:-1],
         "type": r"[a-z_]{1,20}", "reason": r"[ -~]{0,300}"}
other = 0
for n in listdir(adir, "alert-dir"):
    if not re.fullmatch(r"\d{1,12}-[A-Za-z0-9]{1,20}\.alert", n):
        continue
    key = "send-failed:" + n
    try:
        lines = open(os.path.join(adir, n), encoding="ascii").read().splitlines()
        f = dict(l.split("=", 1) for l in lines[1:] if "=" in l)
        shaped = lines[:1] == ["cepa-orca-alert 1"] and all(re.fullmatch(FIELD[k], f.get(k, "")) for k in FIELD)
    except Exception:
        shaped = False
    if not shaped:
        if key not in acked:
            alert(key, "an alert file in an unknown shape: %s" % n)
        continue
    # Repo unknown on either side: shown, never dropped.
    mine = repo == "unknown" or f["repo"] in (repo, "unknown")
    if mine and not main and repo != "unknown":
        mine = f["worktree"] == wt
    if not mine:
        other += 1
        continue
    if key in acked:
        continue
    what = {"send_refused": "was refused before any Orca call",
            "send_failed": "stored nothing",
            "send_unproven": "was not proven stored"}[f["kind"]]
    why = f["reason"] if any(r.fullmatch(f["reason"]) for r in REASONS) else "an unrecognised reason"
    alert(key, "%s: a %s send to %s %s (%s), at %s, from %s" % (
        f["worktree"], f["type"], f["target"], what, why, hhmm(int(f["time"])), f["sender"]))
if other:
    notes.append("%d alert file%s for other worktrees or repos not shown" % (other, "" if other == 1 else "s"))

# 2. The bound Run's live dispatches.
if os.path.exists(os.path.join(tmp, "run.fail")):
    unreadable("run-current")
if run:
    if os.path.exists(os.path.join(tmp, "workers.fail")):
        unreadable("worker-list")
    if os.path.exists(os.path.join(tmp, "capped")):
        unreadable("worker-cap", "more than 20 dispatches are live, or worker-list has more pages; some were not read")
    for n in listdir(os.path.join(tmp, "show"), "show-dir"):
        if n.endswith(".fail"):
            unreadable("worker-show")
            continue
        d = load(os.path.join("show", n))
        r = d.get("result") if d else None
        disp = r.get("dispatch") if isinstance(r, dict) else None
        p = r.get("projection") if isinstance(r, dict) else None
        did = disp.get("id") if isinstance(disp, dict) else None
        start = ts(disp.get("dispatchedAt")) if isinstance(disp, dict) else None
        if did != n[:-5] or not isinstance(p, dict) or not isinstance(p.get("outcome"), str) or start is None:
            unreadable("worker-show")
            continue
        if p["outcome"] != "in_progress":
            continue   # settled between worker-list and worker-show
        cats = (p.get("attention") or {}).get("categories") or []
        verdict = (p.get("liveness") or {}).get("verdict")
        wait = (r.get("observation") or {}).get("agentWait")
        handle = (r.get("worker") or {}).get("agentTerminalHandle") or disp.get("assigneeHandle")
        who = did + (" (%s)" % handle if isinstance(handle, str) and re.fullmatch(r"term_[0-9a-f-]{36}", handle) else "")
        if verdict == "exited":
            k = "exited:" + did
            if k not in acked:
                alert(k, "worker %s exited with no worker_done" % who)
            continue
        if wait:
            # Keyed by the hour, so a worker still parked an hour later asks again.
            k = "waiting:%s:%d" % (did, hour)
            if k not in acked:
                alert(k, "worker %s is parked on a prompt only a human can answer" % who)
            continue
        hb = ts(disp.get("lastHeartbeatAt"))
        if hb is None and disp.get("lastHeartbeatAt") is not None:
            unreadable("worker-show")   # a heartbeat time in a shape this reader cannot date
            continue
        last = hb if hb is not None else start
        k = "stale:%s:%d" % (did, last)
        if "input" not in cats and mins(last) >= HB_STALE and k not in acked:
            alert(k, "worker %s sent no heartbeat for %d minutes (bound %d)%s" % (
                who, mins(last), HB_STALE, "" if hb is not None else ", none since its dispatch"))
        k = "long:" + did
        if mins(start) >= RUN_LONG and k not in acked:
            alert(k, "worker %s has run %d minutes with no worker_done (bound %d)" % (who, mins(start), RUN_LONG))

# 3. Questions, from the inbox.
inbox = load("inbox.json")
rows = (inbox.get("result") or {}).get("messages") if inbox else None
if not isinstance(rows, list):
    unreadable("inbox")
    rows = []
rows = [x for x in rows if isinstance(x, dict)]
if len(rows) >= 200:
    notes.append("inbox window full: questions older than 200 rows not read")
if not me:
    notes.append("own-question check off: ORCA_TERMINAL_HANDLE is not a term_ handle")
sender = {x.get("id"): x.get("from_handle") for x in rows if isinstance(x.get("id"), str)}
answered = set()
for x in rows:
    t = x.get("thread_id")
    # A reply is a row on the thread that the question's own sender did not write.
    if isinstance(t, str) and t != x.get("id") and x.get("from_handle") != sender.get(t):
        answered.add(t)
for x in rows:
    mid, t = x.get("id"), ts(x.get("created_at"))
    if x.get("type") != "question" or t is None or mid in answered \
            or not (isinstance(mid, str) and re.fullmatch(MID, mid)):
        continue
    if run and x.get("to_handle") == "run:" + run and mins(t) >= Q_WAIT:
        k = "question:" + mid
        if k not in acked:
            alert(k, "worker question %s has waited %d minutes for your reply (bound %d)" % (mid, mins(t), Q_WAIT))
    elif me and x.get("from_handle") == me and mins(t) >= AWAIT:
        k = "awaited:" + mid
        to = x.get("to_handle")
        to = to if isinstance(to, str) and SAFE.fullmatch(to) else "its recipient"
        if k not in acked:
            alert(k, "your question %s to %s has had no reply for %d minutes (bound %d)" % (mid, to, mins(t), AWAIT))

seen, hidden = set(), set()
for k, text in alerts:
    if k.startswith("orca-unreadable:") and k in acked:
        hidden.add(k)   # acked this hour: not asked again, and never read as ok
        continue
    if k in seen:
        continue
    seen.add(k)
    print("ORCA alert: %s — %s" % (k, text))
tail = " (%s)" % "; ".join(notes) if notes else ""
if hidden and not seen:
    print("ORCA health: unknown — %s still unreadable (acked this hour)%s" % (", ".join(sorted(hidden)), tail))
    sys.exit(0)
if seen:
    print("ORCA health: %d alert%s — ask the operator (§12b rule 8)%s" % (len(seen), "" if len(seen) == 1 else "s", tail))
    print("Ending first line: Needed from you: check the Orca alerts below")
    sys.exit(1)
print("ORCA health: ok — %s%s" % ("Run %s checked" % run if run else "no bound Run; alert files and questions checked", tail))
PY
cepa_h_rc=$?
# Any other exit is the reader's own failure: an alert, never a quiet pass.
if [ "$cepa_h_rc" -gt 1 ]; then
  echo "ORCA alert: orca-unreadable:reader:$((cepa_h_now / 3600)) — the health reader failed (exit $cepa_h_rc), so this Run's health is unknown"
  echo "ORCA health: 1 alert — ask the operator (§12b rule 8)"
  echo "Ending first line: Needed from you: check the Orca alerts below"
  exit 1
fi
exit "$cepa_h_rc"

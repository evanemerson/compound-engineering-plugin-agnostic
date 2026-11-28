#!/usr/bin/env python3
# Stub `orca-ide` for scripts/check-orca-outbox.sh. It answers the verbs that
# plugins/cepa/scripts/orca-send.sh (coord: target), orca-health.sh and
# orca-outbox.sh call, from a JSON state file, and logs every argv as one JSON
# line. Shapes follow Orca 1.4.245 as measured for L61 on 2026-11-02:
# `run-list` -> result.{runs[{id, objective, coordinator_handle, ...}],
# nextCursor}; `terminal list` -> result.{terminals[{handle, tabId, leafId,
# worktreePath (UNC), connected}], truncated}; `worktree ps` ->
# result.{worktrees[{path (UNC), isMainWorktree, agents[{paneKey, state,
# hasLivePty?}]}], truncated}. Env: STUB_STATE, STUB_LOG. Fault switches are
# the state's "mode" list. Never reaches a real Orca.
#
# L72: Orca 1.4.246 prints an orchestration read in a concise view unless the
# call carries `--full`. So does this stub: an ok answer to such a read
# without `--full` goes through orca-short-shape.py, beside this file. Inbox
# rows carry `thread_id` and `created_at`, as a full 1.4.246 row does. Mode
# "short" answers in the short shape even with `--full`.
import importlib.util, json, os, sys
_ss = importlib.util.spec_from_file_location(
    "orca_short_shape", os.path.join(os.path.dirname(os.path.abspath(__file__)), "orca-short-shape.py"))
_ssm = importlib.util.module_from_spec(_ss)
_ss.loader.exec_module(_ssm)

ST, LOG = os.environ["STUB_STATE"], os.environ["STUB_LOG"]
argv = sys.argv[1:]
with open(LOG, "a") as f:
    f.write(json.dumps(argv) + "\n")
st = json.load(open(ST))
MODE = set(st.get("mode", []))


def opt(name):
    return argv[argv.index(name) + 1] if name in argv else None


def out(obj, rc=0):
    json.dump(st, open(ST, "w"))
    text = json.dumps(obj)
    if argv[:1] == ["orchestration"] and ("--full" not in argv or "short" in MODE):
        text = _ssm.short(argv[1] if len(argv) > 1 else "", text)
    print(text)
    sys.exit(rc)


def err(code, rc=1):
    out({"id": "local", "ok": False, "error": {"code": code, "message": code}}, rc)


verb = " ".join(argv[:2])
if verb == "orchestration run-list":
    if "runlist_fail" in MODE:
        err("runtime_unavailable")
    runs, size = st.get("runs", []), int(st.get("page", 100))
    c = opt("--cursor") or ""
    i = int(c[1:]) if c[:1] == "c" and c[1:].isdigit() else 0   # an unknown cursor reads from the start
    if "runlist_badcursor" in MODE:
        out({"id": "x", "ok": True, "result": {"runs": runs, "nextCursor": "bad cursor!"}})
    nxt = "c%d" % (i + size) if i + size < len(runs) else None
    out({"id": "x", "ok": True, "result": {"runs": runs[i:i + size], "nextCursor": nxt}})
if verb == "terminal list":
    if "tlist_fail" in MODE:
        err("runtime_unavailable")
    out({"id": "x", "ok": True, "result": {"terminals": st.get("terminals", []),
                                           "truncated": "tlist_trunc" in MODE, "totalCount": 0}})
if verb == "worktree ps":
    if "ps_fail" in MODE:
        err("runtime_unavailable")
    out({"id": "x", "ok": True, "result": {"worktrees": st.get("worktrees", []),
                                           "truncated": "ps_trunc" in MODE, "totalCount": 0}})
if verb == "orchestration send":
    if "send_fail" in MODE:
        err("invalid_argument")
    to = opt("--to")
    n = len(st.setdefault("sent", [])) + 1
    # A bot: send is stored for the bot's chat, as Orca does (L103 C1).
    # L104: a bot whose Home chat is bound to a Run (state "bot_run") gets it
    # in that Run, with Orca's botRequest payload (Orca 1.4.280,
    # msg_ede2e13a5255). Mode botrun_nopayload stores it with no payload.
    bot_to = isinstance(to, str) and to.startswith("bot:")
    if bot_to and "store_to" not in st:
        to = ("run:" + st["bot_run"]) if "bot_run" in st else "orca_session_id:" + st.get("bot_chat", "0" * 36)
    m = {"id": "msg_%012x" % (0xabc000 + n), "to_handle": st.get("store_to", to), "from_handle": "term_" + "1" * 36,
         "type": opt("--type"), "subject": opt("--subject"), "body": opt("--body"),
         "thread_id": None, "created_at": "2026-11-02 01:00:00",
         "payload": json.dumps({"botRequest": {"from": "your owner's agent"}})
         if bot_to and "bot_run" in st and "botrun_nopayload" not in MODE else None}
    st["sent"].append(m)
    out({"id": "x", "ok": True, "result": {"message": m}})
# L103 C2: `bot list` (Orca 1.4.280: result.bots[{name, ...}]) and `bot
# chats` (result.{bot, chats[{id, closed}]}). State "bots" lists the names;
# "bot_chat" is the Home chat id each bot has; "bots_paused" names paused
# ones. Mode botchats_closed answers that chat as closed. Modes: botlist_fail (exit 1),
# botlist_shape (no bots list), botlist_none (no `bot` command: exit 64).
if verb == "bot list":
    if "botlist_none" in MODE:
        sys.exit(64)
    if "botlist_fail" in MODE:
        err("runtime_unavailable")
    if "botlist_shape" in MODE:
        out({"id": "x", "ok": True, "result": {"bot": st.get("bots", [])}})
    paused = set(st.get("bots_paused", []))
    out({"id": "x", "ok": True, "result": {"bots": [{"name": n, "agent": "claude", "paused": n in paused, "linked": []}
                                                     for n in st.get("bots", [])], "unreachable": []}})
if verb == "bot chats":
    out({"id": "x", "ok": True, "result": {"bot": opt("--bot"), "chats": [
        {"id": st.get("bot_chat", "0" * 36), "title": "Home", "home": True, "closed": "botchats_closed" in MODE}]}})
if verb == "orchestration inbox":
    out({"id": "x", "ok": True, "result": {"messages": list(reversed(st.get("sent", [])))}})
# L104: `run-show --id` (result.run{id, objective, coordinator_handle}).
# State "bot_run_coord" is that Run's coordinator_handle (default null).
if verb == "orchestration run-show":
    out({"id": "x", "ok": True, "result": {"run": {"id": opt("--id"), "objective": "x",
                                                   "coordinator_handle": st.get("bot_run_coord")}}})
if verb == "orchestration run-current":
    out({"id": "x", "ok": True, "result": {"run": None}})
if verb == "terminal show":
    t = [x for x in st.get("terminals", []) if x["handle"] == opt("--terminal")]
    out({"id": "x", "ok": True, "result": {"terminal": t[0] if t else {}}})
err("unknown_verb")

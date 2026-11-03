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
    m = {"id": "msg_%012x" % (0xabc000 + n), "to_handle": st.get("store_to", to), "from_handle": "term_" + "1" * 36,
         "type": opt("--type"), "subject": opt("--subject"), "body": opt("--body"),
         "thread_id": None, "created_at": "2026-11-02 01:00:00"}
    st["sent"].append(m)
    out({"id": "x", "ok": True, "result": {"message": m}})
if verb == "orchestration inbox":
    out({"id": "x", "ok": True, "result": {"messages": list(reversed(st.get("sent", [])))}})
if verb == "orchestration run-current":
    out({"id": "x", "ok": True, "result": {"run": None}})
if verb == "terminal show":
    t = [x for x in st.get("terminals", []) if x["handle"] == opt("--terminal")]
    out({"id": "x", "ok": True, "result": {"terminal": t[0] if t else {}}})
err("unknown_verb")

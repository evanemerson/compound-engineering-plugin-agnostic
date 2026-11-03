#!/usr/bin/env python3
# The Orca 1.4.246 concise view of an orchestration read, made from the full
# record a checker's stub would print (punch-list L72). Orca 1.4.246 prints
# this short form unless the call carries `--full`; cepa's scripts read
# fields only the full form holds, so every stub answers a read WITHOUT
# `--full` with this short form. A script that drops `--full` then reads the
# short form and its checker's own cases fail.
#
# Measured on Orca 1.4.246 (WSL), 2026-11-02, read-only, each verb with and
# without `--full` (top-level `id` and `_meta` are full-only too):
#   run-list     runs[{id, objective}], nextCursor
#   run-show     {runId, objective, removedWork}   (no `run` object)
#   run-current  {runId, objective}                (no `run` object)
#   worker-list  workers[{dispatchId, taskId, state, outcome, liveness, agent,
#                terminal, terminalState, workspace, host}], scope,
#                nextCursor, warnings              (no projection, no page)
#   worker-show  {dispatchId, taskId, runId, state, stage, liveness, terminal,
#                terminalState, workspace}         (no dispatch/worker/projection)
#   inbox        messages[{id, type, from, to, subject, handled, body (200
#                chars), payload}]                 (no from_handle, to_handle,
#                thread_id, created_at)
#
# Use: `short(verb, text)` returns the short text, or `text` unchanged when it
# is not an ok full record of that verb (a stub's fault output stays a fault).
# As a program: `orca-short-shape.py <verb>` filters stdin to stdout.
import json, sys

VERBS = ("run-list", "run-show", "run-current", "worker-list", "worker-show", "inbox")


def _run(r):
    r = r if isinstance(r, dict) else {}
    return {"runId": r.get("id"), "objective": r.get("objective")}


def _short(verb, d):
    r = d["result"]
    if verb == "run-list":
        out = {"runs": [{"id": x.get("id"), "objective": x.get("objective")} for x in r["runs"]]}
        if "nextCursor" in r:
            out["nextCursor"] = r["nextCursor"]
    elif verb in ("run-show", "run-current"):
        out = _run(r["run"])
        if "removedWork" in r or verb == "run-show":
            out["removedWork"] = r.get("removedWork", {})
    elif verb == "worker-list":
        rows = []
        for w in r["workers"]:
            p = w.get("projection") if isinstance(w.get("projection"), dict) else {}
            rows.append({"dispatchId": w.get("dispatchId"), "taskId": w.get("taskId"),
                         "state": w.get("workerState"), "outcome": p.get("outcome"),
                         "liveness": (p.get("liveness") or {}).get("verdict"),
                         "terminal": w.get("agentTerminalHandle"), "terminalState": w.get("terminalState")})
        out = {"workers": rows, "nextCursor": (r.get("page") or {}).get("nextCursor")}
    elif verb == "worker-show":
        disp, wk = r.get("dispatch") or {}, r.get("worker") or {}
        p = r.get("projection") or {}
        out = {"dispatchId": disp.get("id"), "taskId": disp.get("taskId"), "runId": disp.get("runId"),
               "state": wk.get("state"), "stage": wk.get("stage"),
               "liveness": (p.get("liveness") or {}).get("verdict"),
               "terminal": wk.get("agentTerminalHandle")}
    else:
        out = {"messages": [{"id": m.get("id"), "type": m.get("type"), "from": m.get("from_handle"),
                             "to": m.get("to_handle"), "subject": m.get("subject"), "handled": m.get("read"),
                             "body": (m.get("body") or "")[:200], "payload": m.get("payload")}
                            for m in r["messages"]]}
    return {"ok": True, "result": out}


def short(verb, text):
    try:
        d = json.loads(text)
        if verb not in VERBS or not isinstance(d, dict) or d.get("ok") is not True:
            return text
        return json.dumps(_short(verb, d))
    except Exception:
        return text


if __name__ == "__main__":
    sys.stdout.write(short(sys.argv[1], sys.stdin.read()))

#!/usr/bin/env python3
# Stub `orca-ide` for scripts/check-orca-attention.sh. It answers the three
# verbs plugins/cepa/scripts/orca-attention.sh calls (worktree current, show,
# set) from a JSON state file and logs every argv as one JSON line. Shapes
# follow the Orca 1.4.245 replies measured in L57 (result.worktree.{id,
# repoId, path, comment, isUnread}; paths as Windows UNC; ids
# `<repoId>::<UNC path>`; `current` outside every worktree is `"ok": false`,
# `selector_not_found`). Like the real CLI, `set --comment ""` changes nothing.
# Env: STUB_STATE (state file), STUB_LOG (argv log), STUB_MODE (comma list of
# fault switches, read below). Never reaches a real Orca.
import json, os, sys

ST, LOG = os.environ["STUB_STATE"], os.environ["STUB_LOG"]
MODE = set(filter(None, os.environ.get("STUB_MODE", "").split(",")))
argv = sys.argv[1:]
with open(LOG, "a") as f:
    f.write(json.dumps(argv) + "\n")
st = json.load(open(ST))
DISTRO = st.get("distro", "Ubuntu-24.04")


def save():
    json.dump(st, open(ST, "w"))


def unc(p, distro=DISTRO):
    return "\\\\wsl.localhost\\" + distro + p.replace("/", "\\")


def out(obj, rc=0):
    save()
    print(json.dumps(obj))
    sys.exit(rc)


def err(code, msg, rc=1):
    out({"id": "x", "ok": False, "error": {"code": code, "message": msg}}, rc)


def opt(name):
    return argv[argv.index(name) + 1] if name in argv else None


def row(w, distro=DISTRO, rid=None):
    p = unc(w["path"], distro)
    rid = rid or w["repoId"]
    return {"id": rid + "::" + p, "repoId": w["repoId"], "path": p, "displayName": os.path.basename(w["path"]),
            "comment": w.get("comment", ""), "isUnread": w.get("unread", False), "workspaceStatus": "in-progress"}


def by_id(i):
    for w in st["wts"]:
        if row(w)["id"] == i:
            return w
    return None


# The WSL interop error, once, on the first call that sees this mode.
if "interop" in MODE and not st.get("interop_done"):
    st["interop_done"] = True
    save()
    sys.stderr.write("<3>WSL (1 - ) ERROR: UtilAcceptVsock:271: accept4 failed 110\n")
    sys.exit(1)

if argv[:2] == ["worktree", "current"]:
    if "currentfail" in MODE:
        sys.exit(1)
    cwd = os.path.realpath(os.getcwd())
    hits = [w for w in st["wts"] if cwd == w["path"] or cwd.startswith(w["path"] + "/")]
    if not hits:
        err("selector_not_found", "No Orca-managed worktree contains the current directory: " + unc(cwd))
    w = max(hits, key=lambda x: len(x["path"]))
    if "currentother" in MODE:
        w = [x for x in st["wts"] if x is not w][0]
    if "currentdistro" in MODE:
        out({"id": "x", "ok": True, "result": {"worktree": row(w, distro="Debian")}})
    if "currentbadid" in MODE:
        out({"id": "x", "ok": True, "result": {"worktree": row(w, rid="99999999-9999-4999-8999-999999999999")}})
    out({"id": "x", "ok": True, "result": {"worktree": row(w)}})

if argv[:2] == ["worktree", "show"]:
    if "showfail" in MODE:
        sys.exit(1)
    sel = opt("--worktree") or ""
    w = by_id(sel[3:]) if sel.startswith("id:") else None
    if w is None:
        err("selector_not_found", "no worktree " + sel)
    if "showwrongid" in MODE:
        w = [x for x in st["wts"] if x is not w][0]
    out({"id": "x", "ok": True, "result": {"worktree": row(w)}})

if argv[:2] == ["worktree", "set"]:
    if "setfail" in MODE:
        sys.exit(1)
    sel = opt("--worktree") or ""
    w = by_id(sel[3:]) if sel.startswith("id:") else None
    if w is None:
        err("selector_not_found", "no worktree " + sel)
    if "setnostick" not in MODE:
        if "--unread" in argv:
            w["unread"] = True
        if "--read" in argv:
            w["unread"] = False
        c = opt("--comment")
        if c:  # Orca 1.4.245 ignores an empty --comment (measured L57)
            w["comment"] = c
    out({"id": "x", "ok": True, "result": {"worktree": row(w)}})

err("unknown_command", "stub does not know " + " ".join(argv[:2]))

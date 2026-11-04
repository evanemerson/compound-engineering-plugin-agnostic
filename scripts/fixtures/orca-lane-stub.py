#!/usr/bin/env python3
# Stub `orca-ide` for scripts/check-orca-lane.sh. It answers the verbs
# plugins/cepa/scripts/orca-lane.sh calls (repo list; worktree list, create,
# show, set, ps, rm; terminal list) from a JSON state file, makes and removes real git
# worktrees, and logs every argv as one JSON line. Shapes follow the Orca
# 1.4.245 replies measured in L55's U1 (paths as Windows UNC, ids
# `<repoId>::<UNC path>`, rm's worktree_archive_hook_failed error).
# The `worktree ps` shape (worktrees[].{worktreeId, agents}, hostScope,
# totalCount, truncated) matches a real `worktree ps --limit 500 --json` read
# during the L55 build, which the script's reader parsed.
# Env: STUB_STATE (state file), STUB_LOG (argv log), STUB_MODE (comma list of
# fault switches, read below), STUB_AGENT_ON (lane basename), STUB_AGENT_STATE
# (its agents' state), STUB_AGENT_PANES (their paneKeys, comma list). The
# `terminal list` shape (terminals[].{handle, tabId, leafId, orphaned,
# worktreeId}, hostScope, totalCount, truncated) follows a real read on Orca
# 1.4.246, 2026-11-04. The late-create modes (L79) answer as Orca's CLI did:
# the create call gives up, and the lane shows on a later `worktree list`.
# Never reaches a real Orca.
import json, os, subprocess, sys

ST, LOG = os.environ["STUB_STATE"], os.environ["STUB_LOG"]
MODE = set(filter(None, os.environ.get("STUB_MODE", "").split(",")))
argv = sys.argv[1:]
with open(LOG, "a") as f:
    f.write(json.dumps(argv) + "\n")
st = json.load(open(ST))
st["calls"] = st.get("calls", 0) + 1
DISTRO = st.get("distro", "Ubuntu-24.04")


def save():
    json.dump(st, open(ST, "w"))


def unc(p):
    return "\\\\wsl.localhost\\" + DISTRO + p.replace("/", "\\")


def out(obj, rc=0):
    save()
    print(json.dumps(obj))
    sys.exit(rc)


def err(code, msg, data=None, rc=1):
    e = {"code": code, "message": msg}
    if data is not None:
        e["data"] = data
    out({"id": "x", "ok": False, "error": e}, rc)


def opt(name):
    return argv[argv.index(name) + 1] if name in argv else None


def git(*a, cwd=None):
    return subprocess.run(["git", *a], cwd=cwd, capture_output=True, text=True)


def branch(p):
    r = git("-C", p, "symbolic-ref", "-q", "HEAD")
    return r.stdout.strip() if r.returncode == 0 else ""


def row(w):
    p = w["path"]
    if "otherdistro" in MODE and not w["main"]:
        up = unc(p).replace(DISTRO, "Debian", 1)
    else:
        up = unc(p)
    return {"id": w["repoId"] + "::" + up, "repoId": w["repoId"], "path": up, "branch": branch(p),
            "displayName": w["name"], "displayNameMode": w["mode"], "isMainWorktree": w["main"]}


def find(sel):
    if not sel or not sel.startswith("id:"):
        err("selector_not_supported_by_stub", "stub takes id: selectors only")
    for w in st["wts"]:
        if row(w)["id"] == sel[3:]:
            return w
    err("worktree_not_found", "worktree_not_found")


def make_lane(rid, name, br, base):
    repo = [r for r in st["repos"] if r["id"] == rid][0]
    d = os.path.join(st["ws"], os.path.basename(repo["path"]))
    os.makedirs(d, exist_ok=True)
    p = os.path.join(d, name)
    if os.path.exists(p):
        p, br = p + "-2", br + "-2"
    git("-C", repo["path"], "worktree", "add", "-q", "-b", br, p, base)
    w = {"repoId": rid, "path": p, "name": name, "mode": "fixed", "main": False}
    st["wts"].append(w)
    return w


# The 1.4.246 `repo list` hookSettings shape for a repo with no saved script
# (L76). A state repo's "hook" key replaces it, so the HOOKS leg can stub
# every shape.
HOOK = {"mode": "auto", "setupRunPolicy": "run-by-default", "setupAgentStartupPolicy": "start-immediately",
        "scripts": {"setup": "", "archive": ""}}
verb = argv[:2]
if argv[:2] == ["repo", "list"]:
    if "repofail" in MODE:
        sys.exit(1)
    out({"id": "x", "ok": True, "result": {"repos": [
        {"id": r["id"], "path": unc(r["path"]), "displayName": os.path.basename(r["path"]),
         "hookSettings": r.get("hook", HOOK)}
        for r in st["repos"]]}})
if verb == ["worktree", "list"]:
    st["lists"] = st.get("lists", 0) + 1
    if "listfail" in MODE or ("listfail2" in MODE and st["lists"] >= 2) or ("listfail23" in MODE and st["lists"] in (2, 3)):
        save(); sys.exit(1)
    pend = st.get("pending")
    if pend and st["lists"] >= pend["at"]:
        st.pop("pending")
        w = make_lane(pend["rid"], pend["name"], pend["br"], pend["base"])
        if "createdup" in MODE:
            make_lane(pend["rid"], pend["name"], pend["br"], pend["base"])
        if "createunsettled" in MODE or "createstuck" in MODE:
            w["mode"] = "automatic"
    if "createunsettled" in MODE and st["lists"] >= 5:
        for w in st["wts"]:
            if not w["main"]:
                w["mode"] = "fixed"
    rid = (opt("--repo") or "")[3:]
    # Without --repo, Orca lists every repo's worktrees (measured in L55's U1).
    rows = [row(w) for w in st["wts"] if not rid or w["repoId"] == rid or "leak" in MODE]
    r = {"worktrees": rows, "hostScope": {"hostIds": ["local"], "omittedHostIds": []},
         "totalCount": len(rows), "truncated": False}
    if "listpartial" in MODE:
        r["truncated"] = True
    if "listcount" in MODE:
        r["totalCount"] = len(rows) + 1
    if "listomitted" in MODE:
        r["hostScope"]["omittedHostIds"] = ["ssh:x"]
    out({"id": "x", "ok": True, "result": r})
if verb == ["worktree", "create"]:
    if "createfail" in MODE:
        err("runtime_error", 'Could not refresh base ref "%s" from "origin".' % opt("--base-branch"))
    rid = (opt("--repo") or "")[3:]
    LATE = MODE & {"createlate", "createverylate", "createnojson", "createkilled", "createnocode", "create0timeout",
                   "createnever", "createdup", "createunsettled", "createstuck"}
    if LATE:
        if "createnever" not in MODE:
            st["pending"] = {"rid": rid, "name": opt("--name"), "br": opt("--branch"), "base": opt("--base-branch"),
                             "at": 99 if "createverylate" in MODE else 3}
        if "createnojson" in MODE:
            save(); sys.exit(1)
        if "createkilled" in MODE:
            save(); sys.exit(124)
        if "createnocode" in MODE:
            out({"id": "x", "ok": False, "error": {}}, 1)
        err("runtime_timeout", "Timed out waiting for the Orca runtime to respond.", rc=0 if "create0timeout" in MODE else 1)
    repo = [r for r in st["repos"] if r["id"] == rid][0]
    name, br, base = opt("--name"), opt("--branch"), opt("--base-branch")
    d = os.path.join(st["ws"], os.path.basename(repo["path"]))
    os.makedirs(d, exist_ok=True)
    p = os.path.join(d, name)
    if os.path.exists(p) or "suffix" in MODE:
        p, br = p + "-2", br + "-2"
    if "branchsuffix" in MODE:
        br += "-2"
    if "freshbase" in MODE:
        # Orca fetches the base itself; here the fetch updates no
        # remote-tracking ref, so the caller's origin/<base> stays stale.
        # Origin first moves on DURING the create, after the caller's own
        # step-0 fetch, so only the park step's re-fetch can see the tip.
        url = git("-C", repo["path"], "remote", "get-url", "origin").stdout.strip()
        mv = os.path.join(st["ws"], ".mover-%d" % st["calls"])
        git("clone", "-q", url, mv)
        git("-C", mv, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "moved during create")
        git("-C", mv, "push", "-q", "origin", "HEAD:" + base[len("origin/"):])
        git("-C", repo["path"], "fetch", "-q", "--refmap=", "origin", base[len("origin/"):])
        base = git("-C", repo["path"], "rev-parse", "FETCH_HEAD").stdout.strip()
    r = git("-C", repo["path"], "worktree", "add", "-q", "-b", br, p, base)
    if r.returncode:
        err("runtime_error", r.stderr.strip()[:200])
    if "aheadcommit" in MODE:
        git("-C", p, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "ahead")
    w = {"repoId": rid, "path": p, "name": name, "mode": "automatic" if "automatic" in MODE else "fixed", "main": False}
    st["wts"].append(w)
    out({"id": "x", "ok": True, "result": {"worktree": dict(row(w), workspaceStatus="in-progress"), "warnings": []}})
if verb == ["worktree", "show"]:
    w = find(opt("--worktree"))
    rw = row(w)
    if "showstale" in MODE:
        rw["displayNameMode"] = "automatic"
    out({"id": "x", "ok": True, "result": {"worktree": rw}})
if verb == ["worktree", "set"]:
    w = find(opt("--worktree"))
    if "setfail" in MODE:
        err("runtime_error", "set failed")
    if "setnoop" not in MODE:
        w["name"], w["mode"] = opt("--display-name"), "fixed"
    out({"id": "x", "ok": True, "result": {"worktree": row(w)}})
if verb == ["worktree", "ps"]:
    if "psfail" in MODE:
        sys.exit(1)
    rows = []
    for w in st["wts"]:
        if "psmissing" in MODE and not w["main"]:
            continue
        ag = [{"paneKey": k, "state": os.environ.get("STUB_AGENT_STATE", "done"), "agentType": "claude"}
              for k in os.environ.get("STUB_AGENT_PANES", "a:b").split(",")] \
            if os.path.basename(w["path"]) == os.environ.get("STUB_AGENT_ON") else []
        rows.append({"worktreeId": row(w)["id"], "repoId": w["repoId"], "agents": ag})
    r = {"worktrees": rows, "hostScope": {"hostIds": ["local"], "omittedHostIds": []},
         "totalCount": len(rows), "truncated": "pspartial" in MODE}
    out({"id": "x", "ok": True, "result": r})
if verb == ["terminal", "list"]:
    if "--full" in argv:  # the real CLI refuses it (L72)
        err("invalid_argument", "unknown flag --full")
    if "termfail" in MODE:
        sys.exit(1)
    w = find(opt("--worktree"))
    wid = row(w)["id"]
    rows = [dict(t, worktreeId=wid) for t in st.get("terms", {}).get(os.path.basename(w["path"]), [])]
    out({"id": "x", "ok": True, "result": {"terminals": rows, "hostScope": {"hostIds": ["local"], "omittedHostIds": []},
                                           "totalCount": len(rows), "truncated": False}})
if verb == ["worktree", "rm"]:
    w = find(opt("--worktree"))
    if "hookfail" in MODE or "hookfail2" in MODE:
        err("worktree_archive_hook_failed", "Archive hook failed", {"worktreePath": row(w)["path"], "outcome": "exited",
            "exitCode": 2 if "hookfail2" in MODE else 1, "output": "Command failed with exit code 1.\x1b[0m"})
    if "rmpartial" in MODE:  # L77 item 4: Orca deleted tracked files, then stopped
        os.remove(os.path.join(w["path"], "f.txt"))
        err("runtime_error", "worktree removal failed")
    if "rmerror" in MODE:
        err("runtime_error", "worktree removal failed")
    if "rmnoop" in MODE:
        out({"id": "x", "ok": True, "result": {"removed": True}})
    br = branch(w["path"])
    repo = [r for r in st["repos"] if r["id"] == w["repoId"]][0]
    if "gitkeeps" not in MODE:
        git("-C", repo["path"], "worktree", "remove", "--force", w["path"])
    st["wts"].remove(w)
    if br and "keepbranch" not in MODE:
        tip = git("-C", repo["path"], "rev-parse", br).stdout.strip()
        on = git("-C", repo["path"], "for-each-ref", "--contains", tip, "refs/remotes/origin/").stdout.strip()
        if on:
            git("-C", repo["path"], "branch", "-D", br[len("refs/heads/"):])
    out({"id": "x", "ok": True, "result": {"removed": True}})
err("unknown_verb", "stub does not know " + " ".join(argv[:2]))

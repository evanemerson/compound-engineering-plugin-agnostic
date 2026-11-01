#!/usr/bin/env python3
# Stub `orca-ide` for scripts/check-orca-lane.sh. It answers the five verbs
# plugins/cepa/scripts/orca-lane.sh calls (repo list; worktree list, create,
# show, set, ps, rm) from a JSON state file, makes and removes real git
# worktrees, and logs every argv as one JSON line. Shapes follow the Orca
# 1.4.245 replies measured in L55's U1 (paths as Windows UNC, ids
# `<repoId>::<UNC path>`, rm's worktree_archive_hook_failed error).
# Env: STUB_STATE (state file), STUB_LOG (argv log), STUB_MODE (comma list of
# fault switches, read below). Never reaches a real Orca.
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


verb = argv[:2]
if argv[:2] == ["repo", "list"]:
    if "repofail" in MODE:
        sys.exit(1)
    out({"id": "x", "ok": True, "result": {"repos": [
        {"id": r["id"], "path": unc(r["path"]), "displayName": os.path.basename(r["path"]),
         "hookSettings": {"setupRunPolicy": "run-by-default", "setupAgentStartupPolicy": "start-immediately"}}
        for r in st["repos"]]}})
if verb == ["worktree", "list"]:
    st["lists"] = st.get("lists", 0) + 1
    if "listfail" in MODE or ("listfail2" in MODE and st["lists"] >= 2):
        save(); sys.exit(1)
    rid = (opt("--repo") or "")[3:]
    # Without --repo, Orca lists every repo's worktrees (measured in L55's U1).
    rows = [row(w) for w in st["wts"] if not rid or w["repoId"] == rid or "leak" in MODE]
    r = {"worktrees": rows, "hostScope": {"hostIds": ["local"], "omittedHostIds": []},
         "totalCount": len(rows), "truncated": False}
    if "listpartial" in MODE:
        r["truncated"] = True
    if "listomitted" in MODE:
        r["hostScope"]["omittedHostIds"] = ["ssh:x"]
    out({"id": "x", "ok": True, "result": r})
if verb == ["worktree", "create"]:
    if "createfail" in MODE:
        err("runtime_error", 'Could not refresh base ref "%s" from "origin".' % opt("--base-branch"))
    rid = (opt("--repo") or "")[3:]
    repo = [r for r in st["repos"] if r["id"] == rid][0]
    name, br, base = opt("--name"), opt("--branch"), opt("--base-branch")
    d = os.path.join(st["ws"], os.path.basename(repo["path"]))
    os.makedirs(d, exist_ok=True)
    p = os.path.join(d, name)
    if os.path.exists(p) or "suffix" in MODE:
        p, br = p + "-2", br + "-2"
    if "branchsuffix" in MODE:
        br += "-2"
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
        ag = [{"paneKey": "a:b", "state": "done", "agentType": "claude"}] \
            if os.path.basename(w["path"]) == os.environ.get("STUB_AGENT_ON") else []
        rows.append({"worktreeId": row(w)["id"], "repoId": w["repoId"], "agents": ag})
    r = {"worktrees": rows, "hostScope": {"hostIds": ["local"], "omittedHostIds": []},
         "totalCount": len(rows), "truncated": "pspartial" in MODE}
    out({"id": "x", "ok": True, "result": r})
if verb == ["worktree", "rm"]:
    w = find(opt("--worktree"))
    if "hookfail" in MODE:
        err("worktree_archive_hook_failed", "Archive hook failed", {"worktreePath": row(w)["path"], "outcome": "exited",
            "exitCode": 1, "output": "Command failed with exit code 1.\x1b[0m"})
    if "rmnoop" in MODE:
        out({"id": "x", "ok": True, "result": {"removed": True}})
    br = branch(w["path"])
    repo = [r for r in st["repos"] if r["id"] == w["repoId"]][0]
    git("-C", repo["path"], "worktree", "remove", "--force", w["path"])
    st["wts"].remove(w)
    if br and "keepbranch" not in MODE:
        tip = git("-C", repo["path"], "rev-parse", br).stdout.strip()
        on = git("-C", repo["path"], "for-each-ref", "--contains", tip, "refs/remotes/origin/").stdout.strip()
        if on:
            git("-C", repo["path"], "branch", "-D", br[len("refs/heads/"):])
    out({"id": "x", "ok": True, "result": {"removed": True}})
err("unknown_verb", "stub does not know " + " ".join(argv[:2]))

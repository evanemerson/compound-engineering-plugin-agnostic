#!/usr/bin/env bash
# Check for plugins/cepa/scripts/orca-lane.sh, the one checked form of
# `cepa:autonomy` §12b rule 2's lane lifecycle (punch-list L55). It runs the
# script in throwaway git repos (a bare origin and a main clone, with real
# worktrees) against scripts/fixtures/orca-lane-stub.py as `orca-ide` on
# PATH, so it never reaches a real Orca. The stub returns Orca's UNC paths and
# logs every call.
#
# Usage: check-orca-lane.sh [orca-lane.sh [SKILL.md]]
#   The optional paths replace the shipped script and the autonomy skill whose
#   rule 2 lane block the BLOCK leg runs. Only check-orca-lane-controls.sh
#   sets them, to run this check against a mutant.
#
# Every MISS line starts with its case name, so the controls can assert the
# exact set of cases each mutant breaks. Legs:
#   FIELDS — each bad field, missing field, extra line, argument, bad cli,
#            bad action, a field an action does not take, a bad lane or base,
#            and a linked worktree as the caller: exit 4, `refused`, and the
#            stub is never called.
#   SCOPE  — a same-named lane of another repo is never selected, renamed or
#            removed; a path from another WSL distro reads as UNKNOWN.
#   READS  — a failed, truncated or host-omitting list, or a failed or
#            truncated ps, is UNKNOWN: kept, and no write call is made.
#   CREATE — happy create (exact create argv, parked detached, park branch
#            deleted, show by id); a name taken in Orca or in git; a park
#            branch that exists; a failed create; a suffixed path; a
#            suffixed branch; a non-fixed name; a park branch with a commit;
#            a stale show. Each mismatch keeps the lane and deletes nothing.
#   NAME   — only automatic, non-main lanes with a <wt> basename are renamed,
#            by id; a second run renames none; a failed set and a set that
#            does not stick are failures.
#   RM     — happy rm of a parked lane (ignored files listed, exact rm argv,
#            absent from both lists) and of a lane on a branch; refusals on
#            an untracked file, a tracked change, a HEAD on no origin ref, a
#            reflog-only commit, a live agent, two lanes with one basename;
#            a failed archive hook (kept, exit 3, output scrubbed); a reply
#            that says removed while the lane stays; a re-list that fails.
#   BLOCK  — §12b rule 2's lane block, extracted and run under `bash -e`:
#            it runs `name`; shell text in a field runs nothing; with the
#            script absent it prints the skipped line.
set -u
cd "$(dirname "$0")/.." || { echo "MISS cannot enter repo root"; exit 1; }

CEPA_LANE_SCRIPT="$(realpath "${1:-plugins/cepa/scripts/orca-lane.sh}")" \
CEPA_LANE_SKILL="$(realpath "${2:-plugins/cepa/skills/autonomy/SKILL.md}")" \
python3 - <<'PY'
import json, os, re, shutil, subprocess, sys, tempfile, textwrap

SCRIPT = os.environ["CEPA_LANE_SCRIPT"]
SKILL = os.environ["CEPA_LANE_SKILL"]
STUB = os.path.realpath("scripts/fixtures/orca-lane-stub.py")
RESOLVE = os.path.realpath("plugins/cepa/scripts/resolve-plugin-root.sh")
passed = failed = 0
DISTRO = "Ubuntu-24.04"
RID, RID2 = "11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222"


def ok(name):
    global passed
    passed += 1


def miss(name):
    global failed
    failed += 1
    print("MISS " + name)


def sh(*a, cwd=None, check=True):
    r = subprocess.run(list(a), cwd=cwd, capture_output=True, text=True,
                       env=dict(os.environ, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1"))
    if check and r.returncode:
        raise RuntimeError("%s: %s" % (a, r.stderr))
    return r.stdout.strip()


def unc(p):
    return "\\\\wsl.localhost\\" + DISTRO + p.replace("/", "\\")


class World:
    """A bare origin, a main clone, an Orca workspace dir, a stub on PATH."""

    def __init__(self, tag):
        self.d = tempfile.mkdtemp(prefix="cepa-lane-%s-" % tag)
        self.origin = os.path.join(self.d, "origin.git")
        self.main = os.path.join(self.d, "repo")
        self.other = os.path.join(self.d, "other")
        sh("git", "init", "-q", "--bare", "-b", "main", self.origin)
        sh("git", "clone", "-q", self.origin, self.main)
        self.git("checkout", "-q", "-b", "main")
        open(os.path.join(self.main, ".gitignore"), "w").write("node_modules/\n")
        open(os.path.join(self.main, "f.txt"), "w").write("a\n")
        self.git("add", ".")
        self.commit("init")
        self.git("push", "-q", "origin", "main")
        self.git("fetch", "-q", "origin")
        os.makedirs(self.other)
        self.ws = os.path.join(self.d, "ws")
        os.makedirs(self.ws)
        self.bin = os.path.join(self.d, "bin")
        os.makedirs(self.bin)
        os.symlink(STUB, os.path.join(self.bin, "orca-ide"))
        self.state = os.path.join(self.d, "state.json")
        self.log = os.path.join(self.d, "calls.log")
        self.st = {"distro": DISTRO, "ws": self.ws,
                   "repos": [{"id": RID, "path": self.main}, {"id": RID2, "path": self.other}],
                   "wts": [{"repoId": RID, "path": self.main, "name": "main", "mode": "automatic", "main": True}]}
        self.save()

    def git(self, *a, cwd=None):
        return sh("git", *a, cwd=cwd or self.main)

    def commit(self, msg, cwd=None):
        self.git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", msg, cwd=cwd)

    def save(self):
        json.dump(self.st, open(self.state, "w"))

    def load(self):
        self.st = json.load(open(self.state))
        return self.st

    def lane(self, name, where="ws", mode="fixed", repo=RID, branch=None, register=True):
        """A real worktree, parked at origin/main unless a branch is given."""
        p = os.path.join(self.ws, "repo", name) if where == "ws" else os.path.join(self.main, ".claude", "worktrees", name)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        if branch:
            self.git("worktree", "add", "-q", "-b", branch, p, "origin/main")
        else:
            self.git("worktree", "add", "-q", "--detach", p, "origin/main")
        if register:
            self.load()
            self.st["wts"].append({"repoId": repo, "path": p, "name": name, "mode": mode, "main": False})
            self.save()
        return p

    def wid(self, p, repo=RID):
        return repo + "::" + unc(p)

    def run(self, fields, mode="", cwd=None, args=(), env=None):
        open(self.log, "w").close()
        self.load(); self.st["lists"] = 0; self.save()
        e = dict(os.environ, PATH=self.bin + ":" + os.environ["PATH"], STUB_STATE=self.state, STUB_LOG=self.log,
                 STUB_MODE=mode, WSL_DISTRO_NAME=DISTRO, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1")
        e.pop("ORCA_CLI_COMMAND", None)
        e.update(env or {})
        r = subprocess.run(["bash", SCRIPT, *args], input=fields, cwd=cwd or self.main, capture_output=True,
                           text=True, env=e, timeout=120)
        calls = [json.loads(l) for l in open(self.log) if l.strip()]
        return r.returncode, r.stdout.splitlines(), calls

    def done(self):
        shutil.rmtree(self.d, ignore_errors=True)


def F(**kw):
    order = ["cli", "action", "lane", "base"]
    return "".join("%s: %s\n" % (k, kw[k]) for k in order if k in kw)


def expect(name, got, rc=None, first=None, has=(), lacks=(), calls_none=False, verbs_lack=()):
    rc_, out, calls = got
    why = []
    if rc is not None and rc_ != rc:
        why.append("rc=%s want %s" % (rc_, rc))
    if first is not None and not (out and out[0].startswith(first)):
        why.append("first line %r want %r…" % (out[:1], first))
    text = "\n".join(out)
    for h in has:
        if h not in text:
            why.append("missing %r" % h)
    for h in lacks:
        if h in text:
            why.append("has %r" % h)
    if calls_none and calls:
        why.append("stub called %r" % calls[:2])
    for v in verbs_lack:
        if any(c[:2] == v for c in calls):
            why.append("made a %s call" % " ".join(v))
    (miss if why else ok)("%s: %s | out=%r" % (name, "; ".join(why), out[:4]) if why else name)


def verbs(calls):
    return [c[:2] for c in calls]


CLI = "orca-ide"
W = World("fields")
# ---- FIELDS
R = "ORCA lane refused: "
cases = [
    ("FIELDS argument", F(cli=CLI, action="name"), ("x",), "orca-lane.sh takes no arguments"),
    ("FIELDS not a field line", "cli orca-ide\n", (), "a heredoc line is not a <name>: <value> field"),
    ("FIELDS unknown field", F(cli=CLI, action="name") + "run: x\n", (), "a field name is not cli, action, lane or base"),
    ("FIELDS duplicate", F(cli=CLI, action="name") + "cli: orca-ide\n", (), "the cli field is given twice"),
    ("FIELDS line after fields", F(cli=CLI, action="name") + "\nrm -rf x\n", (), "the heredoc holds a line after its fields"),
    ("FIELDS missing cli", "action: name\n", (), "the cli field is missing"),
    ("FIELDS cli with shell text", "cli: orca-ide$(touch x)\naction: name\n", (), "the cli is not a plain command name"),
    ("FIELDS cli not orca", F(cli="bash", action="name"), (), "the cli does not name an Orca CLI"),
    ("FIELDS cli relative path", F(cli="bin/orca-ide", action="name"), (), "a cli path must be absolute"),
    ("FIELDS missing action", "cli: orca-ide\n", (), "the action field is missing"),
    ("FIELDS bad action", F(cli=CLI, action="remove"), (), "the action is not create, name or rm"),
    ("FIELDS name with lane", F(cli=CLI, action="name", lane="x"), (), "name takes no lane field"),
    ("FIELDS name with base", F(cli=CLI, action="name", base="main"), (), "name takes no base field"),
    ("FIELDS rm with base", F(cli=CLI, action="rm", lane="x", base="main"), (), "rm takes no base field"),
    ("FIELDS rm without lane", F(cli=CLI, action="rm"), (), "the lane field is missing"),
    ("FIELDS create without base", F(cli=CLI, action="create", lane="x"), (), "the base field is missing"),
    ("FIELDS create without lane", F(cli=CLI, action="create", base="main"), (), "the lane field is missing"),
    ("FIELDS lane double dash", F(cli=CLI, action="rm", lane="a--b"), (), "the lane is not a <wt> name"),
    ("FIELDS lane leading dash", F(cli=CLI, action="rm", lane="-x"), (), "the lane is not a <wt> name"),
    ("FIELDS lane slash", F(cli=CLI, action="rm", lane="a/b"), (), "the lane is not a <wt> name"),
    ("FIELDS lane shell text", F(cli=CLI, action="rm", lane="x$(touch m)"), (), "the lane is not a <wt> name"),
    ("FIELDS lane too long", F(cli=CLI, action="rm", lane="a" * 65), (), "the lane is not a <wt> name"),
    ("FIELDS lane main", F(cli=CLI, action="rm", lane="main"), (), "the lane may not be main"),
    ("FIELDS base leading dash", F(cli=CLI, action="create", lane="x", base="-main"), (), "the base is not a branch name"),
    ("FIELDS base dotdot", F(cli=CLI, action="create", lane="x", base="a..b"), (), "the base is not a valid branch name"),
]
for name, fields, args, reason in cases:
    expect(name, W.run(fields, args=args), rc=4, first=R + reason, calls_none=True)
lp = W.lane("linked", register=False)
expect("FIELDS linked worktree caller", W.run(F(cli=CLI, action="name"), cwd=lp), rc=4,
       first=R + "run it from the main checkout", calls_none=True)
W.done()

# ---- SCOPE
W = World("scope")
W.lane("alpha", mode="automatic", repo=RID2)  # a worktree of the main clone, registered to ANOTHER repo id
W.load(); W.st["wts"].append({"repoId": RID2, "path": W.other, "name": "other", "mode": "automatic", "main": True}); W.save()
got = W.run(F(cli=CLI, action="rm", lane="alpha"), mode="leak")
expect("SCOPE rm never selects another repo's lane", got, rc=1, first="ORCA lane: kept alpha — no lane of this repo",
       verbs_lack=[["worktree", "rm"]])
got = W.run(F(cli=CLI, action="name"), mode="leak")
expect("SCOPE name never renames another repo's lane", got, rc=0, has=("named 0 lane(s)",), verbs_lack=[["worktree", "set"]])
rc_, out, calls = got
lists = [c for c in calls if c[:2] == ["worktree", "list"]]
(ok if lists and all("--repo" in c and c[c.index("--repo") + 1] == "id:" + RID for c in lists) else miss)(
    "SCOPE list is scoped by repo id" + ("" if lists else ": no list call"))
W.done()
W = World("distro")
W.lane("beta", mode="automatic")
expect("SCOPE another distro's path is UNKNOWN", W.run(F(cli=CLI, action="name"), mode="otherdistro"), rc=1,
       first="ORCA lane: no lane renamed — worktree list was not a complete read", verbs_lack=[["worktree", "set"]])
W.done()

# ---- READS
W = World("reads")
W.lane("gamma", mode="automatic")
# One lane per rm case, so a mutant that lets one removal through cannot
# change what a later case sees.
for m in ("listfail", "listpartial", "listomitted"):
    expect("READS %s is UNKNOWN for name" % m, W.run(F(cli=CLI, action="name"), mode=m), rc=1,
           first="ORCA lane: no lane renamed", verbs_lack=[["worktree", "set"]])
    W.lane("g-" + m)
    expect("READS %s is UNKNOWN for rm" % m, W.run(F(cli=CLI, action="rm", lane="g-" + m), mode=m), rc=1,
           first="ORCA lane: g-%s unchanged — worktree list was not a complete read" % m, verbs_lack=[["worktree", "rm"]])
    expect("READS %s is UNKNOWN for create" % m, W.run(F(cli=CLI, action="create", lane="new1", base="main"), mode=m),
           rc=1, first="ORCA lane: new1 unchanged", verbs_lack=[["worktree", "create"]])
for m, why in (("psfail", "worktree ps failed"), ("pspartial", "worktree ps was not a complete read"),
               ("psmissing", "worktree ps was not a complete read")):
    W.lane("g-" + m)
    expect("READS %s keeps the lane" % m, W.run(F(cli=CLI, action="rm", lane="g-" + m), mode=m), rc=1,
           first="ORCA lane: kept g-%s — %s" % (m, why), verbs_lack=[["worktree", "rm"]])
expect("READS repo list failure", W.run(F(cli=CLI, action="name"), mode="repofail"), rc=1,
       first="ORCA lane: lanes unchanged — repo list failed")
W.done()

# ---- CREATE
W = World("create")
got = W.run(F(cli=CLI, action="create", lane="delta", base="main"))
rc_, out, calls = got
p = os.path.join(W.ws, "repo", "delta")
expect("CREATE happy", got, rc=0, first="ORCA lane: created delta at " + p, has=("parked detached at", "named delta (fixed)",
       "setup policy run-by-default", "Orca reports no setup result"))
cr = [c for c in calls if c[:2] == ["worktree", "create"]]
want = ["worktree", "create", "--repo", "id:" + RID, "--name", "delta", "--branch", "chore/delta/park",
        "--base-branch", "origin/main", "--no-parent", "--setup", "inherit", "--json"]
(ok if cr == [want] else miss)("CREATE exact create argv" + ("" if cr == [want] else ": %r" % cr))
br = sh("git", "-C", W.main, "branch", "--list", "chore/delta/park")
head = sh("git", "-C", p, "rev-parse", "HEAD") if os.path.isdir(p) else ""
sym = subprocess.run(["git", "-C", p, "symbolic-ref", "-q", "HEAD"], capture_output=True).returncode if os.path.isdir(p) else 0
(ok if not br and head == sh("git", "-C", W.main, "rev-parse", "origin/main") and sym == 1 else miss)(
    "CREATE parks detached at origin/main and deletes the park branch" +
    ("" if not br and sym == 1 else ": branch=%r detached=%s" % (br, sym == 1)))
sh_ = [c for c in calls if c[:2] == ["worktree", "show"]]
(ok if sh_ == [["worktree", "show", "--worktree", "id:" + W.wid(p), "--json"]] else miss)(
    "CREATE show by full id" + ("" if len(sh_) == 1 else ": %r" % sh_))
expect("CREATE name taken in Orca", W.run(F(cli=CLI, action="create", lane="delta", base="main")), rc=1,
       first="ORCA lane: not created — Orca already lists a worktree named delta", verbs_lack=[["worktree", "create"]])
W.lane("eps", where="claude", register=False)
expect("CREATE name taken in git only", W.run(F(cli=CLI, action="create", lane="eps", base="main")), rc=1,
       first="ORCA lane: not created — git worktree list already has a worktree named eps",
       verbs_lack=[["worktree", "create"]])
W.git("branch", "chore/zeta/park", "origin/main")
expect("CREATE park branch exists", W.run(F(cli=CLI, action="create", lane="zeta", base="main")), rc=1,
       first="ORCA lane: not created — branch chore/zeta/park already exists", verbs_lack=[["worktree", "create"]])
expect("CREATE create fails", W.run(F(cli=CLI, action="create", lane="eta", base="main"), mode="createfail"), rc=3,
       first="ORCA lane failed: worktree create failed (runtime_error)")
expect("CREATE suffixed path kept", W.run(F(cli=CLI, action="create", lane="theta", base="main"), mode="suffix"), rc=3,
       first="ORCA lane failed: Orca placed the lane at " + os.path.join(W.ws, "repo", "theta-2"),
       verbs_lack=[["worktree", "rm"]])
(ok if os.path.isdir(os.path.join(W.ws, "repo", "theta-2")) else miss)("CREATE suffixed path left on disk")
got = W.run(F(cli=CLI, action="create", lane="iota", base="main"), mode="branchsuffix")
expect("CREATE suffixed branch kept", got, rc=3, first="ORCA lane failed: the new lane is on branch 'chore/iota/park-2'")
(ok if sh("git", "-C", W.main, "branch", "--list", "chore/iota/park-2") else miss)("CREATE suffixed branch not deleted")
expect("CREATE name not fixed", W.run(F(cli=CLI, action="create", lane="kappa", base="main"), mode="automatic"), rc=3,
       first="ORCA lane failed: the new lane's display name is 'kappa' (automatic)")
got = W.run(F(cli=CLI, action="create", lane="lam", base="main"), mode="aheadcommit")
expect("CREATE park branch with a commit kept", got, rc=3, first="ORCA lane failed: chore/lam/park has 1 commit(s)")
(ok if sh("git", "-C", W.main, "branch", "--list", "chore/lam/park") else miss)("CREATE park branch with a commit not deleted")
expect("CREATE stale show", W.run(F(cli=CLI, action="create", lane="mu", base="main"), mode="showstale"), rc=3,
       first="ORCA lane failed: the lane is created and parked", has=("'mu automatic'",))
W.done()

# ---- NAME
W = World("name")
pa = W.lane("alpha", mode="automatic", where="claude")
W.lane("fixedone", mode="fixed")
W.lane("bad.name", mode="automatic", where="claude")
got = W.run(F(cli=CLI, action="name"))
rc_, out, calls = got
expect("NAME renames automatic non-main lanes only", got, rc=0, has=("ORCA lane: named alpha", "named 1 lane(s); 1 already fixed; 1 skipped",
       "skipped " + os.path.join(W.main, ".claude", "worktrees", "bad.name")))
sets = [c for c in calls if c[:2] == ["worktree", "set"]]
want = [["worktree", "set", "--worktree", "id:" + W.wid(pa), "--display-name", "alpha", "--json"]]
(ok if sets == want else miss)("NAME set by full id only" + ("" if sets == want else ": %r" % sets))
expect("NAME second run is a no-op", W.run(F(cli=CLI, action="name")), rc=0, has=("named 0 lane(s); 2 already fixed",),
       verbs_lack=[["worktree", "set"]])
W.lane("beta", mode="automatic")
expect("NAME set fails", W.run(F(cli=CLI, action="name"), mode="setfail"), rc=3, has=("ORCA lane failed: worktree set failed",))
expect("NAME set that does not stick", W.run(F(cli=CLI, action="name"), mode="setnoop"), rc=3,
       has=("ORCA lane failed: after worktree set, beta reads 'automatic beta'",))
expect("NAME re-list fails", W.run(F(cli=CLI, action="name"), mode="listfail2"), rc=3,
       has=("ORCA lane failed: renamed 1 lane(s), but the re-list was not complete",))
W.done()

# ---- RM
W = World("rm")
p = W.lane("nu")
os.makedirs(os.path.join(p, "node_modules"))
open(os.path.join(p, "node_modules", "x.js"), "w").write("x")
got = W.run(F(cli=CLI, action="rm", lane="nu"))
rc_, out, calls = got
expect("RM happy parked", got, rc=0, has=("ORCA lane: deleting ignored node_modules/",
       "ORCA lane: removed nu (" + p + ") — absent from Orca's list and git worktree list; 1 ignored path(s) deleted; it held no branch"))
rms = [c for c in calls if c[:2] == ["worktree", "rm"]]
want = [["worktree", "rm", "--worktree", "id:" + W.wid(p), "--run-hooks", "--json"]]
(ok if rms == want else miss)("RM exact rm argv (no --force, no waiver)" + ("" if rms == want else ": %r" % rms))
(ok if not os.path.exists(p) and p not in W.git("worktree", "list") else miss)("RM lane gone from git")
p = W.lane("xi", branch="feat/xi/work")
expect("RM lane on a pushed branch", W.run(F(cli=CLI, action="rm", lane="xi")), rc=0,
       has=("Orca deleted branch feat/xi/work",))
p = W.lane("omicron", branch="feat/omicron/work")
expect("RM branch Orca keeps", W.run(F(cli=CLI, action="rm", lane="omicron"), mode="keepbranch"), rc=0,
       has=("Orca kept branch feat/omicron/work",))
# One lane per case, so a mutant that lets one removal through cannot change
# what a later case sees.
p = W.lane("pi1")
open(os.path.join(p, "new.txt"), "w").write("x")
expect("RM untracked file", W.run(F(cli=CLI, action="rm", lane="pi1")), rc=1, first="ORCA lane: kept pi1 — it has changes (?? new.txt)",
       verbs_lack=[["worktree", "rm"]])
p = W.lane("pi2")
open(os.path.join(p, "f.txt"), "w").write("changed\n")
expect("RM tracked change", W.run(F(cli=CLI, action="rm", lane="pi2")), rc=1, first="ORCA lane: kept pi2 — it has changes ( M f.txt)",
       verbs_lack=[["worktree", "rm"]])
p = W.lane("pi3")
W.commit("local", cwd=p)
expect("RM HEAD on no origin ref", W.run(F(cli=CLI, action="rm", lane="pi3")), rc=1, first="ORCA lane: kept pi3 — HEAD",
       has=("is on no origin ref",), verbs_lack=[["worktree", "rm"]])
p = W.lane("pi4")
W.commit("local", cwd=p)
W.git("checkout", "-q", "--detach", "origin/main", cwd=p)
expect("RM reflog-only commit", W.run(F(cli=CLI, action="rm", lane="pi4")), rc=1,
       first="ORCA lane: kept pi4 — HEAD reflog holds a commit no origin ref has", verbs_lack=[["worktree", "rm"]])
p = W.lane("rho1")
expect("RM live agent", W.run(F(cli=CLI, action="rm", lane="rho1"), env={"STUB_AGENT_ON": "rho1"}), rc=1,
       first="ORCA lane: kept rho1 — 1 agent(s) on it", verbs_lack=[["worktree", "rm"]])
p = W.lane("rho2")
expect("RM archive hook fails", W.run(F(cli=CLI, action="rm", lane="rho2"), mode="hookfail"), rc=3,
       first="ORCA lane failed: the archive hook failed (exit 1: Command failed with exit code 1.?[0m)")
(ok if os.path.isdir(p) else miss)("RM archive hook failure keeps the lane")
W.lane("rho3")
expect("RM reply says removed but lane stays", W.run(F(cli=CLI, action="rm", lane="rho3"), mode="rmnoop"), rc=3,
       first="ORCA lane failed: removal not proved — rho3 is still in Orca's list")
W.lane("rho4")
expect("RM re-list fails after rm", W.run(F(cli=CLI, action="rm", lane="rho4"), mode="listfail2"), rc=3,
       first="ORCA lane failed: removal not proved — the re-list")
W.lane("sigma")
W.lane("sigma", where="claude")
expect("RM two lanes with one basename", W.run(F(cli=CLI, action="rm", lane="sigma")), rc=1,
       first="ORCA lane: kept sigma — 2 lanes", verbs_lack=[["worktree", "rm"]])
expect("RM unknown lane", W.run(F(cli=CLI, action="rm", lane="tau")), rc=1, first="ORCA lane: kept tau — no lane")
W.done()

# ---- BLOCK
W = World("block")
text = open(SKILL).read()
blocks = [textwrap.dedent(b) for b in re.findall(r"```bash\n(.*?)\n[ \t]*```", text, re.S) if 'scripts/orca-lane.sh" <<' in b]
b = blocks[0] if len(blocks) == 1 else ""
(ok if b else miss)("BLOCK exactly one lane block in rule 2" + ("" if b else ": found %d" % len(blocks)))
hm = re.search(r"<<'CEPA_FIELDS' \|\| true\n(.*?)\nCEPA_FIELDS\n", b, re.S)
h = hm.group(1).split("\n") if hm else []
(ok if [l.split(":", 1)[0] for l in h] == ["cli", "action", "lane", "base"] else miss)(
    "BLOCK quoted heredoc holds cli, action, lane, base: %r" % h[:5])
plug = os.path.join(W.d, "plug")
os.makedirs(os.path.join(plug, "scripts"))
shutil.copy(SCRIPT, os.path.join(plug, "scripts", "orca-lane.sh"))
shutil.copy(RESOLVE, os.path.join(plug, "scripts", "resolve-plugin-root.sh"))
open(os.path.join(plug, "scripts", "brain-client.sh"), "w").write("#!/bin/sh\nexit 0\n")
os.chmod(os.path.join(plug, "scripts", "brain-client.sh"), 0o755)
mark = os.path.join(W.d, "ran")


def fill(lane=None, base=None, action="name"):
    t = b
    if len(h) == 4:
        t = t.replace(h[0], "cli: orca-ide").replace(h[1], "action: " + action)
        t = t.replace(h[2] + "\n", "" if lane is None else "lane: %s\n" % lane)
        t = t.replace(h[3] + "\n", "" if base is None else "base: %s\n" % base)
    return t


def run_block(name, t, rc_want, first, plugdir=plug):
    bp = os.path.join(W.d, "block.sh")
    open(bp, "w").write("set -e\n" + t)
    e = dict(os.environ, PATH=W.bin + ":" + os.environ["PATH"], STUB_STATE=W.state, STUB_LOG=W.log, STUB_MODE="",
             WSL_DISTRO_NAME=DISTRO, CEPA_PLUGIN_ROOT=plugdir, CLAUDE_PLUGIN_ROOT="", CEPA_DEV="",
             HOME=os.path.join(W.d, "home"), GIT_CONFIG_GLOBAL="/dev/null")
    r = subprocess.run(["bash", bp], cwd=W.main, capture_output=True, text=True, env=e, timeout=120)
    lines = r.stdout.splitlines()
    why = []
    if r.returncode != rc_want:
        why.append("rc=%s" % r.returncode)
    if not (lines and lines[0].startswith(first)):
        why.append("out=%r" % lines[:2])
    if os.path.exists(mark):
        why.append("a filled value ran as a shell command")
    (miss if why else ok)("%s: %s" % (name, "; ".join(why)) if why else name)


run_block("BLOCK runs name", fill(), 0, "ORCA lane: named 0 lane(s)")
run_block("BLOCK shell text in the lane runs nothing", fill(lane="x$(touch %s)" % mark, action="rm"), 0,
          "ORCA lane refused: the lane is not a <wt> name")
run_block("BLOCK with the script absent is skipped", fill(), 0,
          "ORCA lane skipped: orca-lane.sh not found (set CEPA_PLUGIN_ROOT)", plugdir=os.path.join(W.d, "none"))
W.done()

print("-- %d/%d checks passed --" % (passed, passed + failed))
sys.exit(1 if failed else 0)
PY
